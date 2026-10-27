-- GPL-3.0-or-later. Own warning policy; not a certified or recovered F-22 TAWS.
local M = { names = { "pull_up", "roll_left", "roll_right", "altitude", "flight_controls", "caution", "terrain" } }
local function finite(v)
	return type(v) == "number" and v == v and math.abs(v) < 1e9
end
local Escape = dofile(LockOn_Options.script_path .. "Systems/Terrain_Escape.lua")
function M.terrain(s, height, visible)
	local result = Escape.solve(s, height, nil, visible)
	return result.call, result.impact, result
end
function M.new()
	return setmetatable({
		clock = nil,
		terrain_pending = nil,
		terrain_since = 0,
		terrain_until = -1,
		terrain_call = nil,
		terrain_priority = 0,
		floors = {},
		fault_since = nil,
		caution_since = nil,
		last = {},
		queued_altitude = false,
	}, { __index = M })
end
local function floor(self, key, value, limit, valid, now)
	if not valid or not finite(value) or not finite(limit) or limit <= 0 then
		self.floors[key] = nil
		return
	end
	local state = self.floors[key]
	if not state or state.limit ~= limit then
		state = { limit = limit, armed = value > limit + 100 }
		self.floors[key] = state
	end
	if value > limit + 100 then
		state.armed = true
	end
	if state.armed and value < limit then
		state.armed = false
		self.queued_altitude = true
		self.altitude_until = now + 5
		self.altitude_visual_until = now + 3
	end
end
function M:update(s, height, visible)
	local now = s.now
	if not finite(now) then
		return { text = "", priority = 0 }
	end
	if self.clock and now < self.clock then
		local fresh = M.new()
		for k in pairs(self) do
			self[k] = nil
		end
		for k, v in pairs(fresh) do
			self[k] = v
		end
	end
	self.clock = now
	if not s.powered or not s.valid or s.ground then
		self.floors = {}
		self.fault_since = nil
		self.caution_since = nil
		self.terrain_pending = nil
		self.terrain_call = nil
		self.terrain_priority = 0
		self.terrain_until = -1
		self.queued_altitude = false
		self.terrain_engine = nil
		self.spoken = nil
		self.last = {}
		self.fault_ack = false
		self.caution_ack = false
		return { text = "", priority = 0 }
	end
	self.terrain_engine = self.terrain_engine or Escape.new()
	local terrain = self.terrain_engine:update(s, height, visible)
	local call = terrain.call
	local impact = terrain.impact and math.max(0, terrain.impact - math.max(0, now - (terrain.time or now))) or nil
	if not terrain.valid then
		self.terrain_call = nil
		self.terrain_priority = 0
		self.terrain_until = -1
		self.terrain_pending = nil
	else
		if call ~= self.terrain_pending then
			self.terrain_pending = call
			self.terrain_since = now
		end
		local urgent = terrain.priority == 3
		local change_urgent = urgent and self.terrain_priority == 3
		if call and (now - self.terrain_since >= 0.2 or change_urgent or (urgent and impact and impact <= 2)) then
			self.terrain_call = call
			self.terrain_priority = terrain.priority
			self.terrain_until = now + 0.6
		elseif not call then
			-- A viable recovery clears the call; do not substitute another
			-- PULL UP after the terrain-intersection condition is gone.
			self.terrain_call = nil
			self.terrain_priority = 0
			self.terrain_until = -1
		end
		if now > self.terrain_until then
			self.terrain_call = nil
			self.terrain_priority = 0
		end
	end
	floor(self, "baro", s.baro, s.baro_floor, s.baro_valid and not s.gear, now)
	floor(self, "radar", s.radar, s.radar_floor, s.radar_valid and not s.gear, now)
	local below_floor = not s.gear
		and (
			(s.baro_valid and finite(s.baro) and finite(s.baro_floor) and s.baro_floor > 0 and s.baro < s.baro_floor)
			or (
				s.radar_valid
				and finite(s.radar)
				and finite(s.radar_floor)
				and s.radar_floor > 0
				and s.radar < s.radar_floor
			)
		)
	if s.fcs_valid and s.fcs_fault then
		self.fault_since = self.fault_since or now
	else
		self.fault_since = nil
		self.fault_ack = false
	end
	if s.caution then
		self.caution_since = self.caution_since or now
	else
		self.caution_since = nil
		self.caution_ack = false
	end
	local selected, priority
	if self.terrain_call then
		selected = self.terrain_call
		priority = self.terrain_priority
	elseif self.fault_since and now - self.fault_since >= 0.5 then
		selected = "flight_controls"
		priority = 1
	elseif
		below_floor
		or (self.queued_altitude and now < self.altitude_until)
		or now < (self.altitude_visual_until or -1)
	then
		selected = "altitude"
		priority = 1
	elseif self.caution_since and now - self.caution_since >= 2 then
		selected = "caution"
		priority = 1
	end
	local text = selected and selected:upper():gsub("_", " ") or ""
	local event
	local repeat_time = priority == 3 and 2.5
		or selected == "terrain" and 5
		or selected == "altitude" and 2
		or selected == "flight_controls" and 15
		or 30
	local busy = s.missile_warning and priority ~= 3
	local acknowledged = selected == "flight_controls" and self.fault_ack
		or selected == "caution" and self.caution_ack
		or selected == "altitude" and not self.queued_altitude
	if
		selected
		and not acknowledged
		and not busy
		and not s.audio_busy
		and ((priority == 3 and self.spoken ~= selected) or now - (self.last[selected] or -100) > repeat_time)
	then
		event = selected
		-- The audio owner confirms actual playback. Pure policy callers retain
		-- the immediate event contract unless they explicitly defer this commit.
		if not s.defer_audio_commit then self:played(selected, now) end
	end
	return { text = text, priority = priority or 0, event = event, impact = impact, terrain = terrain }
end
function M:played(name, now)
	if not name or not finite(now) then return end
	self.last[name] = now
	self.spoken = name
	if name == "altitude" then self.queued_altitude = false end
end
function M:acknowledge()
	self.fault_ack = self.fault_since ~= nil
	self.caution_ack = self.caution_since ~= nil
	self.queued_altitude = false
	self.altitude_visual_until = -1
end
return M
