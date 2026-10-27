-- GPL-3.0-or-later. Native receiver owner and presentation exporter.
dofile(LockOn_Options.script_path .. "devices.lua")
local library = dofile(LockOn_Options.script_path .. "Systems/RWR_Computer.lua")
local receiver = library.new()
local proximity = dofile(LockOn_Options.script_path .. 'Systems/RWR_Proximity.lua')
local bearing_library = dofile(LockOn_Options.script_path .. "Systems/RWR_Bearings.lua")
local bearings = bearing_library.new()
local geolocation_library = dofile(LockOn_Options.script_path .. "Systems/EW_Geolocation.lua")
local geolocation = geolocation_library.new()
local sensors = get_base_data()
local audio_library = dofile(LockOn_Options.script_path .. "Systems/RWR_Audio.lua")
local audio = audio_library.new()
local audio_gate = dofile(LockOn_Options.script_path .. 'Systems/Warning_Audio_Gate.lua')
local dev = GetSelf()
make_default_activity(0.05)
local input_value = dofile(LockOn_Options.script_path .. "Systems/Input_Value.lua")
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
local supply = dofile(LockOn_Options.script_path..'Systems/EW_Power.lua').new(get)
local tactical = dofile(LockOn_Options.script_path .. "Systems/Tactical_Picture.lua").new(get, put, sensors)
local defensive_library = dofile(LockOn_Options.script_path .. "Systems/EW_Defensive.lua")
local defensive = defensive_library.new(put, library.label_code, sensors)
local overview=dofile(LockOn_Options.script_path..'Systems/Defensive_Overview.lua').new(get,put,sensors)
local enabled, muted, critical = true, false, false
local hud_enabled = true
local volume = 0.8
local clock = 0
local identity_memory = {}
local identity_count = 0
local function retain_identity(source, evidence)
    if not identity_memory[source] then
        if identity_count>=128 then return false end
        identity_count=identity_count+1
    end
    identity_memory[source]=evidence
    return true
end
local identity_sequence = nil
local native_power = nil
local inspection_held = {}
for _, id in ipairs({ 10900, 10901, 10902, 10903, 10904, 10905, 10906, 10907, 10908, 10915, 10916, 10917, 10918 }) do
	dev:listen_command(id)
end
for command=11130,11132 do dev:listen_command(command)end
for command=11140,11144 do dev:listen_command(command)end
function SetCommand(c, v)
	if (c >= 10900 and c <= 10908)or (c>=10915 and c<=10918)
        or (c>=11130 and c<=11132)or (c>=11140 and c<=11144) then
		v = input_value(v, devices.RWR_SYSTEM)
	end
	if v <= 0 then
		inspection_held[c] = nil
		return
	end
	if c >= 10906 and c <= 10908 then
		if not inspection_held[c] and get("MAIN_POWER") > 0.5 then defensive:command(c) end
		inspection_held[c] = true;return
	end
	if c>=10915 and c<=10918 or c>=11130 and c<=11132 or c>=11140 and c<=11144 then
		if not inspection_held[c] and get("MAIN_POWER")>.5 then tactical:command(c) end
		inspection_held[c]=true;return
	end
	if c == 10900 then
		enabled = not enabled
	elseif c == 10901 then
		muted = not muted
	elseif c == 10902 then
		critical = not critical
	elseif c == 10903 then
		hud_enabled = not hud_enabled
	end
	if c == 10904 then
		volume = math.min(1, volume + 0.1)
	elseif c == 10905 then
		volume = math.max(0, volume - 0.1)
	end
end
local host, sounds = nil, {}
local last_diagnostic = nil
function post_initialize()
	receiver = library.new()
	bearings:reset()
	geolocation:reset()
	tactical:reset()
	defensive = defensive_library.new(put, library.label_code, sensors)
	inspection_held = {}
	audio = audio_library.new()
	identity_memory = {}
    identity_count = 0
	identity_sequence = nil
	clock = 0
	native_power = nil
	last_diagnostic = nil
	put("F22_RWR_SUPPLY", 0)
    put('F22_RWR_SUPPLY_VALID', 0)
	put("F22_RWR_READY", 0)
	if create_sound_host then
		host = create_sound_host("F22_RWR_AUDIO", "HEADPHONES", 0, 0, 0)
		for _, n in ipairs(audio_library.names) do
			sounds[n] = host:create_sound("Aircrafts/F-22A/RWR/" .. n)
		end
	end
