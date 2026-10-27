-- GPL-3.0-or-later. Independent pilot warnings and original generated speech.
dofile(LockOn_Options.script_path .. "devices.lua")
local dev, base = GetSelf(), get_base_data()
local policy = dofile(LockOn_Options.script_path .. "Systems/Pilot_Warnings.lua")
local recovery_cue = dofile(LockOn_Options.script_path .. "Systems/Terrain_Recovery_Cue.lua")
local receiver = policy.new()
local fault_definitions = dofile(LockOn_Options.script_path .. 'Systems/Fault_Registry.lua').definitions
local conditions = {}
for index, definition in ipairs(fault_definitions) do
    conditions[index] = { valid = false, active = false }
    for _, field in ipairs({'VALID','ACTIVE','OCCURRENCE','ACK','ONSET','CLEARED'}) do
        get_param_handle('F22_FAULT_' .. definition.id .. '_' .. field)
    end
    get_param_handle('F22_FAULT_LINE_' .. index):set('')
end
local decode = dofile(LockOn_Options.script_path .. "Systems/Input_Value.lua")
local handles = {}
local function h(k)
	if not handles[k] then
		handles[k] = get_param_handle(k)
	end
	return handles[k]
end
local function get(k)
	return h(k):get()
end
local function put(k, v)
	h(k):set(v)
end
for _, k in ipairs({
	"MAIN_POWER",
	"EFM_HUD_VALID",
	"EFM_GROUND_VALID",
	"EFM_WEIGHT_ON_WHEELS",
	"EFM_FCS_INTEGRITY_VALID",
	"EFM_FCS_DAMAGED",
	"F22_MWS_ALERT",
	"F22_RWR_ALERT",
	"F22_ALT_BARO_VALID",
	"F22_ALT_BARO_FT",
	"F22_ALT_RADAR_VALID",
	"F22_ALT_RADAR_FT",
	"F22_ALT_BARO_FLOOR",
	"F22_ALT_RADAR_FLOOR",
	"F22_PILOT_WARNING_VALID",
	"F22_PILOT_WARNING_PRIORITY",
	"F22_PILOT_AUDIO_PRIORITY",
	"F22_PILOT_AUDIO_UNTIL",
	"F22_PILOT_AUDIO_MUTED",
	"F22_PILOT_AUDIO_VOLUME",
	"F22_PILOT_TEST_ACTIVE",
	"F22_PILOT_AUDIO_READY",
	"F22_PILOT_AUDIO_PLAYING",
    "F22_PILOT_AUDIO_STATUS_VALID",
    "F22_PILOT_AUDIO_INFERRED",
}) do
	h(k)
end
put("F22_PILOT_WARNING_TEXT", "")
local terrain_outputs = {
	"READY",
	"REASON",
	"THREAT",
	"ESCAPE_VALID",
	"NO_ESCAPE",
	"TIME_TO_IMPACT",
	"INOPERATIVE",
	"TRACE_ACTIVE",
	"IAS_MPS",
	"LOAD_G",
	"HEADING_RAD",
	"BEST_BANK_DEG",
	"MIN_CLEARANCE",
	"QUERIES",
	"PRIORITY",
	"CUE_VALID",
	"CUE_ROT_RAD",
	"CUE_MODE",
}
for _, name in ipairs(terrain_outputs) do
	put("F22_TAWS_" .. name, 0)
end
for _,key in ipairs({'F22_FAULT_ACTIVE_COUNT','F22_FAULT_UNKNOWN_COUNT','F22_FAULT_UNACK_COUNT',
 'F22_MASTER_ATTENTION','F22_FAULT_REGISTRY_READY','F22_FAULT_OCCURRENCE',
 'F22_FAULT_SELECTED','F22_FAULT_HIDDEN_COUNT'})do h(key)end
put('F22_FAULT_SELECTED_TEXT','')
for index=1,4 do put('F22_FAULT_REFERENCE_'..index,'')end
local references=dofile(LockOn_Options.script_path..'Systems/Cockpit_References.lua').new(get,put)
local equipment=dofile(LockOn_Options.script_path..'Systems/Equipment_Conditions.lua').new(get,conditions)
local clock = 0
local muted = false
local volume = 0.8
local held = {}
local previous_pose
local unavailable_since
local diagnostic_signature, next_diagnostic = nil, 0
local terrain
local host
local sounds = {}
local playing
local test
local next_audio_retry = 0
local start_retry, audio_errors = {}, {}
local duration = {
	pull_up = 1.850952381,
	roll_left = 1.418276644,
	roll_right = 1.418276644,
	altitude = 1.63,
	flight_controls = 1.14,
	caution = 0.6,
	terrain = 1.149047619,
}
local function stop()
	if playing and sounds[playing.name] then
		sounds[playing.name]:stop()
	end
	playing = nil
	put("F22_PILOT_AUDIO_PRIORITY", 0)
	put("F22_PILOT_AUDIO_UNTIL", 0)
	put("F22_PILOT_AUDIO_PLAYING", 0)
    put("F22_PILOT_AUDIO_STATUS_VALID",0)
    put("F22_PILOT_AUDIO_INFERRED",0)
