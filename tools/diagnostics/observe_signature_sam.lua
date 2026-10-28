-- GPL-3.0-or-later. Passive mission-side radar observations, never AI control.
-- The caller supplies at most64 group names and one aircraft unit name.
local M = {}

local function object_id(object)
    if not object then return nil end
    local ok, value = pcall(object.getID, object)
    if ok and type(value) == 'number' and value > 0 then return value end
end

local function radar_detection(controller, own_id, radar_kind)
    if type(radar_kind) ~= 'number' then return false, false end
    if type(controller) ~= 'table' and type(controller) ~= 'userdata' then return false, false end
    local ok, targets = pcall(controller.getDetectedTargets, controller, radar_kind)
    if not ok or type(targets) ~= 'table' then return false, false end
    local count, found = 0, false
    for _, target in pairs(targets) do
        count = count + 1
        if count > 64 then return false, found end
        if type(target) == 'table' and object_id(target.object) == own_id then found = true end
    end
    return true, found
end

local function radar_track(unit, own_id)
    if not unit then return false, false, false end
    local ok, on, target = pcall(unit.getRadar, unit)
    if not ok or type(on) ~= 'boolean' then return false, false, false end
    return true, on, object_id(target) == own_id
end

local function observe_unit(api, now, group_name, unit, own_id, truncated)
    if not unit then api.emit(now, group_name, 'UNIT_UNAVAILABLE'); return end
    local valid, on, tracking = radar_track(unit, own_id)
    local ready, controller = pcall(unit.getController, unit)
    local known, detected = false, false
    if ready and controller then
        known, detected = radar_detection(controller, own_id, api.radar_kind)
    end
    local visual_known, visual = radar_detection(controller or {}, own_id, api.visual_kind)
    local optic_known, optic = radar_detection(controller or {}, own_id, api.optic_kind)
    local ir_known, infrared = radar_detection(controller or {}, own_id, api.ir_kind)
    api.emit(now, group_name, object_id(unit), valid, on, tracking, known, detected, truncated,
        visual_known, visual, optic_known, optic, ir_known, infrared)
end

function M.new(api, aircraft_name, groups)
    assert(type(aircraft_name) == 'string' and #aircraft_name <= 128)
    assert(#groups > 0 and #groups <= 64, 'Observation budget is64 groups')
    local names, selected = {}, {}
    for index = 1, #groups do
        assert(type(groups[index]) == 'string' and #groups[index] <= 128)
        names[index], selected[groups[index]] = groups[index], true
    end
    local self = {samples = 0, events = 0, last_time = nil, stopped = false}
    function self:sample(now)
        if self.stopped or type(now) ~= 'number' or now ~= now or now < 0
            or now == math.huge then return false end
        if self.last_time and now < self.last_time then self.stopped = true; return false end
        if self.last_time and now - self.last_time < 1 then return false end
        if self.samples >= 600 then self.stopped = true; return false end
        self.last_time, self.samples = now, self.samples + 1
        local own_id = object_id(api.unit(aircraft_name))
        if not own_id then api.emit(now, 'OWN_UNAVAILABLE'); return false end
        local observed = 0
        for index = 1, #names do
            local group = api.group(names[index])
            local ok, units = false, nil
            if group then ok, units = pcall(group.getUnits, group) end
            if ok and type(units) == 'table' then
                -- A complete battery can contain up to16 named component units.
                for unit_index = 1, math.min(#units, 16) do
                    observed = observed + 1
                    if observed > 128 then api.emit(now, 'UNIT_BUDGET'); return false end
                    observe_unit(api, now, names[index], units[unit_index], own_id, #units > 16)
                end
            else
                api.emit(now, names[index], 'GROUP_UNAVAILABLE')
            end
        end
        return true
    end
    function self:onEvent(event)
        if self.stopped or self.events >= 1024 or event.id ~= api.shot_kind then return end
        local unit = event.initiator
        if not unit then return end
        local ok, group = pcall(unit.getGroup, unit)
        if not ok or not group then return end
        local named, name = pcall(group.getName, group)
        if not named or not selected[name] then return end
        self.events = self.events + 1
        local known, target = false, nil
        if event.weapon then known, target = pcall(event.weapon.getTarget, event.weapon) end
        -- A shot with no readable weapon target is recorded without attribution.
        api.emit(event.time, 'SHOT', name, object_id(unit), known and object_id(target) or 'unknown')
    end
    return self
end
return M
