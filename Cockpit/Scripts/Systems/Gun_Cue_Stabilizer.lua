-- GPL-3.0-or-later. Target-lead cue damping in world rotation coordinates.
-- Current aircraft attitude and target LOS are never filtered here.
-- Cutoffs are presentation policies, not documented F-22 sight parameters.
local M = {}
local function group(count, minimum, maximum, beta)
    local value = {count=count,minimum=minimum,maximum=maximum,beta=beta,
        raw={},last={},rate={},filtered={}}
    for index=1,count*3 do
        value.raw[index],value.last[index],value.rate[index],value.filtered[index]=0,0,0,0
    end
    return value
end
local function rotation(from, to, raw, offset)
    local a=math.sqrt(from[1]^2+from[2]^2+from[3]^2)
    local b=math.sqrt(to[1]^2+to[2]^2+to[3]^2)
    if a<1e-8 or b<1e-8 then return false end
    local x,y,z=(from[2]*to[3]-from[3]*to[2])/(a*b),
        (from[3]*to[1]-from[1]*to[3])/(a*b),(from[1]*to[2]-from[2]*to[1])/(a*b)
    local square=x*x+y*y+z*z
    local cosine=(from[1]*to[1]+from[2]*to[2]+from[3]*to[3])/(a*b)
    if cosine<-.9 then return false end
    local length=math.sqrt(square)
    local gain=length>1e-8 and math.atan2(length,cosine)/length or 1
    raw[offset+1],raw[offset+2],raw[offset+3]=x*gain,y*gain,z*gain
    return true
end
local function advance(g, now)
    local dt=g.time and now-g.time or 0
    if g.time and dt==0 then return end
    if dt<=0 or dt>.1 then
        for i=1,g.count*3 do
            g.last[i],g.filtered[i],g.rate[i]=g.raw[i],g.raw[i],0
        end
    else
        local derivative=1-math.exp(-2*math.pi*dt)
        local speed=0
        for vector=0,g.count-1 do
            local square=0
            for axis=1,3 do
                local i=vector*3+axis
                g.rate[i]=g.rate[i]+derivative*((g.raw[i]-g.last[i])/dt-g.rate[i])
                square=square+g.rate[i]^2
            end
            speed=math.max(speed,math.sqrt(square))
        end
        -- All four maneuver references share one gain, preserving their
        -- coupling when a genuine maneuver changes the reference plane.
        local cutoff=math.min(g.maximum,g.minimum+g.beta*speed)
        local alpha=1-math.exp(-2*math.pi*cutoff*dt)
        for i=1,g.count*3 do
            g.filtered[i]=g.filtered[i]+alpha*(g.raw[i]-g.filtered[i])
        end
    end
    for i=1,g.count*3 do g.last[i]=g.raw[i] end
    g.time=now
end
local function apply(from, filtered, offset, out)
    local x,y,z=filtered[offset+1],filtered[offset+2],filtered[offset+3]
    local angle=math.sqrt(x*x+y*y+z*z)
    local sinc=angle<1e-5 and 1-angle^2/6 or math.sin(angle)/angle
    local cosc=angle<1e-5 and .5-angle^2/24 or (1-math.cos(angle))/angle^2
    local cosine=math.cos(angle)
    local along=x*from[1]+y*from[2]+z*from[3]
    out[1]=from[1]*cosine+(y*from[3]-z*from[2])*sinc+x*along*cosc
    out[2]=from[2]*cosine+(z*from[1]-x*from[3])*sinc+y*along*cosc
    out[3]=from[3]*cosine+(x*from[2]-y*from[1])*sinc+z*along*cosc
    local length=math.sqrt(from[1]^2+from[2]^2+from[3]^2)
    for axis=1,3 do out[axis]=out[axis]/length end
    return out
end
function M.new()
    local names={'LOW','HIGH','LEFT','RIGHT'}
    local state={lead=group(1,.8,40,40),references=group(4,1.2,8,5),aim={0,0,0},cues={}}
    for _,name in ipairs(names) do state.cues[name]={0,0,0} end
    function state:reset()
        self.lead.time=nil
        self.references.time=nil
    end
    function state:primary(now, aim, los)
        if not rotation(los,aim,self.lead.raw,0) then return end
        advance(self.lead,now)
        return apply(los,self.lead.filtered,0,self.aim)
    end
    function state:maneuver(now, cues, native_motion)
        self.references.minimum = native_motion and 8 or 1.2
        self.references.maximum = native_motion and 24 or 8
        for index,name in ipairs(names) do
            if not rotation(cues.base,cues[name],self.references.raw,(index-1)*3) then return end
        end
        advance(self.references,now)
        self.cues.base,self.cues.time=cues.base,cues.time
        for index,name in ipairs(names) do
            apply(cues.base,self.references.filtered,(index-1)*3,self.cues[name])
        end
        return self.cues
    end
    return state
end
return M
