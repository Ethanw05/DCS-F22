-- GPL-3.0-or-later. Passive mission-side radar observations, never AI control.
-- The caller supplies at most64 group names and one aircraft unit name.
local M = {}
local own_arguments = {600, 601, 602, 0, 3, 5, 22}

local function finite_coordinate(value)
    return type(value) == 'number' and value == value and math.abs(value) <= 100000000
end

local function object_point(object)
    if not object then return nil end
    local ok, point = pcall(object.getPoint, object)
    if not ok or type(point) ~= 'table' then return nil end
    if not finite_coordinate(point.x) or not finite_coordinate(point.y)
        or not finite_coordinate(point.z) then return nil end
    return point
end

local function slant_range(unit, own_point)
    local point = object_point(unit)
    if not point or not own_point then return false, 0 end
    local dx, dy, dz = point.x - own_point.x, point.y - own_point.y, point.z - own_point.z
    return true, math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function draw_argument(unit, argument)
    local ok, value = pcall(unit.getDrawArgumentValue, unit, argument)
    if not ok or not finite_coordinate(value) or value < 0 or value > 1 then
        return false, 0
    end
    return true, value
end

local function object_type(unit)
    local ok, name = pcall(unit.getTypeName, unit)
    if not ok or type(name) ~= 'string' or #name == 0 or #name > 128 then
        return false, 'unknown'
    end
    return true, name
end

local function unit_group_name(unit)
    local ok, group = pcall(unit.getGroup, unit)
    if not ok or not group then return nil end
    local named, name = pcall(group.getName, group)
    if not named or type(name) ~= 'string' then return nil end
    return name
end

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

local function observe_unit(api, now, group_name, unit, own_id, truncated, own_point)
    if not unit then api.emit(now, group_name, 'UNIT_UNAVAILABLE'); return end
    local valid, on, tracking = radar_track(unit, own_id)
    local ready, controller = pcall(unit.getController, unit)
    local known, detected = false, false
    if ready and controller then
        known, detected = radar_detection(controller, own_id, api.radar_kind)
    end
    local visual_known, visual = radar_detection(controller, own_id, api.visual_kind)
    local optic_known, optic = radar_detection(controller, own_id, api.optic_kind)
    local ir_known, infrared = radar_detection(controller, own_id, api.ir_kind)
    local range_known, range_m = slant_range(unit, own_point)
    api.emit(now, group_name, object_id(unit), valid, on, tracking, known, detected, truncated,
        visual_known, visual, optic_known, optic, ir_known, infrared, range_known, range_m)
end

local function observe_ownship(api, row, now, unit, own_id, point)
    row[1], row[2], row[3] = now, 'OWN', own_id
    row[4], row[5] = object_type(unit)
    row[6] = point ~= nil
    row[7], row[8], row[9] = 0, 0, 0
    if point then row[7], row[8], row[9] = point.x, point.y, point.z end
    for index = 1, #own_arguments do
        local field = 10 + (index - 1) * 2
        row[field], row[field + 1] = draw_argument(unit, own_arguments[index])
    end
    api.emit(unpack(row, 1, 23))
end

local function sample_groups(api, names, now, own_id, own_point)
    local observed = 0
    for index = 1, #names do
        local group = api.group(names[index])
        local ok, units = false, nil
        if group then ok, units = pcall(group.getUnits, group) end
        if ok and type(units) == 'table' then
            for unit_index = 1, math.min(#units, 16) do
                observed = observed + 1
                if observed > 128 then api.emit(now, 'UNIT_BUDGET'); return false end
                observe_unit(api, now, names[index], units[unit_index], own_id,
                    #units > 16, own_point)
            end
        else
            api.emit(now, names[index], 'GROUP_UNAVAILABLE')
        end
    end
    return true
end

local function valid_time(now)
    return type(now) == 'number' and now == now and now >= 0 and now < math.huge
end

local function begin_sample(self, now)
    if self.stopped or not valid_time(now) then return false end
    if self.last_time and now < self.last_time then self.stopped = true; return false end
    if self.last_time and now - self.last_time < 1 then return false end
    if self.samples >= 600 then self.stopped = true; return false end
    self.last_time, self.samples = now, self.samples + 1
    return true
end

local function fire_event_label(api, id)
    if type(id) ~= 'number' then return nil end
    if id == api.shot_kind then return 'SHOT' end
    if id == api.gun_start_kind then return 'GUN_START' end
    if id == api.gun_end_kind then return 'GUN_END' end
    return nil
end

local function record_fire(api, aircraft_name, event, label, unit, name)
    local known, target = false, nil
    if label == 'SHOT' and event.weapon then
        known, target = pcall(event.weapon.getTarget, event.weapon)
    end
    local range_known, range_m = slant_range(unit, object_point(api.unit(aircraft_name)))
    -- Gun bursts and shots without a readable target retain unknown attribution.
    api.emit(event.time, label, name, object_id(unit), known and object_id(target) or 'unknown',
        range_known, range_m)
end

function M.new(api, aircraft_name, groups)
    assert(type(aircraft_name) == 'string' and #aircraft_name <= 128)
    assert(#groups > 0 and #groups <= 64, 'Observation budget is64 groups')
    local names, selected, own_row = {}, {}, {}
    for index = 1, #groups do
        assert(type(groups[index]) == 'string' and #groups[index] <= 128)
        names[index], selected[groups[index]] = groups[index], true
    end
    local self = {samples = 0, events = 0, last_time = nil, stopped = false,
        event_limit_reported = false}
    function self:sample(now)
        if not begin_sample(self, now) then return false end
        local ownship = api.unit(aircraft_name)
        local own_id = object_id(ownship)
        if not own_id then api.emit(now, 'OWN_UNAVAILABLE'); return false end
        local own_point = object_point(ownship)
        if api.observe_ownship == true then
            observe_ownship(api, own_row, now, ownship, own_id, own_point)
        end
        return sample_groups(api, names, now, own_id, own_point)
    end
    function self:onEvent(event)
        local label = fire_event_label(api, event.id)
        if self.stopped or not label then return end
        local unit = event.initiator
        if not unit then return end
        local name = unit_group_name(unit)
        if not name or not selected[name] then return end
        if self.events >= 1024 then
            if not self.event_limit_reported then
                api.emit(event.time, 'EVENT_BUDGET')
                self.event_limit_reported = true
            end
            return
        end
        self.events = self.events + 1
        record_fire(api, aircraft_name, event, label, unit, name)
    end
    return self
end
return M
