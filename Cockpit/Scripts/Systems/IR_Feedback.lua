-- GPL-3.0-or-later. Qualified native seeker feedback, never an acquisition model.
-- Schema1 timestamps use absolute World model time, not F22_AP_CLOCK.
-- Ownership history is diagnostic; every active sample requires this schema.
local M = { maximum_age = .1, future_tolerance = .05 }
M.__index = M
local fields = {'F22_IR_SAMPLE_OWNER', 'F22_IR_SAMPLE_SCHEMA', 'F22_IR_SAMPLE_VALID',
    'F22_IR_SAMPLE_SEQUENCE', 'F22_IR_SAMPLE_TIME', 'F22_IR_SAMPLE_STATION',
    'F22_IR_SAMPLE_GENERATION', 'F22_IR_AVAILABLE', 'F22_IR_LOCK', 'F22_IR_STRENGTH',
    'F22_IR_WORLD_VALID', 'F22_IR_WORLD_FWD_N', 'F22_IR_WORLD_FWD_U', 'F22_IR_WORLD_FWD_E',
    'F22_IR_STATION', 'F22_IR_STORE_GENERATION'}

local function finite(value)
    return type(value) == 'number' and value == value and math.abs(value) < math.huge
end

local function integer(value, maximum)
    return finite(value) and value >= 0 and value <= maximum and value % 1 == 0
end

local function current(time, now)
    return finite(time) and time >= 0 and finite(now) and now >= 0
        and now - time >= -M.future_tolerance and now - time <= M.maximum_age
end

local function same_frame(get, schema, valid, sequence, time, station, generation)
    return schema == 1 and get('F22_IR_SAMPLE_SCHEMA') == 1
        and valid == 1 and get('F22_IR_SAMPLE_VALID') == 1
        and sequence == get('F22_IR_SAMPLE_SEQUENCE') and time == get('F22_IR_SAMPLE_TIME')
        and station == get('F22_IR_SAMPLE_STATION') and generation == get('F22_IR_SAMPLE_GENERATION')
end

local function selected(get, station, generation)
    return integer(station, 10) and integer(generation, 16777215)
        and station == get('F22_IR_STATION') and generation == get('F22_IR_STORE_GENERATION')
end

local function committed(sequence, time, now)
    return integer(sequence, 16777214) and sequence >= 2 and sequence % 2 == 0 and current(time, now)
end

local function qualified(get, owner, owner_after, schema, valid, sequence, time, station, generation, now)
    return owner == 1 and owner_after == 1
        and same_frame(get, schema, valid, sequence, time, station, generation)
        and committed(sequence, time, now) and selected(get, station, generation)
end

local function valid_signal(available, locked, strength)
    return available == 1 and (locked == 0 or locked == 1)
        and finite(strength) and strength >= 0 and strength <= 2
end

local function withdraw(self)
    self.valid, self.available, self.locked, self.world_valid = false, false, false, false
    self.strength = 0
end

function M.new(get)
    for index = 1, #fields do get(fields[index]) end
    return setmetatable({ get = get, owned = false, valid = false, available = false,
        locked = false, world_valid = false, strength = 0, n = 0, u = 0, e = 0,
        sequence = 0, time = 0, station = -1, generation = -1 }, M)
end

function M:update(enabled, now)
    withdraw(self)
    local get = self.get
    local owner = get('F22_IR_SAMPLE_OWNER')
    if owner == 1 then self.owned = true end
    local schema, valid = get('F22_IR_SAMPLE_SCHEMA'), get('F22_IR_SAMPLE_VALID')
    local sequence, time = get('F22_IR_SAMPLE_SEQUENCE'), get('F22_IR_SAMPLE_TIME')
    local station, generation = get('F22_IR_SAMPLE_STATION'), get('F22_IR_SAMPLE_GENERATION')
    local available, locked, strength = get('F22_IR_AVAILABLE'), get('F22_IR_LOCK'), get('F22_IR_STRENGTH')
    local world, n, u, e = get('F22_IR_WORLD_VALID'), get('F22_IR_WORLD_FWD_N'),
        get('F22_IR_WORLD_FWD_U'), get('F22_IR_WORLD_FWD_E')
    local owner_after = get('F22_IR_SAMPLE_OWNER')
    if owner_after == 1 then self.owned = true end
    if not enabled then return self end
    if not qualified(get, owner, owner_after, schema, valid, sequence,
        time, station, generation, now) then return self end
    if not valid_signal(available, locked, strength) then return self end
    self.valid, self.available, self.locked = true, true, locked == 1
    self.strength, self.world_valid = strength, world == 1
    self.n, self.u, self.e = n, u, e
    self.sequence, self.time, self.station, self.generation = sequence, time, station, generation
    return self
end

return M
