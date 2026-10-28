-- GPL-3.0-or-later. Mission-only truth logger; never feeds aircraft sensing.
local player_name, jammer_name = 'F22 EW Player', 'EW Jammer'
local phase, requested, manual = 'START', false, false
local nonce, samples, event_count = 0, 0, 0
local function emit(kind, ...)
    local row = {'F22_EW_TRIAL', kind, string.format('%.3f', timer.getTime())}
    for i = 1, select('#', ...) do row[#row+1] = tostring(select(i, ...)) end
    env.info(table.concat(row, '|'))
end
local function message(text, seconds)
    trigger.action.outText('EW TRIAL: '..text, seconds or 12)
end
local function option(group, name, value)
    if not group or not name or value == nil then return false end
    local ok, error = pcall(function() group:getController():setOption(name, value) end)
    if not ok then emit('ERROR', 'option', error) end
    return ok
end
local function enemy_ecm(enabled)
    local air = AI and AI.Option and AI.Option.Air
    local values = air and air.val.ECM_USING
    local value = values and values[enabled and 'ALWAYS_USE' or 'NEVER_USE']
    local ok = option(Group.getByName('EW Jammer Flight'), air and air.id.ECM_USING, value)
    requested = enabled
    emit('JAM_COMMAND', enabled and 1 or 0, ok and 1 or 0)
    if not ok then message('Enemy ECM command unavailable. Setup is NOT qualified.', 25) end
end
local function toggle_own()
    nonce = nonce + 1
    trigger.action.setUserFlag(5102, nonce)
    emit('PLAYER_COMMAND', 'toggle', nonce)
    message('Own ECM toggle sent. Check ECM indication; actual state is logged.')
end
local function set_enemy(enabled)
    manual = true
    enemy_ecm(enabled)
    message('Enemy ECM '..(enabled and 'ON requested' or 'OFF requested')..'. Manual control.')
end
local function sam_fire(enabled)
    local ground = AI and AI.Option and AI.Option.Ground
    local values = ground and ground.val.ROE
    local ok = option(Group.getByName('EW SAM Site'), ground and ground.id.ROE,
        values and values[enabled and 'OPEN_FIRE' or 'WEAPON_HOLD'])
    emit('SAM_FIRE', enabled and 1 or 0, ok and 1 or 0)
    message(enabled and 'SAM live fire enabled. Aircraft damage is enabled.' or 'SAM weapon hold requested.')
end
local function phases(time)
    local name, jam, hint
    if time < 45 then
        name, jam, hint = 'BASELINE', false, 'Keep ECM OFF. Fly heading 103 degrees, 33000 ft. Target ahead; SAM near Kobuleti.'
    elseif time < 90 then
        name, jam, hint = 'OWN_ECM', false, 'Toggle YOUR ECM ON using F10 -> EW Trial. Compare the RWR and enemy radar behavior.'
    elseif time < 135 then
        name, jam, hint = 'RECOVERY', false, 'Toggle YOUR ECM OFF. Clean receiver and radar recovery interval.'
    elseif time < 180 then
        name, jam, hint = 'ENEMY_ECM_1', true, 'Enemy jammer ON requested. Keep own ECM OFF; track the aircraft ahead.'
    elseif time < 225 then
        name, jam, hint = 'ENEMY_OFF', false, 'Enemy jammer OFF requested. Compare radar quality and reacquisition.'
    elseif time < 270 then
        name, jam, hint = 'ENEMY_ECM_2', true, 'Enemy jammer ON requested again. Continue tracking or close the range.'
    else
        name, jam, hint = 'FREEPLAY', false, 'Free play. F10 controls both ECM tests and SAM live fire. Logging continues for 20 minutes.'
    end
    if name ~= phase then
        phase = name
        emit('PHASE', phase)
        if not manual then enemy_ecm(jam) end
        message(hint, 22)
    end
end
local function unit_position(unit)
    if not unit or not unit:isExist() then return 'missing' end
    local p = unit:getPoint()
    return string.format('%.2f,%.2f,%.2f', p.x, p.y, p.z)
end
local function radar_sample(name, player)
    local radar = Unit.getByName(name)
    if not radar or not radar:isExist() or not player then return end
    local on, target = radar:getRadar()
    local detected, visible, last, type_known, range_known = radar:getController():isTargetDetected(player, Controller.Detection.RADAR)
    local target_name = target and target:isExist() and target:getName() or 'none'
    emit('RADAR', phase, name, on and 1 or 0, target_name,
        detected and 1 or 0, visible and 1 or 0, last or -1,
        type_known and 1 or 0, range_known and 1 or 0, unit_position(radar))
end
local function tick(_, now)
    if samples >= 1200 then emit('END', 'logging_limit'); return nil end
    samples = samples + 1
    phases(now)
    local player, jammer = Unit.getByName(player_name), Unit.getByName(jammer_name)
    emit('GEOMETRY', phase, requested and 1 or 0, unit_position(player), unit_position(jammer))
    for _,name in ipairs({'EW Buk Search','EW Buk Tracker'}) do
        local ok,error=pcall(radar_sample,name,player)
        if not ok then emit('ERROR','radar_sample',name,error) end
    end
    return now + 1
end
local events = {}
function events:onEvent(event)
    local allowed = event.id == world.event.S_EVENT_SHOT or event.id == world.event.S_EVENT_HIT
        or event.id == world.event.S_EVENT_DEAD or event.id == world.event.S_EVENT_MISSION_END
    if not allowed then return end
    event_count=event_count+1
    if event_count>2000 then return end
    local initiator = event.initiator and event.initiator:getName() or 'none'
    local target = event.target and event.target:getName() or 'none'
    emit('EVENT', event.id, initiator, target)
end
local root = missionCommands.addSubMenu('EW Trial')
missionCommands.addCommand('Toggle YOUR ECM', root, toggle_own)
missionCommands.addCommand('Enemy jammer ON', root, function() set_enemy(true) end)
missionCommands.addCommand('Enemy jammer OFF', root, function() set_enemy(false) end)
missionCommands.addCommand('Resume scheduled enemy ECM', root, function()
    manual = false;phase = 'RESTART';message('Scheduled ECM cycle resumed.')
end)
missionCommands.addCommand('SAM live fire ON', root, function() sam_fire(true) end)
missionCommands.addCommand('SAM weapon hold', root, function() sam_fire(false) end)
missionCommands.addCommand('Show instructions', root, function()
    message('Fly heading 103, 33000 ft; jammer ahead. Radio menu -> F10 Other -> EW Trial controls both ECM tests. Initial SAM weapon hold; optional live fire. Logging automatic.', 30)
end)
world.addEventHandler(events)
local ground=AI and AI.Option and AI.Option.Ground
option(Group.getByName('EW SAM Site'),ground and ground.id.ALARM_STATE,
    ground and ground.val.ALARM_STATE and ground.val.ALARM_STATE.RED)
sam_fire(false)
emit('START', 'F22-EW-Duel-v1')
timer.scheduleFunction(tick, nil, timer.getTime()+1)
