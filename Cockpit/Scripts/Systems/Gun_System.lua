-- GPL-3.0-or-later. Independent aiming cadence; weapon controls remain in SMS.
-- Reproject through the current aircraft pose at 120 Hz. Target uncertainty
-- belongs in the maneuver estimate, never in a delayed aircraft-motion filter.
dofile(LockOn_Options.script_path .. 'devices.lua')
make_default_activity(1 / 120)
local sensors = get_base_data()
local handles = {}
local function handle(name)
    if not handles[name] then handles[name] = get_param_handle(name) end
    return handles[name]
end
local function get(name) return handle(name):get() end
local function put(name, value) handle(name):set(value) end
local projection = dofile(LockOn_Options.script_path .. 'Systems/HUD_Projection.lua')
local physical = dofile(LockOn_Options.script_path .. 'Systems/Weapon_Physical_State.lua').new()
local director = dofile(LockOn_Options.script_path .. 'Systems/Gun_Director.lua').new(
    sensors, get, put, dispatch_action,
    dofile(LockOn_Options.script_path .. 'Systems/Radar_Display.lua'), devices.WEAPON_NATIVE)
local funnel = dofile(LockOn_Options.script_path .. 'Systems/Gun_Funnel.lua').new(
    sensors, get, put, dispatch_action, devices.WEAPON_NATIVE)

local function publish(az, el)
    local valid = az ~= nil and el ~= nil
    if not valid then az, el = 0, 0 end
    local x, y = projection.planar(az, el)
    local shown = valid and 1 or 0
    put('F22_GUN_USING_DIRECTOR', shown)
    put('HUD_GUN_NATIVE_VALID', shown)
    put('HUD_GUN_NATIVE_AZ', az)
    put('HUD_GUN_NATIVE_EL', el)
    put('HUD_GUN_NATIVE_X_SLOPE', x or 0)
    put('HUD_GUN_NATIVE_Y_SLOPE', y or 0)
end

-- Declare render gates/slopes before native indicator controllers bind, while
-- preserving the existing angular telemetry until the first update.
for _, name in ipairs({'F22_GUN_USING_DIRECTOR', 'HUD_GUN_NATIVE_VALID',
    'HUD_GUN_NATIVE_X_SLOPE', 'HUD_GUN_NATIVE_Y_SLOPE'}) do put(name, 0) end

function post_initialize()
    director:update(false)
    funnel:update(false)
    publish(nil, nil)
end

function update()
    physical:update()
    local enabled = get('F22_WEAPON_BACKEND_READY') == 1 and get('HUD_MODE') == 5 and physical.mission
    local az, el = director:update(enabled)
    publish(az, el)
    funnel:update(enabled)
end

need_to_be_closed = false
