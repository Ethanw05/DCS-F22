-- Read-only clock/generation admission; never advances physical state or source time.
local Envelope=dofile(LockOn_Options.script_path..'Systems/Physical_Snapshot.lua')
local M={}
M.__index=M
local function bounded(value)
    return Envelope.finite(value) and value>=0 and value<1e9
end
function M.new()
    return setmetatable({},M)
end
function M:reset()
    self.last_world,self.generation,self.retired_generation=nil,nil,nil
    self.world_age=nil
end
function M:generation_current(generation,kind,available)
    if available~=true or kind~=2 then return false end
    if not Envelope.finite(generation) or generation<1 or generation>4294967295
        or generation%1~=0 then return false end
    if self.generation and generation<self.generation then return false end
    if self.retired_generation and generation<=self.retired_generation then return false end
    self.generation=generation
    return true
end
function M:sample(generation,kind,stamp,available,now)
    if not bounded(now) then return false end
    if self.last_world and now<self.last_world then self.retired_generation=self.generation end
    self.last_world=now
    if not self:generation_current(generation,kind,available) then return false end
    if not bounded(stamp) then return false end
    self.world_age=now-stamp
    return self.world_age>=-.01 and self.world_age<=.25
end
function M:update(physical,now)
    return self:sample(physical.generation,physical.values.EFM_PHYSICAL_WORLD_CLOCK_KIND,
        physical.values.EFM_PHYSICAL_WORLD_STAMP,physical.valid,now)
end
function M.clock()
    local ok,value=pcall(get_model_time)
    if ok and bounded(value) then return value end
end
return M
