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
	"F22_ECM_PENDING",
	"F22_ECM_CONTROL_READY",
	"F22_CM_INVENTORY_VALID",
	"F22_CHAFF_COUNT",
	"F22_FLARE_COUNT",
	"ECM_ARG",
	"CHAFF_LIGHT",
	"FLARE_LIGHT",
}) do
	handles[name] = get_param_handle(name)
end
local requested, applied = false, nil
local clock, next_retry, set_failed = 0, 0, false
local held = {}
local program_library = dofile(LockOn_Options.script_path .. "Systems/EW_Programs.lua")
local programs = program_library.new()
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
	if not handles[name] then
		handles[name] = get_param_handle(name)
	end
	handles[name]:set(value)
end
programs:publish(publish)
function post_initialize()
	requested, applied, held = false, nil, {}
	clock, next_retry, set_failed = 0, 0, false
	programs = program_library.new()
	for _, h in pairs(handles) do
		h:set(0)
	end
	programs:publish(publish)
end
function SetCommand(command, value)
	if command >= 10910 and command <= 10914 then
		local down = decode(value, devices.EW_SYSTEM) > 0.5
		local previous = held[command]
		held[command] = down
		if down and not previous and power:get() > 0.5 then
			programs:command(command)
			programs:publish(publish)
		end
		return
	end
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
	if action == 2 then
		requested = not requested
		return
	end
	local device = native()
	if not device then
		return
	end
	pcall(function()
		if action == 0 then
			device:drop_flare(1)
		else
			device:drop_chaff(1)
		end
	end)
end
function update()
	local previous = clock
	if type(get_model_time) == "function" then
		local ok, now = pcall(get_model_time)
		if ok and type(now) == "number" and now == now and now >= 0 and now < 1e9 then
			clock = now
		end
	else
		clock = clock + 0.05
	end
	if clock < previous then
		requested, applied = false, nil
		next_retry = 0
		set_failed = false
	end
	programs:publish(publish)
	local device = native()
	if power:get() <= 0.5 then
		requested = false
	end
	if not device then
		applied = nil
		for name, h in pairs(handles) do
			if not name:match("^F22_CM_PROGRAM_") then
				h:set(0)
			end
		end
		publish("F22_ECM_REQUESTED", requested and 1 or 0)
		publish("F22_ECM_PENDING", requested and 1 or 0)
		return
	end
	local ok, actual, chaff, flare = pcall(function()
		return device:get_ECM_status(), device:get_chaff_count(), device:get_flare_count()
	end)
	local function quantity(x)
		return type(x) == "number" and x == x and x >= 0 and x < 1e9 and x % 1 == 0
	end
	local valid = ok and type(actual) == "boolean" and quantity(chaff) and quantity(flare)
	if valid and (applied ~= requested or (actual ~= requested and clock >= next_retry)) then
		local switched = pcall(function()
			device:set_ECM_status(requested)
		end)
		applied = requested
		next_retry = clock + 0.5
		set_failed = not switched
		local read_ok, value = pcall(function()
			return device:get_ECM_status()
		end)
		valid = read_ok and type(value) == "boolean"
		actual = value
	end
	if not valid then
		applied = nil
	end
	if valid and actual == requested then
		set_failed = false
	end
	publish("F22_EW_BACKEND_READY", valid and 1 or 0)
	publish("F22_ECM_REQUESTED", requested and 1 or 0)
	publish("F22_ECM_ACTIVE", valid and actual and 1 or 0)
	publish("F22_ECM_PENDING", valid and actual ~= requested and 1 or not valid and requested and 1 or 0)
	publish("F22_ECM_CONTROL_READY", valid and not set_failed and 1 or 0)
	publish("F22_CM_INVENTORY_VALID", valid and 1 or 0)
	publish("ECM_ARG", valid and actual and 1 or 0)
	publish("F22_CHAFF_COUNT", valid and chaff or 0)
	publish("F22_FLARE_COUNT", valid and flare or 0)
	publish("CHAFF_LIGHT", valid and power:get() > 0.5 and chaff == 0 and 1 or 0)
	publish("FLARE_LIGHT", valid and power:get() > 0.5 and flare == 0 and 1 or 0)
end
for _, command in ipairs({ 357, 358, 136, 10840, 10841, 10842, 10910, 10911, 10912, 10913, 10914 }) do
	dev:listen_command(command)
end
make_default_activity(0.05)
need_to_be_closed = false
