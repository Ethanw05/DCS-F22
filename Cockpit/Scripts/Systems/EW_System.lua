-- GPL-3.0-or-later. Own controls for the common DCS countermeasure/ECM service.
local dev = GetSelf()
dofile(LockOn_Options.script_path .. "devices.lua")
local decode = dofile(LockOn_Options.script_path .. "Systems/Input_Value.lua")
local power = get_param_handle("MAIN_POWER")
local handles = {}
for _, name in ipairs({
	"F22_EW_BACKEND_READY",
	"F22_ECM_REQUESTED",
	"F22_ECM_ACTIVE",
	"F22_CHAFF_COUNT",
	"F22_FLARE_COUNT",
	"ECM_ARG",
	"CHAFF_LIGHT",
	"FLARE_LIGHT",
}) do
	handles[name] = get_param_handle(name)
end
local requested, applied = false, nil
local held = {}
local function native()
	local ok, device = pcall(GetDevice, devices.WEAPON_NATIVE)
	if not ok or not device then
		return nil
	end
	for _, name in ipairs({
		"drop_flare",
		"drop_chaff",
		"get_flare_count",
		"get_chaff_count",
		"get_ECM_status",
		"set_ECM_status",
	}) do
		if type(device[name]) ~= "function" then
			return nil
		end
	end
	return device
end
local function publish(name, value)
	handles[name]:set(value)
end
function post_initialize()
	requested, applied, held = false, nil, {}
	for _, h in pairs(handles) do
		h:set(0)
	end
end
function SetCommand(command, value)
	local action
	if command >= 10840 and command <= 10842 then
		local down = decode(value, devices.EW_SYSTEM) > 0.5
		local old = held[command]
		held[command] = down
		if not down or old then
			return
		end
		action = command - 10840
	elseif command == 357 then
		action = 0
	elseif command == 358 then
		action = 1
	elseif command == 136 then
		action = 2
	else
		return
	end
	-- Global legacy commands are pulses; private physical bindings include up.
	if command < 10840 and value ~= nil and value <= 0 then
		return
	end
	if power:get() <= 0.5 then
		return
	end
	local device = native()
	if not device then
		return
	end
	if action == 0 then
		device:drop_flare(1)
	elseif action == 1 then
		device:drop_chaff(1)
	else
		requested = not requested
	end
end
function update()
	local device = native()
	if power:get() <= 0.5 then
		requested = false
	end
	if not device then
		applied = nil
		for _, h in pairs(handles) do
			h:set(0)
		end
		return
	end
	if applied ~= requested then
		device:set_ECM_status(requested) -- Native wrapper requires a Lua boolean.
		applied = requested
	end
	local actual = device:get_ECM_status()
	local chaff, flare = device:get_chaff_count(), device:get_flare_count()
	local valid = type(actual) == "boolean"
		and type(chaff) == "number"
		and type(flare) == "number"
		and chaff >= 0
		and flare >= 0
	publish("F22_EW_BACKEND_READY", valid and 1 or 0)
	publish("F22_ECM_REQUESTED", requested and 1 or 0)
	publish("F22_ECM_ACTIVE", valid and actual and 1 or 0)
	publish("ECM_ARG", valid and actual and 1 or 0)
	publish("F22_CHAFF_COUNT", valid and chaff or 0)
	publish("F22_FLARE_COUNT", valid and flare or 0)
	publish("CHAFF_LIGHT", valid and power:get() > 0.5 and chaff == 0 and 1 or 0)
	publish("FLARE_LIGHT", valid and power:get() > 0.5 and flare == 0 and 1 or 0)
end
for _, command in ipairs({ 357, 358, 136, 10840, 10841, 10842 }) do
	dev:listen_command(command)
end
make_default_activity(0.05)
need_to_be_closed = false
