-- GPL-3.0-or-later. Navigation/map composition and explicitly unranged cues.
local Layout = dofile(LockOn_Options.script_path .. "Systems/Radar_Display.lua")
local Clip = dofile(LockOn_Options.script_path .. "Systems/Radar_Launch_Zone.lua").clip
local Frames = dofile(LockOn_Options.script_path .. "Systems/Gun_Frames.lua")
local Bearings = dofile(LockOn_Options.script_path .. "Systems/RWR_Bearings.lua")
local Threat = dofile(LockOn_Options.script_path .. "Systems/Tactical_Threat.lua")
local Declutter = dofile(LockOn_Options.script_path .. "Systems/Tactical_Declutter.lua")
local Geolocation = dofile(LockOn_Options.script_path .. "Systems/EW_Geolocation.lua")
local Datalink = dofile(LockOn_Options.script_path .. "Systems/Datalink_Tracks.lua")
local M = {}
local Identity=dofile(LockOn_Options.script_path..'Systems/Tactical_Identity.lua')
local function finite(x)
	return type(x) == "number" and x == x and math.abs(x) < 1e9
end
local function inside(x, y)
	return finite(x) and finite(y) and math.abs(x) < 0.94 and y > -0.91 and y < 0.97
end
function M.new(get, put, sensors)
	local s = { nav = false, passive = true }
	function s:reset()
		self.nav = false
		self.passive = true
	end
	function s:command(c)
		if c == 10915 then
			self.nav = not self.nav
		elseif c == 10916 then
			self.passive = not self.passive
		end
	end
	function s:update(now, tracks, power)
		local frame = Bearings.frame(sensors)
		local heading = frame and -sensors.getHeading() or 0
		local range = get("F22_RADAR_RANGE_NM")
		local enabled = power
			and frame
			and finite(range)
			and range >= 1
			and range <= 320
			and get("F22_AG_RADAR_PAGE") < 0.5
		local stamp = get("F22_NAV_STEER_STAMP")
		local nav = enabled
			and self.nav
			and get("F22_NAV_SOURCE") == 0
			and get("F22_NAV_VALID") > 0.5
			and get("F22_NAV_OWN_VALID") > 0.5
			and get("F22_NAV_STEER_VALID") > 0.5
			and finite(stamp)
			and now - stamp >= -0.05
			and now - stamp <= 0.5
		local factor = Layout.radius / (range * 1852)
		local nav_scale = get("F22_NAV_SCALE_NM")
		local nav_heading = get("F22_NAV_COMPASS_ROT")
		if get("F22_NAV_REFERENCE") > 0.5 and get("F22_MAG_VALID") > 0.5 then
			nav_heading = nav_heading + get("F22_MAG_DECL")
		end
		nav = nav and finite(nav_scale) and nav_scale >= 1 and nav_scale <= 320 and finite(nav_heading)
		local delta = nav_heading - heading
		local function map(x, y)
			if not finite(x) or not finite(y) then
				return
			end
			local f = nav_scale * 1852 / 0.56 * factor
			return (x * math.cos(delta) + y * math.sin(delta)) * f,
				Layout.origin_y + (y * math.cos(delta) - x * math.sin(delta)) * f
		end
		for i = 1, 32 do
			local p = string.format("F22_TSD_NAV_LEG_%02d_", i)
			local origin = string.format("F22_NAV_LEG_%02d_", i)
			local segment
			if nav and get(origin .. "VALID") > 0.5 then
				local x1, y1 = map(get(origin .. "X1"), get(origin .. "Y1"))
				local x2, y2 = map(get(origin .. "X2"), get(origin .. "Y2"))
				if x1 and x2 then
					segment = Clip(x1, y1, x2, y2)
				end
			end
			for j, k in ipairs({ "X1", "Y1", "X2", "Y2" }) do
				put(p .. k, segment and segment[j] or 0)
			end
			put(p .. "ACTIVE", nav and get(origin .. "ACTIVE") > 0.5 and 1 or 0)
			put(p .. "VALID", segment and 1 or 0)
		end
		local x, y, id = 0, 0, 0
		if nav then
			local n = get("F22_NAV_TARGET_N") - get("F22_NAV_OWN_N")
			local e = get("F22_NAV_TARGET_E") - get("F22_NAV_OWN_E")
			if finite(n) and finite(e) then
				x = (-n * math.sin(heading) + e * math.cos(heading)) * factor
				y = Layout.origin_y + (n * math.cos(heading) + e * math.sin(heading)) * factor
				id = get("HUD_WP_INDEX")
			end
		end
		put("F22_TSD_NAV_X", x)
		put("F22_TSD_NAV_Y", y)
		put("F22_TSD_NAV_ID", id)
		put("F22_TSD_NAV_VALID", nav and inside(x, y) and 1 or 0)
		put("F22_TSD_NAV_LAYER", self.nav and 1 or 0)
		put("F22_TSD_PASSIVE_LAYER", self.passive and 1 or 0)
		local radar_on_map = {}
		for i = 1, 24 do
			local p = string.format("F22_SCOPE_%02d_", i)
			if get(p .. "VALID") > 0.5 and get(p .. "COAST") < 0.5 then
				radar_on_map[get(p .. "SOURCE")] = true
			end
		end
        local on_map = {}
        -- Scope IDs are radar track numbers; picture IDs belong to fusion.
        for _,track in ipairs(tracks) do
            local radar=track.observations and track.observations.radar
            if radar and radar_on_map[radar.source] then on_map[track.source]=true end
        end
		local passive = {}
		local estimates,located={},{}
		local own=enabled and Geolocation.position(sensors)
		local offboard = {}
		if enabled and own then
			for _, t in ipairs(tracks) do
				local q = Datalink.position(t.datalink, now)
				if q and not on_map[t.source] then
					local n,e = q.n-own.n,q.e-own.e
					local x = (-n*math.sin(heading)+e*math.cos(heading))*factor
					local y = Layout.origin_y+(n*math.cos(heading)+e*math.sin(heading))*factor
					local dx,dy=x,y-Layout.origin_y
					local scale=1
					if math.abs(dx)>.85 then scale=math.min(scale,.85/math.abs(dx))end
					if dy>0 and y>.88 then scale=math.min(scale,(.88-Layout.origin_y)/dy)
					elseif dy<0 and y<-.86 then scale=math.min(scale,(-.86-Layout.origin_y)/dy)end
					offboard[#offboard+1] = {x=dx*scale,y=Layout.origin_y+dy*scale,source=t.source,age=q.age,coast=q.coast,
						offscale=scale<1,rot=-math.atan2(dx,dy),
						link=t.datalink.link,reporter=t.datalink.reporter,affiliation=Identity.normalize(t.affiliation)}
				end
			end
		end
		for i=1,24 do
			local q=offboard[i];local p=string.format('F22_TSD_DL_%02d_',i)
			put(p..'X',q and q.x or 0);put(p..'Y',q and q.y or 0)
			put(p..'SOURCE',q and q.source or 0);put(p..'AGE',q and q.age or 999)
			put(p..'LINK',q and q.link or 0);put(p..'REPORTER',q and q.reporter or 0)
			put(p..'AFFILIATION',q and q.affiliation or -1)
			put(p..'COAST',q and q.coast and 1 or 0);put(p..'VALID',q and 1 or 0)
			put(p..'OFFSCALE',q and q.offscale and 1 or 0);put(p..'ROT',q and q.rot or 0)
            put(p..'SA_SELECTED',q and q.source==get('F22_DONOR_SOURCE')and 1 or 0)
		end
		put('F22_TSD_DL_COUNT',math.min(24,#offboard))
		put('F22_TSD_DL_OVERFLOW',math.max(0,#offboard-24))
		if enabled and self.passive and own then
			for _,t in ipairs(tracks)do
				local geo=not on_map[t.source] and Geolocation.relative(t.geolocation,now,own)
				if geo then
					local n,e=geo.n-own.n,geo.e-own.e
					local gx=(-n*math.sin(heading)+e*math.cos(heading))*factor
					local gy=Layout.origin_y+(n*math.cos(heading)+e*math.sin(heading))*factor
					if inside(gx,gy)then
						estimates[#estimates+1]={x=gx,y=gy,radius=geo.radius*factor,source=t.source,age=geo.age,affiliation=Identity.normalize(t.affiliation)}
						if #estimates<=8 then located[t.source]=true end
					end
				end
			end
		end
		for i=1,8 do
			local q=estimates[i];local p=string.format('F22_TSD_GEO_%02d_',i)
			put(p..'X',q and q.x or 0);put(p..'Y',q and q.y or 0)
			put(p..'SOURCE',q and q.source or 0);put(p..'AGE',q and q.age or 999)
			put(p..'AFFILIATION',q and q.affiliation or -1)
			for _,axis in ipairs({'H','V'})do
				local line
				if q then
					if axis=='H'then line=Clip(q.x-q.radius,q.y,q.x+q.radius,q.y)
					else line=Clip(q.x,q.y-q.radius,q.x,q.y+q.radius)end
				end
				for j,k in ipairs({'X1','Y1','X2','Y2'})do put(p..axis..'_'..k,line and line[j]or 0)end
				put(p..axis..'_VALID',line and 1 or 0)
			end
			put(p..'VALID',q and 1 or 0)
		end
		put('F22_TSD_GEO_COUNT',math.min(8,#estimates))
		put('F22_TSD_GEO_OVERFLOW',math.max(0,#estimates-8))
		local selected
		for _, t in ipairs(tracks) do
			if t.selected then
				selected = t
			end
			if enabled and self.passive and not on_map[t.source] and not located[t.source] and (t.signal > 0 or t.optical) then
				local o, sensor = Threat.direction(t, now)
				if o then
					local ce = math.cos(o.el)
					local world = Frames.world(frame, { ce * math.cos(o.az), math.sin(o.el), ce * math.sin(o.az) })
					local right = -world[1] * math.sin(heading) + world[3] * math.cos(heading)
					local forward = world[1] * math.cos(heading) + world[3] * math.sin(heading)
					local horizontal = math.sqrt(right * right + forward * forward)
					if horizontal >= 1e-6 then
						passive[#passive + 1] = {
							source = t.source,
							angle = math.atan2(right, forward),
							x = 0.20 * right / horizontal,
							y = Layout.origin_y + 0.20 * forward / horizontal,
							age = Threat.age(o, now),
							coast = Threat.coast(o, sensor, t.signal, now),
							optical = sensor == "mws",
							affiliation = Identity.normalize(t.affiliation),
							priority = Threat.priority(t, now),
						}
					end
				end
			end
		end
		table.sort(passive, function(a, b)
			if a.priority ~= b.priority then
				return a.priority > b.priority
			end
			return a.source < b.source
		end)
		local clusters, omitted = Declutter.group(passive)
		for i = 1, 8 do
			local cluster = clusters[i]
			local c = cluster and cluster.representative
			local p = string.format("F22_TSD_BEARING_%02d_", i)
			put(p .. "X", c and c.x or 0)
			put(p .. "Y", c and c.y or 0)
			put(p .. "AGE", c and c.age or 999)
			put(p .. "SOURCE", c and c.source or 0)
			put(p .. "OPTICAL", c and c.optical and 1 or 0)
			put(p .. "COAST", c and c.coast and 1 or 0)
			put(p .. "AFFILIATION", c and c.affiliation or -1)
			put(p .. "COUNT", cluster and cluster.count or 0)
			put(p .. "EXTRA_COUNT", cluster and cluster.count - 1 or 0)
			put(p .. "VALID", c and 1 or 0)
		end
		put("F22_TSD_BEARING_TOTAL", #passive)
		put("F22_TSD_BEARING_SHOWN", math.min(8, #clusters))
		put("F22_TSD_BEARING_OMITTED", omitted)
		for _, v in ipairs({ { "RADAR", "radar" }, { "RF", "rf" }, { "OPTICAL", "mws" } }) do
			put("F22_TSD_SELECTED_" .. v[1], enabled and selected and selected.observations[v[2]] and 1 or 0)
		end
		put("F22_TSD_VALID", enabled and 1 or 0)
	end
	return s
end
return M
