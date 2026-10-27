-- GPL-3.0-or-later. Independent missile warning, distinct from radar reception.
local dev = GetSelf()
dofile(LockOn_Options.script_path .. "devices.lua")
local library = dofile(LockOn_Options.script_path .. "Systems/MWS_Computer.lua")
local decode = dofile(LockOn_Options.script_path .. "Systems/Input_Value.lua")
local receiver = library.new()
local audio_gate = dofile(LockOn_Options.script_path .. 'Systems/Warning_Audio_Gate.lua')
local bearing_library = dofile(LockOn_Options.script_path .. "Systems/RWR_Bearings.lua")
local bearings = bearing_library.new()
local base = get_base_data()
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
-- Declare every producer/indicator handle before indicator Lua states bind it.
for _, name in ipairs({
	"MAIN_POWER",
	"F22_MWS_DEVICE_ID",
	"F22_MWS_SUPPLY",
	"F22_MWS_POWER",
	"F22_MWS_READY",
	"F22_MWS_NATIVE_READY",
	"F22_MWS_NATIVE_REASON",
	"F22_MWS_NATIVE_TIME",
	"F22_MWS_NATIVE_COUNT",
	"F22_MWS_NATIVE_RAW_COUNT",
	"F22_MWS_NATIVE_MAX_HITS",
	"F22_MWS_NATIVE_EYE_COUNT",
	"F22_MWS_NATIVE_ANGULAR_LIMIT",
	"F22_MWS_ALERT",
	"F22_MWS_COUNT",
	"F22_MWS_BLINK",
	"F22_MWS_CLOCK",
	"F22_MWS_ELEVATION",
	"F22_MWS_COAST",
	"F22_MWS_AUDIO_PRIORITY",
	"F22_MWS_AUDIO_READY",
	"F22_MWS_MUTED",
}) do
	h(name)
end
for i = 1, 16 do
	local p = string.format("F22_MWS_NATIVE_%02d_", i)
	for _, suffix in ipairs({ "VALID", "SOURCE", "TIME", "AZ", "EL", "THREAT" }) do
		h(p .. suffix)
	end
	p = string.format("F22_MWS_%02d_", i)
	for _, suffix in ipairs({ "VALID", "SOURCE", "AZ", "EL", "AGE", "COAST", "X", "Y" }) do
		h(p .. suffix)
	end
end
local enabled, muted = true, false
local held = {}
local host, sound = nil, nil
local signature = nil
local next_sample = 0
local publish_sequence = 0
for _, c in ipairs({ 10920, 10921 }) do
	dev:listen_command(c)
end
function SetCommand(c, v)
	local down = decode(v, devices.MWS_SYSTEM) > 0.5
	local previous = held[c]
	held[c] = down
	if not down or previous then
		return
	end
	if c == 10920 then
		enabled = not enabled
	elseif c == 10921 then
		muted = not muted
	end
end
function post_initialize()
	receiver = library.new()
	bearings:reset()
	enabled = true
	muted = false
	held = {}
	signature = nil
	next_sample = 0
	put("F22_MWS_DEVICE_ID", devices.MWS_NATIVE)
	put("F22_MWS_SUPPLY", 0)
	put("F22_MWS_ALERT", 0)
	put("F22_MWS_AUDIO_PRIORITY", 0)
