-- GPL-3.0-or-later. Conditional stationary-ground RF location estimate.
-- Own bearing-only model; no target positions, radar range or terrain queries.
local M = {
    window = 45, max_samples = 32, sample_interval = 1.5, max_tracks = 16, min_samples = 5,
    min_span = 8, min_baseline = 1000, min_cross_baseline = 100,
    min_parallax = math.rad(5), max_rms = math.rad(.6), max_error = math.rad(1.5),
    assumed_angle_error = math.rad(1), ground_motion_allowance = 30,
    max_radius = 10000, max_relative_radius = .5, max_range = 300000,
    lifetime = 6,
}
local function finite(x)
    return type(x) == 'number' and x == x and math.abs(x) < 1e9
end
local function clamp(x, a, b) return math.max(a, math.min(b, x)) end
local function distance(a,b)
    return math.sqrt((a.n-b.n)^2+(a.u-b.u)^2+(a.e-b.e)^2)
end
local function valid(p)
    return type(p)=='table' and finite(p.time) and finite(p.n) and finite(p.u) and finite(p.e)
end
function M.position(sensors)
    if not sensors then return end
    local ok,n,u,e=pcall(function()return sensors.getSelfCoordinates()end)
    if ok and finite(n) and finite(u) and finite(e) then return {n=n,u=u,e=e} end
end
-- Preserve provenance and an explicit finite life. A new RF reception does
-- not renew an old solution. This is a model envelope, not a confidence level.
function M.current(fix, now)
    if not valid(fix) or not finite(now) or now-fix.time<-.01 or now-fix.time>M.lifetime
        or not finite(fix.radius) or fix.radius<=0 or fix.radius>M.max_radius
        or not finite(fix.samples) or fix.samples<M.min_samples or fix.samples>M.max_samples
        or fix.samples%1~=0 or not finite(fix.span) or fix.span<M.min_span or fix.span>M.window+.01
        or not finite(fix.residual) or fix.residual<0 or fix.residual>M.max_rms then return end
    local out={}
    for k,v in pairs(fix)do out[k]=v end
    out.age=math.max(0,now-fix.time)
    out.radius=fix.radius+M.ground_motion_allowance*out.age
    if out.radius>M.max_radius then return end
    return out
end
function M.relative(fix, now, position)
    local q=M.current(fix,now)
    if not q or not position or not finite(position.n)or not finite(position.u)or not finite(position.e)then return end
    local n,u,e=q.n-position.n,q.u-position.u,q.e-position.e
    q.range=math.sqrt(n*n+u*u+e*e)
    q.horizontal=math.sqrt(n*n+e*e)
    if q.range<500 or q.range>M.max_range or q.radius>q.range*M.max_relative_radius then return end
    q.bearing=math.atan2(e,n)
    q.elevation=math.atan2(u,q.horizontal)
    return q
end
local function state(reason)
    if reason=='samples'or reason=='span'then return 1 end -- collecting
    if reason=='maneuver'or reason=='baseline'then return 2 end -- need ownship baseline
    return 3 -- geometry, parallax, residual or uncertainty inhibits a fix
