-- GPL-3.0-or-later. Heading-up polar presentation inspired by Top Mach PMFD.
-- Layout and polar projection are shared with the offline renderer/tests.
local M = { origin_y = -0.66, radius = 1.45, half_radius = 0.725 }
local pi = math.pi
function M.finite(v)
	return type(v) == "number" and v == v and math.abs(v) < 1e9
end
function M.wrap(a)
	return (a + pi) % (2 * pi) - pi
end
function M.affiliation(native_iff)
	if native_iff == 1 then
		return 1
	end -- friendly
	-- No positive reply is not evidence of hostility or neutrality.
	-- Retain simulator coalition values in the sensor layer, not as pilot ID.
	return -1 -- disabled interrogation, missing or unknown
end
function M.point(distance, bearing, range)
	local fraction = distance / range
	return M.radius * fraction * math.sin(bearing), M.origin_y + M.radius * fraction * math.cos(bearing)
end
-- Inverse of the body transform used by NavGeometry/HUD_FlightMath. DCS
-- map north/east are world X/Z; world Y is altitude. This helper accepts
-- aircraft-body polar data, not the native radar's stabilized scan-frame data.
function M.body_vector(range, az, el, pitch, roll)
	local forward = range * math.cos(el) * math.cos(az)
	local right = range * math.cos(el) * math.sin(az)
	local up = range * math.sin(el)
	local level_right = right * math.cos(roll) + up * math.sin(roll)
	local level_up = -right * math.sin(roll) + up * math.cos(roll)
	return forward * math.cos(pitch) - level_up * math.sin(pitch),
		level_right,
		forward * math.sin(pitch) + level_up * math.cos(pitch)
end
function M.world_observation(o, pose)
	if not pose or not M.finite(o.range) or not M.finite(o.az) or not M.finite(o.el) then
		return
	end
	local f, r, u = M.body_vector(o.range, o.az, o.el, pose.pitch, pose.roll)
	local ch, sh = math.cos(pose.heading), math.sin(pose.heading)
	o.north = pose.north + f * ch - r * sh
	o.east = pose.east + f * sh + r * ch
	o.altitude = pose.altitude + u
end
-- Predict the selected observation in the current aircraft frame while the
-- native radar acquires; a fixed old TDC azimuth loses targets in a turn.
function M.body_observation(t, pose, age)
	if not t.north or not pose then
		return t.range, t.az, t.el
	end
	local n = t.north - pose.north
	local e = t.east - pose.east
	local u = t.altitude - pose.altitude
	if t.velocity_valid then
		n = n + t.vn * age
		e = e + t.ve * age
		u = u + t.vu * age
	end
	local ch, sh = math.cos(pose.heading), math.sin(pose.heading)
	local f, lr = n * ch + e * sh, -n * sh + e * ch
	local forward = f * math.cos(pose.pitch) + u * math.sin(pose.pitch)
	local lu = -f * math.sin(pose.pitch) + u * math.cos(pose.pitch)
	local right = lr * math.cos(pose.roll) - lu * math.sin(pose.roll)
	local up = lr * math.sin(pose.roll) + lu * math.cos(pose.roll)
	return math.sqrt(forward * forward + right * right + up * up),
		math.atan2(right, forward),
		math.atan2(up, math.sqrt(forward * forward + right * right))
end
function M.plot(track, pose, range, age)
	local distance, bearing = M.scope_observation(track, pose, age)
	return M.point(distance, bearing, range)
end
-- The PMFD is a heading-up map, while acquisition is aircraft-body LOS.
-- Use this same projection for plot drawing, TDC following and hit testing.
function M.scope_observation(track, pose, age)
	if track.north and track.east and pose then
		local n = track.north - pose.north
		local e = track.east - pose.east
		if track.velocity_valid then
			n = n + track.vn * (age or 0)
			e = e + track.ve * (age or 0)
		end
		local ch, sh = math.cos(pose.heading), math.sin(pose.heading)
		local f, r = n * ch + e * sh, -n * sh + e * ch
		return math.sqrt(f * f + r * r), math.atan2(r, f)
	end
	return track.range, track.az
end
function M.compass(heading, put)
	local deg = heading * 180 / pi
	local base = math.floor(deg / 5) * 5
	for i = -9, 9 do
		local bearing = (base + i * 5) % 360
		local relative = M.wrap(math.rad(bearing) - heading)
		local p = string.format("F22_COMPASS_%02d_", i + 10)
		put(p .. "X", M.radius * math.sin(relative))
		put(p .. "Y", M.origin_y + M.radius * math.cos(relative))
		local x = M.radius * math.sin(relative)
		local y = M.origin_y + M.radius * math.cos(relative)
		local in_range_label = x > 0.63 and x < 0.81 and y > 0.54 and y < 0.65
		local visible = math.abs(relative) <= math.rad(44)
		put(p .. "ROT", -relative)
		put(p .. "VISIBLE", visible and 1 or 0)
		put(p .. "TICK_VISIBLE", visible and math.abs(x) < 0.965 and not in_range_label and 1 or 0)
		local major = bearing % 30 == 0
		put(p .. "MAJOR", major and 1 or 0)
		put(p .. "LABEL_X", (M.radius - 0.11) * math.sin(relative))
		put(p .. "LABEL_Y", M.origin_y + (M.radius - 0.11) * math.cos(relative))
		local cardinal = ({ [0] = "N", [90] = "E", [180] = "S", [270] = "W" })[bearing]
		put(p .. "LABEL", cardinal or string.format("%02d", bearing / 10))
		put(p .. "LABEL_NUMBER", bearing / 10)
		put(p .. "CARDINAL", ({ [0] = 1, [90] = 2, [180] = 3, [270] = 4 })[bearing] or 0)
	end
end
return M
