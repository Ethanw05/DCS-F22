-- GPL-3.0-or-later. Stable inspection over the common tactical picture.
local M = {}
local Threat = dofile(LockOn_Options.script_path .. "Systems/Tactical_Threat.lua")
local Geolocation = dofile(LockOn_Options.script_path .. "Systems/EW_Geolocation.lua")
local Proximity = dofile(LockOn_Options.script_path .. 'Systems/RWR_Proximity.lua')
function M.new(put, label_code, sensors)
	local s = { source = nil, step = 0, detail = false }
	function s:command(command)
		if command == 10906 then
			self.step = 1
		elseif command == 10907 then
			self.step = -1
		elseif command == 10908 then
			self.detail = not self.detail
		end
	end
	function s:update(tracks, critical)
		local threats = {}
		for _, t in ipairs(tracks) do
			if t.optical or (t.signal > 0 and (not critical or t.signal > 1)) then
				threats[#threats + 1] = t
			end
		end
		table.sort(threats, function(a, b)
			local a_score, b_score = Threat.priority(a, self.now), Threat.priority(b, self.now)
			if a_score ~= b_score then
				return a_score > b_score
			end
			return a.source < b.source
		end)
		local index = 1
		for i, t in ipairs(threats) do
			if t.source == self.source then
				index = i
				break
			end
		end
		if #threats > 0 then
			index = (index - 1 + self.step) % #threats + 1
		end
		self.step = 0
		local t = threats[index]
		self.source = t and t.source or nil
		local ir = t and t.observations.mws
		local rf = t and t.observations.rf
		local direction, direction_sensor
		if t then
			direction, direction_sensor = Threat.direction(t, self.now)
		end
		local az = direction and direction.az or 0
		local radius = rf and (Proximity.radius(rf.power,.84) or ({ [1] = 0.78, [2] = 0.53, [3] = 0.28 })[t.signal]) or 0.9
		put('F22_DEFENSIVE_PROXIMITY_VALID',rf and Proximity.valid(rf.power) and 1 or 0)
		put('F22_DEFENSIVE_PROXIMITY',rf and rf.power or 0)
		put("F22_DEFENSIVE_X", math.sin(az) * radius)
		put("F22_DEFENSIVE_Y", math.cos(az) * radius)
		put("F22_DEFENSIVE_COUNT", #threats)
		put("F22_DEFENSIVE_INDEX", t and index or 0)
		put("F22_DEFENSIVE_DETAIL", self.detail and 1 or 0)
		put("F22_DEFENSIVE_SOURCE", t and t.source or 0)
		put("F22_DEFENSIVE_LABEL", label_code(t and t.label or "U"))
		put("F22_DEFENSIVE_AZ_DEG", math.deg(az) % 360)
		put("F22_DEFENSIVE_EL_DEG", direction and math.deg(direction.el) or 0)
		put("F22_DEFENSIVE_AGE", Threat.age(direction, self.now))
		put("F22_DEFENSIVE_DIRECTION_SOURCE", direction_sensor == "mws" and 4 or direction_sensor == "rf" and 2 or 0)
		put("F22_DEFENSIVE_RF_AGE", Threat.age(rf, self.now))
		put("F22_DEFENSIVE_OPTICAL_AGE", Threat.age(ir, self.now))
		put("F22_DEFENSIVE_RANGE_AGE", t and t.radar_age or 999)
		put("F22_DEFENSIVE_RANGE_ESTIMATED", t and t.range_estimated and 1 or 0)
		put("F22_DEFENSIVE_RF", rf and 1 or 0)
		put("F22_DEFENSIVE_OPTICAL", ir and 1 or 0)
		put("F22_DEFENSIVE_SIGNAL", t and t.signal or 0)
		put("F22_DEFENSIVE_AFFILIATION", t and t.affiliation or -1)
        put('F22_DEFENSIVE_IDENTITY_CONFLICT',t and t.identity_conflict and 1 or 0)
        put('F22_DEFENSIVE_ID_RADAR_AGE',Threat.age(t and t.observations.radar,self.now))
        put('F22_DEFENSIVE_ID_DONOR_AGE',Threat.age(t and t.observations.datalink,self.now))
		put("F22_DEFENSIVE_RANGE_VALID", t and t.range and 1 or 0)
		put("F22_DEFENSIVE_RANGE_NM", t and t.range and t.range / 1852 or 0)
		local geo=t and Geolocation.relative(t.geolocation,self.now,Geolocation.position(sensors))
		put("F22_DEFENSIVE_GEO_VALID",geo and 1 or 0)
		put("F22_DEFENSIVE_GEO_RANGE_NM",geo and geo.range/1852 or 0)
		put("F22_DEFENSIVE_GEO_RADIUS_NM",geo and geo.radius/1852 or 0)
		put("F22_DEFENSIVE_GEO_AGE",geo and geo.age or 999)
		put("F22_DEFENSIVE_GEO_STATUS",geo and 4 or t and t.geolocation_status~=4 and t.geolocation_status or 0)
		put(
			"F22_DEFENSIVE_COAST",
			t
					and (not ir or self.now - ir.time > 0.5)
					and (not rf or self.now - rf.time > (t.signal > 1 and 3.5 or 6))
					and 1
				or 0
		)
		put("F22_DEFENSIVE_VALID", t and 1 or 0)
	end
	s:update({}, false)
	return s
end
return M
