-- SPDX-License-Identifier: GPL-3.0-or-later
local dev, sensor = GetSelf(), get_base_data()
local Math = dofile(LockOn_Options.script_path .. "Common/Math.lua")
local config = dofile(LockOn_Options.script_path .. "HUD/config.lua")
local dt = 0.02
make_default_activity(dt)
local handles = {}
local function parameter(name)
    if not handles[name] then handles[name] = get_param_handle(name) end
    return handles[name]
end
local function set(name, value) parameter(name):set(value) end
local function read(name) return parameter(name):get() end
local function sample(name, fallback)
    if type(sensor[name]) ~= "function" then return fallback end
    local ok, value = pcall(sensor[name])
    if ok and type(value) == "number" and value == value then return value end
    return fallback
end
local custom, nativeDimmed, mode, brightness = config.defaultCustom, false, 105, 0.8
local function nativeBrightness(dim)
    if dim == nativeDimmed then return end
    -- Existing module commands: dim only on transitions; restore for native combat cues.
    for _ = 1, config.nativeBrightnessSteps do dispatch_action(nil, dim and 747 or 746) end
    nativeDimmed = dim
end
for command = 105, 113 do dev:listen_command(command) end
dev:listen_command(10680) -- custom/native HUD selection
dev:listen_command(10681)
dev:listen_command(10682)
function post_initialize()
    custom, nativeDimmed, mode, brightness = config.defaultCustom, false, 105, 0.8
    set("F22_HUD_CUSTOM", custom and 1 or 0)
end
function SetCommand(command, value)
    if command >= 105 and command <= 113 then mode = command end
    if command == 10680 and value > 0 then custom = not custom end
    if command == 10681 then brightness = Math.Clamp(brightness + 0.05, 0.05, 1) end
    if command == 10682 then brightness = Math.Clamp(brightness - 0.05, 0.05, 1) end
end
function update()
    local power = read("MAIN_POWER") > 0.5
    local show = custom and mode == 105 and power
    nativeBrightness(custom and mode == 105)
    set("F22_HUD_VISIBLE", show and brightness or 0)
    set("F22_HUD_CUSTOM", custom and 1 or 0)
    set("F22_HUD_MODE", mode)
    local pitch, roll = sample("getPitch", 0), sample("getRoll", 0)
    local ias = math.max(0, sample("getIndicatedAirSpeed", 0) * 1.943844492)
    local altitude = sample("getBarometricAltitude", 0) * 3.280839895
    local heading = Math.Wrap360(-sample("getHeading", 0) * 180 / math.pi)
    set("F22_HUD_IAS", ias)
    set("F22_HUD_ALT", altitude)
    set("F22_HUD_HEADING", heading)
    -- A bounded heading tape. Values wrap independently from their angular position.
    local nearest = math.floor(heading / 5) * 5
    for index = -3, 3 do
        local mark = nearest + index * 5
        set("F22_HUD_HDG_X_" .. index, math.tan(math.rad(mark - heading)) * 1000)
        set("F22_HUD_HDG_LABEL_" .. index, Math.Wrap360(mark))
        set("F22_HUD_HDG_VALID_" .. index, math.abs(mark - heading) <= 8 and 1 or 0)
    end
    set("F22_HUD_SPEED_POINTER", Math.CounterAngle(ias, 100))
    set("F22_HUD_ALT_POINTER", Math.CounterAngle(altitude, 1000))
    set("F22_HUD_MACH", sample("getMachNumber", 0))
    set("F22_HUD_G", sample("getVerticalAcceleration", 1))
    set("F22_HUD_ALPHA", sample("getAngleOfAttack", 0) * 180 / math.pi)
    set("F22_HUD_BANK_POINTER", Math.Clamp(-roll, -math.pi / 3, math.pi / 3))
    set("F22_HUD_RADALT", sample("getRadarAltitude", 0) * 3.280839895)
    local x, y, valid, caged = Math.FlightPath(read("F22_VEL_BODY_X"), read("F22_VEL_BODY_Y"), read("F22_VEL_BODY_Z"), 85, 115)
    if read("F22_EFM_VALID") < 0.5 then valid = false end
    set("F22_HUD_FPM_X", x); set("F22_HUD_FPM_Y", y)
    set("F22_HUD_FPM_VALID", valid and 1 or 0)
    set("F22_HUD_FPM_CAGED", caged and 1 or 0)
    set("F22_HUD_ROLL", roll)
    for angle = -90, 90, 5 do
        local relative = math.rad(angle) - pitch
        local visible = math.abs(relative) < math.rad(12)
        set("F22_HUD_PITCH_" .. angle, visible and math.tan(relative) * 1000 or 0)
        set("F22_HUD_PITCH_VALID_" .. angle, visible and 1 or 0)
    end
end
need_to_be_closed = false
