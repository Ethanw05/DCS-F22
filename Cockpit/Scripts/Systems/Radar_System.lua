-- GPL-3.0-or-later. Single owner of radar power, controls and presentation.
dofile(LockOn_Options.script_path .. "devices.lua")
dofile(LockOn_Options.script_path .. "command_defs.lua")
local input_value = dofile(LockOn_Options.script_path .. "Systems/Input_Value.lua")
local radar_focus_policy = dofile(LockOn_Options.script_path .. "Systems/Radar_Focus.lua")
local radar_service = dofile(LockOn_Options.script_path .. "Systems/Radar_Service_Adapter.lua").new()
local commands = dofile(LockOn_Options.script_path .. "Systems/Radar_Commands.lua")
local computer = dofile(LockOn_Options.script_path .. "Systems/Radar_Computer.lua").new()
local task_library = dofile(LockOn_Options.script_path .. "Systems/Radar_Sensor_Tasking.lua")
local sensor_tasks = task_library.new()
local display = dofile(LockOn_Options.script_path .. "Systems/Radar_Display.lua")
local tactical = dofile(LockOn_Options.script_path .. "Systems/Radar_Tactical.lua")
local stt_contract = dofile(LockOn_Options.script_path .. "Systems/Radar_STT.lua")
local identification = dofile(LockOn_Options.script_path .. "Systems/Radar_IFF.lua").new()
local sensors = get_base_data()
local dev = GetSelf()
local dt = 1/60
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
tactical.publish({tracks={},clock=0}, put, false)
sensor_tasks:publish(put,0)
-- Indicators retain these handles; create them before their Lua states bind.
for i = 1, 24 do
	h(string.format("F22_SCOPE_%02d_DESIGNATED", i))
end
-- Native-video consumers must bind their handles before indicators initialize.
for _, name in ipairs({
 "F22_AG_VIDEO_SOURCE_PRESENT", "F22_AG_VIDEO_GEOMETRY_QUALIFIED", "F22_AG_VIDEO_READY",
 "F22_AG_VIDEO_REASON", "F22_AG_VIDEO_FRAMES", "F22_AG_VIDEO_ENABLE", "F22_AG_VIDEO_TIME",
 "F22_AG_VIDEO_NORTH", "F22_AG_VIDEO_ALTITUDE", "F22_AG_VIDEO_EAST", "F22_AG_VIDEO_HEADING",
 "F22_AG_VIDEO_FOV_DEG", "F22_AG_VIDEO_SCAN_DIRECTION", "F22_AG_VIDEO_SCAN_FRACTION",
 "F22_AG_VIDEO_SCAN_AZ_DEG", "F22_AG_VIDEO_GAIN", "F22_AG_VIDEO_GAIN_PCT",
 "F22_AG_VIDEO_FROZEN", "F22_AG_VIDEO_ERASE_SEQUENCE",
}) do h(name) end
local telemetry_config = dofile(LockOn_Options.script_path .. "Systems/Radar_Config.lua")
radar_service:publish(put, 0, telemetry_config.service_enabled, 0, false)
local telemetry = nil
if telemetry_config.telemetry_enabled then
	telemetry = dofile(LockOn_Options.script_path .. "Systems/Radar_Telemetry.lua").new(get, function(row)
		if log and log.write then
			log.write("F22_RADAR_TEST", log.INFO, row)
		end
	end)
end
local by_id = {}
for name, id in pairs(commands) do
	by_id[id] = name
	dev:listen_command(id)
end
-- Legacy mode keys remain usable; private commands avoid broadcast duplication.
local legacy = {
	[Keys.PlaneModeBVR] = "bvr",
	[Keys.PlaneModeVS] = "vertical",
	[Keys.PlaneModeBore] = "boresight",
	[285] = "toggle",
	[86] = "power",
	[88] = "cursor_left",
	[89] = "cursor_right",
	[90] = "cursor_up",
	[91] = "cursor_down",
}
for id in pairs(legacy) do
	dev:listen_command(id)
end
dev:listen_command(10620)
dev:listen_command(10621)
local slew_x, slew_y = 0, 0
local slew_focus, slew_role = nil, nil
local pending_unlock = false
local acquiring = false
local native_power = nil
local last_diagnostic = nil
local last_sensor_task_diagnostic = nil
local next_scope_diagnostic = 0
local emission_inhibited = false
local was_stt = false
local lock_iff = nil
local previous_hud_mode = 0
-- ACM is a weapon-specific request, not a global return mode. GUN starts in
-- WIDE; SRM keeps search until the pilot explicitly selects an ACM pattern.
local weapon_patterns = { [5] = "WIDE" }
local last_fusion = nil
local latest_pose = nil
local publish_sequence = 0
local last_acquire_request = -100
local previous_acquire_mode = -1
local ag = nil
local function sync_model_clock()
	if type(get_model_time) ~= "function" then
		return
	end
	local ok, now = pcall(get_model_time)
	if not ok or not display.finite(now) then
		return
	end
	if now < computer.clock - 0.001 then
		computer:reset()
		radar_service:reset(now)
		slew_x, slew_y, slew_focus, slew_role = 0, 0, nil, nil
		acquiring = false
		pending_unlock = false
		previous_acquire_mode = -1
		last_acquire_request = -100
	end
	computer.clock = now
	return now
end
local function sync_weapon_mode()
	local mode = get("HUD_MODE")
	if mode == previous_hud_mode or not ({[1]=true,[2]=true,[3]=true,[5]=true,[7]=true})[mode] then
		return
	end
	local old_mode, old_pattern = previous_hud_mode, computer.return_mode
	if old_mode == 3 or old_mode == 5 then
		weapon_patterns[old_mode] = computer:profile() and computer.mode or "SEARCH"
	end
	previous_hud_mode = mode
	local pattern = weapon_patterns[mode]
	local next_mode = pattern and pattern ~= "SEARCH" and pattern or computer.search_mode
	local native_mode = get("F22N_RADAR_MODE")
	if mode == 2 and not emission_inhibited then computer.power = true end
	if next_mode ~= computer.mode or computer.acquire or native_mode == 2 then
		if native_mode == 3 then
			-- Keep the confirmed target; reject/track loss must return to the
			-- new weapon's scan, never resurrect the previous GUN pattern.
			computer.mode, computer.return_mode = next_mode, next_mode
		else
			local command = ({VACQ="vertical",BORE="boresight",WIDE="wide"})[next_mode] or string.lower(next_mode)
			computer:command(command)
			computer.acquire_id = nil
			pending_unlock = true
			acquiring = false
		end
	end
	computer.return_mode = next_mode
	computer.scan, computer.effective_scan = nil, nil
	computer.rf_scan_windows = {}
	sensor_tasks:reset()
	if mode == 7 or old_mode == 7 then slew_x, slew_y = 0, 0 end
	if log and log.write then
		log.write("F22_RADAR_WEAPON_MODE", log.INFO, string.format(
			"t=%.3f from=%d to=%d previous=%s requested=%s return=%s native=%d acquire=%d pending_unlock=%d",
			computer.clock, old_mode, mode, old_pattern, next_mode, computer.return_mode,
			native_mode, computer.acquire and 1 or 0, pending_unlock and 1 or 0))
	end
