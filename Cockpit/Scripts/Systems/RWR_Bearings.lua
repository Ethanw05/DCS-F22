-- GPL-3.0-or-later. Rotate remembered passive directions, never infer range.
-- Reuse the existing orthonormal body/world frame math.
local Frames = dofile(LockOn_Options.script_path .. "Systems/Gun_Frames.lua")
local M = {}
local function finite(x)
	return type(x) == "number" and x == x and math.abs(x) < 1e12
end
function M.frame(sensors)
	if not sensors then
		return
	end
	local ok, heading, pitch, roll = pcall(function()
		return sensors.getHeading(), sensors.getPitch(), sensors.getRoll()
	end)
	if ok and finite(heading) and finite(pitch) and finite(roll) then
		return Frames.from_pose({ heading = -heading, pitch = pitch, roll = roll })
	end
end
function M.new()
	local s = { history = {}, tracks = {} }
	function s:reset()
		self.history = {}
		self.tracks = {}
		self.time = nil
	end
	function s:update(now, frame, contacts, power)
		if not power or not finite(now) or not frame then
			self:reset()
			return
		end
		if self.time and (now < self.time or now - self.time > 0.25) then
			self:reset()
		end
		self.time = now
		local last = self.history[#self.history]
		if last and last.time == now then
			table.remove(self.history)
		end
		self.history[#self.history + 1] = { time = now, frame = frame }
		while #self.history > 2 and now - self.history[2].time > 12.1 do
			table.remove(self.history, 1)
		end
		local seen = {}
		for _, c in ipairs(contacts) do
			seen[c.source] = true
			local old = self.tracks[c.source]
			local az, el = c.az, c.el
			c.bearing_compensated = false
			if finite(az) and finite(el) and math.abs(el) <= math.pi / 2 + 0.001 then
				local stamp = now - c.age
				-- TIME is receiver age. Ignore small export scheduling skew,
				-- but accept a changed angle, age reset or newer reception.
				local changed = not old
					or math.abs(math.atan2(math.sin(az - old.az), math.cos(az - old.az))) > 1e-7
					or math.abs(el - old.el) > 1e-7
					or c.age < old.age - 1e-4
					or stamp > old.stamp + 0.075
				if changed then
					local at = Frames.at(self.history, stamp)
					old = { az = az, el = el, stamp = stamp }
					if at then
						local ce = math.cos(el)
						-- Native getEmitterPos uses -atan2(right,forward).
						old.world = Frames.world(at, { ce * math.cos(az), math.sin(el), -ce * math.sin(az) })
					end
					self.tracks[c.source] = old
				end
				old.age = c.age
				if old.world then
					local body = Frames.body(frame, old.world)
					local horizontal = math.sqrt(body[1] ^ 2 + body[3] ^ 2)
					-- At the vertical axis azimuth is undefined. Keep the last
					-- displayed bearing until the direction leaves the pole.
					c.az = horizontal > 1e-8 and (-math.atan2(body[3], body[1])) % (2 * math.pi) or old.display_az or az
					c.el = math.atan2(body[2], horizontal)
					old.display_az = c.az
					c.bearing_compensated = true
				end
			end
		end
		for source in pairs(self.tracks) do
			if not seen[source] then
				self.tracks[source] = nil
			end
		end
	end
	return s
end
return M