end
-- Sum squared perpendicular distances to observed 3-D LOS rays, translated
-- around the newest observer position for numerical conditioning.
function M.solve(samples)
    local count=#samples
    if count<M.min_samples then return nil,'samples' end
    for i,s in ipairs(samples)do
        if not valid(s)or type(s.direction)~='table'then return nil,'invalid'end
        local x,y,z=unpack(s.direction)
        if not finite(x)or not finite(y)or not finite(z)or math.abs(x*x+y*y+z*z-1)>.001 then
            return nil,'invalid'
        end
        if i>1 and s.time<=samples[i-1].time then return nil,'invalid'end
    end
    local first,last=samples[1],samples[count]
    if last.time-first.time<M.min_span then return nil,'span' end
    if count>M.max_samples or last.time-first.time>M.window+.01 then return nil,'invalid' end
    local baseline=distance(first,last)
    if baseline<M.min_baseline then return nil,'baseline' end
    local dn,de=last.n-first.n,last.e-first.e
    local horizontal=math.sqrt(dn*dn+de*de)
    if horizontal<1 then return nil,'baseline' end
    local curved,parallax=0,0
    local a,b,c,d,e,f=0,0,0,0,0,0
    local bn,bu,be=0,0,0
    for _,s in ipairs(samples)do
        if not valid(s) or not s.direction then return nil,'invalid' end
        local x,y,z=unpack(s.direction)
        if not finite(x)or not finite(y)or not finite(z)or math.abs(x*x+y*y+z*z-1)>.001 then
            return nil,'invalid'
        end
        local off=math.abs((s.n-first.n)*de-(s.e-first.e)*dn)/horizontal
        curved=math.max(curved,off)
        local dot=x*last.direction[1]+y*last.direction[2]+z*last.direction[3]
        parallax=math.max(parallax,math.acos(clamp(dot,-1,1)))
        local aa,bb,cc,dd,ee,ff=1-x*x,-x*y,-x*z,1-y*y,-y*z,1-z*z
        local n,u,v=s.n-last.n,s.u-last.u,s.e-last.e
        a,b,c,d,e,f=a+aa,b+bb,c+cc,d+dd,e+ee,f+ff
        bn,bu,be=bn+aa*n+bb*u+cc*v,bu+bb*n+dd*u+ee*v,be+cc*n+ee*u+ff*v
    end
    -- Ownship motion along a straight line cannot distinguish important
    -- moving-emitter ambiguities. Attitude changes alone create no baseline.
    if curved<M.min_cross_baseline then return nil,'maneuver' end
    if parallax<M.min_parallax then return nil,'parallax' end
    local determinant=a*(d*f-e*e)-b*(b*f-c*e)+c*(b*e-c*d)
    if determinant<=1e-9 then return nil,'geometry' end
    local aa,bb,cc,dd,ee,ff=(d*f-e*e)/determinant,(c*e-b*f)/determinant,
        (b*e-c*d)/determinant,(a*f-c*c)/determinant,(b*c-a*e)/determinant,
        (a*d-b*b)/determinant
    local fix={n=last.n+aa*bn+bb*bu+cc*be,u=last.u+bb*bn+dd*bu+ee*be,
        e=last.e+cc*bn+ee*bu+ff*be,time=last.time,samples=count,span=last.time-first.time}
    if not valid(fix)then return nil,'geometry' end
    local sum,maxrange=0,0
    for _,s in ipairs(samples)do
        local n,u,e=fix.n-s.n,fix.u-s.u,fix.e-s.e
        local r=math.sqrt(n*n+u*u+e*e)
        if r<500 or r>M.max_range then return nil,'range' end
        local dot=(n*s.direction[1]+u*s.direction[2]+e*s.direction[3])/r
        if dot<=0 then return nil,'behind' end
        local error=math.acos(clamp(dot,-1,1))
        if error>M.max_error then return nil,'inconsistent' end
        sum=sum+error*error;maxrange=math.max(maxrange,r)
    end
    fix.residual=math.sqrt(sum/count)
    if fix.residual>M.max_rms then return nil,'inconsistent' end
    local norm=math.max(math.abs(aa)+math.abs(bb)+math.abs(cc),
        math.abs(bb)+math.abs(dd)+math.abs(ee),math.abs(cc)+math.abs(ee)+math.abs(ff))
    -- Conservative model envelope, NOT calibrated ALR-94 covariance or a
    -- statistical confidence guarantee. Includes ground-motion allowance.
    fix.radius=math.max(3*maxrange*M.assumed_angle_error*math.sqrt(norm),maxrange*math.tan(M.assumed_angle_error))
        +M.ground_motion_allowance*fix.span
    local r=distance(fix,last)
    if not finite(fix.radius)or fix.radius>M.max_radius or fix.radius>r*M.max_relative_radius then
        return nil,'uncertainty'
    end
    return fix