end
function SetCommand(command, value)
	local command_time = sync_model_clock()
	-- Synchronize before accepting a pattern command as well as on update:
	-- weapon mode and its scan request can arrive during the same frame.
	sync_weapon_mode()
	if command >= 10600 and command <= 10652 then
		value = input_value(value, devices.RADAR_COMPUTER)
	end
	if get("HUD_MODE") == 7 and ag then
		local name = command == 10620 and "axis_x" or command == 10621 and "axis_y" or by_id[command] or legacy[command]
		if name == "axis_x" or name == "axis_y" then
			slew_focus, slew_role = get("F22_SOI"), get("HUD_MODE")
			if not display.finite(value) or not radar_focus_policy.allowed(get)
				or not computer.power or get("MAIN_POWER") <= 0.5 then value = 0 end
		end
		if name == "power" then
			if value > 0 then computer.power = not computer.power; emission_inhibited = not computer.power end
		elseif name == "operate" then
			if value > 0 and not emission_inhibited then computer.power = true end
		elseif name == "iff_auto" then
			if value > 0 then identification:toggle_auto() end
		else
			ag:command(name, value, computer.power and get("MAIN_POWER") > .5, command_time)
		end
		return
	end
	if command == 10620 then
		slew_focus, slew_role = get("F22_SOI"), get("HUD_MODE")
		slew_x = radar_focus_policy.allowed(get) and computer.power
			and get("MAIN_POWER") > 0.5 and display.finite(value) and value or 0
		if math.abs(slew_x) > 0.08 then
			computer.cursor_follow = false
		end
		return
	end
	if command == 10621 then
		slew_focus, slew_role = get("F22_SOI"), get("HUD_MODE")
		slew_y = radar_focus_policy.allowed(get) and computer.power
			and get("MAIN_POWER") > 0.5 and display.finite(value) and value or 0
		if math.abs(slew_y) > 0.08 then
			computer.cursor_follow = false
		end
		return
	end
	local name = by_id[command] or legacy[command]
	if not name or value <= 0 then
		return
	end
	if name == "operate" then
		if not emission_inhibited then computer.power = true end
		return
	end
	if name == "bvr" then
		if not emission_inhibited then computer.power = true end
		name = string.lower(computer.search_mode)
		if computer.mode == computer.search_mode then
			return
		end
	end
	local pattern = ({ vertical = "VACQ", boresight = "BORE", wide = "WIDE" })[name]
	if not emission_inhibited and (name == "rws" or name == "tws" or name == "toggle" or name == "designate") then
		computer.power = true
	end
	if pattern and computer.mode == pattern then
		return
	end -- retain confirmation/lock
	-- Selecting the next search pattern must not discard a valid native STT.
	-- It takes effect on deliberate reject or genuine native track loss.
	if (pattern or name == "rws" or name == "tws" or name == "toggle") and get("F22N_RADAR_MODE") == 3 then
		local next_mode = pattern
			or (name == "toggle" and (computer.search_mode == "TWS" and "RWS" or "TWS"))
			or string.upper(name)
		computer.mode = next_mode
		computer.return_mode = next_mode
		if next_mode == "RWS" or next_mode == "TWS" then
			computer.search_mode = next_mode
		end
		return
	end
	if name == "iff_auto" then
		identification:toggle_auto()
		return
	end
	if name == "interrogate" or name == "interrogate_los" then
		local t = computer.selected and computer.tracks[computer.selected]
		local a, e = computer.cursor_az, computer.elevation
		if t and latest_pose then
			local _, az, el = display.body_observation(t, latest_pose, computer:age(t))
			a, e = az, el
		end
		identification:request(name, computer.clock, a, e)
		return
	end
	-- The shared backend can guide one STT target. Reject before swapping.
	if name == "swap_targets" and get("F22N_RADAR_MODE") == 3 then
		return
	end
	if
		name == "undesignate"
		or name == "rws"
		or name == "tws"
		or name == "toggle"
		or name == "vertical"
		or name == "boresight"
		or name == "wide"
		or name == "power"
	then
		pending_unlock = true
	end
	if latest_pose then
		computer:geometry(display, latest_pose)
	end
	sensor_tasks:command(name,computer.clock)
	computer:command(name)
	if name == "power" then emission_inhibited = not computer.power end
	if (name == "designate" or name == "stt") and log and log.write then
		local t = computer.selected and computer.tracks[computer.selected]
		log.write(
			"F22_RADAR_DESIGNATE",
			log.INFO,
			string.format(
				"mode=%s native=%.0f file=%d source=%d acquire=%s cursor=(%.1f,%.3f) age=%.2f",
				computer.mode,
				get("F22N_RADAR_MODE"),
				computer.selected or 0,
				t and t.native_id or 0,
				tostring(computer.acquire),
				computer.cursor_range,
				computer.cursor_az,
				t and computer.clock - t.observed or 999
			)
		)
	end
end
function post_initialize()
	slew_x, slew_y, slew_focus, slew_role = 0, 0, nil, nil
	radar_service:reset()
	radar_service:publish(put, 0, telemetry_config.service_enabled, 0, false)
	sensor_tasks:reset()
	last_sensor_task_diagnostic = nil
	sensor_tasks:publish(put,0)
	-- Default to radar operation. Actual emission still requires electrical
	-- supply and a qualified native backend; deliberate OFF remains respected.
	computer.power = true
	put("RADAR_PWR", 0)
	put("F22_RADAR_SUPPLY", 0)
	put("F22_RADAR_BACKEND_READY", 0)
	put("F22_RADAR_FC_ENABLE", 1)
	put("F22_RADAR_STT_VALID", 0)
	put("F22_RADAR_EMISSION_INHIBIT", 0)
