-- GPL-3.0-or-later. Editable manual dispenser programs, no automatic release.
local M = { intervals = { 0.1, 0.25, 0.5, 1, 2 } }
function M.new()
	local s = {
		selected = 1,
		programs = {
			{ chaff = 1, flare = 1, interval = 0.25, repetitions = 4 },
			{ chaff = 0, flare = 1, interval = 0.25, repetitions = 2 },
			{ chaff = 1, flare = 1, interval = 0.25, repetitions = 6 },
		},
	}
	function s:command(c)
		local p = self.programs[self.selected]
		if c == 10910 then
			self.selected = self.selected % 3 + 1
		elseif c == 10911 then
			p.chaff = (p.chaff + 1) % 5
		elseif c == 10912 then
			p.flare = (p.flare + 1) % 5
		elseif c == 10913 then
			for i, value in ipairs(M.intervals) do
				if p.interval == value then
					p.interval = M.intervals[i % #M.intervals + 1]
					break
				end
			end
		elseif c == 10914 then
			p.repetitions = p.repetitions % 8 + 1
		end
	end
	function s:publish(put)
		for i, p in ipairs(self.programs) do
			local prefix = "F22_CM_PROGRAM_" .. i .. "_"
			put(prefix .. "CHAFF", p.chaff)
			put(prefix .. "FLARE", p.flare)
			put(prefix .. "INTERVAL", p.interval)
			put(prefix .. "REPETITIONS", p.repetitions)
		end
		local p = self.programs[self.selected]
		put("F22_CM_PROGRAM_SELECTED", self.selected)
		put("F22_CM_PROGRAM_CHAFF", p.chaff)
		put("F22_CM_PROGRAM_FLARE", p.flare)
		put("F22_CM_PROGRAM_INTERVAL", p.interval)
		put("F22_CM_PROGRAM_REPETITIONS", p.repetitions)
	end
	return s
end
function M.read(get, index)
	if index ~= 1 and index ~= 2 and index ~= 3 then
		return
	end
	local p = "F22_CM_PROGRAM_" .. index .. "_"
	local c, f, dt, n = get(p .. "CHAFF"), get(p .. "FLARE"), get(p .. "INTERVAL"), get(p .. "REPETITIONS")
	local function integer(x, lo, hi)
		return type(x) == "number" and x >= lo and x <= hi and x % 1 == 0
	end
	if not integer(c, 0, 4) or not integer(f, 0, 4) or c + f == 0 or not integer(n, 1, 8) then
		return
	end
	for _, v in ipairs(M.intervals) do
		if dt == v then
			return { chaff = c, flare = f, interval = dt, repetitions = n }
		end
	end
end
return M
