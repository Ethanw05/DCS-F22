-- Read-only engine workflow indications. Numeric states belong to the EFM.
local Envelope = dofile(LockOn_Options.script_path .. 'Systems/Physical_Snapshot.lua')
local M = {}
local phases = { 'OFF', 'CRANK', 'LIGHTING', 'ACCELERATING', 'RUN', 'SHUTDOWN', 'WINDMILL' }
local faults = { '', 'NO LIGHT', 'HUNG START', 'HOT START', 'CONTROL LOST', 'STARTER DUTY', 'DATA INVALID' }
local rejections = { '', 'NO FUEL', 'NO POWER', 'NO STARTER', 'DAMAGE', 'ISOLATED',
    'FAULT LATCHED', 'PURGE REQUIRED', 'COOL ENGINE', 'NO CONTROL', 'DATA INVALID',
    'WAIT ROTOR', 'RESET INHIBITED' }
local suffixes = { 'ENGINE_PHASE', 'START_FAULT', 'START_REJECTION', 'ENGINE_CONTROL',
    'PURGE_S', 'CONTROL_AVAILABLE', 'AUG_AVAILABLE', 'STARTER_ENGAGED', 'FUEL_VALVE',
    'STARTER_SELECTED', 'FUEL_SELECTED', 'IGNITION_SELECTED', 'START_RESET_READY' }

local function enumerated(value, maximum)
    return Envelope.finite(value) and value >= 0 and value <= maximum and value % 1 == 0
end

local function valid_side(v)
    if not enumerated(v[1], 6) or not enumerated(v[2], 6)
        or not enumerated(v[3], 12) or not enumerated(v[4], 2)
        or not Envelope.finite(v[5]) or v[5] < 0 or v[5] > 60 then return false end
    for index = 6, 13 do
        if not Envelope.boolean(v[index]) then return false end
    end
    if v[8] == 1 and v[10] == 0 then return false end
    if v[9] == 1 and v[11] == 0 then return false end
    if v[13] == 1 and v[2] == 0 then return false end
    return true
end

local function status(v)
    if v[2] ~= 0 then
        local action = v[13] == 1 and ' RESET READY' or ' INHIBIT'
        if v[5] > 0 then action = ' PURGE ' .. tostring(v[5]) .. 'S' end
        return faults[v[2] + 1] .. action
    end
    if v[3] ~= 0 and v[1] ~= 4 then return rejections[v[3] + 1] end
    if v[1] == 1 and v[9] == 0 then return 'DRY CRANK' end
    return phases[v[1] + 1]
end

local function control(v)
    if v[4] == 2 then return 'CONTROL LOST' end
    if v[6] == 0 then return 'CONTROL OFF' end
    if v[4] == 1 then return 'CONTROL DEGRADED' end
    return v[7] == 0 and 'CONTROL OK / AUG INHIBIT' or 'CONTROL OK'
end

local function changed(side)
    local different = not side.was_valid
    for index = 1, 13 do
        if side.last[index] ~= side.values[index] then different = true end
        side.last[index] = side.values[index]
    end
    side.was_valid = true
    return different
end

local function update_side(side, frame, publish)
    for index = 1, 13 do side.values[index] = frame.values[side.keys[index]] end
    local valid = frame.valid and frame.values.EFM_ENGINE_CONTROL_SCHEMA == 1 and valid_side(side.values)
    publish(side.valid_key, valid and 1 or 0)
    if not valid then
        side.was_valid = false
        publish(side.status_key, side.letter .. ' UNKNOWN')
        publish(side.control_key, 'CONTROL UNKNOWN')
        return
    end
    side.values[5] = math.ceil(side.values[5]) -- bounded, readable purge countdown
    if changed(side) then
        publish(side.status_key, side.letter .. ' ' .. status(side.values))
        publish(side.control_key, control(side.values))
    end
end

function M.new(get_handle)
    local handles, previous, sides = {}, {}, {}
    local function get(key)
        if not handles[key] then handles[key] = get_handle(key) end
        return handles[key] and handles[key]:get() or nil
    end
    local function publish(key, value)
        if previous[key] == value then return end
        previous[key] = value
        if not handles[key] then handles[key] = get_handle(key) end
        if handles[key] then handles[key]:set(value) end
    end
    local fields = { 'EFM_ENGINE_CONTROL_SCHEMA' }
    for index, letter in ipairs({ 'L', 'R' }) do
        local side = { letter = letter, values = {}, last = {}, keys = {}, was_valid = false,
            status_key = 'F22_ENGINE_' .. letter .. '_STATUS',
            control_key = 'F22_ENGINE_' .. letter .. '_CONTROL',
            valid_key = 'F22_ENGINE_' .. letter .. '_STATUS_VALID' }
        for field = 1, #suffixes do
            side.keys[field] = 'EFM_' .. letter .. '_' .. suffixes[field]
            fields[#fields + 1] = side.keys[field]
            side.values[field], side.last[field] = 0, -1
        end
        sides[index] = side
        publish(side.status_key, letter .. ' UNKNOWN')
        publish(side.control_key, 'CONTROL UNKNOWN')
        publish(side.valid_key, 0)
    end
    local frame = Envelope.new(get, fields)
    local instance = {}
    function instance.update()
        frame:update()
        for index = 1, 2 do update_side(sides[index], frame, publish) end
    end
    return instance
end
return M
