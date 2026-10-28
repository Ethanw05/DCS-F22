-- GPL-3.0-or-later. Native-return surface map and pilot designation, no unit search.
-- Shared display/selection geometry and declared common-backend policies.
-- These are not recovered APG-77 performance specifications.
local Modes=dofile(LockOn_Options.script_path .. "Systems/AG_Radar_Modes.lua")
local M = { cursor_half_width = .025, cursor_half_height = .025,
    image_seconds = 8, snapshot_seconds = .5, scan_azimuth_limit = math.rad(60), renderer_clearance_m = 30 }
local function finite(v)
	return type(v) == "number" and v == v and math.abs(v) < 1e8
end
local function clamp(v, a, b)
	return math.max(a, math.min(b, v))
end
M.finite = finite
function M.video_pose(pose)
	if not pose then return end
	-- The core terrain/shadow renderer includes our opaque aircraft mesh.
	-- Moving-flight A/B/A remained blocked at12m and recovered at30m.
	-- Earlier active-pause-only clearance measurements were insufficient.
	-- This is a renderer clearance, not an APG-77 antenna/performance claim.
	local pitch=pose.pitch or 0
	local horizontal=M.renderer_clearance_m*math.cos(pitch)
	return {north=pose.north+horizontal*math.cos(pose.heading),east=pose.east+horizontal*math.sin(pose.heading),
		altitude=pose.altitude+M.renderer_clearance_m*math.sin(pitch),heading=pose.heading,
		pitch=pitch,roll=pose.roll or 0,time=pose.time}
end
function M.fresh(now, stamp, lifetime)
	return finite(now) and finite(stamp) and now - stamp >= -.05 and now - stamp <= lifetime
end
function M.new()
	return setmetatable({
		range_nm = 20,
		width = 90,
		cursor_az = 0,
		cursor_fraction = 0.5,
		slew_x = 0,
		slew_y = 0,
		returns = {},
		sequence = 0,
		clock = -1,
		candidate = nil,
		mode = 1, movers = {},
	}, { __index = M })
end
function M:point(pose, terrain)
	if self.exp_view and terrain then return Modes.point(self.exp_view,self.exp_x or 0,self.exp_y or 0,terrain)end
	if not pose or not terrain or type(terrain.GetHeight) ~= "function" then
		return nil
	end
	local r = self.range_nm * 1852 * self.cursor_fraction
	local heading = pose.heading + self.cursor_az
	local n, e = pose.north + r * math.cos(heading), pose.east + r * math.sin(heading)
	local ok, u = pcall(terrain.GetHeight, n, e)
	if not ok or not finite(u) then
		return nil
	end
	return { north = n, altitude = u, east = e }
end
function M:project(p, pose)
	if self.exp_view then return Modes.project(p,self.exp_view)end
	local n, e = p.north - pose.north, p.east - pose.east
	local f = n * math.cos(pose.heading) + e * math.sin(pose.heading)
	local r = -n * math.sin(pose.heading) + e * math.cos(pose.heading)
	return r / (self.range_nm * 1852) * 1.65, -0.76 + f / (self.range_nm * 1852) * 1.52
