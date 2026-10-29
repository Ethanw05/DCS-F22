-- GPL-3.0-or-later. Deterministic radar presentation/track-file computer.
-- Input observations come from a sensor; this module never enumerates world objects.
-- RWS/TWS/VACQ/BORE are simulation workflows, not claimed classified F-22 logic.
local M = { fresh_seconds = 6, support_seconds = 6, maximum_tracks = 64, maximum_hits = 255 }
-- Keep this numerical owner independent of host globals/file loading.
local metadata_fields = {"coalition_known","coalition_affiliation",
    "association_valid","filter_valid","position_sigma_m","velocity_sigma_mps","range_sigma_m",
    "angle_sigma_rad","raw_north","raw_altitude","raw_east","measured_range","measured_azimuth",
    "measured_elevation","range_rate","rate_sigma_mps"}
local function copy_metadata(target, observation)
    target.type_name = observation.type_name
    for i = 1, #metadata_fields do target[metadata_fields[i]] = observation[metadata_fields[i]] end
    target.covariance = target.covariance or {}
    for i = 1, 21 do target.covariance[i] = observation.covariance and observation.covariance[i] or 0 end
end
local rad = math.rad
-- Reference: installed Hornet guide p171. BST is a 3.3-degree full
-- cone; VACQ -13..+46 degrees. Our VACQ uses 10 NM for the F-22
-- simulation (the Hornet guide specifies 5 NM). VACQ width and WIDE dimensions
-- remain declared F-22 simulation choices, not verified Hornet values.
M.profiles = {
	BORE = { code = 1, az = 1.65, lo = -1.65, hi = 1.65, nm = 10 },
	VACQ = { code = 2, az = 5, lo = -13, hi = 46, nm = 10 },
	WIDE = { code = 3, az = 15, lo = -10, hi = 10, nm = 10 },
}
local function finite(x)
	return type(x) == "number" and x == x and math.abs(x) < 1e9
end
local function clamp(x, a, b)
	return math.max(a, math.min(b, x))
end
local function angular(a, b)
	return (a - b + math.pi) % (2 * math.pi) - math.pi
