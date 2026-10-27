-- GPL-3.0-or-later. Sole CM execution owner and optional host ECM adapter.
local dev = GetSelf()
dofile(LockOn_Options.script_path .. 'devices.lua')
local decode = dofile(LockOn_Options.script_path .. 'Systems/Input_Value.lua')
local library = dofile(LockOn_Options.script_path .. 'Systems/EW_Programs.lua')
local dispenser = dofile(LockOn_Options.script_path .. 'Systems/EW_Dispenser.lua')
local power = get_param_handle('MAIN_POWER')
local handles, held = {}, {}
local programs = library.new()
local runner = dispenser.new(programs)
local requested, applied, set_failed = false, nil, false
local clock, next_retry, test_until = 0, 0, nil
local system, ready = 2, false -- OFF/STBY/ON; hot-start ON.
local function publish(name, value)
    if not handles[name] then handles[name] = get_param_handle(name) end
    handles[name]:set(value)
end
local function native()
    local ok, device = pcall(GetDevice, devices.WEAPON_NATIVE)
    if not ok or not device then return nil end
    for _, method in ipairs({'drop_flare', 'drop_chaff', 'get_flare_count', 'get_chaff_count'}) do
        if type(device[method]) ~= 'function' then return nil end
    end
    return device
end
local function quantity(value)
    return type(value) == 'number' and value >= 0 and value < 1e6 and value % 1 == 0
end
local function inventory(device)
    if not device then return false, 0, 0 end
    local ok, chaff, flare = pcall(function()
        return device:get_chaff_count(), device:get_flare_count()
    end)
    if not ok or not quantity(chaff) or not quantity(flare) then return false, 0, 0 end
    return true, chaff, flare
end
local function publish_control()
    programs:publish(publish)
    runner:publish(publish)
    publish('F22_CM_SYSTEM', system)
    publish('F22_CM_READY', ready and 1 or 0)
    publish('F22_CM_SELF_TEST', test_until and 1 or 0)
    publish('F22_CM_AUTO_AVAILABLE', ready and 1 or 0)
    publish('F22_CM_BYPASS_INDEPENDENT', 0) -- Direct singles share MAIN_POWER.
end
function post_initialize()
    requested, applied, set_failed = false, nil, false
    held, clock, next_retry, test_until = {}, 0, 0, nil
    local cold = LockOn_Options.init_conditions.birth_place == 'GROUND_COLD'
    system, ready = cold and 0 or 2, false
    programs = library.new()
    runner = dispenser.new(programs)
    for _, handle in pairs(handles) do handle:set(0) end
    publish_control()
end
local function cm_command(command)
    if command == 11100 then runner:request(programs.normal, ready)
    elseif command == 11101 then runner:request(programs.direct, ready)
    elseif command == 11102 then runner:request(3, ready) -- Preserved CMS-push direct bank.
    elseif command >= 11103 and command <= 11106 then programs:command(command)
    elseif command == 11107 then runner:set_mode(runner.mode % 3 + 1)
    elseif command == 11108 then
        system = (system + 1) % 3
        ready = false
        runner:revoke()
    elseif command == 11109 then
        runner:revoke(); ready = false; test_until = clock + 1 -- Game test estimate, seconds.
    elseif command == 11110 then runner:event(ready) -- Neutral scripted event only.
    elseif command == 11111 then runner:authorize(ready)
    elseif command == 11112 then runner:revoke()
    elseif command == 11113 then runner:stop()
    end
    publish_control()
end
local function single(command)
    local device = native()
    if not device then runner:stop(dispenser.status.fault); return end
    -- Direct singles cancel programmed work so their count changes cannot ACK it.
    runner:stop()
    local valid, chaff, flare = inventory(device)
    local method = command == 0 and 'drop_flare' or 'drop_chaff'
    local count = command == 0 and flare or chaff
    if not valid then runner:stop(dispenser.status.fault)
    elseif count == 0 then runner:stop(dispenser.status.empty)
    else
        local ok, result = pcall(device[method], device, 1)
        if not ok or result == false then runner:stop(dispenser.status.fault) end
    end
end
function SetCommand(command, value)
    if command >= 10910 and command <= 10914 or command >= 11100 and command <= 11113
        or command >= 10840 and command <= 10842 then
        local down = decode(value, devices.EW_SYSTEM) > 0.5
        local previous = held[command]
        held[command] = down
        if not down or previous then return end
    elseif command ~= 357 and command ~= 358 and command ~= 136 then return
    elseif value ~= nil and value <= 0 then return end
    if power:get() <= 0.5 then return end
    if command >= 10910 and command <= 10914 then
        programs:command(command); publish_control()
    elseif command >= 11100 and command <= 11113 then cm_command(command)
    elseif command == 10842 or command == 136 then requested = not requested
    else single((command == 357 or command == 10840) and 0 or 1) end
    publish_control()
