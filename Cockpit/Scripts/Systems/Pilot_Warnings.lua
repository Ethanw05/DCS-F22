-- GPL-3.0-or-later. Own warning policy; not a certified or recovered F-22 TAWS.
local M = { names = { "pull_up", "roll_left", "roll_right", "altitude", "flight_controls", "caution", "terrain" } }
local function finite(v)
	return type(v) == "number" and v == v and math.abs(v) < 1e9
end
local Faults = dofile(LockOn_Options.script_path .. 'Systems/Fault_Registry.lua')
local Altitude = dofile(LockOn_Options.script_path .. "Systems/Altitude_Alerts.lua")
local Escape = dofile(LockOn_Options.script_path .. "Systems/Terrain_Escape.lua")
function M.terrain(s, height, visible)
	local result = Escape.solve(s, height, nil, visible)
	return result.call, result.impact, result
end
function M.new()
	return setmetatable({
		clock = nil,
        faults = Faults.new(),
        unavailable_terrain = {valid = false},
		terrain_pending = nil,
		terrain_since = 0,
		terrain_until = -1,
		terrain_call = nil,
		terrain_priority = 0,
		altitude = Altitude.new(),
		fault_since = nil,
		caution_since = nil,
		last = {},
		was_powered = false,
	}, { __index = M })
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
    self.faults:update(now, s.conditions)
    local fcs=self.faults.records[1]
    if self.fcs_occurrence ~= fcs.occurrence then self.fault_ack = false;self.fcs_occurrence = fcs.occurrence end
	if not s.powered then
		if not self.was_powered then return { text = '', priority = 0 } end
		self.was_powered = false
		self.altitude:power_lost()
		self.fault_since = nil
		self.caution_since = nil
		self.terrain_pending = nil
		self.terrain_call = nil
		self.terrain_priority = 0
		self.terrain_until = -1
		self.terrain_engine = nil
		self.spoken = nil
		self.last = {}
		self.fault_ack = false
		self.caution_ack = false
		return { text = "", priority = 0 }
	end
	self.was_powered = true
    local flight_valid = s.valid and not s.ground
    local terrain = self.unavailable_terrain
    if flight_valid then
        self.terrain_engine = self.terrain_engine or Escape.new()
        terrain = self.terrain_engine:update(s, height, visible)
    else
        self.altitude_visual_until = -1
    end
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
    local altitude_active = self.altitude:update(s, flight_valid)
    local altitude_ticket = self.altitude.selected
    if altitude_ticket ~= self.altitude_ticket then
        self.last.altitude = nil
        self.altitude_ticket = altitude_ticket
    end
	if fcs.valid and fcs.active and s.airborne==true then
		self.fault_since = self.fault_since or now
	else
		self.fault_since = nil
		self.fault_ack = false
	end
    local caution = self.faults.attention > 0
    if self.caution_occurrence ~= self.faults.occurrence then
        self.caution_ack = false
        self.caution_since = nil
        self.last.caution = nil
        self.caution_occurrence = self.faults.occurrence
    end
	if caution then
		self.caution_since = self.caution_since or now
	else
		self.caution_since = nil
		self.caution_ack = false
	end
	local selected, priority
    local ap = s.ap_event
    self.ap_current = ap
    local ap_pending = ap and (ap.epoch~=self.ap_played_epoch or ap.ticket~=self.ap_played_ticket)
	if self.terrain_call then
		selected = self.terrain_call
		priority = self.terrain_priority
	elseif ap_pending or self.fault_since and now - self.fault_since >= 0.5 then
		selected = "flight_controls"
		priority = 1
	elseif
        altitude_active or now < (self.altitude_visual_until or -1)
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
	local acknowledged = selected == "flight_controls" and self.fault_ack and not ap_pending
		or selected == "caution" and self.caution_ack
		or selected == "altitude" and not altitude_active
	if
		selected
		and not acknowledged
		and not busy
		and not s.audio_busy
		and (ap_pending and selected=='flight_controls' or
            (priority == 3 and self.spoken ~= selected) or now - (self.last[selected] or -100) > repeat_time)
	then
		event = selected
	end
	return { text = text, priority = priority or 0, event = event, impact = impact, terrain = terrain,
        altitude_ticket = altitude_ticket, altitude_label = self.altitude.label,
        ap_event = selected=='flight_controls' and ap_pending and ap or nil }
end
function M:played(name, now, ticket, ap)
	if not name or not finite(now) then return end
	if name == "altitude" then
        if not finite(ticket) or ticket<1 or ticket>16777215 or ticket%1~=0 then return end
        self.altitude:played(ticket)
        -- A late confirmation belongs to its original occurrence. It cannot
        -- consume or rate-limit a different event selected while speech started.
        if ticket~=self.altitude_ticket then return end
        self.altitude_visual_until = now + 3
    end
	self.last[name] = now
	self.spoken = name
    if name=='flight_controls' and ap then self.ap_played_epoch,self.ap_played_ticket=ap.epoch,ap.ticket end
end
function M:acknowledge()
    if self.ap_current then
        self.ap_played_epoch,self.ap_played_ticket=self.ap_current.epoch,self.ap_current.ticket
    end
    self.faults:acknowledge()
	self.fault_ack = self.fault_since ~= nil
	self.caution_ack = self.caution_since ~= nil
	self.altitude:played(self.altitude_ticket)
	self.altitude_visual_until = -1
end
return M
