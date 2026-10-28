-- GPL-3.0-or-later. Sole ground-designation owner: radar, HUD LOS or steerpoint.
dofile(LockOn_Options.script_path .. "devices.lua")
local decode = dofile(LockOn_Options.script_path .. "Systems/Input_Value.lua")
local geom = dofile(LockOn_Options.script_path .. "Systems/NavGeometry.lua")
local projection = dofile(LockOn_Options.script_path .. "Systems/HUD_Projection.lua")
local edge_projection = dofile(LockOn_Options.script_path .. "Systems/HUD_TargetMath.lua").new(
    dofile(LockOn_Options.script_path .. "HUD/glass.lua"))
local base = get_base_data()
local dev = GetSelf()
make_default_activity(0.05)
local handles = {}
local function h(n)
	if not handles[n] then
		handles[n] = get_param_handle(n)
	end
	return handles[n]
end
local function get(n)
	return h(n):get()
end
local function put(n, v)
	h(n):set(v)
end
-- Complete invalid ground-marker render snapshot before the HUD binds.
for _,name in ipairs({"HUD_AG_TGT_X_SLOPE","HUD_AG_TGT_Y_SLOPE",
    "HUD_AG_TARGET_VALID","HUD_AG_CUE_VALID","HUD_AG_EDGE_VALID","HUD_AG_EDGE_FLASH",
    "HUD_AG_EDGE_X","HUD_AG_EDGE_Y"}) do put(name,0) end
local function finite(v)
	return type(v) == "number" and v == v and math.abs(v) < 1e7
end
local terrain, target, mark_sequence, radar_sequence, request, sequence = nil, nil, 0, 0, nil, 0
local waypoint_request
-- A NAV designation captures the selected coordinates on the command edge.
-- Display publications can still describe the previous waypoint for one tick.
for _, name in ipairs({"F22_NAV_TARGET_REQUEST_SEQUENCE", "F22_NAV_TARGET_REQUEST_VALID",
    "F22_NAV_TARGET_REQUEST_N", "F22_NAV_TARGET_REQUEST_E", "F22_NAV_TARGET_ACK_SEQUENCE",
    "F22_NAV_TARGET_RESULT", "F22_NAV_TARGET_ACK_TARGET_SEQUENCE"}) do h(name) end
local function acknowledge_waypoint(r, result)
	if not r or not r.sequence then return end
	put("F22_NAV_TARGET_RESULT", result)
	put("F22_NAV_TARGET_ACK_TARGET_SEQUENCE", result == 1 and sequence or 0)
	put("F22_NAV_TARGET_ACK_SEQUENCE", r.sequence)
end
local held = {}
for _, c in ipairs({ 10810, 10811, 10812, 10843 }) do
	dev:listen_command(c)
end
local function height(n, e)
	if not terrain then
		return
	end
	local ok, v = pcall(terrain.GetHeight, n, e)
	if ok and finite(v) then
		return v
	end
end
local function clear()
	target = nil
	sequence = sequence + 1
	put("F22_AG_TARGET_SEQUENCE", sequence)
	put("HUD_AG_TARGET_VALID", 0)
	put("HUD_AG_CUE_VALID", 0)
	put("HUD_AG_EDGE_VALID", 0)
	put("HUD_AG_TGT_RANGE_NM", 0)
end
local function assign(n, u, e, source)
	if not finite(n) or not finite(u) or not finite(e) then
		return
	end
	target = { n = n, u = u, e = e, source = source }
	sequence = sequence + 1
	put("F22_AG_TARGET_SOURCE", source)
	put("F22_AG_TARGET_SEQUENCE", sequence)
end
local function designate_los()
	local n, u, e = base.getSelfCoordinates()
	local heading = -base.getHeading()
	local pitch = base.getPitch()
	if not finite(n) or not finite(u) or not finite(e) then
		return
	end
	local dn, de, du = math.cos(heading) * math.cos(pitch), math.sin(heading) * math.cos(pitch), math.sin(pitch)
	local previous = 0
	for r = 100, 80000, 100 do
		local floor = height(n + dn * r, e + de * r)
		if not floor then
			return
		end
		if u + du * r <= floor then
			local lo, hi = previous, r
			for _ = 1, 14 do
				local m = (lo + hi) / 2
				local z = height(n + dn * m, e + de * m)
				if not z then
					return
				end
				if u + du * m > z then
					lo = m
				else
					hi = m
				end
			end
			local d = (lo + hi) / 2
			assign(n + dn * d, height(n + dn * d, e + de * d), e + de * d, 1)
			return
		end
		previous = r
	end
end
function post_initialize()
	local ok, t = pcall(require, "terrain")
	if ok and type(t) == "table" and type(t.GetHeight) == "function" then
		terrain = t
	end
	held = {}
	request = nil
	waypoint_request = nil
	put("F22_NAV_TARGET_ACK_SEQUENCE", 0)
	put("F22_NAV_TARGET_RESULT", 0)
	put("F22_NAV_TARGET_ACK_TARGET_SEQUENCE", 0)
	clear()
	mark_sequence = get("HUD_AG_MARK_SEQUENCE")
	radar_sequence = get("F22_AG_DESIGNATION_SEQUENCE")
