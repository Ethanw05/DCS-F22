-- GPL-3.0-or-later. User-specified range envelope for the polar PMFD.
-- Ownship -> target ray, crossed at the native minimum, maximum launch and
-- turn-away limits. STT and TWS use the same geometry and scope range.
local M = { segments = { "MIN", "MAX", "TURN", "AXIS" } }
local function finite(v)
	return type(v) == "number" and v == v and math.abs(v) < 1e9
end
local function clip(x1, y1, x2, y2)
	local dx, dy = x2 - x1, y2 - y1
	local lo, hi = 0, 1
	local p = { -dx, dx, -dy, dy }
	local q = { x1 + 0.965, 0.965 - x1, y1 + 0.925, 0.985 - y1 }
	for i = 1, 4 do
		if math.abs(p[i]) < 1e-10 then
			if q[i] < 0 then
				return nil
			end
		elseif p[i] < 0 then
			lo = math.max(lo, q[i] / p[i])
		else
			hi = math.min(hi, q[i] / p[i])
		end
	end
	if lo > hi then
		return nil
	end
	return { x1 + lo * dx, y1 + lo * dy, x1 + hi * dx, y1 + hi * dy }
end
function M.project(relative, heading, minimum, maximum, turn, scope_range, layout, kind)
	if
		not relative
		or not finite(heading)
		or not finite(scope_range)
		or scope_range <= 0
		or not finite(minimum)
		or not finite(maximum)
		or minimum < 0
		or maximum <= minimum
	then
		return nil
	end
	for i = 1, 3 do
		if not finite(relative[i]) then
			return nil
		end
	end
	local north, alt, east = relative[1], relative[2], relative[3]
	local horizontal = math.sqrt(north * north + east * east)
	if horizontal < 1 then
		return nil
	end
	local forward = north * math.cos(heading) + east * math.sin(heading)
	local right = -north * math.sin(heading) + east * math.cos(heading)
	local ax, ay = right / horizontal, forward / horizontal
	local function distance(slant)
		-- Native limits are slant range; the map plots horizontal separation
		-- at the selected target's height, using the existing scope scale.
		return math.sqrt(math.max(0, slant * slant - alt * alt)) / scope_range * layout.radius
	end
	local function point(d)
		return d * ax, layout.origin_y + d * ay
	end
	local result = {}
	local half_tick = 0.045
	local function tick(name, distance)
		local x, y = point(distance)
		-- Each midpoint is ON the ownship-target ray. Crossbars rotate with
		-- the ray so even an abeam contact has distinct, readable range marks.
		result[name] = clip(x-half_tick*ay, y+half_tick*ax,
			x+half_tick*ay, y-half_tick*ax)
	end
	local low, high = distance(minimum), distance(maximum)
	if low <= layout.radius then
		tick("MIN", low)
	end
	if high <= layout.radius then
		tick("MAX", high)
	end
	if finite(turn) and turn >= minimum and turn <= maximum then
		local d = distance(turn)
		if d <= layout.radius then
			tick("TURN", d)
		end
	end
	-- Both modes use the same full-scale ray, starting at the aircraft's
	-- centre and continuing through the selected contact. It is not a
	-- TWS-only line connecting range ticks, nor a separate steering cue.
	local x, y = point(layout.radius)
	result.AXIS = clip(0, layout.origin_y, x, y)
	return result
end
M.clip = clip -- shared normalized LCD viewport for real map overlays
return M