end
function M.new()
	local r = {
		mode = "RWS",
		search_mode = "RWS",
		range_index = 5,
		ranges = { 5, 10, 20, 40, 80, 160 },
		azimuth = 60,
		elevation = 0,
		cursor_az = 0,
		cursor_range = 20 * 1852,
		tracks = {},
		next_id = 1,
		selected = nil,
		clock = 0,
		power = false,
		plots = {},
		native_mode = -1,
		acquire = false,
		acquire_time = 0,
		locked = false,
		vertical_span = 20,
		expand = false,
		return_mode = "RWS",
	}
	function r:profile()
		return M.profiles[self.mode]
	end
	function r:memory_time()
		return (self.mode == "TWS" or self.return_mode == "TWS") and 20 or 10
	end
	-- Freshness is an explicit simulation policy, not an accuracy percentage.
	function r:fresh_time()
		return self:profile() and 1 or M.fresh_seconds
	end
	function r:age(t)
		return t and finite(t.observed) and math.max(0, self.clock - t.observed) or math.huge
	end
	function r:quality(t)
		if not t or self:age(t) > self:memory_time() then
			return 0
		end
		if self:age(t) > self:fresh_time() then
			return 3
		end
		return t.hits >= 2 and 2 or 1
	end
	function r:supportable(t)
		return t and finite(t.native_id) and t.native_id > 0 and t.hits >= 2 and self:age(t) <= M.support_seconds
			and (t.measurement_source ~= 2 or t.velocity_valid == true and t.association_valid == true)
			or false
	end
	function r:source(id)
		for _, t in pairs(self.tracks) do
			if t.native_id == id then
				return t
			end
		end
	end
	function r:forget(id)
		self.tracks[id] = nil
		if self.secondary == id then self.secondary = nil end
		if self.acquire_id == id then self.acquire, self.acquire_id = false, nil end
		if self.selected == id then self.selected, self.secondary = self.secondary, nil end
	end
	function r:retire_owned(observations)
		local active = {}
		for i = 1, math.min(M.maximum_tracks, #observations) do
			local o = observations[i]
			if o.measurement_source == 2 and o.native_id then active[o.native_id] = true end
		end
		for id, t in pairs(self.tracks) do
			if t.measurement_source == 2 and not active[t.native_id] then self:forget(id) end
		end
	end
	-- The native owner interleaves priority revisits within the pilot search.
	-- This describes requests and measured support age, never a second sensor.
	function r:search_plan(required)
		if not self.power or (self.mode ~= "TWS" and self.mode ~= "RWS") then return end
		local plan = {
			az = 0, el = self.elevation,
			half_az = rad(self.azimuth), half_el = rad(self.vertical_span / 2),
			range = self:range(), obligations = 0, support_count = 0,
			support_overdue = 0, revisit_remaining = M.support_seconds,
		}
		local seen = {}
		for i = 1, math.min(8, #(required or {})) do
			local id = required[i]
			if finite(id) and id > 0 and not seen[id] then
				seen[id] = true
				local track = self:source(id)
				plan.support_count = plan.support_count + 1
				plan.revisit_remaining = math.min(plan.revisit_remaining,
					math.max(0, M.support_seconds - self:age(track)))
				if not self:supportable(track) then
					plan.support_overdue = plan.support_overdue + 1
				end
			end
		end
		plan.obligations = plan.support_count
		return plan
	end
	function r:geometry(display, pose)
		for _, t in pairs(self.tracks) do
			t.current_range, t.current_az, t.current_el =
				display.body_observation(t, pose, math.max(0, self.clock - t.observed))
			t.scope_range, t.scope_az = display.scope_observation(t, pose, math.max(0, self.clock - t.observed))
		end
		local t = self.selected and self.tracks[self.selected]
		if self.cursor_follow and t then
			self.cursor_range = t.scope_range
			self.cursor_az = t.scope_az
		end
	end
	function r:range()
		local profile = self:profile()
		if profile then
			return profile.nm * 1852
		end
		return self.ranges[self.range_index] * 1852
	end
	-- Display scale is independent of the sensing volume. A close gun target
	-- must not remain buried against ownship on an 80-NM search display.
	function r:scope_range(locked_range, envelope_range)
		if finite(locked_range) and locked_range >= 40 then
			if finite(envelope_range) and envelope_range > locked_range then
				locked_range = envelope_range
			end
			local scales = { 1, 2, 5, 10, 20, 40, 80, 160, 320 }
			local current = self.lock_scope_nm
			if not current or locked_range > current * 1852 * 0.85 or locked_range < current * 1852 * 0.28 then
				current = scales[#scales]
				for _, nm in ipairs(scales) do
					if locked_range <= nm * 1852 * 0.75 then
						current = nm
						break
					end
				end
				self.lock_scope_nm = current
			end
			return current * 1852
		end
		self.lock_scope_nm = nil
		return self:range() / (self.expand and 2 or 1)
	end
	function r:reset()
		self.tracks = {}
		self.plots = {}
		self.selected = nil
		self.secondary = nil
		self.acquire = false
		self.locked = false
		self.cursor_follow = false
		self.acquire_id = nil
	end
	function r:command(c)
		if c:find("cursor_", 1, true) == 1 or c == "recenter" then
			self.cursor_follow = false
		end
		if c == "power" then
			self.power = not self.power
			self:reset()
			return
		end
		if c == "range_up" then
			self.range_index = math.min(#self.ranges, self.range_index + 1)
		elseif c == "range_down" then
			self.range_index = math.max(1, self.range_index - 1)
		elseif c == "azimuth" then
			self.azimuth = self.azimuth == 60 and 30 or self.azimuth == 30 and 15 or 60
		elseif c == "vertical_span" then
			self.vertical_span = self.vertical_span == 10 and 20 or self.vertical_span == 20 and 40 or 10
		elseif c == "expand" then
			self.expand = not self.expand
		elseif c == "elevation_up" then
			self.elevation = clamp(self.elevation + rad(2), rad(-40), rad(40))
		elseif c == "elevation_down" then
			self.elevation = clamp(self.elevation - rad(2), rad(-40), rad(40))
		elseif c == "cursor_left" then
			self.cursor_az = self.cursor_az - rad(2)
		elseif c == "cursor_right" then
			self.cursor_az = self.cursor_az + rad(2)
		elseif c == "cursor_up" then
			self.cursor_range = self.cursor_range + self:range() * 0.025
		elseif c == "cursor_down" then
			self.cursor_range = self.cursor_range - self:range() * 0.025
		elseif c == "recenter" then
			self.cursor_az = 0
			self.cursor_range = self:range() / 2
			self.elevation = 0
		elseif c == "rws" or c == "tws" or c == "vertical" or c == "boresight" or c == "wide" or c == "toggle" then
			if c == "toggle" then
				c = self.search_mode == "TWS" and "rws" or "tws"
			end
			self.mode = ({ rws = "RWS", tws = "TWS", vertical = "VACQ", boresight = "BORE", wide = "WIDE" })[c]
			if self.mode == "RWS" or self.mode == "TWS" then
				self.search_mode = self.mode
			end
			self.return_mode = self.mode
			self.acquire = false
			self.locked = false
			self.plots = {}
		elseif c == "undesignate" then
			for _, t in pairs(self.tracks) do
				t.designated = false
			end
			self.selected = nil
			self.secondary = nil
			self.acquire = false
			self.locked = false
			self.mode = self.return_mode
		elseif c == "next_track" or c == "previous_track" then
			local ids = {}
			for id, t in pairs(self.tracks) do
				-- A pilot may designate a retained sensor return between
				-- revisits. Native acquisition must still confirm any lock.
				if t.hits >= 1 and self.clock - t.observed <= self:memory_time() then
					ids[#ids + 1] = id
				end
			end
			table.sort(ids)
			local direction = c == "previous_track" and -1 or 1
			local index = direction == -1 and 1 or 0
			for i, id in ipairs(ids) do
				if id == self.selected then
					index = i
				end
			end
			self.selected = #ids > 0 and ids[(index + direction - 1) % #ids + 1] or nil
			self.cursor_follow = self.selected ~= nil
			local t = self.selected and self.tracks[self.selected]
			if t then
				self.cursor_az = t.scope_az or t.az
				self.cursor_range = t.scope_range or t.range
			end
		elseif c == "swap_targets" then
			if self.secondary and self.tracks[self.secondary] and not self.locked then
				self.selected, self.secondary = self.secondary, self.selected
			end
		elseif c == "clear_secondary" then
			local t = self.secondary and self.tracks[self.secondary]
			if t then
				t.designated = false
			end
			self.secondary = nil
		elseif c == "designate" or c == "secondary" or c == "stt" then
			if c ~= "secondary" and (self.acquire or self.locked) then
				return
			end
			local best, score = nil, math.huge
			for id, t in pairs(self.tracks) do
				local cost = (angular(t.scope_az or t.current_az or t.az, self.cursor_az) / rad(5)) ^ 2
					+ (((t.scope_range or t.current_range or t.range) - self.cursor_range) / (self:range() * 0.06))
						^ 2
				if self.clock - t.observed <= self:memory_time() and cost < 1 and cost < score then
					best = id
					score = cost
				end
			end
			if c == "stt" or c == "designate" and self.cursor_follow then
				local held = self.selected and self.tracks[self.selected]
				if held and self:age(held) <= self:memory_time() then
					best = self.selected
				end
			end
			if best then
				if c == "secondary" then
					if best ~= self.selected then
						self.secondary = best
						self.tracks[best].designated = true
					end
				else
					if c == "stt" or self.mode ~= "TWS" or self.selected == best then
						self.acquire = true
						self.acquire_time = self.clock
						self.acquire_id = best
					end
					if self.mode == "TWS" and self.selected ~= best then
						local previous = self.selected and self.tracks[self.selected]
						if previous then
							previous.designated = true
						end
						self.secondary = self.selected
					elseif self.secondary == best then
						self.secondary = self.selected
					end
					self.tracks[best].designated = self.mode == "TWS" or self.tracks[best].designated
					self.selected = best
					self.cursor_follow = true
				end
			end
		end
		self.cursor_az = clamp(self.cursor_az, -rad(self.azimuth), rad(self.azimuth))
		self.cursor_range = clamp(self.cursor_range, 40, self:range())
	end
	function r:inside(o)
		if not (finite(o.range) and finite(o.az) and finite(o.el) and finite(o.age)) then
			return false
		end
		if o.age < 0 or o.age > self:memory_time() or o.range < 40 then
			return false
		end
		if o.measurement_source == 2 and not (finite(o.north) and finite(o.altitude) and finite(o.east)) then
			return false
		end
		-- A retained source was already sensed. Mode/ownship geometry changes
		-- must not reject a genuine newer observation of that same source.
		if o.native_id and self:source(o.native_id) then
			return true
		end
		if self.native_mode == 3 then
			return math.abs(o.az) <= rad(60) and math.abs(o.el) <= rad(60)
		end
		-- A current owned report has already passed native sensing. Its
		-- original observation remains authoritative after later search changes.
		if o.measurement_source == 2 then
			return o.range <= self.ranges[#self.ranges] * 1852
				and math.abs(o.az) <= rad(60) + 1e-9
				and math.abs(o.el) <= rad(60) + 1e-9
		end
		if o.range > self:range() then return false end
		-- During native acquisition the candidate may move outside the
		-- original search pattern. Fresh sensor updates must still guide the
		-- existing acquisition; they are not new STT claims.
		if self.acquire and self.native_mode == 2 then
			return math.abs(o.az) <= rad(60) and math.abs(o.el) <= rad(60)
		end
		local p = self:profile()
		if p then
			return math.abs(o.az) <= rad(p.az) and o.el >= rad(p.lo) and o.el <= rad(p.hi)
		end
		return math.abs(o.az) <= rad(self.azimuth) and math.abs(o.el - self.elevation) <= rad(self.vertical_span / 2)
	end
	function r:update(dt, observations, native_mode, owned_snapshot)
		self.clock = self.clock + dt
		self.native_mode = native_mode
		if not self.power then
			self:reset()
			return
		end
		-- A coherent owned snapshot already includes native coasted files.
		-- Its missing IDs are retired, not a second independent Lua memory.
		if owned_snapshot then self:retire_owned(observations) end
		if self.locked and native_mode ~= 3 then
			self.acquire = false
			self.locked = false
			self.mode = self.return_mode
		end
		self.locked = native_mode == 3
		if self.locked then
			self.acquire = false
			self.acquire_id = nil
		end
		if self.acquire and self.clock - self.acquire_time > 4 then
			self.acquire = false
			self.acquire_id = nil
		end
		-- Observation time is now minus native AGE, not the changing slot number.
		-- Deduplicate echoes; one observation may update only one track per frame.
		local obs = {}
		local by_native_id = {}
		for observation_index = 1, math.min(M.maximum_tracks, #observations) do
			local o = observations[observation_index]
			if self:inside(o) then
				local duplicate = false
				if o.native_id and by_native_id[o.native_id] then
					local index = by_native_id[o.native_id]
					if o.age < obs[index].age then
						obs[index] = o
					end
					duplicate = true
				end
				for _, p in ipairs(obs) do
					if not o.native_id and not p.native_id then
						if
							math.abs(p.range - o.range) < 150
							and math.abs(angular(p.az, o.az)) < rad(0.3)
							and math.abs(p.el - o.el) < rad(0.3)
						then
							duplicate = true
						end
					end
				end
				if not duplicate then
					obs[#obs + 1] = o
					if o.native_id then
						by_native_id[o.native_id] = #obs
					end
				end
			end
		end
		self.plots = obs
		local candidates = {}
		for i, o in ipairs(obs) do
			for id, t in pairs(self.tracks) do
				local elapsed = self.clock - t.observed
				local pred = t.range + (t.rate or 0) * elapsed
				local dr = math.abs(o.range - pred) / math.max(600, elapsed * 500)
				local da = math.abs(angular(o.az, t.az)) / rad(3)
				local de = math.abs(o.el - t.el) / rad(3)
				if o.north and t.north then
					-- World-coordinate gating survives ownship turns; slots and
					-- transient body angles are not durable target identities.
					local elapsed = math.max(0, self.clock - o.age - t.observed)
					local pn = t.north + (t.velocity_valid and t.vn * elapsed or 0)
					local pe = t.east + (t.velocity_valid and t.ve * elapsed or 0)
					local pu = t.altitude + (t.velocity_valid and t.vu * elapsed or 0)
					dr = math.sqrt((o.north - pn) ^ 2 + (o.east - pe) ^ 2) / math.max(600, elapsed * 500)
					da = 0
					de = math.abs(o.altitude - pu) / math.max(600, elapsed * 500)
				end
				if o.native_id and t.native_id then
					if o.native_id == t.native_id then
						candidates[#candidates + 1] = { i = i, id = id, cost = -1 }
					end
				elseif dr < 1 and da < 1 and de < 1 then
					candidates[#candidates + 1] = { i = i, id = id, cost = dr * dr + da * da + de * de }
				end
			end
		end
		table.sort(candidates, function(a, b)
			return a.cost < b.cost
		end)
		local used, matched = {}, {}
		for _, c in ipairs(candidates) do
			if not used[c.i] and not matched[c.id] then
				local o, t = obs[c.i], self.tracks[c.id]
				used[c.i] = true
				matched[c.id] = true
				o.id = t.id
				t.current_range = o.range
				t.current_az = o.az
				t.current_el = o.el
                t.association_valid = o.association_valid
                if o.measurement_source==2 and not o.association_valid then t.velocity_valid=false end
				local stamp = o.observed or self.clock - o.age
				if stamp > t.observed + 0.01 and stamp <= self.clock + 0.001 then
					local delta = stamp - t.observed
					t.revisit_s = delta
					if o.north and t.north and t.velocity_valid then
						local dn = o.north - t.north - t.vn * delta
						local de = o.east - t.east - t.ve * delta
						local du = o.altitude - t.altitude - t.vu * delta
						t.prediction_error_m = math.sqrt(dn * dn + de * de + du * du)
					end
					local rate = (o.range - t.range) / delta
					t.rate = math.abs(rate) < 1500 and rate or nil
					-- A new return after a freshness gap is reacquisition, not
					-- continuation of an indefinitely cumulative two-hit track.
					t.hits = delta <= self:fresh_time() and math.min(M.maximum_hits, t.hits + 1) or 1
					t.range = o.range
					t.az = o.az
					t.el = o.el
					t.iff = o.iff
					t.observed = stamp
					t.north = o.north
					t.east = o.east
					t.altitude = o.altitude
					t.vn = o.vn
					t.ve = o.ve
					t.vu = o.vu
					t.velocity_valid = o.velocity_valid
					t.native_id = o.native_id
					t.measurement_source = o.measurement_source or 1
					copy_metadata(t,o)
				end
				if o.iff == 1 then
					t.friend_until = math.max(t.friend_until or 0, self.clock - o.age + 30)
					t.hostile_until = nil
				elseif o.iff == 0 then
					t.hostile_until = math.max(t.hostile_until or 0, self.clock - o.age + 30)
				end
				if o.iff == 1 or o.iff == 0 then
					t.ident_class = o.iff
					t.ident_time = math.max(t.ident_time or -1, self.clock - o.age)
				end
			end
		end
		local track_count = 0
		for _ in pairs(self.tracks) do track_count = track_count + 1 end
		for i, o in ipairs(obs) do
			if not used[i] and track_count < M.maximum_tracks then
				track_count = track_count + 1
				local id = self.next_id
				self.next_id = id + 1
				o.id = id
				self.tracks[id] = {
					id = id,
					range = o.range,
					az = o.az,
					el = o.el,
					iff = o.iff,
					current_range = o.range,
					current_az = o.az,
					current_el = o.el,
					observed = o.observed or self.clock - o.age,
					hits = 1,
					friend_until = o.iff == 1 and self.clock - o.age + 30 or nil,
					hostile_until = o.iff == 0 and self.clock - o.age + 30 or nil,
					native_id = o.native_id,
					measurement_source = o.measurement_source or 1,
					north = o.north,
					east = o.east,
					altitude = o.altitude,
					vn = o.vn,
					ve = o.ve,
					vu = o.vu,
					velocity_valid = o.velocity_valid,
				}
				copy_metadata(self.tracks[id],o)
				if o.iff == 1 or o.iff == 0 then
					self.tracks[id].ident_class = o.iff
					self.tracks[id].ident_time = self.clock - o.age
				end
			end
		end
		for id, t in pairs(self.tracks) do
			t.iff = (t.friend_until and self.clock < t.friend_until) and 1
				or (t.hostile_until and self.clock < t.hostile_until) and 0 or -1
			if self.clock - t.observed > self:memory_time() then
				self:forget(id)
			end
		end
		if
			(self.mode == "VACQ" or self.mode == "BORE" or self.mode == "WIDE")
			and #obs > 0
			and not self.locked
			and not self.acquire
		then
			local candidate = nil
			local profile = self:profile()
			for _, o in ipairs(obs) do
				local t = o.id and self.tracks[o.id]
				if
					o.age <= 1
					and o.range <= profile.nm * 1852
					and math.abs(o.az) <= rad(profile.az)
					and o.el >= rad(profile.lo)
					and o.el <= rad(profile.hi)
					and o.iff ~= 1
					and (not t or t.iff ~= 1)
					and (not candidate or o.range < candidate.range)
				then
					candidate = o
				end
			end
			if candidate then
				-- An ACM observation is already selected in the body search gate;
				-- it must not pass through the heading-up map cursor hit test.
				self.selected = candidate.id
				self.acquire = true
				self.acquire_time = self.clock
				self.acquire_id = candidate.id
				self.cursor_follow = true
			end
		end
	end
	return r
end
return M
