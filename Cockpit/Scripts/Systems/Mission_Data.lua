-- GPL-3.0-or-later. Bounded preplanned partitions, separate from live observations.
local M = { schema = 1, route_limit = 256, zone_limit = 32, preset_limit = 40 }
local function finite(value)
    return type(value) == 'number' and value == value and math.abs(value) < 1e9
end
local function text(value, maximum)
    return type(value) == 'string' and #value > 0 and #value <= maximum
end
local function array(items, limit)
    if type(items) ~= 'table' or #items > limit then return false end
    local count = 0
    for key in pairs(items) do
        count = count + 1
        if count > limit or type(key) ~= 'number' or key % 1 ~= 0 or key < 1 or key > #items then return false end
    end
    return count == #items
end
local function route_position(point)
    return type(point)=='table' and finite(point.x) and finite(point.y)
        and math.abs(point.x)<=1e7 and math.abs(point.y)<=1e7
end
local function route_height(point)
    if point.alt~=nil and(not finite(point.alt)or point.alt< -1000 or point.alt>32000)then
        return 'ROUTE ALTITUDE'
    end
    if point.alt_type~=nil and point.alt_type~='BARO'and point.alt_type~='RADIO'then return 'ROUTE DATUM' end
end
local function route(items)
    if not array(items, M.route_limit) then return nil, 'ROUTE CAPACITY' end
    local accepted = {}
    for index = 1, #items do
        local point = items[index]
        if not route_position(point)then return nil,'ROUTE POSITION'end
        local reason=route_height(point)
        if reason then return nil,reason end
        accepted[index] = { x = point.x, y = point.y, alt = point.alt, alt_type = point.alt_type,
            name = type(point.name) == 'string' and point.name:sub(1,64) or nil }
    end
    return accepted
end
local function zones(items)
    if not array(items, M.zone_limit) then return nil, 'ZONE CAPACITY' end
    local accepted = {}
    for index = 1, #items do
        local zone = items[index]
        if type(zone) ~= 'table' or not finite(zone.n) or not finite(zone.e)
            or math.abs(zone.n) > 1e7 or math.abs(zone.e) > 1e7 or not finite(zone.radius_m)
            or zone.radius_m <= 0 or zone.radius_m > 1e6 or not text(zone.label,32) then
            return nil, 'PLANNED ZONE'
        end
        accepted[index] = { n = zone.n, e = zone.e, radius_m = zone.radius_m, label = zone.label, planned = true }
    end
    return accepted
end
local function presets(items)
    if not array(items, M.preset_limit) then return nil, 'PRESET CAPACITY' end
    local accepted = {}
    for index = 1, #items do
        local preset = items[index]
        if type(preset) ~= 'table' or (preset.radio ~= 1 and preset.radio ~= 2)
            or not finite(preset.hz) or preset.hz < 30000000 or preset.hz > 400000000
            or preset.hz % 1 ~= 0 or (preset.modulation ~= 'AM' and preset.modulation ~= 'FM') then
            return nil, 'RADIO PRESET'
        end
        accepted[index] = {radio=preset.radio,hz=preset.hz,modulation=preset.modulation}
    end
    return accepted
end
local validators = { route = route, planned_zones = zones, radio_presets = presets }
function M.new()
    local state = { partitions = {}, sequence = 0 }
    function state:replace(partition, envelope)
        local validate = validators[partition]
        if not validate or type(envelope) ~= 'table' or envelope.schema ~= M.schema
            or not text(envelope.source,96) or not text(envelope.date,32) then return false, 'DATA SCHEMA' end
        if self.sequence >= 16777215 then return false, 'DATA GENERATION' end
        local items, reason = validate(envelope.items)
        if not items then return false, reason end
        self.sequence = self.sequence + 1
        self.partitions[partition] = { items=items,source=envelope.source,date=envelope.date,generation=self.sequence }
        return true, self.partitions[partition]
    end
    return state
end
return M
