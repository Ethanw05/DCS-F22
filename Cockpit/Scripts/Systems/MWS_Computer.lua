-- GPL-3.0-or-later. Native optical warning bearings with bounded observation memory.
local M = { memory_seconds = 3, fresh_seconds = 0.5 }
local function finite(x)
	return type(x) == "number" and x == x and math.abs(x) < 1e12
end
function M.sector(az)
	local clock = math.floor(az / (math.pi / 6) + 0.5) % 12
	return clock == 0 and 12 or clock
end
function M.new()
	local r = { tracks = {}, contacts = {}, clock = 0 }
	function r:update(now, observations, enabled)
		if not finite(now) or now < 0 then
			self.tracks = {}
			self.contacts = {}
			return
		end
		if now < self.clock or not enabled then
			self.tracks = {}
		end
		self.clock = now
		if enabled then
			for _, o in ipairs(observations) do
				if finite(o.source)and o.threat==false then
					local old=self.tracks[o.source]
					if finite(o.time)and o.time<=now+.05 and now-o.time<=M.fresh_seconds and(not old or o.time>=old.time)then self.tracks[o.source]=nil end
				else
				if
					finite(o.source)
					and o.source >= 1
					and o.source <= 4294967295
					and o.source == math.floor(o.source)
					and finite(o.time)
					and o.time <= now + 0.05
					and now - o.time <= M.fresh_seconds
					and finite(o.az)
					and math.abs(o.az) <= math.pi + 0.001
					and finite(o.el)
					and math.abs(o.el) <= math.pi / 2 + 0.001
				then
					local old = self.tracks[o.source]
					if not old or o.time > old.time then
						self.tracks[o.source] = { source = o.source, time = o.time, az = o.az, el = o.el }
					end
				end
				end
			end
		end
		self.contacts = {}
		for source, t in pairs(self.tracks) do
			t.age = math.max(0, now - t.time)
			if t.age > M.memory_seconds then
				self.tracks[source] = nil
			else
				t.coast = t.age > M.fresh_seconds
				self.contacts[#self.contacts + 1] = t
			end
		end
		table.sort(self.contacts, function(a, b)
			if a.coast ~= b.coast then
				return not a.coast
			end
			if a.time ~= b.time then
				return a.time > b.time
			end
			return a.source < b.source
		end)
	end
	return r
end
return M