end
local function reset()
	stop()
	receiver = policy.new()
	test = nil
	held = {}
	put("F22_PILOT_WARNING_TEXT", "")
	put("F22_PILOT_WARNING_VALID", 0)
	put("F22_PILOT_WARNING_PRIORITY", 0)
	put("F22_PILOT_TEST_ACTIVE", 0)
	previous_pose = nil
	unavailable_since = nil
	diagnostic_signature = nil
	next_diagnostic = 0
	next_audio_retry, start_retry, audio_errors = 0, {}, {}
	for _, name in ipairs(terrain_outputs) do
		put("F22_TAWS_" .. name, 0)
	end
end
function post_initialize()
	reset()
	clock = 0
	muted = false
	volume = 0.8
	local ok, t = pcall(require, "terrain")
	terrain = ok and t or nil
end
for c = 11000, 11007 do
	dev:listen_command(c)
end
function SetCommand(c, v)
	local down = decode(v, devices.PILOT_WARNING_SYSTEM) > 0.5
	local old = held[c]
	held[c] = down
	if not down or old or get("MAIN_POWER") < 0.5 then
		return
	end
	if c == 11000 then
		receiver:acknowledge()
        dispatch_action(devices.FLIGHT_GUIDANCE,11016,1)
		if playing and playing.priority < 3 then
			stop()
		end
    elseif c == 11005 or c == 11006 then
        local selected = get('F22_FAULT_SELECTED')
        put('F22_FAULT_SELECTED', (selected - 1 + (c == 11005 and 1 or -1)) % #fault_definitions + 1)
	elseif c == 11001 then
		if test then
			test = nil
			stop()
		else
			test = { index = 1, at = clock }
		end
	elseif c == 11002 then
		volume = math.min(1, volume + 0.1)
	elseif c == 11003 then
		volume = math.max(0, volume - 0.1)
	elseif c == 11004 then
		muted = not muted
		if muted then
			stop()
		end
	end
end
local function audio_error(key, detail, now)
	if now < (audio_errors[key] or -1) then return end
	audio_errors[key] = now + 5
	if log and log.write then
		log.write("F22_PILOT_AUDIO", log.ERROR or log.WARNING or log.INFO, key .. ": " .. tostring(detail))
	end
end
local function audio_status(sound)
	local ok, value = pcall(function() return sound:is_playing() end)
	if ok and (type(value) == "boolean" or value == 0 or value == 1) then
		return true, value == true or value == 1
	end
	return false, false
end
local function initialize_audio(now)
	if now >= next_audio_retry then
		next_audio_retry = now + 0.5
		if not host and create_sound_host then
			local ok, value = pcall(create_sound_host, "F22_PILOT_WARNINGS", "HEADPHONES", 0, 0, 0)
			if ok and value then host = value
			else audio_error("host", value or "creation returned no host", now) end
		end
		if host then
			-- One failed source must not abort creation of later voices or leave
			-- a permanently partial host. Preserve healthy sources and retry gaps.
			for _, name in ipairs(policy.names) do
				if not sounds[name] then
					local ok, value = pcall(function() return host:create_sound("Aircrafts/F-22A/Warnings/" .. name) end)
					if ok and value then sounds[name] = value
					else audio_error("source " .. name, value or "creation returned no source", now) end
				end
			end
		end
	end
	if not host then return false end
	for _, name in ipairs(policy.names) do if not sounds[name] then return false end end
	return true
end
local function speak(name, priority, now, test_step)
	local sound = sounds[name]
	if playing or muted or volume <= 0.01 or not sound or now < (start_retry[name] or -1) then
		return false
	end
	local ok, err = pcall(function() sound:update(1, volume); sound:play_once() end)
	if not ok then
		start_retry[name] = now + 0.5
		audio_error("start " .. name, err, now)
		return false
	end
	playing = { name = name, priority = priority, started = now,
		until_time = now + (duration[name] or 2) + 0.15, test_step = test_step }
	return true
end
local function confirm_playback(now)
	if playing.confirmed then return end
	playing.confirmed = true
	-- Use the actual recording length from confirmed start. The Hornet's
	-- intercom also bounds its voice slot by duration, not an indefinite source
	-- status. A stale true status must never mute every subsequent warning.
	playing.until_time = now + (duration[playing.name] or 2) + 0.15
	if log and log.write then
		log.write('F22_PILOT_AUDIO', log.INFO, string.format('started %s t=%.3f until=%.3f',playing.name,now,playing.until_time))
	end
	if playing.test_step then
		if test == playing.test_step then
			test.index = test.index + 1
			test.at = now + (duration[playing.name] or 2) + 0.5
		end
	else
		receiver:played(playing.name, now)
	end
end
local function update_playback(now)
    put('F22_PILOT_AUDIO_INFERRED',0)
    put('F22_PILOT_AUDIO_STATUS_VALID',0)
	if not playing then return end
	local sound = sounds[playing.name]
	if sound then sound:update(1, muted and 0 or volume) end
	local ok, active = audio_status(sound)
    put('F22_PILOT_AUDIO_STATUS_VALID',ok and 1 or 0)
	if playing.confirmed and now >= playing.until_time then
		if active and sound then sound:stop() end
		if log and log.write then
			log.write('F22_PILOT_AUDIO', log.INFO, 'completed '..playing.name..' status_active='..(active and '1' or '0'))
		end
		playing = nil
		return
	end
	if ok then
		if active then confirm_playback(now); return end
		-- Allow the sound engine to accept play_once before trusting an initial
		-- false readback. Once started, its real tail owns the voice slot.
		if not playing.confirmed then
			if now - playing.started < 0.2 then return end
			start_retry[playing.name] = now + 0.5
			audio_error("start " .. playing.name, "source never reported playback; request remains pending", now)
		end
	else
        -- Keep the known-duration slot bounded, but an accepted call without
        -- playback status must not mark the real event delivered.
        put('F22_PILOT_AUDIO_INFERRED',1)
        if now < playing.until_time then return end
        if playing.test_step and test == playing.test_step then
            test.index = test.index + 1
            test.at = now + .5
        end
        start_retry[playing.name] = now + .5
	end
	-- Natural completion releases the slot; it never stops a sounding clip.
	playing = nil
end
local function equipment_snapshot()
    equipment.update()
end
local function publish_faults(priority)
    local faults = receiver.faults
    put('F22_FAULT_REGISTRY_READY', 1)
    put('F22_FAULT_ACTIVE_COUNT', faults.active)
    put('F22_FAULT_UNKNOWN_COUNT', faults.unknown)
    put('F22_FAULT_UNACK_COUNT', faults.attention)
    put('F22_FAULT_OCCURRENCE', faults.occurrence)
    put('F22_MASTER_ATTENTION', (faults.attention > 0 or priority == 3) and 1 or 0)
    put('F22_FAULT_HIDDEN_COUNT', math.max(0, faults.active - 1))
    local selected = get('F22_FAULT_SELECTED')
    if selected < 1 or selected > #fault_definitions then selected = faults.first or 1 end
    put('F22_FAULT_SELECTED', selected)
    local id=faults.records[selected].id
    local guidance=id=='FCS' and 'FLIGHT CONTROLS - CHECK'
        or id=='CANOPY' and 'CANOPY POSITION - CHECK'
        or id:sub(1,3)=='GEN' and 'ELECTRICAL SUPPLY - CHECK'
        or id:sub(1,3)=='HYD' and 'GEAR / BRAKES / CONTROLS - CHECK' or 'ENGINE INDICATIONS - CHECK'
    put('F22_FAULT_REFERENCE_1',guidance)
    put('F22_FAULT_REFERENCE_2','REMAINING CAPABILITY - ASSESS')
    put('F22_FAULT_REFERENCE_3','MANUAL RECOVERY - PLAN')
    put('F22_FAULT_REFERENCE_4','ACK DOES NOT CLEAR THE CAUSE')
    for index = 1, #fault_definitions do
        local record = faults.records[index]
        local prefix = 'F22_FAULT_' .. record.id .. '_'
        put(prefix .. 'VALID', record.valid and 1 or 0)
        put(prefix .. 'ACTIVE', record.active and 1 or 0)
        put(prefix .. 'OCCURRENCE', record.occurrence)
        put(prefix .. 'ACK', record.acknowledged)
        put(prefix .. 'ONSET', record.onset)
        put(prefix .. 'CLEARED', record.cleared)
        local status = not record.valid and ' UNAVAILABLE' or record.active
            and (record.acknowledged == record.occurrence and ' ACK' or ' NEW')
            or record.occurrence > 0 and ' CLEARED' or ' NORMAL'
        if record.display_status ~= status then
            record.display_status = status
            record.display_text = record.label .. status
            put('F22_FAULT_LINE_' .. index, record.display_text)
        end
        if index == selected then put('F22_FAULT_SELECTED_TEXT', record.display_text)end
    end
end
function update()
	local now = type(get_model_time) == "function" and get_model_time() or clock + 0.05
	if type(now) ~= "number" or now ~= now then
		return
	end
	if now < clock then
		reset()
	end
	clock = now
	references.update()
	local powered = get("MAIN_POWER") > 0.5
	if not powered then
		reset()
        equipment_snapshot()
        receiver.faults:update(now, conditions)
        publish_faults(0)
		return
	end
    equipment_snapshot()
	local audio_ok, all_ready = pcall(initialize_audio, now)
	put("F22_PILOT_AUDIO_READY", audio_ok and all_ready and 1 or 0)
	update_playback(now)
	local ok, n, u, e = pcall(base.getSelfCoordinates)
	local roll_ok, roll = pcall(base.getRoll)
	local cas_ok, cas = pcall(function()
		return base.getIndicatedAirSpeed()
	end)
	local nz_ok, nz = pcall(function()
		return base.getVerticalAcceleration()
	end)
	local heading_ok, heading = pcall(function()
		return -base.getHeading()
	end)
	put("F22_TAWS_IAS_MPS", cas_ok and type(cas) == "number" and cas == cas and cas or 0)
	put("F22_TAWS_LOAD_G", nz_ok and type(nz) == "number" and nz == nz and nz or 0)
	put("F22_TAWS_HEADING_RAD", heading_ok and type(heading) == "number" and heading == heading and heading or 0)
	local roll_rate = 0
	if roll_ok and type(roll) == "number" and roll == roll then
		if previous_pose and now > previous_pose.time and now - previous_pose.time <= 0.25 then
			roll_rate = ((roll - previous_pose.roll + math.pi) % (2 * math.pi) - math.pi) / (now - previous_pose.time)
		end
		previous_pose = { time = now, roll = roll }
	end
	local gear_ok, gear = pcall(get_aircraft_draw_argument_value, 0)
	local state = {
		now = now,
        conditions = conditions,
		powered = powered,
		valid = ok and roll_ok and get("EFM_HUD_VALID") > 0.5 and get("EFM_GROUND_VALID") > 0.5,
		ground = get("EFM_WEIGHT_ON_WHEELS") > 0.5,
		gear = gear_ok and gear > 0.05,
		n = n,
		u = u,
		e = e,
		roll = roll,
		vn = get("EFM_HUD_VN"),
		vu = get("EFM_HUD_VU"),
		ve = get("EFM_HUD_VE"),
		cas = cas_ok and cas or nil,
		nz = nz_ok and nz or nil,
		heading = heading_ok and heading or nil,
		roll_rate = roll_rate,
		wn = get("EFM_HUD_WN"),
		wu = get("EFM_HUD_WU"),
		we = get("EFM_HUD_WE"),
		baro = get("F22_ALT_BARO_FT"),
		baro_valid = get("F22_ALT_BARO_VALID") > 0.5,
		baro_floor = get("F22_ALT_BARO_FLOOR"),
		radar = get("F22_ALT_RADAR_FT"),
		radar_valid = get("F22_ALT_RADAR_VALID") > 0.5,
		radar_floor = get("F22_ALT_RADAR_FLOOR"),
		fcs_valid = get("EFM_FCS_INTEGRITY_VALID") > 0.5,
		fcs_fault = get("EFM_FCS_DAMAGED") > 0.5,
		caution = get("OIL_LIGHT") > 0.5
			or get("HYD_LIGHT") > 0.5
			or get("L_GEN_OUT") > 0.5
			or get("R_GEN_OUT") > 0.5
			or get("CANOPY_LIGHT") > 0.5,
		missile_warning = get("F22_MWS_ALERT") > 0.5 or get("F22_RWR_ALERT") >= 3,
		audio_busy = playing ~= nil or muted or volume <= 0.01 or not audio_ok or not host,
		defer_audio_commit = true,
	}
	state.approach = get("F22_NAV_SOURCE") == 2
		and get("HUD_ILS_LOC_VALID") > 0.5
		and get("HUD_ILS_GS_VALID") > 0.5
		and math.abs(get("HUD_ILS_LOC")) < 0.35
		and math.abs(get("HUD_ILS_GS")) < 0.35
	local height = terrain and terrain.GetHeight
	local visible = terrain and terrain.isVisible
	local result = receiver:update(state, height, visible)
    publish_faults(result.priority)
	-- The display follows the current prediction immediately. Speech completes
	-- before the latest still-active directive gets the next slot (Hornet intercom
	-- 0x18048ECA9..0x18048EE64). Do not queue obsolete words or stop on clear/change.
	if result.priority > 0 then
		test = nil
	end
	if result.event then
		speak(result.event, result.priority, now)
	end
	if test and not muted and not state.missile_warning and not playing and now >= test.at then
		local name = policy.names[test.index]
		if name then
			speak(name, 1, now, test)
		else
			test = nil
		end
	end
	put("F22_PILOT_WARNING_TEXT", result.text)
	put("F22_PILOT_WARNING_VALID", result.priority > 0 and 1 or 0)
	put("F22_PILOT_WARNING_PRIORITY", result.priority)
	local recovery = result.terrain
	-- Recompute the display angle at the owner rate, independently of cached
	-- trajectory samples and the voice clip's playback/repeat timing.
	local cue = recovery_cue.evaluate(state, recovery)
	put("F22_TAWS_CUE_VALID", cue.valid and 1 or 0)
	put("F22_TAWS_CUE_ROT_RAD", cue.rotation)
	put("F22_TAWS_CUE_MODE", cue.mode)
	if state.valid and not state.ground and recovery and not recovery.valid then
		unavailable_since = unavailable_since or now
	else
		unavailable_since = nil
	end
	put("F22_TAWS_INOPERATIVE", unavailable_since and now - unavailable_since >= 1 and 1 or 0)
	put("F22_TAWS_READY", recovery and recovery.valid and 1 or 0)
	put("F22_TAWS_REASON", recovery and recovery.reason or 0)
	put("F22_TAWS_THREAT", recovery and recovery.threat and 1 or 0)
	put("F22_TAWS_ESCAPE_VALID", recovery and recovery.escape_valid and 1 or 0)
	put("F22_TAWS_NO_ESCAPE", recovery and recovery.no_escape and 1 or 0)
	put("F22_TAWS_TIME_TO_IMPACT", result.impact or 999)
	put("F22_TAWS_BEST_BANK_DEG", recovery and recovery.best and math.deg(recovery.best.bank) or 0)
	put("F22_TAWS_MIN_CLEARANCE", recovery and recovery.best and recovery.best.minimum or 0)
	put("F22_TAWS_QUERIES", recovery and recovery.queries or 0)
	put("F22_TAWS_PRIORITY", recovery and recovery.priority or 0)
	put("F22_TAWS_TRACE_ACTIVE", recovery and recovery.valid and recovery.trace and 1 or 0)
	if recovery and log and log.write then
		local signature = string.format(
			"ready=%d reason=%d threat=%d safe=%d call=%s plan=%s",
			recovery.valid and 1 or 0,
			recovery.reason or 0,
			recovery.threat and 1 or 0,
			recovery.escape_valid and 1 or 0,
			recovery.call or "none",
			recovery.best and recovery.best.name or "none"
		)
		if signature ~= diagnostic_signature or (recovery.threat and now >= next_diagnostic) then
			log.write(
				"F22_TAWS",
				log.INFO,
				signature
					.. string.format(
						" tti=%.2f clearance=%.1f queries=%d agl=%.1f cas=%.1f nz=%.2f roll=%.1f vu=%.1f",
						result.impact or -1,
						recovery.best and recovery.best.minimum or 0,
						recovery.queries or 0,
						recovery.current and recovery.current.initial_agl or -1,
						state.cas or -1,
						state.nz or 0,
						math.deg(state.roll or 0),
						state.vu or 0
					)
			)
			diagnostic_signature = signature
			next_diagnostic = now + 2
		end
	end
	update_playback(now)
	put("F22_PILOT_AUDIO_PRIORITY", playing and playing.confirmed and playing.priority or 0)
	put("F22_PILOT_AUDIO_UNTIL", playing and playing.confirmed and playing.until_time or 0)
	local actual = false
	if playing then local _, on = audio_status(sounds[playing.name]); actual = on end
	put("F22_PILOT_AUDIO_PLAYING", actual and 1 or 0)
	put("F22_PILOT_AUDIO_MUTED", muted and 1 or 0)
	put("F22_PILOT_AUDIO_VOLUME", volume)
	put("F22_PILOT_AUDIO_VOLUME", volume)
	put("F22_PILOT_TEST_ACTIVE", test and 1 or 0)
end
make_default_activity(0.05)
need_to_be_closed = false
