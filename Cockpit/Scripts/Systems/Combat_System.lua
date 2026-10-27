-- GPL-3.0-or-later. Warthog/STECS routing with a single master-mode owner.
dofile(LockOn_Options.script_path .. "devices.lua")
local input_value = dofile(LockOn_Options.script_path .. "Systems/Input_Value.lua")
local commands = dofile(LockOn_Options.script_path .. "Systems/Combat_Commands.lua")
local radar = dofile(LockOn_Options.script_path .. "Systems/Radar_Commands.lua")
local navigation = dofile(LockOn_Options.script_path .. "Systems/Nav_Commands.lua")
local dev = GetSelf()
local dt = 0.02
make_default_activity(dt)
local handles = {}
local function h(n)
	if not handles[n] then
		handles[n] = get_param_handle(n)
	end
	return handles[n]
end
local function get(n)
	return h(n):get()
end
local function put(n, v)
	h(n):set(v)
end
local by_id = {}
dev:listen_command(10742) -- internal bezel-focus notification
for n, id in pairs(commands) do
	by_id[id] = n
	dev:listen_command(id)
end
local function send(id, c, v)
	dispatch_action(id, c, v or 1)
end
local bursts = 0
local next_burst = 0
local program_library = dofile(LockOn_Options.script_path .. "Systems/EW_Programs.lua")
local active_program = nil
local clock = 0
local function emit(n, v)
	if n == "weapon_mode" then
		send(devices.WEAPON_SYSTEM, 10800, v)
	elseif n == "ag_gun" then
		send(devices.WEAPON_SYSTEM, 10807)
	elseif n == "ag_ccip" then
		send(devices.WEAPON_SYSTEM, 10808)
	elseif n == "ag_auto" then
		send(devices.WEAPON_SYSTEM, 10809)
	elseif n == "ag_cycle" then
		send(devices.WEAPON_SYSTEM, 10813)
	elseif n == "ag_mark" then
		send(devices.AG_MARK_SYSTEM, 10810)
	elseif n == "ag_clear" then
		send(devices.AG_MARK_SYSTEM, 10811)
	elseif n == "ground_tdc" then
		send(devices.RADAR_COMPUTER, v > 0 and radar.designate_begin or radar.designate_end)
	elseif n == "ground_acquire" then
		send(devices.RADAR_COMPUTER, v > 0 and radar.acquire_begin or radar.acquire)
	elseif n == "ground_preview_cancel" then
		send(devices.RADAR_COMPUTER, radar.preview_cancel)
	elseif n == "ag_waypoint" then
		send(devices.AG_MARK_SYSTEM, 10812)
	elseif n == "ew_priority" then
		send(devices.RWR_SYSTEM, 10902)
	elseif n == "nav_zoom" then
		send(devices.NAV_SYSTEM, navigation.range_in)
	elseif n == "trigger_first" then
		send(devices.WEAPON_SYSTEM, 10801, v)
	elseif n == "trigger_second" then
		send(devices.WEAPON_SYSTEM, 10802, v)
	elseif n == "pickle" then
		send(devices.WEAPON_SYSTEM, 10803, v)
	elseif n == "radar_operate" then
		send(devices.RADAR_COMPUTER, radar.operate)
	elseif n == "radar_page" then
		send(devices.PMFD_SYSTEM, 10005)
	elseif n == "arm" then
		send(devices.WEAPON_SYSTEM, 10008)
	elseif n == "station_step" then
		send(devices.WEAPON_SYSTEM, 10804)
	elseif n == "cage" then
		send(devices.WEAPON_SYSTEM, 10805)
	elseif n == "nws" then
		dispatch_action(nil, 562, 1)
	elseif n == "autopilot_off" then
		dispatch_action(nil, 408, 1)
	elseif n == "defense_program" then
		active_program = program_library.read(get, v)
		bursts = active_program and active_program.repetitions or 0
		next_burst = clock
	elseif n == "defense_consent" then
		-- No automatic threat responder is claimed. Consent is stored, not automatic release.
		put("F22_CM_CONSENT", v)
	elseif n == "expand" then
		send(devices.RADAR_COMPUTER, 10624)
	elseif n == "interrogate_los" then
		send(devices.RADAR_COMPUTER, 10625)
	elseif radar[n] then
		if log and log.write then
			log.write("F22_RADAR_REQUEST", log.INFO, string.format(
				"action=%s hud=%.0f soi=%.0f native=%.0f", n,
				get("HUD_MODE"), get("F22_SOI"), get("F22N_RADAR_MODE")))
		end
		send(devices.RADAR_COMPUTER, radar[n])
	end
