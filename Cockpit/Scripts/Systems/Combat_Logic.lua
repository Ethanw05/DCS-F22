-- GPL-3.0-or-later. Contextual inputs, no sensor or weapon simulation here.
local M = {}
local display = dofile(LockOn_Options.script_path .. "Systems/Sensor_Control.lua")
local sensor_actions = {
	scs_depress = true,
	tdc = true,
	tms_up = true,
	tms_down = true,
	tms_left = true,
	tms_right = true,
	expand = true,
	coverage = true,
	range_up = true,
	range_down = true,
}
function M.new(emit)
	local s =
		{ mode = 1, last_aa = 2, dogfight = false, saved = 1, soi = 2, held = {}, clock = 0 }
	function s:cancel_ground_preview()
		for _, h in pairs(self.held) do
			if h.ground_action and not h.done then emit("ground_preview_cancel");h.done=true end
		end
	end
	function s:set_mode(mode)
		self:cancel_ground_preview()
		self.mode = mode
		if mode == 2 or mode == 3 or mode == 5 then
			self.last_aa = mode
		end
		-- A mode change must not erase the physical down latch. DCS can repeat
		-- down events; only the matching release permits another press.
		for _, h in pairs(self.held) do
			h.done = true
		end
		emit("weapon_mode", mode)
		-- Master-mode changes retain the pilot's display arrangement.
		-- Change the return search even during STT; the radar owner preserves lock.
		if mode == 2 then
			emit("bvr")
		end
	end
	function s:focus(soi)
		if self.soi ~= soi then
			self:cancel_ground_preview()
			-- A delayed press belongs to its original focus, never the new display.
			for name, h in pairs(self.held) do
				if sensor_actions[name] then
					h.done = true
				end
			end
		end
		self.soi = soi
	end
	function s:act(n, long, c)
		if n == "scs_depress" then
			local action = display.action(self.soi, display.page(c, self.soi), self.mode, c)
			if action then
				emit(action)
			end
			return
		end
		local acm = self.mode == 5 or self.mode == 3
		local hud_ag = self.soi == 1 and (self.mode == 7 and (n == "tdc" or n == "tms_up" or n == "tms_down")
			or self.mode == 1 and (n == "tdc" or n == "tms_down"))
		-- GUN/SRM acquisition patterns control the weapon's radar search, not a
		-- display page. A previous bezel/focus selection must not disable them.
		local weapon_acm = acm and (n == "tms_up" or n == "tms_down" or n == "tms_right")
		local radar_focus=display.is_radar(c,self.soi)
		if sensor_actions[n] and not radar_focus and not hud_ag and not weapon_acm then
			return
		end
		if n == "ag_gun" or n == "ag_ccip" or n == "ag_auto" or n == "ag_cycle" then
			if self.mode ~= 7 then
				self:set_mode(7)
			end
			emit(n)
		elseif n == "ag_waypoint" or n == "ag_mark" or n == "ag_clear" then
			emit(n)
		elseif n == "tdc" and (self.mode == 7 or self.mode == 1) and self.soi == 1 then
			emit("ag_mark")
		elseif n == "tdc" then
			emit("designate")
		elseif n == "tms_up" then
			if self.mode == 7 and self.soi == 1 then
				emit("ag_mark")
			elseif acm then
				emit("boresight")
			else
				emit("designate")
			end
		elseif n == "tms_down" then
			if self.mode == 7 or (self.mode == 1 and self.soi == 1) then
				emit(radar_focus and "undesignate"or "ag_clear")
			elseif acm then
				emit("vertical")
			else
				emit("undesignate")
			end
		elseif n == "tms_right" then
			if acm then
				emit("wide")
			elseif long then
				emit("toggle")
			else
				emit("next_track")
			end
		elseif n == "tms_left" then
			emit(long and "interrogate_los" or "interrogate")
		elseif n == "dms_up" then
			self:focus(1)
		elseif n == "dms_down" then
			self:focus(2)
		elseif n == "dms_left" then
			self:focus(3)
		elseif n == "dms_right" then
			self:focus(4)
		elseif n == "cms_up" then
			emit("defense_program", 1)
		elseif n == "cms_left" then
			emit("defense_program", 2)
		elseif n == "cms_push" then
			emit("defense_program", 3)
		elseif n == "cms_right" then
			emit("defense_consent", 0)
		elseif n == "cms_down" then
			emit("defense_consent", 1)
		elseif n == "expand" then
			emit("expand")
		elseif n == "coverage" then
			emit(long and "vertical_span" or "azimuth")
		elseif n == "missile_step" then
			if c.ground then
				emit("nws")
			elseif long then
				emit("station_step")
			else
				emit("undesignate")
			end
		elseif n == "paddle" then
			emit("autopilot_off")
		elseif n == "dogfight" then
			if self.dogfight then
				self.dogfight = false
				self:set_mode(self.saved)
			else
				self.saved = self.mode
				self.dogfight = true
				self:set_mode(5)
			end
		elseif n == "weapon_select" then
			if self.dogfight then
				self:set_mode(self.mode == 5 and 3 or 5)
			else
				self:set_mode(self.mode == 2 and 3 or self.mode == 3 and 5 or 2)
			end
		elseif n == "aa" then
			self.dogfight = false
			if self.mode == 2 or self.mode == 3 or self.mode == 5 then
				self:set_mode(1)
			else
				self:set_mode(self.last_aa)
			end
		elseif n == "ag" then
			self.dogfight = false
			self:set_mode(self.mode == 7 and 1 or 7)
		elseif n == "nav" then
			self.dogfight = false
			self:set_mode(1)
		elseif n == "gun" or n == "srm" or n == "mrm" then
			if n == "gun" and self.mode == 7 then
				emit("ag_gun")
				return
			end
			self.dogfight = false
			self:set_mode(({ gun = 5, srm = 3, mrm = 2 })[n])
		elseif n == "cage" then
			emit(self.mode == 1 and "nav_cage" or "cage")
		elseif n == "arm" then
			emit("arm")
		elseif n == "radar_power" then
			emit("power")
		elseif n == "range_up" or n == "range_down" then
			emit(n)
		end
	end
	local delayed = { tms_right = true, tms_left = true, coverage = true, missile_step = true }
	function s:input(n, v, c)
		local held = self.held[n]
		if (n=="tdc" or n=="scs_depress" or n=="dms_down") and
			((held and held.ground_action) or (v>0 and self.mode==7 and display.is_radar(c,self.soi))) then
			if v>0 then
				if held then return end
				local action=n=="tdc" and "ground_tdc" or "ground_acquire"
				self.held[n]={ground_action=action,done=false};emit(action,1)
			else
				self.held[n]=nil
				if held and not held.done then emit(held.ground_action,0) end
			end
			return
		end
		if n == "trigger_first" or n == "trigger_second" or n == "pickle" then
			emit(n, v > 0 and 1 or 0)
			return
		end
		if v > 0 then
			if self.held[n] then
				return
			end
			self.held[n] = { start = self.clock, done = false, context = c }
			self.held[n].delayed = delayed[n] and not (n == "tms_right" and (self.mode == 5 or self.mode == 3))
			if not self.held[n].delayed then
				self:act(n, false, c)
			end
		else
			local h = self.held[n]
			self.held[n] = nil
			if h and h.delayed and not h.done then
				self:act(n, false, c)
			end
		end
	end
	function s:update(dt, c)
		self.clock = self.clock + dt
		if self.mode~=7 or not display.is_radar(c,self.soi)then self:cancel_ground_preview()end

		for n, h in pairs(self.held) do
			local threshold = n == "tms_right" and 1 or 0.5
			if h.delayed and not h.done and self.clock - h.start >= threshold then
				h.done = true
				self:act(n, true, c)
			end
		end
	end
	return s
end
return M
