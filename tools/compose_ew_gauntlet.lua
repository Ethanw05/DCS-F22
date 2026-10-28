-- Offline build adapter, run by build_ew_gauntlet.py with DCS Lua 5.1.
-- Only plain mission data is packaged; this file never runs in a flight.
local stage = assert(arg[1], 'missing staging directory')
assert(loadfile(stage .. '/mission'))()
assert(loadfile(stage .. '/warehouses'))()
local overrides = assert(loadfile(stage .. '/overrides.lua'))()
for key, value in pairs(overrides) do
    mission[key] = value
end

-- Batumi is Caucasus airdrome 22. The base's warehouses use a generic stock
-- unlimited service record; copy that record to the correct recovery airfield.
local recovery = {}
for key, value in pairs(assert(warehouses.airports[1])) do
    recovery[key] = value
end
recovery.coalition = 'BLUE'
warehouses.airports = {[22] = recovery}
mission.weather.clouds = {density = 0, thickness = 200, base = 4500, iprecptns = 0}
mission.weather.name = 'Clear daylight'

-- Iterative serialization avoids a recursive traversal and bounds the stack.
local function literal(value)
    if type(value) == 'string' then
        return string.format('%q', value)
    end
    assert(type(value) == 'number' or type(value) == 'boolean', 'invalid scalar')
    return tostring(value)
end

local function keys_for(value)
    local keys = {}
    for key in pairs(value) do
        keys[#keys + 1] = key
        assert(#keys <= 4096, 'oversized mission table')
    end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    return keys
end

local function write_data(name, value)
    local file = assert(io.open(stage .. '/' .. name, 'wb'))
    assert(file:write(name .. ' = {\n'))
    local stack = {{value = value, keys = keys_for(value), index = 1}}
    local work = 0
    while #stack > 0 do
        work = work + 1
        assert(work <= 200000 and #stack <= 32, 'serialization bound exceeded')
        local frame = stack[#stack]
        local key = frame.keys[frame.index]
        if key == nil then
            assert(file:write(string.rep('    ', #stack - 1) .. '}' .. (#stack > 1 and ',\n' or '\n')))
            stack[#stack] = nil
        else
            frame.index = frame.index + 1
            local item = frame.value[key]
            assert(file:write(string.rep('    ', #stack) .. '[' .. literal(key) .. '] = '))
            if type(item) == 'table' then
                assert(file:write('{\n'))
                stack[#stack + 1] = {value = item, keys = keys_for(item), index = 1}
            else
                assert(file:write(literal(item) .. ',\n'))
            end
        end
    end
    assert(file:close())
end

write_data('mission', mission)
write_data('warehouses', warehouses)

-- Read the serialized result, rather than merely validating the input plan.
assert(loadfile(stage .. '/mission'))()
assert(loadfile(stage .. '/warehouses'))()
local players = mission.coalition.blue.country[1].plane.group
assert(#players == 1 and players[1].units[1].skill == 'Player')
assert(players[1].units[1].type == 'F-22A')
assert(players[1].units[1].x == players[1].route.points[1].x)
assert(players[1].units[1].y == players[1].route.points[1].y)
local pylons = players[1].units[1].payload.pylons
assert(pylons[5].CLSID == '{GBU_32_V_2B}' and pylons[7].CLSID == '{GBU_32_V_2B}')
assert(pylons[4] == nil and pylons[8] == nil, 'bomb rack exclusion violated')
assert(warehouses.airports[22].coalition == 'BLUE')
assert(next(mission.trigrules) == nil and next(mission.trig.funcStartup) == nil)
assert(next(mission.trig.actions) == nil, 'unexpected runtime script/action')
local ids, names, moving, total = {[1] = true}, {['Raptor EW Gauntlet'] = true}, 0, 0
for _, group in ipairs(mission.coalition.red.country[1].vehicle.group) do
    assert(group.lateActivation == false and group.start_time == 0)
    for _, unit in ipairs(group.units) do
        assert(not ids[unit.unitId] and not names[unit.name], 'duplicate unit')
        ids[unit.unitId], names[unit.name] = true, true
        assert(unit.skill == 'Excellent')
        total = total + 1
    end
    local points = group.route.points
    assert(points[1].task.params.tasks[1].params.action.params.value == 2)
    assert(points[1].task.params.tasks[2].params.action.params.value == 0)
    if #points == 2 then
        moving = moving + 1
        assert(points[1].speed > 0 and points[2].speed > 0)
        assert(points[1].action == 'On Road' and points[2].action == 'On Road')
        local loop = points[2].task.params.tasks[1].params.action
        assert(loop.id == 'SwitchWaypoint' and loop.params.goToWaypointIndex == 1)
    end
end
assert(moving == 6 and total < 150)
for _, name in ipairs({'options', 'l10n/DEFAULT/dictionary', 'l10n/DEFAULT/mapResource'}) do
    assert(loadfile(stage .. '/' .. name))
end
print('DCS Lua 5.1 mission reload/structure: PASS (' .. total .. ' ground units)')