end
function update()
	local now = get_model_time()
	local powered = enabled and get("MAIN_POWER") > 0.5
	put("F22_MWS_SUPPLY", powered and 1 or 0)
	local age = now - get("F22_MWS_NATIVE_TIME")
	local ready = get("F22_MWS_NATIVE_READY") > 0.5 and age >= -0.05 and age <= 0.35
	local observations = {}
	if powered and ready then
		for i = 1, 16 do
			local p = string.format("F22_MWS_NATIVE_%02d_", i)
			if get(p .. "VALID") > 0.5 then
				observations[#observations + 1] =
					{ source = get(p .. "SOURCE"), time = get(p .. "TIME"), az = get(p .. "AZ"), el = get(p .. "EL"), threat = get(p .. "THREAT") > .5 }
			end
		end
	end
	receiver:update(now, observations, powered and ready)
	local contacts = {}
	for _,raw in ipairs(receiver.contacts)do
		local c={};for key,value in pairs(raw)do c[key]=value end
		contacts[#contacts+1]=c
	end
	local directions = {}
	for _,c in ipairs(contacts)do
		directions[#directions+1]={source=c.source,age=c.age,az=-c.az,el=c.el}
	end
	bearings:update(now,bearing_library.frame(base),directions,powered and ready)
	for i,c in ipairs(contacts)do
		local d=directions[i]
		c.az=((-d.az+math.pi)%(2*math.pi))-math.pi;c.el=d.el
	end
	local first = contacts[1]
	local alert = powered and ready and first ~= nil
	put("F22_MWS_POWER", powered and 1 or 0)
	put("F22_MWS_READY", ready and 1 or 0)
	put("F22_MWS_ALERT", alert and 1 or 0)
	put("F22_MWS_COUNT", #contacts)
	put("F22_MWS_BLINK", alert and now % 0.5 < 0.35 and 1 or 0)
	put("F22_MWS_CLOCK", first and library.sector(first.az) or 0)
	put("F22_MWS_ELEVATION", first and (first.el > math.rad(10) and 1 or first.el < math.rad(-10) and -1 or 0) or 0)
	put("F22_MWS_COAST", first and first.coast and 1 or 0)
	put("F22_MWS_MUTED", muted and 1 or 0)
	for i = 1, 16 do
		local p = string.format("F22_MWS_%02d_", i)
		local c = contacts[i]
		put(p .. "VALID", c and 1 or 0)
		put(p .. "SOURCE", c and c.source or 0)
		put(p .. "AZ", c and c.az or 0)
		put(p .. "EL", c and c.el or 0)
		put(p .. "AGE", c and c.age or 999)
		put(p .. "COAST", c and c.coast and 1 or 0)
		put(p .. "X", c and math.sin(c.az) * 0.9 or 0)
		put(p .. "Y", c and math.cos(c.az) * 0.9 or 0)
	end
	publish_sequence = publish_sequence + 1
	put("F22_MWS_PUBLISH_TIME", now)
	put("F22_MWS_PUBLISH_SEQUENCE", publish_sequence)
	local playing = false
	local ok, err = pcall(function()
		if not host and create_sound_host then
			host = create_sound_host("F22_MWS_WARNING", "HEADPHONES", 0, 0, 0)
		end
		if host and not sound then
			sound = host:create_sound("Aircrafts/F-22A/MWS/approach")
		end
		if sound then
			sound:update(1, 1)
			if alert and not muted and audio_gate.priority(get, now) < 3 then
				if not audio_gate.playing(sound) then
					sound:play_continue()
				end
				playing = audio_gate.playing(sound)
			else
				sound:stop()
			end
		end
	end)
	put("F22_MWS_AUDIO_READY", ok and sound and 1 or 0)
	put("F22_MWS_AUDIO_PRIORITY", ok and playing and 1 or 0)
	local state = string.format(
		"power=%d ready=%d count=%d audio=%d first=%d clock=%d coast=%d reason=%.0f voice=%d voice_until=%.3f",
		powered and 1 or 0,
		ready and 1 or 0,
		#contacts,
		playing and 1 or 0,
		first and first.source or 0,
		first and library.sector(first.az) or 0,
		first and first.coast and 1 or 0,
		get("F22_MWS_NATIVE_REASON"), audio_gate.priority(get, now), get('F22_PILOT_AUDIO_UNTIL')
	)
	if log and log.write then
		if state ~= signature then
			log.write("F22_MWS", log.INFO, state)
			signature = state
		end
		if now >= next_sample then
			next_sample = now + 0.2
			local source_ids = {}
			for _, contact in ipairs(contacts) do
				source_ids[#source_ids + 1] = string.format("%.0f", contact.source)
			end
			log.write(
				"F22_MWS_SAMPLE",
				log.INFO,
				string.format(
					"t=%.3f %s az=%.5f el=%.5f age=%.3f raw=%.0f hits=%.0f eyes=%.0f rate=%.5f sources=%s",
					now,
					state,
					first and first.az or 0,
					first and first.el or 0,
					first and first.age or 999,
					get("F22_MWS_NATIVE_RAW_COUNT"),
					get("F22_MWS_NATIVE_MAX_HITS"),
					get("F22_MWS_NATIVE_EYE_COUNT"),
					get("F22_MWS_NATIVE_ANGULAR_LIMIT"),
					table.concat(source_ids, "|")
				)
			)
		end
		if not ok then
			log.write("F22_MWS_AUDIO", log.ERROR, tostring(err))
		end
	end
end
make_default_activity(0.05)
need_to_be_closed = false