end
function update()
	local step = 0.05
	local rewound = false
	if type(get_model_time) == "function" then
		local ok, now = pcall(get_model_time)
		if ok and type(now) == "number" and now == now and now >= 0 and now < 1e12 then
			if now < clock then
				receiver = library.new()
				audio = audio_library.new()
				identity_memory = {}
                identity_count = 0
				identity_sequence = nil
				native_power = nil
				last_diagnostic = nil
				step = 0
				rewound = true
			else
				step = now - clock
			end
			clock = now
		else
			clock = clock + step
		end
	else
		clock = clock + step
	end
    supply:update()
	local powered = enabled and supply.electrical
	put("F22_RWR_SUPPLY", powered and 1 or 0)
    put('F22_RWR_SUPPLY_VALID', supply.valid and 1 or 0)
	local native = nil
	if type(GetDevice) == "function" then
		local ok, result = pcall(GetDevice, devices.RWR_NATIVE)
		if ok then
			native = result
		end
	end
	local ready = native and type(native.set_power) == "function"
	if ready and native_power ~= powered then
		local ok = pcall(function()
			native:set_power(powered)
		end)
		if ok then
			native_power = powered
		else
			ready = false
		end
	end
	local observations = {}
	if ready and powered then
		for i = 1, 16 do
			local p = string.format("RWR_CONTACT_%02d_", i)
			observations[#observations + 1] = {
				source = get(p .. "SOURCE"),
				age = get(p .. "TIME"),
				az = get(p .. "AZIMUTH"),
				el = get(p .. "ELEVATION"),
				signal = get(p .. "SIGNAL"),
				priority = get(p .. "PRIORITY"),
				power = get(p .. "POWER"),
				general = get(p .. "GENERAL_TYPE"),
				label = get(p .. "UNIT_TYPE"),
			}
		end
	end
	receiver:update(observations, ready and powered)
	bearings:update(clock, bearing_library.frame(sensors), receiver.contacts, ready and powered)
	-- Radar publishes this sequence last. Consume each complete identity
	-- snapshot once; frozen producer parameters cannot renew a 30-second ID.
	local sequence = get("F22_TWS_PUBLISH_SEQUENCE")
	if rewound then
		identity_sequence = sequence
	end
	if sequence ~= identity_sequence then
		for i = 1, 64 do
			local p = string.format("F22_IDENT_%02d_", i)
			local source, age, class = get(p .. "SOURCE"), get(p .. "AGE"), get(p .. "CLASS")
			-- This is the radar's qualified classification snapshot, not a raw
			-- missing-IFF reply. Preserve both known friend and known hostile.
			if get(p .. "VALID") > 0.5 and source > 0 and age >= 0 and age <= 30 and (class == 1 or class == 0) then
				local retained=retain_identity(source,{class=class,time=clock-age,expires=clock+30-age})
                if not retained then put('F22_IFF_MEMORY_OVERFLOW',1)end
			end
		end
		identity_sequence = sequence
	end
	for source, id in pairs(identity_memory) do
		if id.expires <= clock then
			identity_memory[source] = nil
            identity_count=identity_count-1
		end
	end
	for _, c in ipairs(receiver.contacts) do
		local id = identity_memory[c.source]
        c.hostile_act=c.signal==3 and not library.coasting(c)
		if c.hostile_act and not(id and id.class == 1) then
			-- A fresh launch/illumination warning is itself hostile-act evidence.
			-- Subtract observation age so cached emissions cannot renew the ID.
			id = {class=0,time=clock-c.age,expires=clock+30-c.age}
            local retained=retain_identity(c.source,id)
            if not retained then put('F22_IFF_MEMORY_OVERFLOW',1)end
		end
		c.affiliation = id and id.class or -1
        c.identity_time=id and id.time
        c.hostile_time=c.hostile_act and clock-c.age or nil
	end
	-- Export only an attitude-qualified measured RF direction, never source position.
	for _,c in ipairs(receiver.contacts)do
		local measured=bearings.tracks[c.source]
		c.bearing_world=c.bearing_compensated and measured and measured.world or nil
	end
	geolocation:update(clock, geolocation_library.position(sensors), receiver.contacts, bearings.tracks, ready and powered)
	tactical:update(clock, receiver.contacts, supply.electrical)
	defensive.now = clock
	defensive:update(tactical.store.contacts, critical)
    overview:update(clock,tactical.store.contacts,supply.electrical,critical,defensive.source)
	put("F22_RWR_READY", ready and 1 or 0)
	put("F22_RWR_POWER", powered and 1 or 0)
	put("F22_RWR_MUTE", (muted or volume < 0.01) and 1 or 0)
	put("F22_RWR_FILTER", critical and 1 or 0)
	put("F22_RWR_HUD_ENABLED", hud_enabled and 1 or 0)
	put("F22_RWR_AUDIO_VOLUME", volume)
	put("F22_RWR_COUNT", #receiver.contacts)
	put("F22_RWR_ALERT", receiver.alert)
	local summary = {
		string.format(
			"power=%d ready=%d count=%d alert=%d",
			powered and 1 or 0,
			ready and 1 or 0,
			#receiver.contacts,
			receiver.alert
		),
	}
	for _, c in ipairs(receiver.contacts) do
		summary[#summary + 1] =
			string.format("id=%d signal=%d label=%s class=%d", c.source, c.signal, c.label, c.affiliation)
	end
	local signature = table.concat(summary, "; ")
	if signature ~= last_diagnostic and log and log.write then
		local angles = {}
		for _, c in ipairs(receiver.contacts) do
			angles[#angles + 1] = string.format("%d:%.1fdeg age=%.2f", c.source, math.deg(c.az), c.age)
		end
		log.write("F22_EW", log.INFO, signature .. " bearings " .. table.concat(angles, "; "))
		last_diagnostic = signature
	end
	for i = 1, 16 do
		local p = string.format("F22_EW_%02d_", i)
		local c = receiver.contacts[i]
		put(p .. "VALID", c and (not critical or c.signal > 1) and 1 or 0)
		put(p .. "SOURCE", c and c.source or 0)
		put(p .. "SIGNAL", c and c.signal or 0)
		put(p .. "AFFILIATION", c and c.affiliation or -1)
		put(p .. "AGE", c and c.age or 999)
		put(p .. "COAST", c and library.coasting(c) and 1 or 0)
		put(p .. "LABEL", c and c.label or "")
		put(p .. "LABEL_CODE", library.label_code(c and c.label or "U"))
		put(p .. "AZ", c and c.az or 0)
		put(p .. "GENERAL", c and c.general or 0)
		-- Native POWER supplies relative proximity; warnings retain their own
		-- signal/color/launch markings instead of replacing proximity with severity.
		local radius = c and (proximity.radius(c.power,.84) or ({ [1] = 0.78, [2] = 0.53, [3] = 0.28 })[c.signal]) or 0
		put(p .. 'PROXIMITY_VALID',c and proximity.valid(c.power) and 1 or 0)
		put(p .. 'POWER',c and c.power or 0)
		put(p .. "X", c and -math.sin(c.az) * radius or 0)
		put(p .. "Y", c and math.cos(c.az) * radius or 0)
	end
	-- Hornet convention: up to six emitter identifiers around a bearing circle,
	-- with azimuth lines. This is a repeater, never a conformal target position.
	for i = 1, 6 do
		local c = receiver.contacts[i]
		local p = string.format("HUD_EW_%02d_", i)
		local valid = c and hud_enabled and (not critical or c.signal > 1)
		valid = valid and (c.signal ~= 3 or library.coasting(c) or clock % 0.5 < 0.3)
		put(p .. "VALID", valid and 1 or 0)
		put(p .. "LABEL", c and c.label or "")
		put(p .. "LABEL_CODE", library.label_code(c and c.label or "U"))
		put(p .. "X", c and -math.sin(c.az) * 0.32 or 0)
		put(p .. "Y", c and math.cos(c.az) * 0.32 - 0.06 or 0)
		put(p .. "ROT", c and c.az or 0)
		put(p .. "SIGNAL", c and c.signal or 0)
		put(p .. "COAST", c and library.coasting(c) and 1 or 0)
	end
	local cue = audio:update(
		step,
		receiver.contacts,
		powered and ready,
		muted or volume < 0.01 or audio_gate.mws(get, clock) or audio_gate.priority(get, clock) > 0.5,
		receiver.alert
	)
	for n, s in pairs(sounds) do
		s:update(1, volume)
		if n == "lock" or n == "launch" then
			if cue.loop == n then
				if not audio_gate.playing(s) then
					s:play_continue()
				end
			else
				s:stop()
			end
		elseif not powered or muted or volume < 0.01 or cue.loop or cue.event then
			s:stop()
		end
	end
	if cue.event and sounds[cue.event] then
		sounds[cue.event]:play_once()
	end
	local loop_code = cue.loop == "launch" and 3 or cue.loop == "lock" and 2 or 0
	put("F22_RWR_AUDIO_LOOP", loop_code)
	put("F22_RWR_AUDIO_EVENT", ({ ping = 1, new_contact = 2, contact_lost = 3 })[cue.event] or 0)
	if cue.event and log and log.write then
		log.write("F22_EW_AUDIO", log.INFO, "event=" .. cue.event)
	end
end
need_to_be_closed = false
