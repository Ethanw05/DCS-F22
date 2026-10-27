-- Read-only SEN-09 consumer of the flight owner's physical publication.
-- The 0.25 s freshness limit / 0.05 s future tolerance are mod adapter policies.
local M = { maximum_age = 0.25, future_tolerance = 0.05 }
M.__index = M

local names = {
    'EFM_POWER_OWNER', 'EFM_PHYSICAL_VALID', 'EFM_PHYSICAL_GENERATION',
    'EFM_PHYSICAL_STAMP', 'EFM_PHYSICAL_CLOCK_KIND', 'F22_AP_CLOCK',
    'EFM_UTILITY_AVAILABLE', 'EFM_MISSION_POWER_AVAILABLE',
    'F22_ELECTRICAL_VALID', 'MAIN_POWER',
    'EFM_VEHICLE_VALID', 'EFM_ACTUATOR_AVAILABLE',
}

local function finite(value)
    return type(value) == 'number' and value == value and math.abs(value) < math.huge
end

local function boolean(value)
    return value == 0 or value == 1
end

local function coherent(owner, owner_after, valid, valid_after, generation,
    generation_after, stamp, stamp_after, kind, kind_after)
    return owner == 1 and owner_after == 1 and valid == 1 and valid_after == 1
        and generation == generation_after and stamp == stamp_after
        and kind == 1 and kind_after == 1
end

local function valid_epoch(generation, stamp, clock)
    if not finite(generation) or generation < 1 or generation > 4294967295
        or generation % 1 ~= 0 or not finite(stamp) or stamp < 0
        or not finite(clock) or clock < 0 then return false end
    local age = clock - stamp
    return age >= -M.future_tolerance and age <= M.maximum_age
end

local function valid_payload(utility, mission, electrical, main)
    return finite(utility) and utility >= 0 and utility <= 1
        and boolean(mission) and electrical == 1 and boolean(main)
end

local function withdraw(self)
    self.valid, self.utility_valid = false, false
    self.electrical, self.mission, self.utility = false, false, 0
end

local function legacy(self)
    local main = self.handles[10]:get()
    self.electrical = finite(main) and main > 0.5
    self.mission = self.electrical
    -- Older DLLs lack the owned utility publication. Retain their existing
    -- actuator fallback only until the new owner has ever been observed.
    self.utility_valid = self.handles[11]:get() == 1
    local supply = self.handles[12]:get()
    self.utility = not self.utility_valid and 1
        or finite(supply) and math.max(0, math.min(1, supply)) or 0
end

function M.new()
    local self = setmetatable({ handles = {}, owned = false, valid = false,
        utility_valid = false, electrical = false, mission = false, utility = 0,
        generation = 0, stamp = 0 }, M)
    for index = 1, #names do self.handles[index] = get_param_handle(names[index]) end
    return self
end

function M:update()
    withdraw(self)
    local h = self.handles
    local owner = h[1]:get()
    if owner == 1 then self.owned = true end
    if not self.owned then
        legacy(self)
        owner = h[1]:get()
        if owner ~= 1 then return self end
        self.owned = true
        withdraw(self)
    end

    local valid, generation, stamp, kind = h[2]:get(), h[3]:get(), h[4]:get(), h[5]:get()
    local utility, mission, electrical, main = h[7]:get(), h[8]:get(), h[9]:get(), h[10]:get()
    local clock = h[6]:get() -- Spawn-relative RAPTOR clock, never World model time.
    local valid_after, generation_after, stamp_after = h[2]:get(), h[3]:get(), h[4]:get()
    local kind_after, owner_after = h[5]:get(), h[1]:get()
    if not coherent(owner, owner_after, valid, valid_after, generation,
        generation_after, stamp, stamp_after, kind, kind_after) then return self end
    if not valid_epoch(generation, stamp, clock)
        or not valid_payload(utility, mission, electrical, main) then return self end

    self.valid, self.utility_valid = true, true
    self.electrical, self.mission = main == 1, main == 1 and mission == 1
    self.utility, self.generation, self.stamp = utility, generation, stamp
    return self
end

return M
