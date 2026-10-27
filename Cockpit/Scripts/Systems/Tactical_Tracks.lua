-- GPL-3.0-or-later. Source-aware tactical picture, separate from fire control.
-- Exact simulator source identity is association plumbing, not combat ID.
local M = { limits = { radar = 20, rf = 12, mws = 3, datalink = 75 }, bits = { radar = 1, rf = 2, mws = 4, datalink = 8 } }
local Threat = dofile(LockOn_Options.script_path .. "Systems/Tactical_Threat.lua")
local Geolocation = dofile(LockOn_Options.script_path .. "Systems/EW_Geolocation.lua")
local Identification = dofile(LockOn_Options.script_path .. 'Systems/Identification_State.lua')
local capacities = { radar = 64, rf = 16, mws = 16, datalink = 64 }
local direction_rank = { radar = 3, mws = 2, rf = 1, datalink = 0 }
local function finite(x)
	return type(x) == "number" and x == x and math.abs(x) < 1e12
end
local function source(x)
	return finite(x) and x >= 1 and x < 4294967296 and x % 1 == 0
end
function M.new()
	local s = { batches = {}, contacts = {}, sequence = 0 }
	function s:reset()
		self.batches = {}
		self.contacts = {}
		self.clock = nil
	end
	function s:update(now, batches, power)
		if not power or not finite(now) then
			self:reset()
			return
		end
		if self.clock and now < self.clock then
			self:reset()
		end
		self.clock = now
		for sensor, batch in pairs(batches) do
			local old = self.batches[sensor]
			if
				M.bits[sensor]
				and finite(batch.sequence)
				and batch.sequence >= 0
				and finite(batch.time)
				and batch.time <= now + 0.05
				and now - batch.time <= 0.25
				and (not old or batch.time >= old.time)
				and (not old or old.sequence ~= batch.sequence)
			then
				local accepted = {}
				local inputs = batch.contacts or {}
				for index = 1, math.min(#inputs, capacities[sensor]) do
					local o = inputs[index]
					if
						source(o.source)
						and finite(o.age)
						and o.age >= 0
						and o.age <= M.limits[sensor]
						and finite(o.az)
						and math.abs(o.az) <= 2 * math.pi + 0.001
						and finite(o.el)
						and math.abs(o.el) <= math.pi / 2 + 0.001
						and (sensor ~= "rf" or o.signal == 1 or o.signal == 2 or o.signal == 3)
					then
						local c = {
							source = o.source,
							time = batch.time - o.age,
							az = o.az,
							el = o.el,
							signal = o.signal,
							friendly = o.friendly == true,
							hostile = o.hostile == true,
							label = o.label,
							selected = o.selected == true,
                            identity_time = finite(o.identity_time) and o.identity_time or nil,
                            hostile_time = finite(o.hostile_time) and o.hostile_time or nil,
							range = sensor == "radar" and finite(o.range) and o.range >= 40 and o.range or nil,
							measured_range = sensor == "radar"
									and finite(o.measured_range)
									and o.measured_range >= 40
									and o.measured_range
								or nil,
							quality = o.quality,
                            measurement_source = (o.measurement_source==1 or o.measurement_source==2)
                                and o.measurement_source or 0,
							estimated = o.estimated == true,
							uncertainty = finite(o.uncertainty) and o.uncertainty >= 0 and o.uncertainty or nil,
						}
						if sensor == 'datalink' then
							for _,k in ipairs({'n','u','e','vn','vu','ve','link','reporter','flight','ppli',
                                'received','observation_known','observation_time','epoch'}) do c[k]=o[k] end
						end
						if sensor=="rf" then
							c.power=finite(o.power) and o.power>=0 and o.power<=1 and o.power or nil
							c.general=o.general
							local w=o.world
							if type(w)=="table"and finite(w[1])and finite(w[2])and finite(w[3])
								and math.abs(w[1]^2+w[2]^2+w[3]^2-1)<=.005 then
								c.world={w[1],w[2],w[3]}
							end
							if o.general==2 and c.world then
								c.geolocation_status=({[1]=true,[2]=true,[3]=true,[4]=true})[o.geolocation_status] and o.geolocation_status or 0
								if Geolocation.current(o.geolocation,batch.time)then
									c.geolocation={}
									for k,v in pairs(o.geolocation)do c.geolocation[k]=v end
								end
							end
						end
						if not accepted[c.source] or accepted[c.source].time < c.time then
							accepted[c.source] = c
						end
					end
				end
				self.batches[sensor] = { sequence = batch.sequence, time = batch.time, contacts = accepted }
			end
		end
		local joined = {}
		for sensor, batch in pairs(self.batches) do
			for id, o in pairs(batch.contacts) do
				local age = math.max(0, now - o.time)
				if age <= M.limits[sensor] then
					local t = joined[id]
						or {
							source = id,
							mask = 0,
							observations = {},
							affiliation = -1,
							signal = 0,
							age = math.huge,
						}
					joined[id] = t
					t.mask = t.mask + M.bits[sensor]
					t.observations[sensor] = o
					t.age = math.min(t.age, age)
                    Identification.evidence(t, o, sensor)
					if o.friendly then
						t.affiliation = 1
					elseif o.hostile and t.affiliation ~= 1 then
						t.affiliation = 0
					end
					if sensor == 'datalink' then
						t.datalink = o
						t.datalink_age = age
					end
					if sensor == "rf" then
						t.signal = o.signal or 1
						t.label = o.label
						t.geolocation_status=o.geolocation_status
						if Geolocation.current(o.geolocation,now)then t.geolocation=o.geolocation end
					end
					if sensor == "mws" then
						t.optical = true
					end
					-- Each field retains its originating observation. Radar range expires
					-- independently even when optical/RF observations keep the object alive.
					if sensor == "radar" then
						t.selected = o.selected
						t.radar_age = age
						t.range_estimated = o.estimated or age > 0.001
						if age <= 6 then
							t.range = o.range
							t.measured_range = o.measured_range
							t.range_time = o.time
						end
					end
					if
						not t.direction
						or o.time > t.direction.time
						or (o.time == t.direction.time and direction_rank[sensor] > direction_rank[t.direction_sensor])
					then
						t.direction = o
						t.direction_sensor = sensor
						t.az = o.az
						t.el = o.el
						t.uncertainty = o.uncertainty
					end
				end
			end
		end
		self.contacts = {}
		for _, t in pairs(joined) do
			if t.datalink and t.datalink.flight then t.affiliation = 3 end
			t.rf_age = Threat.age(t.observations.rf, now)
			t.rf_coast = t.observations.rf and Threat.coast(t.observations.rf, "rf", t.signal, now) or false
			t.optical_age = Threat.age(t.observations.mws, now)
			t.optical_coast = t.observations.mws and Threat.coast(t.observations.mws, "mws", 0, now) or false
			t.threat_priority = Threat.priority(t, now)
			self.contacts[#self.contacts + 1] = t
		end
		table.sort(self.contacts, function(a, b)
			if not not a.selected ~= not not b.selected then
				return not not a.selected
			end
			if a.threat_priority ~= b.threat_priority then
				return a.threat_priority > b.threat_priority
			end
			return a.source < b.source
		end)
		self.sequence = self.sequence + 1
	end
	return s
end
return M