end
local function position_at(history,time)
    for i=#history-1,1,-1 do
        local a,b=history[i],history[i+1]
        if time>=a.time and time<=b.time then
            local fraction=(time-a.time)/(b.time-a.time)
            return {n=a.n+(b.n-a.n)*fraction,u=a.u+(b.u-a.u)*fraction,
                e=a.e+(b.e-a.e)*fraction,time=time}
        end
    end
    local last=history[#history]
    if last and math.abs(time-last.time)<=.01 then
        return {n=last.n,u=last.u,e=last.e,time=time}
    end
end
function M.new()
    local s={history={},tracks={}}
    function s:reset()self.history={};self.tracks={};self.clock=nil end
    function s:update(now,position,contacts,bearings,power)
        for _,c in ipairs(contacts)do c.geolocation=nil;c.geolocation_status=0 end
        if not power or not finite(now)or not position or not finite(position.n)
            or not finite(position.u)or not finite(position.e)then self:reset();return end
        if self.clock and(now<self.clock or now-self.clock>.25)then self:reset()end
        local last=self.history[#self.history]
        if last and distance(last,position)>1200 then self:reset();last=nil end
        self.clock=now
        if last and now==last.time then table.remove(self.history)end
        self.history[#self.history+1]={n=position.n,u=position.u,e=position.e,time=now}
        while #self.history>2 and now-self.history[2].time>M.window+1 do table.remove(self.history,1)end
        local seen,total={},0
        for _,c in ipairs(contacts)do
            -- Checked common native taxonomy: 2=ground; not aircraft, ship or weapon.
            local received=bearings[c.source]
            if c.general==2 and c.bearing_compensated and received and received.world
                and finite(received.stamp)and received.stamp<=now+.01
                and now-received.stamp<=M.lifetime and total<M.max_tracks then
                seen[c.source]=true;total=total+1
                local t=self.tracks[c.source]or{samples={},reason='samples'}
                self.tracks[c.source]=t
                local latest=t.samples[#t.samples]
                if not t.received or received.stamp>t.received+1e-4 then
                    local at=position_at(self.history,received.stamp)
                    if at then
                        t.received=received.stamp
                        at.direction={unpack(received.world)}
                        -- Contradicting fresh evidence withdraws a fix immediately,
                        -- even between decimated fit samples.
                        if t.fix then
                            local n,u,e=t.fix.n-at.n,t.fix.u-at.u,t.fix.e-at.e
                            local r=math.sqrt(n*n+u*u+e*e)
                            local dot=r>0 and(n*at.direction[1]+u*at.direction[2]+e*at.direction[3])/r or -1
                            if math.acos(clamp(dot,-1,1))>M.max_error then
                                t.samples={};t.fix=nil;t.reason='inconsistent';latest=nil
                            end
                        end
                        -- Retain a useful time/baseline window instead of the
                        -- newest twelve 20-Hz callbacks (which can never fit).
                        if not latest or at.time-latest.time>=M.sample_interval-1e-6 then
                            t.samples[#t.samples+1]=at
                            while #t.samples>M.max_samples or (#t.samples>0 and at.time-t.samples[1].time>M.window) do
                                table.remove(t.samples,1)
                            end
                            t.fix,t.reason=M.solve(t.samples)
                            if t.reason=='inconsistent'or t.reason=='behind'then
                                -- New contradicting evidence withdraws the previous fix.
                                t.samples={at}
                            end
                        end
                    end
                end
                c.geolocation_status=state(t.reason)
                if M.current(t.fix,now)then c.geolocation=t.fix;c.geolocation_status=4 end
            end
        end
        for id in pairs(self.tracks)do if not seen[id]then self.tracks[id]=nil end end
    end
    return s
end
return M
