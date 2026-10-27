-- GPL-3.0-or-later. Read-only EW supply consumer, no separate power model.
local envelope = dofile(LockOn_Options.script_path..'Systems/Physical_Snapshot.lua')
local M = {}
M.__index = M

function M.new(get)
    return setmetatable({ get = get, snapshot = envelope.new(get, {
        'MAIN_POWER', 'F22_ELECTRICAL_VALID', 'EFM_MISSION_POWER_AVAILABLE',
    }), valid = false, electrical = false, mission_valid = false, mission = false }, M)
end

function M:update()
    local snapshot = self.snapshot:update()
    self.valid, self.electrical, self.mission_valid, self.mission = false, false, false, false
    if snapshot.owned then
        local values = snapshot.values
        self.valid = snapshot.valid and values.F22_ELECTRICAL_VALID == 1
            and envelope.boolean(values.MAIN_POWER)
        self.electrical = self.valid and values.MAIN_POWER == 1
        self.mission_valid = self.valid and envelope.boolean(values.EFM_MISSION_POWER_AVAILABLE)
        self.mission = self.mission_valid and self.electrical and values.EFM_MISSION_POWER_AVAILABLE == 1
    else
        local main = self.get('MAIN_POWER')
        self.valid = envelope.boolean(main)
        self.electrical = self.valid and main == 1
        self.mission_valid = self.valid
        self.mission = self.electrical -- Compatibility only before the owner latch.
    end
    return self
end

return M
