-- GPL-3.0-or-later. RF-cued search over one native radar scan volume.
-- Mod task policy, not recovered APG-77 beam scheduling or RF performance.
local M = {
	cue_dwell = 2,
	background_dwell = 2,
	manual_hold = 8,
	snapshot_life = 0.25,
	cue_life = 4,
	max_cues = 16,
	limit = math.rad(60),
}
local function finite(v)
	return type(v) == "number" and v == v and math.abs(v) < 1e9
end
local function clamp(x, a, b)
	return math.max(a, math.min(b, x))
end
local function copy(t)
	local o = {}
	for k, v in pairs(t or {}) do
		o[k] = v
	end
	return o
end
function M.project(c, pose)
	local n, u, e = c.wn, c.wu, c.we
	if
		not pose
		or not finite(pose.heading)
		or not finite(pose.pitch)
		or not finite(pose.roll)
		or not finite(n)
		or not finite(u)
		or not finite(e)
		or math.abs(n * n + u * u + e * e - 1) > 0.005
	then
		return
	end
	local ch, sh = math.cos(pose.heading), math.sin(pose.heading)
	local cp, sp = math.cos(pose.pitch), math.sin(pose.pitch)
	local cr, sr = math.cos(pose.roll), math.sin(pose.roll)
	local f, lr = n * ch + e * sh, -n * sh + e * ch
	local forward, lu = f * cp + u * sp, -f * sp + u * cp
	local right, up = lr * cr - lu * sr, lr * sr + lu * cr
	return math.atan2(right, forward), math.atan2(up, math.sqrt(forward * forward + right * right))
