-- GPL-3.0-or-later. Resample coherent native angular curves; no ballistics model.
local M = { delay = 0.04 }
function M.new()
	local s = { samples = {} }
	function s:reset()
		for index = #self.samples, 1, -1 do self.samples[index] = nil end
	end
	function s:push(stamp, points)
		local last = self.samples[#self.samples]
		if last and stamp <= last.time then
			return
		end
		self.samples[#self.samples + 1] = { time = stamp, points = points }
		while #self.samples > 2 and stamp - self.samples[2].time > 0.2 do
			table.remove(self.samples, 1)
		end
	end
	function s:at(now)
		local samples = self.samples
		local latest = samples[#samples]
		if not latest then
			return {}
		end
		-- A single native update of display latency makes the 25 Hz samples
		-- continuous at Lua/render cadence. Never extrapolate a trajectory.
		local time = now - M.delay
		local a, b = samples[1], samples[1]
		if time >= latest.time then
			a, b = latest, latest
		elseif time > samples[1].time then
			for i = 1, #samples - 1 do
				if time >= samples[i].time and time <= samples[i + 1].time then
					a, b = samples[i], samples[i + 1]
					break
				end
			end
		end
		local blend = b.time > a.time and math.max(0, math.min(1, (time - a.time) / (b.time - a.time))) or 0
		local out = {}
		for i = 1, 7 do
			-- Missing native points disappear immediately; do not bridge gaps.
			if latest.points[i] and a.points[i] and b.points[i] then
				local p, q = a.points[i], b.points[i]
				out[i] = { p[1] + (q[1] - p[1]) * blend, p[2] + (q[2] - p[2]) * blend, p[3] + (q[3] - p[3]) * blend }
			end
		end
		return out
	end
	return s
end
return M
