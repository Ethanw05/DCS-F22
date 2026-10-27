-- GPL-3.0-or-later. Range/format-independent snapshot for tactical consumers.
local M = { sequence = 0 }
function M.publish(computer, put, ready, stt)
	local tracks = {}
	if ready then
		for _, t in pairs(computer.tracks) do
			if t.native_id and computer:quality(t) > 0 then
				tracks[#tracks + 1] = t
			end
		end
		if stt and stt.native_id then
			local found = false
			for _, t in ipairs(tracks) do
				if t.native_id == stt.native_id then
					found = true
				end
			end
			if not found then
				tracks[#tracks + 1] = stt
			end
		end
	end
	table.sort(tracks, function(a, b)
		local sa = a.id == computer.selected or a.stt
		local sb = b.id == computer.selected or b.stt
		if not not sa ~= not not sb then
			return not not sa
		end
		return a.native_id < b.native_id
	end)
	for i = 1, 64 do
		local p = string.format("F22_RADAR_TACTICAL_%02d_", i)
		local t = tracks[i]
		local quality = t and (t.hits and computer:quality(t) or 2) or 0
		put(p .. "VALID", t and 1 or 0)
		put(p .. "SOURCE", t and t.native_id or 0)
		put(p .. "AGE", t and math.max(0, computer.clock - (t.observed or computer.clock)) or 999)
		put(p .. "AZ", t and (t.current_az or t.az) or 0)
		put(p .. "EL", t and (t.current_el or t.el) or 0)
		put(p .. "RANGE", t and (t.current_range or t.range) or 0)
		put(p .. "MEASURED_RANGE", t and t.range or 0)
		-- IFDL can share only the radar's own measured world observation.
		local world=t and type(t.north)=='number' and type(t.east)=='number' and type(t.altitude)=='number'
		put(p..'POSITION_VALID',world and 1 or 0)
		put(p..'N',world and t.north or 0);put(p..'U',world and t.altitude or 0);put(p..'E',world and t.east or 0)
		put(p..'VN',world and t.vn or 0);put(p..'VU',world and t.vu or 0);put(p..'VE',world and t.ve or 0)
		put(p .. "QUALITY", quality)
		put(p .. "FRIENDLY", t and t.iff == 1 and 1 or 0)
		put(p .. "HOSTILE", t and t.iff == 0 and 1 or 0)
		put(p .. "SELECTED", t and (t.id == computer.selected or t.stt) and 1 or 0)
	end
	put("F22_RADAR_TACTICAL_TIME", computer.clock)
	M.sequence = M.sequence + 1
	put("F22_RADAR_TACTICAL_SEQUENCE", M.sequence)
end
return M