end
-- Dedicated RF fields keep optical missiles and radar-supplied directions out
-- of RF tasking. Publication age is added to reception age, never subtracted.
function M.read(get, now, pose)
	local sequence = get("F22_TACTICAL_SEQUENCE")
	local stamp = get("F22_TACTICAL_TIME")
	if
		not finite(sequence)
		or sequence < 1
		or not finite(stamp)
		or now - stamp < -0.01
		or now - stamp > M.snapshot_life
	then
		return {}
	end
	local cues = {}
	for i = 1, 64 do
		local p = string.format("F22_TACTICAL_%02d_", i)
		local source, age = get(p .. "SOURCE"), get(p .. "RF_AGE") + math.max(0, now - stamp)
		local signal = get(p .. "RF_SIGNAL")
		local hold = signal > 1 and 3.5 or M.cue_life
		if
			get(p .. "VALID") > 0.5
			and get(p .. "RF_DIRECTION_VALID") > 0.5
			and get(p .. "RF_GENERAL") == 1
			and get(p .. "AFFILIATION") ~= 1
			and get(p .. "AFFILIATION") ~= 3
			and finite(source)
			and source > 0
			and source % 1 == 0
			and finite(age)
			and age >= 0
			and age <= math.min(M.cue_life, hold)
			and (signal == 1 or signal == 2 or signal == 3)
		then
			local c = {
				source = source,
				age = age,
				signal = signal,
				wn = get(p .. "RF_WORLD_N"),
				wu = get(p .. "RF_WORLD_U"),
				we = get(p .. "RF_WORLD_E"),
			}
			c.az, c.el = M.project(c, pose)
			if c.az and math.abs(c.az) <= M.limit and math.abs(c.el) <= M.limit then
				cues[#cues + 1] = c
			end
		end
	end
	if get("F22_TACTICAL_SEQUENCE") ~= sequence then
		return {}
	end
	table.sort(cues, function(a, b)
		if a.signal ~= b.signal then
			return a.signal > b.signal
		end
		return a.source < b.source
	end)
	while #cues > M.max_cues do
		table.remove(cues)
	end
	return cues
end
local function envelope(a, half, b, extra)
	local lo, hi = math.min(a - half, b - extra), math.max(a + half, b + extra)
	local width = (hi - lo) / 2
	if width > M.limit then
		return
	end
	local center = clamp((hi + lo) / 2, -M.limit + width, M.limit - width)
	if lo < center - width - 1e-8 or hi > center + width + 1e-8 then
		return
	end
	return center, width
end
function M.new()
	local s = { served = {}, manual_until = 0, phase = "background", since = nil }
	function s:reset()
		self.served = {}
		self.manual_until = 0
		self.phase = "background"
		self.since = nil
		self.source = nil
		self.plan = nil
		self.clock = nil
		self.status = {}
	end
	function s:command(name, now)
		if
			({ elevation_up = true, elevation_down = true, azimuth = true, vertical_span = true, recenter = true })[name]
		then
			self.manual_until = now + M.manual_hold
			self.source = nil
			self.plan = nil
			self.phase = "background"
			self.since = now
		end
	end
	function s:publish(put, now, plan)
		local q = self.status or {}
        local donor = plan and plan.cue_request and plan.cue_request > 0
		put("F22_RADAR_SENSOR_TASK", donor and 4 or q.task or 0)
		put("F22_RADAR_RF_CUE_ACTIVE", not donor and q.task == 2 and 1 or 0)
		put("F22_RADAR_RF_CUE_SOURCE", q.source or 0)
		put("F22_RADAR_RF_CUE_COUNT", q.count or 0)
		put("F22_RADAR_RF_CUE_PENDING", q.pending or 0)
		put("F22_RADAR_RF_CUE_AGE", q.age or 999)
		put("F22_RADAR_RF_MANUAL_HOLD", math.max(0, self.manual_until - (now or 0)))
	end
	function s:update(now, computer, base, cues, enabled)
		if not finite(now) then
			self:reset()
			self.status = {}
			return base
		end
		if self.clock and now < self.clock then
			self:reset()
		end
		self.clock = now
		local eligible = {}
		if
			enabled
			and computer.power
			and (computer.mode == "RWS" or computer.mode == "TWS")
			and not computer.acquire
			and computer.native_mode ~= 3
		then
			for _, c in ipairs(cues) do
				local t = computer:source(c.source)
				-- Already confirmed local files do not repeatedly steal discovery time.
				if not t or (t.hits or 0) < 2 or computer:age(t) > 2 then
					eligible[#eligible + 1] = c
				end
			end
		else
			self:reset()
			self.clock = now
			self.status = {}
			return base
		end
		local active = {}
		for _, c in ipairs(eligible) do
			active[c.source] = true
		end
		for id, time in pairs(self.served) do
			if not active[id] or now - time > 30 then
				self.served[id] = nil
			end
		end
		self.status = { task = 1, pending = #eligible }
		local mandatory = base and base.obligations > 0
		if mandatory then
			self.source = nil
			self.plan = nil
			self.phase = "background"
			self.since = now
			self.status.task = 3
			-- Never steal an active support dwell. A small enlargement is
			-- allowed only with spare revisit budget and full hard coverage.
			if
				now >= self.manual_until
				and base.uncovered == 0
				and (base.support_count == 0 or base.revisit_remaining >= 4)
				and (base.support_overdue or 0) == 0
			then
				local plan = copy(base)
				for _, c in ipairs(eligible) do
					local az, ha = envelope(plan.az, plan.half_az, c.az, math.rad(4))
					local el, he = envelope(plan.el, plan.half_el, c.el, math.rad(4))
					if az and el and ha * he <= base.half_az * base.half_el * 1.25 then
						plan.az, plan.el, plan.half_az, plan.half_el = az, el, ha, he
						self.status.pending = math.max(0, self.status.pending - 1)
					end
				end
				return plan
			end
			return base
		end
		if now < self.manual_until or #eligible == 0 then
			if self.phase == "cue" and self.source then
				self.served[self.source] = now
			end
			if now < self.manual_until or self.phase == "cue" then
				self.since = now
			elseif not self.since then
				self.since = now - M.background_dwell
			end
			self.source = nil
			self.plan = nil
			self.phase = "background"
			if now < self.manual_until then
				self.status.task = 0
			end
			return base
		end
		local current
		for _, c in ipairs(eligible) do
			if c.source == self.source then
				current = c
			end
		end
		if not self.since then
			self.since = now - M.background_dwell
		end
		if self.phase == "cue" and (not current or now - self.since >= M.cue_dwell) then
			if self.source then
				self.served[self.source] = now
			end
			self.phase = "background"
			self.since = now
			self.source = nil
			self.plan = nil
		end
		if self.phase == "background" and now - self.since < M.background_dwell then
			return base
		end
		if self.phase == "background" then
			table.sort(eligible, function(a, b)
				local function score(c)
					return c.signal * 2 + math.min(12, now - (self.served[c.source] or (now - 12)))
				end
				if score(a) ~= score(b) then
					return score(a) > score(b)
				end
				return a.source < b.source
			end)
			current = eligible[1]
			self.source = current.source
			self.phase = "cue"
			self.since = now
		end
		local margin = math.rad(math.ceil((4 + current.age * 2) / 2) * 2)
		local ha, he = math.max(math.rad(10), margin), math.max(math.rad(6), margin)
		local lo, hi, below, above = current.az, current.az, current.el, current.el
		local count = 0
		for _, c in ipairs(eligible) do
			if math.abs(c.az - current.az) <= math.rad(15) and math.abs(c.el - current.el) <= math.rad(10) then
				lo, hi = math.min(lo, c.az), math.max(hi, c.az)
				below, above = math.min(below, c.el), math.max(above, c.el)
				count = count + 1
			end
		end
		ha = math.min(math.rad(30), math.max(ha, (hi - lo) / 2 + margin))
		he = math.min(math.rad(20), math.max(he, (above - below) / 2 + margin))
		local a = clamp((lo + hi) / 2, -M.limit + ha, M.limit - ha)
		local e = clamp((below + above) / 2, -M.limit + he, M.limit - he)
		local old = self.plan
		if
			old
			and lo >= old.az - old.half_az + math.rad(2)
			and hi <= old.az + old.half_az - math.rad(2)
			and below >= old.el - old.half_el + math.rad(2)
			and above <= old.el + old.half_el - math.rad(2)
			and ha <= old.half_az
			and he <= old.half_el
		then
			a, e, ha, he = old.az, old.el, old.half_az, old.half_el
		end
		local plan = copy(base)
		plan.az, plan.el, plan.half_az, plan.half_el = a, e, ha, he
		plan.range = computer:range()
		plan.obligations = 0
		plan.uncovered = 0
		plan.support_count = 0
		plan.support_overdue = 0
		plan.revisit_remaining = 0
		plan.changed = now
		plan.rf_cued = true
		self.plan = plan
		self.status =
			{ task = 2, source = current.source, count = count, pending = #eligible - count, age = current.age }
		return plan
	end
	return s
end
return M
