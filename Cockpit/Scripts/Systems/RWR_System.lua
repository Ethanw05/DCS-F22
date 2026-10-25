-- GPL-3.0-or-later. Native receiver owner and presentation exporter.
dofile(LockOn_Options.script_path .. "devices.lua")
local library = dofile(LockOn_Options.script_path .. "Systems/RWR_Computer.lua")
local receiver = library.new()
local audio_library = dofile(LockOn_Options.script_path .. "Systems/RWR_Audio.lua")
local audio = audio_library.new()
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
local enabled, muted, critical = true, false, false
local hud_enabled = true
local volume = 0.8
local clock = 0
local identity_memory = {}
local identity_sequence = nil
local native_power = nil
for _, id in ipairs({ 10900, 10901, 10902, 10903, 10904, 10905 }) do
	dev:listen_command(id)
end
function SetCommand(c, v)
	if c >= 10900 and c <= 10905 then
		v = input_value(v, devices.RWR_SYSTEM)
	end
	if v <= 0 then
		return
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
	audio = audio_library.new()
	identity_memory = {}
	identity_sequence = nil
	clock = 0
	native_power = nil
	last_diagnostic = nil
	put("F22_RWR_SUPPLY", 0)
	put("F22_RWR_READY", 0)
	if create_sound_host then
		host = create_sound_host("COCKPIT_ARMS", "HEADPHONES", 0, 0, 0)
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
	local powered = enabled and get("MAIN_POWER") > 0.5
	put("F22_RWR_SUPPLY", powered and 1 or 0)
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
				general = get(p .. "GENERAL_TYPE"),
				label = get(p .. "UNIT_TYPE"),
			}
		end
	end
	receiver:update(observations, ready and powered)
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
			if get(p .. "VALID") > 0.5 and source > 0 and age >= 0 and age <= 30 and (class == 0 or class == 1) then
				identity_memory[source] = { class = class, expires = clock + 30 - age }
			end
		end
		identity_sequence = sequence
	end
	for source, id in pairs(identity_memory) do
		if id.expires <= clock then
			identity_memory[source] = nil
		end
	end
	for _, c in ipairs(receiver.contacts) do
		local id = identity_memory[c.source]
		c.affiliation = id and id.class or -1
	end
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
		-- Threat rings encode warning level. Neither radius nor POWER is range.
		local radius = c and ({ [1] = 0.78, [2] = 0.53, [3] = 0.28 })[c.signal] or 0
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
	local cue = audio:update(step, receiver.contacts, powered and ready, muted or volume < 0.01, receiver.alert)
	for n, s in pairs(sounds) do
		s:update(1, volume)
		if n == "lock" or n == "launch" then
			if cue.loop == n then
				if not s:is_playing() then
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