end
local logic = dofile(LockOn_Options.script_path .. "Systems/Combat_Logic.lua").new(emit)
local function context()
	return {
		locked = get("F22_RADAR_STT_VALID") > 0.5,
		selected = get("F22_RADAR_SELECTED_VALID") > 0.5,
		ground = get("WoW") > 0.5,
		primary_page = get("F22_PMFD_PAGE"),
		left_page = get("LMFD_PAGE"),
		right_page = get("RMFD_PAGE"),
		center_page = get("CMFD_PAGE"),
		common_formats = get('F22_MFD_LAYOUT_READY')>.5 and {
			[2]=get('F22_PMFD_FORMAT'),[3]=get('F22_LMFD_FORMAT'),
			[4]=get('F22_RMFD_FORMAT'),[5]=get('F22_CMFD_FORMAT'),
		}or nil,
	}
end
local function publish_display_control()
	put("F22_SOI", logic.soi)
end
function post_initialize()
	put("F22_SOI", 2)
	put("F22_CM_CONSENT", 0)
	put("F22_CM_AUTO_AVAILABLE", 0)
	bursts = 0;active_program = nil
	publish_display_control()
end
function SetCommand(c, v)
	if c == 10742 then
		v = input_value(v, devices.COMBAT_SYSTEM)
		if get("MAIN_POWER") > 0.5 and v == math.floor(v) and v >= 1 and v <= 5 then
			logic:focus(v)
			publish_display_control()
		end
		return
	end
	local n = by_id[c]
	if n then
		if (n == "scs_depress" or n:match("^dms_")) and get("MAIN_POWER") < 0.5 then
			publish_display_control()
			return
		end
		local decoded = input_value(v, devices.COMBAT_SYSTEM)
		if log and log.write then
			log.write("F22_HOTAS", log.INFO, n .. " value=" .. tostring(v) .. string.format(
				" decoded=%.3f mode=%d soi=%d primary=%.0f", decoded,
				logic.mode, logic.soi, get("F22_PMFD_PAGE")))
		end
		logic:input(n, decoded, context())
		publish_display_control()
	end
end
function update()
	clock = clock + dt
	-- Mirror keyboard/cockpit mode changes without re-emitting them.
	local mode = get("HUD_MODE")
	if mode >= 1 and mode <= 7 and mode ~= logic.mode then
		logic.mode = mode
		if mode == 2 or mode == 3 or mode == 5 then
			logic.last_aa = mode
		end
	end
	if get("MAIN_POWER") > 0.5 then
		logic:update(dt, context())
	else
		logic:cancel_ground_preview()
		logic.held = {}
		bursts = 0
		emit("trigger_first", 0)
		emit("trigger_second", 0)
		emit("pickle", 0)
	end
	publish_display_control()
	put("F22_DOGFIGHT", logic.dogfight and 1 or 0)
	if bursts > 0 and active_program and clock >= next_burst and get("MAIN_POWER") > 0.5 then
		local ok, native = pcall(GetDevice, devices.WEAPON_NATIVE)
		local released = false
		if ok and native and type(native.drop_chaff) == "function" and type(native.drop_flare) == "function"
			and type(native.get_chaff_count) == "function" and type(native.get_flare_count) == "function" then
			local success = pcall(function()
				local c,f = native:get_chaff_count(),native:get_flare_count()
				if type(c)~='number' or type(f)~='number' or c~=c or f~=f or c<0 or f<0 then return end
				local nc,nf = math.min(c,active_program.chaff),math.min(f,active_program.flare)
				if nc>0 then native:drop_chaff(nc);released=true end
				if nf>0 then native:drop_flare(nf);released=true end
			end)
			if not success then released = false end
		end
		bursts = released and bursts-1 or 0
		next_burst = clock + active_program.interval
	end
	put("F22_CM_PROGRAM_RUNNING", bursts > 0 and 1 or 0)
	put("F22_CM_BURSTS_REMAINING", bursts)
end
need_to_be_closed = false
