-- Pilot requests are always published. Only a coherent EFM snapshot supplies
-- achieved power; missing authority never starts another battery/APU model.
local Envelope = dofile(LockOn_Options.script_path .. 'Systems/Physical_Snapshot.lua')
local M = {}
local supply_fields = {
    'F22_ELECTRICAL_VALID', 'APU_RPM_STATE', 'APU_POWER', 'L_GEN_POWER',
    'R_GEN_POWER', 'MAIN_POWER', 'EFM_APU_AUTO_SHUTDOWN',
}
local binary_fields = {'APU_POWER', 'L_GEN_POWER', 'R_GEN_POWER',
    'MAIN_POWER', 'EFM_APU_AUTO_SHUTDOWN'}

local function valid_supply(values)
    local spool = values.APU_RPM_STATE
    if values.F22_ELECTRICAL_VALID ~= 1 or not Envelope.finite(spool)
        or spool < 0 or spool > 4 then return false end
    for index = 1, #binary_fields do
        if not Envelope.boolean(values[binary_fields[index]]) then return false end
    end
    return true
end

local function publish_requests(self, battery, left_generator, right_generator, apu)
    local h = self.handles
    h.F22_POWER_REQUEST_VALID:set(0)
    h.F22_BATTERY_REQUEST:set(battery == 1 and 1 or 0)
    h.F22_L_GEN_REQUEST:set(left_generator == 1 and 1 or 0)
    h.F22_R_GEN_REQUEST:set(right_generator == 1 and 1 or 0)
    h.F22_APU_REQUEST:set(apu == 1 and 1 or 0)
    self.sequence = self.sequence % 16777215 + 1
    h.F22_POWER_REQUEST_SEQUENCE:set(self.sequence)
    h.F22_POWER_REQUEST_VALID:set(1)
end

local function withdraw(self)
    self.valid = false
    self.apu_rpm, self.apu_power = nil, nil
    self.left_generator, self.right_generator, self.main = nil, nil, nil
    self.auto_shutdown = false
end

function M.new()
    local handles = {}
    local function get(key)
        if not handles[key] then handles[key] = get_param_handle(key) end
        return handles[key]:get()
    end
    local snapshot = Envelope.new(get, supply_fields)
    for _, key in ipairs({'F22_POWER_REQUEST_VALID', 'F22_BATTERY_REQUEST',
        'F22_L_GEN_REQUEST', 'F22_R_GEN_REQUEST', 'F22_APU_REQUEST',
        'F22_POWER_REQUEST_SEQUENCE'}) do get(key) end
    -- Initial cockpit selection only; provider arrival/recovery cannot reset
    -- a bleed or ECS selection made after this device was initialized.
    for _, key in ipairs({'F22_L_BLEED_REQUEST', 'F22_R_BLEED_REQUEST', 'F22_ECS_REQUEST'}) do
        get_param_handle(key):set(1)
    end
    local adapter = {handles = handles, sequence = 0, valid = false, auto_shutdown = false}
    function adapter:update(battery, left_generator, right_generator, apu)
        publish_requests(self, battery, left_generator, right_generator, apu)
        local frame = snapshot:update()
        if not frame.valid or not valid_supply(frame.values) then
            withdraw(self)
            return false
        end
        local values = frame.values
        self.valid = true
        self.apu_rpm, self.apu_power = values.APU_RPM_STATE, values.APU_POWER
        self.left_generator, self.right_generator = values.L_GEN_POWER, values.R_GEN_POWER
        self.main = values.MAIN_POWER
        self.auto_shutdown = values.EFM_APU_AUTO_SHUTDOWN == 1
        return true
    end
    return adapter
end
return M