end
function M:observe(raw, pose, terrain, now)
	if now < self.clock then
		self.returns = {}
		self.candidate = nil
	end
	self.clock = now
	local bins = {}
	for _, p in ipairs(raw) do
		if
			finite(p.north)
			and finite(p.east)
			and finite(p.altitude)
			and finite(p.stamp)
			and finite(p.rcs)
			and p.rcs > 0
			and M.fresh(now, p.stamp, M.image_seconds)
			and terrain
			and type(terrain.GetHeight) == "function"
		then
			-- NOISE tags both native terrain and jammer records. Require a
			-- native world point on the actual surface, never infer from IFF.
			local ok, u = pcall(terrain.GetHeight, p.north, p.east)
			if ok and finite(u) and math.abs(p.altitude - u) <= 2 then
				local x, y = self:project(p, pose)
				if math.abs(x) < 0.83 and y > -0.76 and y < 0.76 then
					local key = math.floor((x + 0.83) * 36) .. ":" .. math.floor((y + 0.76) * 24)
					local prior = bins[key]
					if not prior or prior.stamp < p.stamp then
						p.x, p.y = x, y
						bins[key] = p
					end
				end
			end
		end
	end
	self.returns = {}
	for _, p in pairs(bins) do
		self.returns[#self.returns + 1] = p
	end
	table.sort(self.returns, function(a, b)
		if a.stamp ~= b.stamp then
			return a.stamp > b.stamp
		end
		if a.north ~= b.north then
			return a.north < b.north
		end
		return a.east < b.east
	end)
	self:select(pose, terrain, now)
end
function M:select(pose, terrain, now)
	local cursor = self:point(pose, terrain)
	self.candidate = nil
	if cursor then
		local cx, cy = self:project(cursor, pose)
		local best = math.huge
		for _, p in ipairs(self.returns) do
			local x, y = self:project(p, pose)
			local dx, dy = (x - cx) / M.cursor_half_width, (y - cy) / M.cursor_half_height
			local d = dx * dx + dy * dy
			-- A surface-map pixel represents stationary terrain, not a moving
			-- target track. Its hit test uses the drawn cursor's exact footprint.
			if math.abs(dx) <= 1 + 1e-9 and math.abs(dy) <= 1 + 1e-9 and d < best and M.fresh(now, p.stamp, M.image_seconds) then
				best = d
				self.candidate = p
			end
		end
	end
	return self.candidate
end
function M:scan_plan(azimuth)
	local limit = M.scan_azimuth_limit
	local half = math.min(limit, math.rad(self.width) / 2)
	local center = clamp(azimuth, -limit + half, limit - half)
	return { az = center, half_az = half,
		limited = math.abs(center - azimuth) > 1e-9,
		cursor_covered = math.abs(azimuth - center) <= half + 1e-9 }
end
function M:slew(dt)
	if self.exp_view then
	 self.exp_x=clamp((self.exp_x or 0)+self.slew_x*dt*.5,-.8,.8)
	 self.exp_y=clamp((self.exp_y or 0)+self.slew_y*dt*.5,-.73,.73)
	 return
	end
	self.cursor_az = clamp(self.cursor_az + self.slew_x * dt * 0.45, -math.rad(55), math.rad(55))
	self.cursor_fraction = clamp(self.cursor_fraction + self.slew_y * dt * 0.3, 0.05, 0.95)
	local limit = math.asin(math.min(1, 0.80 / (1.65 * self.cursor_fraction)))
	self.cursor_az = clamp(self.cursor_az, -limit, limit)
end
function M:observe_movers(raw, pose, now)
	self.movers = {}
	for _,p in ipairs(raw) do
		if finite(p.id) and p.id>0 and finite(p.north) and finite(p.altitude) and finite(p.east)
			and finite(p.vn) and finite(p.vu) and finite(p.ve) and M.fresh(now,p.stamp,6) then
			p.age=math.max(0,now-p.stamp)
			p.display={north=p.north,east=p.east,altitude=p.altitude}
			-- Register the measured coordinate to the displayed image's pose.
			-- Keep its observation time and position; search history is not a
			-- new measurement or an extrapolated moving-target track.
			p.x,p.y=self:project(p.display,pose)
			p.speed=math.sqrt(p.vn*p.vn+p.ve*p.ve)*1.943844492440605
			p.heading=math.atan2(p.ve,p.vn)
			if not p.out_of_range and math.abs(p.x)<.825 and p.y>-.76 and p.y<.76 then self.movers[#self.movers+1]=p end
		end
	end
	return self:mover_under_cursor(pose,now)
end
function M:mover_under_cursor(pose,now)
	local p=self:point(pose,{GetHeight=function()return 0 end})
	if not p then return end
	local cx,cy=self:project(p,pose)
	local best,chosen=math.huge,nil
	for _,r in ipairs(self.movers) do
		local dx,dy=(r.x-cx)/.055,(r.y-cy)/.045
		local d=dx*dx+dy*dy
		if math.abs(dx)<=1 and math.abs(dy)<=1 and d<best and M.fresh(now,r.stamp,6) then best,chosen=d,r end
	end
	return chosen
end
return M
