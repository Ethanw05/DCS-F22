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
local physical = dofile(LockOn_Options.script_path .. 'Systems/Physical_Snapshot.lua')
local steering = physical.new(get, {
	'EFM_NWS_SELECTED', 'EFM_GROUND_VALID', 'EFM_WEIGHT_ON_WHEELS',
})
local function toggle_steering()
	steering:update()
	local state = steering.values
	if steering.valid and state.EFM_GROUND_VALID == 1 and state.EFM_WEIGHT_ON_WHEELS == 1
		and physical.boolean(state.EFM_NWS_SELECTED) then
		-- The EFM owns steering authority; the inherited FC3 562 command does not.
		dispatch_action(nil, 11701, 1 - state.EFM_NWS_SELECTED)
	end
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
		send(devices.AG_MARK_SYSTEM, 10810, 1);send(devices.AG_MARK_SYSTEM, 10810, 0)
	elseif n == "ag_clear" then
		send(devices.AG_MARK_SYSTEM, 10811, 1);send(devices.AG_MARK_SYSTEM, 10811, 0)
	elseif n == "ground_tdc" then
		send(devices.RADAR_COMPUTER, v > 0 and radar.designate_begin or radar.designate_end)
	elseif n == "ground_acquire" then
		send(devices.RADAR_COMPUTER, v > 0 and radar.acquire_begin or radar.acquire)
	elseif n == "ground_preview_cancel" then
		send(devices.RADAR_COMPUTER, radar.preview_cancel)
	elseif n == "ag_waypoint" then
		send(devices.AG_MARK_SYSTEM, 10812, 1);send(devices.AG_MARK_SYSTEM, 10812, 0)
	elseif n == "ew_priority" then
		send(devices.RWR_SYSTEM, 10902)
	elseif n == "nav_zoom" then
		send(devices.NAV_SYSTEM, navigation.range_in)
	elseif n == 'nav_undesignate' then
		send(devices.NAV_SYSTEM, navigation.undesignate, 1)
		send(devices.NAV_SYSTEM, navigation.undesignate, 0)
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
	elseif n == "nav_cage" then
		send(devices.HUD_FLIGHT_DATA, 11840)
	elseif n == "nws" then
		toggle_steering()
	elseif n == "autopilot_off" then
		dispatch_action(nil, 408, 1)
	elseif n == "defense_program" then
		local command = 11099 + v
		send(devices.EW_SYSTEM, command, 1)
		send(devices.EW_SYSTEM, command, 0)
	elseif n == "defense_consent" then
		local command = v > 0 and 11111 or 11112
		send(devices.EW_SYSTEM, command, 1)
		send(devices.EW_SYSTEM, command, 0)
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
local physical_down, power_blocked = {}, {}
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
		local decoded = input_value(v, devices.COMBAT_SYSTEM)
		if decoded > 0 then
			physical_down[n] = true
			if get('MAIN_POWER') < .5 then power_blocked[n] = true end
			if power_blocked[n] then return end
		else
			physical_down[n], power_blocked[n] = nil, nil
		end
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
		for _, held in pairs(logic.held) do held.done = true end
		for name in pairs(physical_down) do power_blocked[name] = true end
		-- The weapon owner cancels consent from its physical supply snapshot.
		-- Fabricated UP events here erase physical ownership across recovery.
	end
	publish_display_control()
	put("F22_DOGFIGHT", logic.dogfight and 1 or 0)
end
need_to_be_closed = false
