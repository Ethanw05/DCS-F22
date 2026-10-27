-- Read-only, coherent achieved engine/circuit data. Limits below validate this
-- simulation payload; they are not production F119 operating limitations.
local Envelope = dofile(LockOn_Options.script_path .. 'Systems/Physical_Snapshot.lua')
local M = {}
local specifications = {
    {'rpm', 'RPM_PCT', 0, 120}, {'temperature', 'TEMP_C', -273.15, 4000},
    {'oil', 'OIL_PSI', 0, 400}, {'nozzle', 'NOZZLE_PCT', 0, 100},
    {'flow', 'FLOW_KG_S', 0, 1000}, {'hydraulic', nil, 0, 3950},
}

local function update_side(side, frame)
    local v = frame.values
    local qualified = frame.valid and v.EFM_ENGINE_INDICATION_SCHEMA == 1
        and v.EFM_ENGINE_VALID == 1 and v.EFM_VEHICLE_VALID == 1
    for index = 1, #specifications do
        local spec = specifications[index]
        local value = v[side.keys[index]]
        local valid = qualified and Envelope.finite(value) and value >= spec[3] and value <= spec[4]
        side.valid[spec[1]] = valid
        if valid then side[spec[1]] = value else side[spec[1]] = nil end
    end
end

function M.new(get_handle)
    local handles = {}
    local function get(key)
        if not handles[key] then handles[key] = get_handle(key) end
        return handles[key]:get()
    end
    local fields = {'EFM_ENGINE_INDICATION_SCHEMA', 'EFM_ENGINE_VALID', 'EFM_VEHICLE_VALID'}
    local sides = {}
    for index, name in ipairs({'LEFT', 'RIGHT'}) do
        local side = {keys = {}, valid = {}}
        for field = 1, #specifications do
            local spec = specifications[field]
            local key = spec[1] == 'hydraulic' and ('EFM_HYD_' .. name .. '_PSI')
                or ('EFM_ENGINE_' .. name .. '_' .. spec[2])
            side.keys[field], side.valid[spec[1]] = key, false
            fields[#fields + 1] = key
        end
        sides[index] = side
    end
    local snapshot = Envelope.new(get, fields)
    local reader = {left = sides[1], right = sides[2]}
    function reader:update()
        local frame = snapshot:update()
        update_side(self.left, frame)
        update_side(self.right, frame)
        return self
    end
    return reader
end
return M
