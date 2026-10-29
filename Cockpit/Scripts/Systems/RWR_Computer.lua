-- GPL-3.0-or-later. Passive, bearing-only warning and exact-source association.
-- Native SIGNAL: 1 search, 2 lock, 3 launch/active missile (setEmitterTypes).
local M = { lifetime = 12, search_coast = 6, warning_coast = 3.5 }
function M.coasting(c)
	return c.age > (c.signal > 1 and M.warning_coast or M.search_coast)
end
-- Pilot-requested mod attention cues: 1 Hz lock, 2 Hz launch/optical warning.
-- These rates are display policies, not recovered Hornet or ALR-94 timings.
function M.pulse(now, signal)
    if signal < 2 then return 1 end
    if type(now) ~= 'number' or now ~= now or math.abs(now) >= 1e12 then return 0 end
    local period = signal == 2 and 1 or .5
    return now % period < period * .6 and 1 or 0
end
M.symbols = { "U", "M", "M2", "E3", "P", "EWR", "SAM", "AAA" }
function M.label_code(label)
	local number = tonumber(label)
	if number then
		return number
	end
	for i, symbol in ipairs(M.symbols) do
		if label == symbol then
			return 99 + i
		end
	end
	return 100
end
local function finite(v)
	return type(v) == "number" and v == v and math.abs(v) < 1e12
end
-- Compact simulation emitter library. Type text is supplied by the receiver;
-- it is never used to assign friend/hostile allegiance.
function M.label(name, general)
	local s = type(name) == "string" and name:upper():gsub("[^A-Z0-9]", "") or ""
	if general == 4 then
		return "M"
	end
    -- The stock S means a ground search/early-warning radar, not a fighter.
    if s == 'S' or s:find('EWR') then return 'EWR' end
    if general == 2 then
        if s=='A' or s=='AAA' or s:find('SHILKA') or s:find('GEPARD') or s:find('VULCAN') then return 'AAA' end
        return 'SAM'
    end
	local patterns = {
		-- Shared DCS AN_ALR_SymbolsBase maps the stock J-11A emitter to29.
		{ "^J11A$", "29" },
		{ "^MIG29", "29" },
		{ "^MIG23", "23" },
		{ "^MIG31", "31" },
		{ "^MIG25", "25" },
		{ "^SU27", "29" },
		{ "^SU33", "29" },
		{ "^SU30", "30" },
		{ "^SU34", "34" },
		{ "^F15", "15" },
		{ "^F16", "16" },
		{ "^FA18", "18" },
		{ "^F18", "18" },
		{ "^F14", "14" },
		{ "^F22", "22" },
		{ "^M2000", "M2" },
		{ "^MIRAGE", "M2" },
		{ "^E3", "E3" },
		{ "^A50", "50" },
		{ "^PATRIOT", "P" },
		{ "^S300", "10" },
		{ "^BUK", "11" },
		{ "^KUB", "6" },
		{ "^TOR", "15" },
		{ "^OSA", "8" },
	}
	for _, v in ipairs(patterns) do
		if s:find(v[1]) then
			return v[2]
		end
	end
	if s:match("^%d%d?$") or s == "U" or s == "M" then
		return s
	end
	return "U"
end
function M.new()
	local r = { contacts = {}, alert = 0 }
	function r:update(observations, power)
		self.contacts = {}
		self.alert = 0
		if not power then
			return
		end
		local seen = {}
		for _, o in ipairs(observations) do
			if
				finite(o.source)
				and o.source > 0
				and o.source < 4294967296
				and o.source % 1 == 0
				and finite(o.age)
				and o.age >= 0
				and o.age <= M.lifetime
				and finite(o.az)
				and (o.signal == 1 or o.signal == 2 or o.signal == 3)
			then
				local c = {
					source = o.source,
					age = o.age,
					az = o.az % (2 * math.pi),
					el = o.el or 0,
					signal = o.signal,
					priority = finite(o.priority) and o.priority or 0,
					power = finite(o.power) and o.power>=0 and o.power<=1 and o.power or nil,
					general = o.general or 0,
					label = M.label(o.label, o.general),
				}
				local prev = seen[c.source]
				if not prev or c.age < prev.age or (c.age == prev.age and c.signal > prev.signal) then
					seen[c.source] = c
				end
			end
		end
		for _, c in pairs(seen) do
			-- A remembered launch is still displayed, but is not a perpetual alarm.
			local warning_hold = c.signal > 1 and M.warning_coast or M.search_coast
			if c.age <= warning_hold then
				self.alert = math.max(self.alert, c.signal)
			end
			self.contacts[#self.contacts + 1] = c
		end
		table.sort(self.contacts, function(a, b)
			local ap = not M.coasting(a) and a.signal or 1
			local bp = not M.coasting(b) and b.signal or 1
			if ap ~= bp then
				return ap > bp
			end
			if a.priority ~= b.priority then
				return a.priority > b.priority
			end
			return a.source < b.source
		end)
	end
	function r:associate(native_id)
		if not native_id or native_id <= 0 then
			return
		end
		for _, c in ipairs(self.contacts) do
			if c.source == native_id then
				return c
			end
		end
	end
	return r
end
return M
