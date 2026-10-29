-- GPL-3.0-or-later. Awareness association; never grants radar or weapon authority.
local M = { maximum = 176 }
local RF=dofile(LockOn_Options.script_path..'Systems/Tactical_RF_Association.lua')
local History=dofile(LockOn_Options.script_path..'Systems/Tactical_Radar_History.lua')
local axes = {'n','u','e','vn','vu','ve'}
local order = {'radar','rf','mws','datalink','irst'}
local function finite(v) return type(v)=='number' and v==v and math.abs(v)<1e9 end
local function angular(a,b) return (a-b+math.pi)%(2*math.pi)-math.pi end
local function key(sensor,o)
    if sensor=='datalink' then
        return sensor..':'..tostring(o.link)..':'..tostring(o.reporter)..':'..tostring(o.epoch)..':'..o.source
    end
    if sensor=='radar' or sensor=='irst' then return sensor..':'..tostring(o.epoch)..':'..o.source end
    return sensor..':'..o.source
end
local function known_position(o,now)
    if o.observation_known==false or now-o.time<0 or now-o.time>13 then return end
    for _,k in ipairs(axes) do if not finite(o[k]) then return end end
    local dt=now-o.time
    return o.n+o.vn*dt,o.u+o.vu*dt,o.e+o.ve*dt
end
local function position_match(x,y,now,an,au,ae,bn,bu,be)
    local margin=500+25*(now-x.time+now-y.time)
    return (an-bn)^2+(au-bu)^2+(ae-be)^2<=margin^2
        and (x.vn-y.vn)^2+(x.vu-y.vu)^2+(x.ve-y.ve)^2<=100^2
end
local function current(entry,now)
    return now-entry.observation.time <= (entry.sensor=='datalink' and 13 or 1)
end
local function compatible(a,b,now)
    if a.sensor==b.sensor then return false end
    local x,y=a.observation,b.observation
    local matched
    if a.sensor=='radar' and b.sensor=='rf' then matched=RF.match(x,y,now,a.history)
    elseif b.sensor=='radar' and a.sensor=='rf' then matched=RF.match(y,x,now,b.history) end
    if matched~=nil then return matched end
    if not current(a,now) or not current(b,now) then return false end
    if math.abs(angular(x.az,y.az))>math.rad(3) or math.abs(x.el-y.el)>math.rad(3) then return false end
    local an,au,ae=a.n,a.u,a.e
    local bn,bu,be=b.n,b.u,b.e
    if an and bn then return position_match(x,y,now,an,au,ae,bn,bu,be) end
    if a.sensor=='datalink' or b.sensor=='datalink' then return false end
    return true
end
local function root(entries,index)
    for _=1,M.maximum do
        local parent=entries[index].parent
        if parent==index then return index end
        index=parent
    end
end
local function merge(entries,a,b)
    a,b=root(entries,a),root(entries,b)
    if not a or not b or a==b then return end
    local left,right=entries[a],entries[b]
    for _,sensor in ipairs(order) do if left.sensors[sensor] and right.sensors[sensor] then return end end
    if right.identity<left.identity then a=b;left,right=right,left end
    right.parent=a
    for _,sensor in ipairs(order) do left.sensors[sensor]=left.sensors[sensor] or right.sensors[sensor] end
end
local function clear(buffer)
    for k in pairs(buffer) do buffer[k]=nil end
end
local function prepare_entry(entry,o,sensor,id,index,now)
    entry.observation,entry.sensor,entry.identity,entry.parent=o,sensor,id,index
    clear(entry.candidates);clear(entry.counts);clear(entry.sensors)
    entry.sensors[sensor]=true
    entry.n,entry.u,entry.e=known_position(o,now)
end
function M.new()
    local state={entries={},identities={},scratch={},next_id=1,history=History.new()}
    function state:reset() clear(self.identities);clear(self.scratch);clear(self.history.tracks) end
    function state:prepare(batches,now,limits)
        self.history:update(batches.radar,now)
        local count,active=0,self.scratch
        clear(active)
        for _,sensor in ipairs(order) do
            local contacts=batches[sensor] and batches[sensor].contacts or {}
            for _,o in pairs(contacts) do
                if now-o.time<=limits[sensor] and count<M.maximum then
                    count=count+1
                    local identity=key(sensor,o)
                    local id=self.identities[identity]
                    if not id then id=self.next_id;self.next_id=self.next_id%16000000+1 end
                    active[identity]=id
                    local entry=self.entries[count]
                    if not entry then
                        entry={candidates={},counts={},sensors={}}
                        self.entries[count]=entry
                    end
                    prepare_entry(entry,o,sensor,id,count,now)
                    entry.history=sensor=='radar' and self.history.tracks[o.source] or nil
                end
            end
        end
        self.scratch,self.identities=self.identities,active
        return count
    end
    function state:associate(batches,now,limits)
        local count=self:prepare(batches,now,limits)
        local entries=self.entries
        for a=1,count do for b=a+1,count do
            local left,right=entries[a],entries[b]
            if compatible(left,right,now) then
                left.candidates[right.sensor]=b;right.candidates[left.sensor]=a
                left.counts[right.sensor]=(left.counts[right.sensor] or 0)+1
                right.counts[left.sensor]=(right.counts[left.sensor] or 0)+1
            end
        end end
        for a=1,count do
            local left=entries[a]
            for sensor,b in pairs(left.candidates) do
                if left.counts[sensor]==1 and entries[b].counts[left.sensor]==1 then merge(entries,a,b) end
            end
        end
        for index=1,count do
            local entry=entries[index]
            entry.observation.picture_source=entries[root(entries,index)].identity
        end
    end
    return state
end
return M