end
function SetCommand(c, v)
	if c ~= 10843 and (c < 10810 or c > 10812) then
		return
	end
	local down = decode(v, devices.AG_MARK_SYSTEM) > 0.5
	local old = held[c]
	held[c] = down
	if down and not old and c == 10843 then
		local id = get("F22_NAV_TARGET_REQUEST_SEQUENCE")
		waypoint_request = id > 0 and {sequence=id,
			n=get("F22_NAV_TARGET_REQUEST_N"), e=get("F22_NAV_TARGET_REQUEST_E")} or nil
		if get("MAIN_POWER") <= .5 then acknowledge_waypoint(waypoint_request, 4) end
	end
	if down and not old and get("MAIN_POWER") > 0.5
        and (get("HUD_MODE") == 7 or get("HUD_MODE") == 1 or c == 10812 or c == 10843 or (c == 10811 and target)) then
		request = c
	end
end
function update()
	local marks = get("HUD_AG_MARK_SEQUENCE")
	local radar = get("F22_AG_DESIGNATION_SEQUENCE")
	if get("MAIN_POWER") < 0.5 then
		clear()
		acknowledge_waypoint(waypoint_request, 4)
		waypoint_request = nil
		request = nil
		mark_sequence = marks
		radar_sequence = radar
		return
	end
	if get("HUD_MODE") == 7 and radar ~= radar_sequence then
		radar_sequence = radar
		if get("F22_AG_DESIGNATION_VALID") > 0.5 then
			assign(
				get("F22_AG_DESIGNATION_NORTH"),
				get("F22_AG_DESIGNATION_ALTITUDE"),
				get("F22_AG_DESIGNATION_EAST"),
				2
			)
		else
			clear()
		end
	end
	if get("HUD_MODE") == 7 and marks ~= mark_sequence then
		mark_sequence = marks
		request = target and 10811 or 10810
	end
	if request == 10810 then
		designate_los()
	elseif request == 10811 then
		clear()
	elseif request == 10843 then
		local r = waypoint_request
		if r then
			if get("F22_NAV_TARGET_REQUEST_VALID") <= .5 or
				get("F22_NAV_TARGET_REQUEST_SEQUENCE") ~= r.sequence then
				acknowledge_waypoint(r, 5) -- superseded/cancelled request
			elseif not finite(r.n) or not finite(r.e) then
				acknowledge_waypoint(r, 2)
			else
				local u = height(r.n, r.e)
				if u then assign(r.n, u, r.e, 3);acknowledge_waypoint(r, 1)
				else acknowledge_waypoint(r, 3) end
			end
		end
	elseif request == 10812 and get("F22_NAV_VALID") > .5 then
		-- Direct legacy waypoint-mark commands retain their original channel.
		local n, e = get("F22_NAV_TARGET_N"), get("F22_NAV_TARGET_E")
		local u = finite(n) and finite(e) and height(n, e)
		if u then assign(n, u, e, 3) end
	end
	request = nil
	waypoint_request = nil
	if not target then
		put("HUD_AG_TARGET_VALID", 0)
		put("HUD_AG_CUE_VALID", 0)
		put("HUD_AG_EDGE_VALID", 0)
		return
	end
	local n, u, e = base.getSelfCoordinates()
	if not finite(n) or not finite(u) or not finite(e) then
		clear()
		return
	end
	local az, el, r =
		geom.project(target.n - n, target.e - e, target.u - u, -base.getHeading(), base.getPitch(), base.getRoll())
	if not r or r < 1 then
		put("HUD_AG_TARGET_VALID", 0)
		put("HUD_AG_CUE_VALID", 0)
		put("HUD_AG_EDGE_VALID", 0)
		return
	end
	put("HUD_AG_MARK_NORTH", target.n)
	put("HUD_AG_MARK_ALT", target.u)
	put("HUD_AG_MARK_EAST", target.e)
	put("HUD_AG_TGT_RANGE_NM", r / 1852)
	put("HUD_AG_TGT_AZ_RAD", az or 0)
	put("HUD_AG_TGT_EL_RAD", el or 0)
    local x,y=projection.planar(az,el)
    put("HUD_AG_TGT_X_SLOPE",x or 0);put("HUD_AG_TGT_Y_SLOPE",y or 0)
	put("HUD_AG_TARGET_VALID", 1)
	local forward,right,up=geom.body(target.n-n,target.e-e,target.u-u,-base.getHeading(),base.getPitch(),base.getRoll())
	if not forward then put("HUD_AG_CUE_VALID",0);put("HUD_AG_EDGE_VALID",0);return end
	local cue=edge_projection(math.atan2(right,forward),math.atan2(up,math.sqrt(forward*forward+right*right)))
	put("HUD_AG_CUE_VALID",az and el and cue.visible and 1 or 0)
	put("HUD_AG_EDGE_X",cue.arrow_x);put("HUD_AG_EDGE_Y",cue.arrow_y)
	local now=type(get_model_time)=="function" and get_model_time() or nil
	put("HUD_AG_EDGE_FLASH",finite(now) and now%0.5<0.25 and 1 or 0)
	put("HUD_AG_EDGE_VALID",not cue.visible and finite(now) and 1 or 0)
end
need_to_be_closed = false
