-- GPL-3.0-or-later. Sole ground-designation owner: radar, HUD LOS or steerpoint.
dofile(LockOn_Options.script_path .. "devices.lua")
local decode = dofile(LockOn_Options.script_path .. "Systems/Input_Value.lua")
local geom = dofile(LockOn_Options.script_path .. "Systems/NavGeometry.lua")
local projection = dofile(LockOn_Options.script_path .. "Systems/HUD_Projection.lua")
local edge_projection = dofile(LockOn_Options.script_path .. "Systems/HUD_Designation_Projection.lua").new(
    dofile(LockOn_Options.script_path .. "HUD/glass.lua"),
    dofile(LockOn_Options.script_path .. "HUD/geometry.lua"))
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
    "HUD_AG_TARGET_VALID","HUD_AG_CUE_VALID","HUD_AG_EDGE_VALID",
    "HUD_AG_EDGE_X","HUD_AG_EDGE_Y"}) do put(name,0) end
local function finite(v)
	return type(v) == "number" and v == v and math.abs(v) < 1e7
end
local evidence=dofile(LockOn_Options.script_path.."Systems/AG_Target_Provenance.lua")
local target_snapshot=dofile(LockOn_Options.script_path.."Systems/AG_Target_Snapshot.lua")
local terrain, target, mark_sequence, radar_sequence, request, sequence = nil, nil, 0, nil, nil, 0
local radar_epoch,packet_sequence,packet_epoch,last_clock=nil,0,1,nil
local empty_target={n=0,u=0,e=0,source=0}
local function model_clock()
 local ok,now=pcall(get_model_time)
 if ok and type(now)=="number" and now==now and now>=0 and now<1e9 then return now end
end
local function begin_packet()
 packet_sequence=packet_sequence>=16777212 and 2 or packet_sequence+2
 put("F22_AG_TARGET_PACKET_SEQUENCE",packet_sequence-1)
 put("HUD_AG_TARGET_VALID",0);put("HUD_AG_CUE_VALID",0);put("HUD_AG_EDGE_VALID",0)
end
local function finish_packet(now,healthy)
 local p=target or empty_target
 if not healthy then put("HUD_AG_TARGET_VALID",0)end
 put("F22_AG_TARGET_SOURCE",p.source)
 put("F22_AG_TARGET_SEQUENCE",sequence)
 put("HUD_AG_MARK_NORTH",p.n)
 put("HUD_AG_MARK_ALT",p.u)
 put("HUD_AG_MARK_EAST",p.e)
 target_snapshot.publish_metadata(put,"F22_AG_TARGET_",target)
 put("F22_AG_TARGET_PACKET_SCHEMA",1)
 put("F22_AG_TARGET_PACKET_EPOCH",packet_epoch)
 put("F22_AG_TARGET_PACKET_TIME",now or -100)
 put("F22_AG_TARGET_PACKET_SEQUENCE",packet_sequence)
end
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
	sequence = sequence>=16777215 and 1 or sequence+1
	put("F22_AG_TARGET_SEQUENCE", sequence)
	put("HUD_AG_TARGET_VALID", 0)
	put("HUD_AG_CUE_VALID", 0)
	put("HUD_AG_EDGE_VALID", 0)
	put("HUD_AG_TGT_RANGE_NM", 0)
end
local function assign(n, u, e, source, origin)
	if not finite(n) or not finite(u) or not finite(e) then
		return
	end
	target = { n=n,u=u,e=e,source=source,time=-100,epoch=0,request=0,kind=0,live=false,
        observation_known=false,observation_sequence=0 }
    if source==2 then
        if not origin then target=nil;return end
        target.time,target.epoch,target.request=origin.time,origin.epoch,origin.request
        target.kind,target.live=origin.kind,origin.live
        target.observation_known,target.observation_sequence=true,origin.sequence
    end
	sequence = sequence>=16777215 and 1 or sequence+1
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
 begin_packet()
 local previous=get("F22_AG_TARGET_PACKET_EPOCH")
 packet_epoch=type(previous)=="number" and previous==previous and previous>=0
  and previous<16777215 and previous%1==0 and previous+1 or 1
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
	local now=model_clock()
 local packet=evidence.read(get,now)
 radar_sequence,radar_epoch=packet and packet.sequence,packet and packet.epoch
 last_clock=now
 finish_packet(now,true)
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
local function receive_radar(radar)
    if not radar then return end
    if radar.sequence == radar_sequence and radar.epoch == radar_epoch then return end
    radar_sequence, radar_epoch = radar.sequence, radar.epoch
    -- Ground-format selection does not require changing the HUD master mode.
    if radar.valid then assign(radar.n, radar.u, radar.e, 2, radar)
    elseif target and target.source == 2 then clear() end
end
local function update_body(now)
	local marks = get("HUD_AG_MARK_SEQUENCE")
	local radar = evidence.read(get,now)
	if get("MAIN_POWER") < 0.5 then
		clear()
		acknowledge_waypoint(waypoint_request, 4)
		waypoint_request = nil
		request = nil
		mark_sequence = marks
		if radar then radar_sequence,radar_epoch=radar.sequence,radar.epoch end
		return
	end
    receive_radar(radar)
    if target and target.source==2 and not evidence.current(target,get,now) then clear()end
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
	if not cue then put("HUD_AG_CUE_VALID",0);put("HUD_AG_EDGE_VALID",0);return end
	put("HUD_AG_CUE_VALID",az and el and cue.visible and 1 or 0)
	put("HUD_AG_EDGE_X",cue.arrow_x);put("HUD_AG_EDGE_Y",cue.arrow_y)
	put("HUD_AG_EDGE_VALID",not cue.visible and finite(now) and 1 or 0)
end
function update()
 begin_packet()
 local now=model_clock()
 if now and last_clock and now<last_clock then
  packet_epoch=packet_epoch>=16777215 and 1 or packet_epoch+1
  clear();request=nil;waypoint_request=nil
  -- Keep the seen radar packet: rewind cannot replay an old designation.
 end
 local healthy=now~=nil
 if healthy then
  local ok,message=pcall(update_body,now)
  healthy=ok
  if not ok and log and log.write then log.write("F22_AG_TARGET",log.ERROR or log.INFO,tostring(message))end
 end
 if not healthy then clear();request=nil;waypoint_request=nil end
 last_clock=now
 finish_packet(now,healthy)
end
need_to_be_closed = false