end
local function native_command(c)
	dispatch_action(devices.RADAR_NATIVE, c, 1)
end
ag = dofile(LockOn_Options.script_path .. "Systems/AG_Radar_System.lua").new(get, put, native_command)
local function publish_quality(prefix, t)
	local age = computer:age(t)
	put(prefix .. "AGE", display.finite(age) and age or 999)
	put(prefix .. "QUALITY", computer:quality(t))
	put(prefix .. "HITS", t and t.hits or 0)
	put(prefix .. "REVISIT_S", t and t.revisit_s or 0)
	put(prefix .. "PREDICTION_ERROR_VALID", t and t.prediction_error_m and 1 or 0)
	put(prefix .. "PREDICTION_ERROR_M", t and t.prediction_error_m or 0)
end
function update()
	local model_time = sync_model_clock()
	local step = model_time and 0 or dt
	-- Radar owns weapon-entry/exit state regardless of the input source.
	local hud_mode = get("HUD_MODE")
	sync_weapon_mode()
	local north, altitude, east = sensors.getSelfCoordinates()
	local heading = (2 * math.pi - sensors.getHeading()) % (2 * math.pi)
	local pose = nil
	local pitch, roll = sensors.getPitch(), sensors.getRoll()
	if
		display.finite(north)
		and display.finite(altitude)
		and display.finite(east)
		and display.finite(pitch)
		and display.finite(roll)
		and display.finite(heading)
	then
		pose = {
			north = north,
			east = east,
			altitude = altitude,
			heading = heading,
			pitch = pitch,
			roll = roll,
			time = computer.clock + step,
		}
	end
	latest_pose = pose
	display.compass(heading, put)
	put("F22_RADAR_HEADING_DEG", math.floor(math.deg(heading) + 0.5) % 360)
	local radar_focus = radar_focus_policy.allowed(get)
	local cursor_authority = radar_focus and get("MAIN_POWER") > 0.5 and computer.power
		and slew_focus == get("F22_SOI") and slew_role == hud_mode
	if not cursor_authority then
		slew_x, slew_y = 0, 0
	end
	if radar_focus and math.abs(slew_x) > 0.08 then
		computer.cursor_az = math.max(-math.rad(60), math.min(math.rad(60), computer.cursor_az + slew_x * dt * 0.4))
	end
	if radar_focus and math.abs(slew_y) > 0.08 then
		computer.cursor_range =
			math.max(40, math.min(computer:range(), computer.cursor_range + slew_y * dt * computer:range() * 0.4))
	end
	local powered = computer.power and get("MAIN_POWER") > 0.5
	local now_stt = get("F22N_RADAR_MODE") == 3
	if now_stt and not was_stt then
		lock_iff = nil
	end
	if not now_stt then
		lock_iff = nil
	end
	was_stt = now_stt
	identification:update(computer.clock, powered)
	local iff_enabled = identification:enabled()
	put("F22_RADAR_EMISSION_INHIBIT", emission_inhibited and 1 or 0)
	put("F22_RADAR_IFF_AUTO", identification.automatic and 1 or 0)
	put("F22_RADAR_IFF_REQUEST", identification.mode)
	put("F22_RADAR_IFF_REMAINING", identification.mode ~= 0 and math.max(0, identification.until_time - computer.clock) or 0)
	put("F22_RADAR_SUPPLY", powered and 1 or 0)
	put("RADAR_PWR", powered and 1 or 0)
	put("F22N_IFF_INTERROGATOR_STATUS", powered and iff_enabled and 1 or 0)
	put("F22_RADAR_IFF_ON", powered and iff_enabled and 1 or 0)
	local native = nil
	if GetDevice then
		local ok, result = pcall(GetDevice, devices.RADAR_NATIVE)
		if ok then
			native = result
		end
	end
	local available = native and type(native.set_power) == "function"
	local ready = available and get("F22_RADAR_ACQ_COORDINATES_READY") > 0.5
	local service_resource = radar_service:health(get, computer.clock + step, powered)
	ready = ready and service_resource >= 0.1
	put("F22_RADAR_DEVICE_ID", devices.RADAR_NATIVE)
	-- The A/G computer keeps its frozen picture powered in SIL while the
	-- owned native transmitter is independently inhibited.
	if hud_mode==7 then
	 if not cursor_authority then ag:command("axis_x",0,powered);ag:command("axis_y",0,powered)end
	 ag:update(pose,computer.clock,dt,powered,ready)
	end
	local requested_power = powered and ready and (hud_mode~=7 or ag:emitting())
	put("F22_RADAR_EMISSION_INHIBIT",(emission_inhibited or (hud_mode==7 and not ag:emitting()))and 1 or 0)
	if available and native_power ~= requested_power then
		local ok = pcall(function()
			native:set_power(requested_power)
		end)
		if ok then
			native_power = requested_power
		else
			ready = false
		end
	end
	put("F22_RADAR_BACKEND_READY", ready and 1 or 0)
	put("F22_AG_RADAR_PAGE", hud_mode == 7 and 1 or 0)
	if hud_mode == 7 then
		radar_service:reset(computer.clock)
		radar_service:publish(put, service_resource, telemetry_config.service_enabled, 0, true, ready)
		computer.effective_scan=nil
		computer.rf_scan_windows={}
		sensor_tasks:reset()
		sensor_tasks:publish(put,computer.clock)
		tactical.publish(computer, put, false)

		return
	end
	put("F22_AG_RADAR_OPERATING", 0)
	put("F22_AG_RADAR_EMITTING",0)
	ag.controls.active=false;ag.controls.active_end=nil;ag.controls.pending=0
	ag:cancel_preview()
	put("F22_RADAR_FC_ENABLE", 1)
	local native_mode = get("F22N_RADAR_MODE")
	if pending_unlock then
		if native_mode == 3 then
			native_command(509)
		elseif native_mode == 2 then
			native_command(510)
		end
		-- Do not feed the previous STT/acquisition export into the newly
		-- selected pattern while the native unlock command is taking effect.
		if native_mode == 3 or native_mode == 2 then
			native_mode = 1
		end
		pending_unlock = false
		acquiring = false
	end
	local observations = {}
	-- Native scan polar angles include scan-origin elevation and stabilization.
	-- Use only sensor-detected world observations from the checked ABI bridge;
	-- project those into the current aircraft frame for gating and acquisition.
	local observations_ready = get("F22_RADAR_OBSERVATIONS_READY") > 0.5
	put("F22_RADAR_OBSERVATION_BACKEND_READY", observations_ready and 1 or 0)
	if
		powered
		and ready
		and observations_ready
		and pose
		and (native_mode == 1 or native_mode == 2 or native_mode == 6)
	then
		for i = 1, math.min(64, math.max(0, get("F22_RADAR_OBSERVATION_COUNT"))) do
			local p = string.format("F22O_%02d_", i)
			local age = get(p .. "AGE")
			local id = get(p .. "ID")
			if
				display.finite(age)
				and age >= 0
				and age <= computer:memory_time()
				and id > 0
				and display.finite(get(p .. "NORTH"))
				and display.finite(get(p .. "EAST"))
				and display.finite(get(p .. "ALTITUDE"))
			then
				local o = {
					native_id = id,
					age = age,
					observed = computer.clock + step - age,
					north = get(p .. "NORTH"),
					east = get(p .. "EAST"),
					altitude = get(p .. "ALTITUDE"),
					iff = get(p .. "IFF"),
					vn = get(p .. "VN"),
					vu = get(p .. "VU"),
					ve = get(p .. "VE"),
				}
				o.velocity_valid = display.finite(o.vn) and display.finite(o.ve) and display.finite(o.vu)
				o.range, o.az, o.el = display.body_observation(o, pose, age)
				o.iff = identification:reply(o.iff, o.observed, o.az, o.el, true)
				observations[#observations + 1] = o
			end
		end
	end
	-- STT exports are timestamped measurements too. Re-reading one cache must
	-- not count as another hit or make its age zero on each Lua activity.
	local stt_observation = nil
	if powered and ready and native_mode == 3 and pose and model_time and get("F22_STT_MOTION_VALID") > 0.5 then
		local stamp = get("F22_STT_TIME")
		local age = model_time - stamp
		if stt_contract.fresh(model_time, stamp) then
			age = math.max(0, age)
			local o = {
				native_id = get("F22_STT_ID"),
				age = age,
				observed = computer.clock + step - age,
				north = get("F22_STT_PN"),
				east = get("F22_STT_PE"),
				altitude = get("F22_STT_PU"),
				vn = get("F22_STT_VN"),
				ve = get("F22_STT_VE"),
				vu = get("F22_STT_VU"),
				velocity_valid = true,
				iff = iff_enabled and get("F22N_RADAR_STT_FRIENDLY") or -1,
			}
			o.velocity_valid = display.finite(o.vn) and display.finite(o.ve) and display.finite(o.vu)
			o.range, o.az, o.el = display.body_observation(o, pose, age)
			o.iff = identification:reply(o.iff, o.observed, o.az, o.el)
			-- Native STT publishes a friendly boolean, not the full detected
			-- contact class. Maintain an already confirmed affiliation while the
			-- same exact source stays in fresh hard lock; otherwise a long dogfight
			-- would lose known hostile ID when the old search reply aged out.
			if o.iff == -1 then
				local known = computer:source(o.native_id)
				if known and ((known.friend_until and known.friend_until > computer.clock)
					or (known.hostile_until and known.hostile_until > computer.clock)) then
					o.iff = known.iff
				end
			end
			if o.native_id > 0 and display.finite(o.range) and display.finite(o.az) and display.finite(o.el) then
				observations[#observations + 1] = o
				stt_observation = o
			end
		end
	end
	if powered and ready and pose and telemetry_config.service_enabled then
		observations = radar_service:process(computer.clock + step, computer, observations, native_mode, service_resource)
		for i = 1, #observations do
			local o = observations[i]
			o.age = math.max(0, computer.clock + step - o.observed)
			o.range, o.az, o.el = display.body_observation(o, pose, o.age)
		end
	elseif not powered or not ready or not pose then
		radar_service:reset(computer.clock + step)
	end
	radar_service:publish(put, service_resource, telemetry_config.service_enabled, native_mode, false, ready)
	if powered and ready then
		computer:update(step, observations, native_mode)
	else
		computer:reset()
		computer.clock = computer.clock + step
	end
	if native_mode == 3 and stt_observation then
		for id, t in pairs(computer.tracks) do
			if t.native_id == stt_observation.native_id then
				computer.selected = id
				if computer.secondary == id then
					computer.secondary = nil
				end
				break
			end
		end
	end
	if pose then
		computer:geometry(display, pose)
	end
	local required = {}
	for i = 1, 8 do
		local p = string.format("F22_MSL_%02d_", i)
		local id = get(p .. "TARGET")
		if get(p .. "SUPPORT_REQUIRED") > 0.5 and display.finite(id) and id > 0 then
			required[#required + 1] = id
		end
	end
	local scan = nil
	radar_service.required = required
	if powered and ready and pose then
		scan = computer:scan_plan(required)
	else
		computer.scan = nil
	end
	local rf_cues={}
	if powered and ready and pose and get("HUD_MODE")~=7 then
		rf_cues=task_library.read(get,computer.clock,pose)
	end
	scan=sensor_tasks:update(computer.clock,computer,scan,rf_cues,
		telemetry_config.rf_tasking_enabled~=false and powered and ready and pose~=nil and get("HUD_MODE")~=7)
	computer:set_effective_scan(scan,computer.clock)
	sensor_tasks:publish(put,computer.clock)
	if log and log.write then
		local task=sensor_tasks.status or{}
		local signature=string.format("task=%d source=%d pending=%d",task.task or 0,task.source or 0,task.pending or 0)
		if signature~=last_sensor_task_diagnostic then
			log.write("F22_SENSOR_TASK",log.INFO,signature..string.format(
				" rf_age=%.2f az=%.1f el=%.1f width=%.1f height=%.1f hard=%d support=%d",
				task.age or -1,math.deg(scan and scan.az or 0),
				math.deg(scan and scan.el or computer.elevation),
				math.deg(scan and scan.half_az or math.rad(computer.azimuth))*2,
				math.deg(scan and scan.half_el or math.rad(computer.vertical_span/2))*2,
				scan and scan.obligations or 0,scan and scan.support_count or 0))
			last_sensor_task_diagnostic=signature
		end
	end
	put("F22_RADAR_SCAN_AUTO", powered and ready and scan and 1 or 0)
	put("F22_RADAR_SCAN_OBLIGATIONS", scan and scan.obligations or 0)
	put("F22_RADAR_SCAN_UNCOVERED", scan and scan.uncovered or 0)
	put("F22_RADAR_SUPPORT_OVERDUE", scan and scan.support_overdue or 0)
	put("F22_RADAR_SUPPORT_TASKS", scan and scan.support_count or 0)
	put("F22_RADAR_REVISIT_REMAINING", scan and scan.support_count > 0 and scan.revisit_remaining or 0)
	put("F22_RADAR_SUPPORT_DEGRADED", scan and scan.support_count > 0 and (scan.uncovered > 0 or scan.support_overdue > 0) and 1 or 0)
	put("F22_RADAR_SCAN_COVERAGE_COMPLETE", powered and ready and scan and scan.uncovered == 0 and 1 or 0)
	put("F22_RADAR_SCAN_RANGE_NM", scan and scan.range / 1852 or computer:range() / 1852)
	local identities = {}
	for _, t in pairs(computer.tracks) do
		if t.native_id and t.ident_time then
			identities[#identities + 1] = t
		end
	end
	table.sort(identities, function(a, b)
		return a.native_id < b.native_id
	end)
	for i = 1, 64 do
		local p = string.format("F22_IDENT_%02d_", i)
		local t = identities[i]
		local age = t and math.max(0, computer.clock - t.ident_time) or 999
		put(p .. "VALID", t and age <= 30 and 1 or 0)
		put(p .. "SOURCE", t and t.native_id or 0)
		put(p .. "CLASS", t and t.ident_class or -1)
		put(p .. "AGE", age)
	end
	local mode = not powered and "OFF"
		or (not ready or (not observations_ready and native_mode ~= 3)) and "SENSOR N/A"
		or native_mode == 3 and not stt_observation and "SENSOR N/A"
		or native_mode == 0 and "STBY"
		or native_mode == 3 and "STT"
		or computer.acquire and "ACQ"
		or computer.mode
	put("F22_RADAR_MODE_TEXT", mode)
	put(
		"F22_RADAR_MODE_CODE",
		({ OFF = 0, STBY = 1, RWS = 2, TWS = 3, ACQ = 4, STT = 5, BORE = 6, VACQ = 7, WIDE = 8, ["SENSOR N/A"] = 9 })[mode]
			or 9
	)
	local sr, sa, se = 0, 0, 0
	if stt_observation then
		sr, sa, se = stt_observation.range, stt_observation.az, stt_observation.el
	end
	local stt_valid = powered
		and ready
		and native_mode == 3
		and stt_observation ~= nil
		and display.finite(sr)
		and sr >= 40
		and sr <= 300000
		and display.finite(sa)
		and display.finite(se)
		and math.abs(sa) <= math.pi / 2
		and math.abs(se) <= math.pi / 2
	-- One timestamped contract for scope, HUD and gun-target consumers.
	put("F22_RADAR_STT_SOURCE_ID", stt_valid and stt_observation.native_id or 0)
	put("F22_RADAR_STT_TIME", stt_valid and stt_observation.observed or -100)
	put("F22_RADAR_STT_RANGE", stt_valid and sr or 0)
	put("F22_RADAR_STT_AZIMUTH", stt_valid and sa or 0)
	put("F22_RADAR_STT_ELEVATION", stt_valid and se or 0)
	local identified_track = stt_observation and computer:source(stt_observation.native_id)
	local friend = stt_valid and (stt_observation.iff == 1 or identified_track and identified_track.iff == 1)
	put("F22_RADAR_STT_IFF", friend and 1 or stt_valid and identified_track and identified_track.iff == 0 and 0 or -1)
	local closure_valid, closure = false, 0
	if stt_valid and stt_observation.velocity_valid and get("EFM_HUD_VALID") > .5 then
		local age = math.max(0, computer.clock - stt_observation.observed)
		local dn = stt_observation.north + stt_observation.vn * age - pose.north
		local de = stt_observation.east + stt_observation.ve * age - pose.east
		local du = stt_observation.altitude + stt_observation.vu * age - pose.altitude
		local vn, ve, vu = get("EFM_HUD_VN"), get("EFM_HUD_VE"), get("EFM_HUD_VU")
		if display.finite(vn) and display.finite(ve) and display.finite(vu) then
			closure = ((vn - stt_observation.vn) * dn + (ve - stt_observation.ve) * de + (vu - stt_observation.vu) * du) / sr * 1.943844492
			closure_valid = display.finite(closure)
		end
	end
	put("F22_RADAR_STT_CLOSURE_VALID", closure_valid and 1 or 0)
	put("F22_RADAR_STT_CLOSURE_KTS", closure_valid and closure or 0)
	put("F22_RADAR_STT_VALID", stt_valid and 1 or 0)
	local scope_range = computer:scope_range(stt_valid and sr or nil)
	put("F22_RADAR_RANGE_NM", scope_range / 1852)
	put("F22_RADAR_HALF_RANGE_NM", scope_range / 3704)
	put("F22_RADAR_AZ_DEG", computer.azimuth)
	put("F22_RADAR_SEARCH_WIDTH_DEG", computer.azimuth * 2)
	put("F22_RADAR_SEARCH_HEIGHT_DEG", computer.vertical_span)
	put("F22_RADAR_EL_DEG", math.deg(computer.elevation))
	put("PMFD_RADAR_SELECTION", computer.search_mode == "TWS" and 1 or 0)
	local vertical = computer.mode == "VACQ"
	local bore = computer.mode == "BORE"
	local wide = computer.mode == "WIDE"
	local acm = vertical or bore or wide
	put("F22_ACM_MODE", native_mode ~= 3 and (vertical and 2 or bore and 1 or wide and 3 or 0) or 0)
	-- Body-frame scan coordinates: do not mix stabilized polar returns with HUD LOS.
	local profile = computer:profile()
	local scan_az = math.rad(profile and profile.az or computer.azimuth)
	local scan_el = math.rad(profile and (profile.hi - profile.lo) / 2 or computer.vertical_span / 2)
	if scan then
		scan_az = scan.half_az
		scan_el = scan.half_el
	end
	put("F22_RADAR_SCAN_AZ_DEG", math.deg(scan_az) * 2)
	put("F22_RADAR_SCAN_EL_DEG", math.deg(scan_el) * 2)
	put("F22_RADAR_SCAN_CENTER_EL_DEG", math.deg(stt_valid and se or scan and scan.el or computer.elevation))
	-- The selected ACM profile is the search to resume after track loss. It is
	-- not the antenna's active direction during confirmed native STT. Show that
	-- measured tracking LOS as one line; no invented tracking beam width.
	put("F22_RADAR_COVERAGE_VALID", powered and ready and (native_mode ~= 3 or stt_valid) and 1 or 0)
	local tracking_bearing = 0
	if stt_valid then
		-- This display is heading-up: project the observed world LOS just as
		-- the target symbol does, including during pitch/roll maneuvers.
		local _, bearing = display.scope_observation(stt_observation, pose,
			math.max(0, computer.clock - stt_observation.observed))
		tracking_bearing = bearing
	end
	put("F22_RADAR_COVERAGE_CENTER_ROT", stt_valid and -tracking_bearing or scan and -scan.az or 0)
	put("F22_RADAR_EXPANDED", computer.expand and 1 or 0)
	put("F22_RADAR_COVERAGE_ROT", native_mode == 3 and 0 or scan_az)
	-- Search-pattern azimuth is a native beam rotation, opposite body +Z.
	-- Unlike the TDC input below, the native owner does not negate this input.
	put("F22N_SCAN_ZONE_ORIGIN_AZIMUTH", scan and -scan.az or 0)
	put(
		"F22N_SCAN_ZONE_ORIGIN_ELEVATION",
		scan and scan.el or profile and math.rad((profile.hi + profile.lo) / 2) or computer.elevation
	)
	put("F22N_SCAN_ZONE_VOLUME_AZIMUTH", scan_az * 2)
	put("F22N_SCAN_ZONE_VOLUME_ELEVATION", scan_el * 2)
	-- Scan centres and gates are already in the current aircraft body frame.
	-- AUTO projects real world tracks through the current pitch/roll every tick.
	-- Native stabilization would rotate that plan again during a maneuver.
	put("F22N_RADAR_PITCH_BANK_STABILIZATION", 0)
	put("F22N_RADAR_PITCH_STABILIZATION", 0)
	put("F22N_RADAR_BANK_STABILIZATION", 0)
	put("F22N_SCAN_VOLUME_CUT_OFF_DISTANCE_MIN", 40)
	put("F22N_SCAN_VOLUME_CUT_OFF_DISTANCE_MAX", scan and scan.range or computer:range())
	put("F22N_ACQUSITION_ZONE_VOLUME_AZIMUTH", math.rad(6))
	put("F22N_RADAR_TDC_RANGE_CARRET_SIZE", 1500)
	local selected = computer.selected and computer.tracks[computer.selected]
	-- Keep the native candidate-ranking centre in body +Z. The checked native
	-- coordinate adapter supplies the opposite pattern rotation to the scanner,
	-- so both the beam and candidate ranking follow this same selected LOS.
	local ar, aa, ae = computer.cursor_range, computer.cursor_az, computer.elevation
	local acquisition_track = computer.acquire_id and computer.tracks[computer.acquire_id]
	if acquisition_track and computer.acquire then
		ar, aa, ae =
			display.body_observation(acquisition_track, pose, math.max(0, computer.clock - acquisition_track.observed))
		do
			-- Acquire around the candidate LOS, including elevation. Keeping
			-- VACQ's search centre here does not follow a crossing close target.
			put("F22N_SCAN_ZONE_ORIGIN_ELEVATION", ae)
			put("F22N_SCAN_ZONE_VOLUME_ELEVATION", math.rad(10))
			put("F22N_ACQUSITION_ZONE_VOLUME_AZIMUTH", acm and scan_az * 2 or math.rad(8))
		end
	end
	put("F22N_RADAR_TDC_AZIMUTH", -aa)
	put("F22N_RADAR_TDC_RANGE", ar)
	-- Native acquisition can briefly enter STT and reject it between Lua ticks.
	-- Re-request from native search; a stale local latch must not block retry.
	if
		computer.acquire
		and ready
		and native_mode == 1
		and (not acquiring or previous_acquire_mode == 2 or computer.clock - last_acquire_request >= 0.25)
	then
		native_command(509)
		acquiring = true
		last_acquire_request = computer.clock
	end
	previous_acquire_mode = native_mode
	if not computer.acquire or not ready then
		if acquiring and native_mode == 2 then
			native_command(510)
		end
		acquiring = false
	end
	local cursor_x, cursor_y = display.point(computer.cursor_range, computer.cursor_az, scope_range)
	put("F22_RADAR_CURSOR_X", cursor_x)
	put("F22_RADAR_CURSOR_Y", cursor_y)
	local locked_track = stt_observation and computer:source(stt_observation.native_id)
	local visible = {}
	if powered and ready and native_mode == 3 then
		local r, a, e = sr, sa, se
		if stt_valid and math.abs(a) <= math.rad(60) then
			lock_iff = get("F22_RADAR_STT_IFF")
			visible[1] = {
				id = locked_track and locked_track.id or 0,
				range = r,
				az = a,
				el = e,
				stt = true,
				iff = lock_iff or -1,
				ident_class = locked_track and locked_track.ident_class or lock_iff,
				native_id = locked_track and locked_track.native_id or nil,
			}
			visible[1].observed = locked_track and locked_track.observed
			visible[1].hits = locked_track and locked_track.hits or 0
			visible[1].revisit_s = locked_track and locked_track.revisit_s
			visible[1].prediction_error_m = locked_track and locked_track.prediction_error_m
			display.world_observation(visible[1], pose)
		end
		-- Other files coast honestly during single-target track.
		for _, t in pairs(computer.tracks) do
			if t.id ~= computer.selected and computer:quality(t) > 0 then
				visible[#visible + 1] = t
			end
		end
	else
		for _, t in pairs(computer.tracks) do
			if t.hits >= 1 then
				visible[#visible + 1] = t
			end
		end
	end
	table.sort(visible, function(a, b)
		local ab = a.stt or (a.id and a.id == computer.selected)
		local bb = b.stt or (b.id and b.id == computer.selected)
		if not not ab ~= not not bb then
			return not not ab
		end
		return a.range < b.range
	end)
	put("F22_RADAR_TRACK_COUNT", #visible)
	local drawn_count = 0
	put("F22_RADAR_SELECTED_EW_SIGNAL", 0)
	local diagnostic = string.format(
		"power=%s api=%s native=%s mode=%s returns=%d",
		tostring(powered),
		tostring(ready),
		tostring(native_mode),
		mode,
		#visible
	)
	if diagnostic ~= last_diagnostic and log and log.write then
		log.write("F22_RADAR", log.INFO, diagnostic)
		last_diagnostic = diagnostic
	end
	for i = 1, 24 do
		local t = visible[i]
		local p = string.format("F22_SCOPE_%02d_", i)
		local current_range = t and (t.current_range or t.range) or 0
		local current_az = t and (t.current_az or t.az) or 0
		local valid = t
			and current_range >= 40
			and math.abs(current_az) <= math.rad(60)
			and current_range <= scope_range
		put(p .. "VALID", valid and 1 or 0)
		local age = t and t.observed and math.max(0, computer.clock - t.observed) or 0
		local x, y = 0, 0
		if t then
			x, y = display.plot(t, pose, scope_range, age)
		end
		valid = valid and math.abs(x) < 0.95 and y > -0.93 and y < 0.96
		put(p .. "VALID", valid and 1 or 0)
		put(p .. "X", x)
		put(p .. "Y", y)
		if valid then
			drawn_count = drawn_count + 1
		end
		put(p .. "SELECTED", t and (t.stt or (t.id and t.id == computer.selected)) and 1 or 0)
		put(p .. "SECONDARY", t and t.id == computer.secondary and 1 or 0)
		put(
			p .. "DESIGNATED",
			t and (t.designated or t.id == computer.selected or t.id == computer.secondary) and 1 or 0
		)
		local ew_signal = 0
		if t and t.native_id then
			for j = 1, 16 do
				local ew = string.format("F22_EW_%02d_", j)
				if get(ew .. "SOURCE") == t.native_id and get(ew .. "AGE") <= 12 then
					ew_signal = get(ew .. "SIGNAL")
					break
				end
			end
		end
		put(p .. "EW_SIGNAL", ew_signal)
		if t and (t.stt or t.id == computer.selected) then
			put("F22_RADAR_SELECTED_EW_SIGNAL", ew_signal)
		end
		publish_quality(p, t)
		put(p .. "COAST", computer:quality(t) == 3 and 1 or 0)
		put(p .. "ID", t and t.id or 0)
		put(p .. "SOURCE", t and t.native_id or 0)
		local affiliation = display.affiliation(t and t.iff)
		-- A correlated emitter does not turn simulator coalition into combat ID.
		put(p .. "AFFILIATION", affiliation)
		put(p .. "ALT_VALID", t and display.finite(t.altitude) and 1 or 0)
		put(p .. "ALT_FT", t and t.altitude and t.altitude * 3.280839895 or 0)
		local vx, vy = 0, 0
		if t and t.velocity_valid then
			vx = display.radius * (-t.vn * math.sin(heading) + t.ve * math.cos(heading)) * 30 / scope_range
			vy = display.radius * (t.vn * math.cos(heading) + t.ve * math.sin(heading)) * 30 / scope_range
		end
		put(p .. "VECTOR_X", vx)
		put(p .. "VECTOR_Y", vy)
		put(p .. "VECTOR_LEN", math.sqrt(vx * vx + vy * vy))
		put(p .. "VECTOR_ROT", -(math.atan2(vx, vy)))
	end
	put("F22_RADAR_DRAWN_COUNT", drawn_count)
	if telemetry_config.telemetry_enabled then
		local rows = {}
		for i = 1, 24 do
			local p = string.format("F22_SCOPE_%02d_", i)
			if get(p .. "VALID") > 0.5 then
				rows[#rows + 1] = string.format(
					"file=%d source=%d iff=%d ew=%d pri=%d sec=%d coast=%d",
					get(p .. "ID"),
					get(p .. "SOURCE"),
					get(p .. "AFFILIATION"),
					get(p .. "EW_SIGNAL"),
					get(p .. "SELECTED"),
					get(p .. "SECONDARY"),
					get(p .. "COAST")
				)
			end
		end
		local signature = table.concat(rows, "; ")
		if signature ~= last_fusion and log and log.write then
			log.write("F22_SA", log.INFO, signature ~= "" and signature or "no ranged files")
			last_fusion = signature
		end
	end
	if powered and computer.clock >= next_scope_diagnostic and log and log.write then
		next_scope_diagnostic = computer.clock + 1
		log.write(
			"F22_RADAR_SCOPE",
			log.INFO,
			string.format(
				"pattern=%s native=%.0f raw=%d plots=%d drawn=%d page=%.0f opacity=%.2f scale=%.6f cue=(%.1f,%.4f,%.4f) first=(%.3f,%.3f) tws_backend=%.0f weapon_target=%.0f support_calls=%.0f support_ok=%.0f shot_seq=%.0f",
				computer.mode,
				native_mode,
				#observations,
				#visible,
				drawn_count,
				get("PMFD_RDR_PAGE"),
				get("MFD_OPACITY"),
				get("F22_RADAR_PAGE_SCALE"),
				ar,
				aa,
				ae,
				get("F22_SCOPE_01_X"),
				get("F22_SCOPE_01_Y"),
				get("F22_TWS_GUIDANCE_BACKEND_READY"),
				get("F22_RADAR_WEAPON_TARGET_ID"),
				get("F22_TWS_SUPPORT_QUERIES"),
				get("F22_TWS_SUPPORT_ACCEPTS"),
				get("F22_LAUNCH_SEQUENCE")
			)
		)
	end
	-- TWS designation is not a native weapon lock. Keep that distinction explicit.
	local secondary = computer.secondary and computer.tracks[computer.secondary]
	local age2 = secondary and math.max(0, computer.clock - secondary.observed) or 999
	local r2, a2, e2 = 0, 0, 0
	if secondary and pose then
		r2, a2, e2 = display.body_observation(secondary, pose, age2)
	end
	put("F22_RADAR_SECONDARY_VALID", powered and ready and secondary and computer:quality(secondary) > 0 and 1 or 0)
	put("F22_RADAR_SECONDARY_AZ", a2)
	put("F22_RADAR_SECONDARY_EL", e2)
	put("F22_RADAR_SECONDARY_RANGE", r2)
	put("F22_RADAR_SECONDARY_AGE", age2)
	put("F22_RADAR_SECONDARY_SWAP_AVAILABLE", secondary and native_mode ~= 3 and 1 or 0)
	local support_tracks = {}
	local priority = {}
	for _, id in ipairs(required) do
		priority[id] = true
	end
	if selected and selected.native_id then
		priority[selected.native_id] = true
	end
	if secondary and secondary.native_id then
		priority[secondary.native_id] = true
	end
	for _, t in pairs(computer.tracks) do
		if computer:supportable(t) then
			support_tracks[#support_tracks + 1] = t
		end
	end
	table.sort(support_tracks, function(a, b)
		if not not priority[a.native_id] ~= not not priority[b.native_id] then
			return not not priority[a.native_id]
		end
		return a.native_id < b.native_id
	end)
	for i = 1, 24 do
		local p = string.format("F22_SUPPORT_%02d_", i)
		local t = support_tracks[i]
		put(p .. "ID", t and t.native_id or 0)
		put(p .. "AGE", t and math.max(0, computer.clock - t.observed) or 999)
	end
	publish_sequence = publish_sequence + 1
	-- Support of an existing launched ID is independent of selecting a new
	-- TWS launch target. STT cannot revisit other files; their real ages expire.
	put("F22_RADAR_SUPPORT_ENABLED", powered and ready and 1 or 0)
	put("F22_TWS_ACTIVE", powered and ready and computer.mode == "TWS" and native_mode ~= 3 and 1 or 0)
	put("F22_TWS_TARGET_ID", computer:supportable(selected) and selected.native_id or 0)
	put("F22_TWS_TARGET_AGE", selected and math.max(0, computer.clock - selected.observed) or 999)
	put("F22_TWS_TARGET_RANGE", selected and (selected.current_range or selected.range) or 0)
	tactical.publish(computer, put, powered and ready, stt_observation)
	put("F22_TWS_PUBLISH_SEQUENCE", publish_sequence)
	local quality_track = selected
	if native_mode == 3 then
		quality_track = locked_track
	end
	publish_quality("F22_RADAR_SELECTED_", quality_track)
	put("F22_RADAR_SELECTED_MEASUREMENT_SOURCE", quality_track and quality_track.measurement_source or 0)
	put("F22_RADAR_SELECTED_SUPPORT_ELIGIBLE", powered and ready and computer:supportable(quality_track) and 1 or 0)
	put("F22_RADAR_SELECTED_VALID", powered and ready and (computer:quality(selected) > 0 or stt_valid) and 1 or 0)
	local friendly = native_mode == 3 and lock_iff == 1 or native_mode ~= 3 and selected and selected.iff == 1
	put("F22_RADAR_SELECTED_FRIENDLY", powered and ready and friendly and 1 or 0)
	put(
		"F22_RADAR_SELECTED_RANGE_NM",
		stt_valid and sr / 1852 or selected and (selected.current_range or selected.range) / 1852 or 0
	)
	-- A designated TWS/search track is a HUD cue, not an STT weapon solution.
	local designation_age = selected and math.max(0, computer.clock - selected.observed) or 999
	local dr, da, de = 0, 0, 0
	if selected and pose then
		dr, da, de = display.body_observation(selected, pose, designation_age)
	end
	local designation = powered
		and ready
		and native_mode ~= 3
		and selected
		and pose
		and designation_age <= computer:memory_time()
		and display.finite(dr)
		and dr >= 40
		and dr <= 300000
		and display.finite(da)
		and display.finite(de)
	put("F22_RADAR_DESIGNATION_VALID", designation and 1 or 0)
	put("F22_RADAR_DESIGNATION_RANGE", designation and dr or 0)
	put("F22_RADAR_DESIGNATION_AZ", designation and da or 0)
	put("F22_RADAR_DESIGNATION_EL", designation and de or 0)
	put("F22_RADAR_DESIGNATION_AGE", designation_age)
	put(
		"F22_RADAR_SELECTED_CLOSURE_VALID",
		powered
				and ready
				and selected
				and selected.rate
				and computer:age(selected) <= computer:fresh_time()
				and native_mode ~= 3
				and 1
			or 0
	)
	put("F22_RADAR_SELECTED_CLOSURE_KTS", selected and selected.rate and -selected.rate * 1.943844492 or 0)
	if stt_valid then
		put("F22_RADAR_SELECTED_CLOSURE_VALID", closure_valid and 1 or 0)
		put("F22_RADAR_SELECTED_CLOSURE_KTS", closure_valid and closure or 0)
	end
	-- Ownship-to-target relative velocity from the actual native world velocity
	-- and EFM velocity, when both records are fresh and available.
	if
		selected
		and selected.north
		and selected.velocity_valid
		and pose
		and powered
		and ready
		and computer:age(selected) <= computer:fresh_time()
		and get("EFM_HUD_VALID") > 0.5
		and native_mode ~= 3
	then
		local age = computer:age(selected)
		local dn = selected.north + selected.vn * age - pose.north
		local de = selected.east + selected.ve * age - pose.east
		local du = selected.altitude + selected.vu * age - pose.altitude
		local range = math.sqrt(dn * dn + de * de + du * du)
		if range > 40 then
			local closure = (
				(get("EFM_HUD_VN") - selected.vn) * dn
				+ (get("EFM_HUD_VE") - selected.ve) * de
				+ (get("EFM_HUD_VU") - selected.vu) * du
			) / range
			put("F22_RADAR_SELECTED_CLOSURE_KTS", closure * 1.943844492)
			put("F22_RADAR_SELECTED_CLOSURE_VALID", 1)
		end
	end
	if telemetry and type(get_model_time) == "function" then
		local ok, model_time = pcall(get_model_time)
		if ok then
			telemetry:sample(model_time, pose)
		end
	end
end
need_to_be_closed = false