end
local function update_clock()
    local previous = clock
    if type(get_model_time) == 'function' then
        local ok, now = pcall(get_model_time)
        if ok and type(now) == 'number' and now >= 0 and now < 1e9 then clock = now end
    else clock = clock + 0.05 end
    if clock < previous then
        requested, applied, set_failed = false, nil, false
        next_retry, test_until = 0, nil
        runner:revoke()
    end
end
local function update_cm(device, valid, chaff, flare)
    local powered = power:get() > 0.5
    if not powered or not valid then test_until = nil end
    if test_until and clock >= test_until then test_until = nil end
    ready = powered and system == 2 and valid and not test_until
    runner:update(device, chaff, flare, clock, ready, powered)
    publish('F22_EW_BACKEND_READY', valid and 1 or 0)
    publish('F22_CM_INVENTORY_VALID', valid and 1 or 0)
    publish('F22_CHAFF_COUNT', chaff)
    publish('F22_FLARE_COUNT', flare)
    publish('CHAFF_LIGHT', valid and powered and chaff == 0 and 1 or 0)
    publish('FLARE_LIGHT', valid and powered and flare == 0 and 1 or 0)
    publish('F22_CM_LOW', valid and (chaff <= 10 or flare <= 10) and 1 or 0)
    publish('F22_CM_FAILURE', powered and system == 2 and not valid and 1 or 0)
    publish_control()
end
local function ecm_read(device)
    if not device or type(device.get_ECM_status) ~= 'function' then return false, false end
    local ok, value = pcall(device.get_ECM_status, device)
    if value == 0 then value = false elseif value == 1 then value = true end
    return ok and type(value) == 'boolean', value
end
local function update_ecm(device)
    if power:get() <= 0.5 then requested = false end
    local valid, actual = ecm_read(device)
    local control = device and type(device.set_ECM_status) == 'function'
    if valid and control and (applied ~= requested or actual ~= requested and clock >= next_retry) then
        local ok, result = pcall(device.set_ECM_status, device, requested)
        applied, next_retry, set_failed = requested, clock + 0.5, not ok or result == false
        valid, actual = ecm_read(device)
    end
    if not valid then applied = nil end
    if valid and actual == requested then set_failed = false end
    publish('F22_ECM_REQUESTED', requested and 1 or 0)
    publish('F22_ECM_ACTIVE', valid and actual and 1 or 0) -- Host enabled, not radiation proof.
    publish('F22_ECM_HOST_VALID', valid and 1 or 0)
    publish('F22_ECM_TRANSMITTING_VALID', 0) -- Host flag supplies no radiation observation.
    publish('F22_ECM_TRANSMITTING', 0)
    publish('F22_ECM_FAILED', set_failed and 1 or 0)
    publish('F22_ECM_PENDING', (not valid and requested or valid and actual ~= requested) and 1 or 0)
    publish('F22_ECM_CONTROL_READY', valid and control and not set_failed and 1 or 0)
    publish('ECM_ARG', valid and actual and 1 or 0)
end
function update()
    update_clock()
    local device = native()
    local valid, chaff, flare = inventory(device)
    update_cm(device, valid, chaff, flare)
    update_ecm(device)
end
for _, name in ipairs({'F22_EW_BACKEND_READY','F22_CM_INVENTORY_VALID','F22_CHAFF_COUNT',
    'F22_FLARE_COUNT','CHAFF_LIGHT','FLARE_LIGHT','F22_CM_LOW','F22_CM_FAILURE','ECM_ARG',
    'F22_ECM_REQUESTED','F22_ECM_ACTIVE','F22_ECM_HOST_VALID','F22_ECM_TRANSMITTING_VALID',
    'F22_ECM_TRANSMITTING','F22_ECM_FAILED','F22_ECM_PENDING','F22_ECM_CONTROL_READY'}) do
    publish(name, 0)
end
publish_control() -- Producer handles must exist before native indicator binding.
for _, command in ipairs({357, 358, 136, 10840, 10841, 10842,
    10910, 10911, 10912, 10913, 10914}) do dev:listen_command(command) end
for command = 11100, 11113 do dev:listen_command(command) end
make_default_activity(0.05)
need_to_be_closed = false
