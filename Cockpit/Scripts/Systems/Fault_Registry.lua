-- GPL-3.0-or-later. Latest occurrence/history for a fixed equipment catalogue.
local M = { definitions = {
    { id = 'FCS', label = 'FLIGHT CONTROLS' },
    { id = 'GEN_L', label = 'L GENERATOR' },
    { id = 'GEN_R', label = 'R GENERATOR' },
    { id = 'HYD_L', label = 'L HYDRAULIC' },
    { id = 'HYD_R', label = 'R HYDRAULIC' },
    { id = 'OIL_L', label = 'L OIL PRESSURE' },
    { id = 'OIL_R', label = 'R OIL PRESSURE' },
    { id = 'CANOPY', label = 'CANOPY' },
} }
local function finite(value)
    return type(value) == 'number' and value == value and math.abs(value) < 1e9
end
function M.new()
    local registry = { records = {}, occurrence = 0, active = 0, unknown = 0, attention = 0 }
    for index, definition in ipairs(M.definitions) do
        registry.records[index] = { id = definition.id, label = definition.label,
            valid = false, active = false, occurrence = 0, acknowledged = 0, onset = 0, cleared = 0 }
    end
    function registry:update(now, conditions)
        if not finite(now) then return end
        self.active, self.unknown, self.attention, self.first = 0, 0, 0, nil
        for index = 1, #M.definitions do
            local record, condition = self.records[index], conditions[index]
            local valid = condition and condition.valid == true
            if valid then
                local active = condition.active == true
                if active and (not record.active or not record.valid) then
                    self.occurrence = math.min(16777215, self.occurrence + 1)
                    record.occurrence, record.acknowledged, record.onset = self.occurrence, 0, now
                elseif record.active and not active then record.cleared = now end
                record.active = active
            end
            record.valid = valid
            if not valid then self.unknown = self.unknown + 1
            elseif record.active then
                self.active = self.active + 1
                self.first = self.first or index
                if record.acknowledged ~= record.occurrence then self.attention = self.attention + 1 end
            end
        end
    end
    function registry:acknowledge()
        for index = 1, #M.definitions do
            local record = self.records[index]
            if record.valid and record.active then record.acknowledged = record.occurrence end
        end
        self.attention = 0
    end
    return registry
end
return M
