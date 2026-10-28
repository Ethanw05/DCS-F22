-- GPL-3.0-or-later. One visible binding per action; internal command IDs stay owned.
-- Loaded once by each input profile. DCS supplies folder and its command globals
-- in Scripts/Input/Data.lua; the cockpit's devices environment is unavailable.
local aliases = {
    [10007]=10724, [10008]=10724, -- old arm bindings toggle on both edges
    [10021]=10716, [10022]=10717, [10026]=10718,
    [10151]=11905, [10152]=11905, [10153]=11906, [10154]=11906,
    [10600]=10725, [10606]=10733, [10607]=10726, [10608]=10727,
    [10609]=10714, [10619]=10703, [10842]=10714,
    [11100]=10708, [11101]=10711, [11701]=10714,
}
local host_aliases = {
    PlaneFire=10717, PlaneChangeWeapon=10720, PlaneModeCannon=10728,
    PlaneModeNAV=10721, PlaneModeBVR=10730, PlaneModeGround=10732,
    PlaneChangeLock=10733, SensorReset=10714, RefusalTWS=10714,
    Plane_HOTAS_NoseWheelSteeringButton=10714,
    Plane_HOTAS_NoseWheelSteeringButtonOff=10714,
    PlaneRadarOnOff=10725, PlaneRadarChangeMode=10603,
    PlaneRadarUp=10610, PlaneRadarDown=10611,
    PlaneRadarLeft=10612, PlaneRadarRight=10613, PlaneRadarCenter=10617,
    PlaneZoomIn=10726, PlaneZoomOut=10727,
    ChangeRWRMode=10902, PlaneThreatWarnSoundVolumeDown=10905,
    PlaneThreatWarnSoundVolumeUp=10904,
    PlaneLightsOnOff=11911, PlaneHeadLightOnOff=11906,
    PowerOnOff=10010, PlaneAirRefuel=10016,
    AltimeterPressureIncrease=11021, AltimeterPressureDecrease=11022,
    PlaneChangeTarget=10830, PlaneUFC_STEER_DOWN=10831,
    PlaneResetMasterWarning=11000, PlaneDropSnar=10708, PlaneDropSnarOnce=10708,
    PlaneWheelBrakeLeftOn=10056, PlaneWheelBrakeRightOn=10057,
}
-- No matching implemented owner, or deliberate development stimuli rather
-- than pilot functions. Ground servicing and real emergency controls remain.
local removed = { [11110]=true, [11130]=true, [11131]=true, [11132]=true }
local unused_host = {
    'PlaneChangeRadarPRF', 'PlaneSalvoOnOff', 'ChangeGunRateOfFire',
    'PlaneIncreaseBase_Distance', 'PlaneDecreaseBase_Distance',
    'SelecterUp', 'SelecterDown', 'SelecterLeft', 'SelecterRight',
    'PlaneModeFI0',
}
local unused_axes = {
    'PlaneSelecterHorizontalAbs', 'PlaneSelecterVerticalAbs',
    'PlaneRadarHorizontalAbs', 'PlaneRadarVerticalAbs',
    'PlaneMFDZoomAbs', 'PlaneBase_DistanceAbs',
}
local identity_fields = {'down','pressed','up','cockpit_device_id',
    'value_down','value_pressed','value_up'}
local function identity(binding)
    local parts = {}
    for i, key in ipairs(identity_fields) do parts[i]=tostring(binding[key]) end
    return table.concat(parts, ':')
end
local function has_combo(target, combo)
    for _, existing in ipairs(target.combos or {}) do
        if existing.key==combo.key and
            table.concat(existing.reformers or {}, ':')==table.concat(combo.reformers or {}, ':') then
            return true
        end
    end
    return false
end
local function add_combos(target, source)
    for _, combo in ipairs(source.combos or {}) do
        if not has_combo(target,combo) then
            target.combos=target.combos or {}
            target.combos[#target.combos+1]=combo
        end
    end
end
local function host_rules(host)
    local map, drop = {}, {}
    for old, target in pairs(aliases) do map[old]=target end
    for command in pairs(removed) do drop[command]=true end
    for name, target in pairs(host_aliases) do
        local command=host['iCommand'..name]
        if command then map[command]=target end
    end
    for _, name in ipairs(unused_host) do
        local command=host['iCommand'..name]
        if command then drop[command]=true end
    end
    return map, drop
end
local function trim_down(binding, host)
    return binding.down and
        (binding.down==host.iCommandPlaneTrimUp or binding.down==host.iCommandPlaneTrimDown)
end
local function command_targets(profile, host, map)
    local targets = {}
    for _, binding in ipairs(profile.keyCommands) do
        if binding.down and not map[binding.down] and not trim_down(binding,host) then
            targets[binding.down]=binding
        end
        if binding.pressed==host.iCommandPlaneTrimUp or binding.pressed==host.iCommandPlaneTrimDown then
            if binding.pressed then targets[binding.pressed]=binding end
        end
    end
    return targets
end
local function alias_target(binding, targets, host, map)
    if trim_down(binding,host) then return targets[binding.down] end
    local command=binding.down or binding.pressed
    return map[command] and targets[map[command]]
end
local function keep_binding(binding, kept, identities)
    local key=identity(binding)
    if identities[key] then add_combos(identities[key],binding)
    else kept[#kept+1]=binding;identities[key]=binding end
end
local function clean_keys(profile, host, keyboard)
    local map, drop = host_rules(host)
    local targets=command_targets(profile,host,map)
    local kept, identities = {}, {}
    for _, binding in ipairs(profile.keyCommands) do
        local command=binding.down or binding.pressed
        local target=alias_target(binding,targets,host,map)
        if target then
            -- Never install inherited generic JOY_BTN defaults onto the pilot's
            -- custom HOTAS rows: their old removed diffs have different IDs.
            if keyboard then add_combos(target,binding) end
        elseif not drop[command] then
            keep_binding(binding,kept,identities)
        end
    end
    profile.keyCommands=kept
end
return function(profile, host, keyboard)
    assert(#profile.keyCommands<=2048, 'Input command budget exceeded')
    clean_keys(profile,host,keyboard)
    local drop = {}
    for _, name in ipairs(unused_axes) do
        local command=host['iCommand'..name]
        if command then drop[command]=true end
    end
    local kept = {}
    for _, binding in ipairs(profile.axisCommands or {}) do
        if not drop[binding.action] then kept[#kept+1]=binding end
    end
    profile.axisCommands=kept
end
