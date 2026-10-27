-- GPL-3.0-or-later. Native selected-store bomb ballistics and shell/terrain CCIP.
local base = get_base_data()
local dt = 0.05
make_default_activity(dt)
local geom = dofile(LockOn_Options.script_path .. "Systems/NavGeometry.lua")
local delivery = dofile(LockOn_Options.script_path .. "Systems/AG_Delivery.lua")
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
local function finite(v)
	return type(v) == "number" and v == v and math.abs(v) < 1e8
end
local last_motion,next_telemetry=nil,0
local pending,last_activity,last_bay=nil,nil,nil
local last_station, last_type3
local terrain, sequence, last_ground, last_mode, last_type, last_target = nil, 0, nil, nil, nil, nil
local optical = dofile(LockOn_Options.script_path .. "HUD/optics.lua").frl_elevation
local projection = dofile(LockOn_Options.script_path .. "Systems/HUD_Projection.lua")
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
	for _, name in ipairs({
		"F22_AG_SOLUTION_VALID",
        "F22_AG_SOLUTION_SCHEMA",
        "F22_AG_LAR_READY",
        "F22_AG_LAR_ESTIMATED",
        "F22_AG_TERRAIN_PATH_VALID",
        "F22_AG_BAY_PREDICTION_VALID",
		"F22_AG_AUTO_RELEASE",
		"HUD_AG_CCIP_EST_VALID",
		"HUD_AG_CCIP_CUE_VALID",
		"HUD_AG_CCRP_EST_VALID",
		"F22_AG_GUN_REQUEST_VALID",
	}) do
		put(name, 0)
	end
end
-- Native result buffers belong to the EFM. These stable, Lua-owned fields
-- describe only the response actually consumed, never the next queued input.
for _,name in ipairs({'F22_AG_SOLUTION_IMPACT_N','F22_AG_SOLUTION_IMPACT_U','F22_AG_SOLUTION_IMPACT_E',
 'F22_AG_SOLUTION_REQUEST_TIME','F22_AG_SOLUTION_PUBLICATION_TIME','F22_AG_SOLUTION_NATIVE_TIME',
 'F22_AG_SOLUTION_PREDICTION_SEC','F22_AG_SOLUTION_MEASUREMENT_AGE_SEC','F22_AG_SOLUTION_NATIVE_LATENCY_SEC',
 'F22_AG_SOLUTION_SEQUENCE','F22_AG_SOLUTION_FALL_TIME','F22_AG_SOLUTION_DELAY',
 'F22_AG_SOLUTION_TARGET_VALID','F22_AG_SOLUTION_TARGET_SOURCE','F22_AG_SOLUTION_TARGET_SEQUENCE',
 'F22_AG_SOLUTION_TARGET_N','F22_AG_SOLUTION_TARGET_U','F22_AG_SOLUTION_TARGET_E'})do put(name,0)end
-- Binding is earlier than post_initialize. These are render fields only;
-- native trajectory results and the retained angular outputs are untouched.
for _,name in ipairs({"HUD_AG_CCIP_X_SLOPE","HUD_AG_CCIP_Y_SLOPE",
    "HUD_AG_DIL_X0","HUD_AG_DIL_Y0","HUD_AG_DIL_X1","HUD_AG_DIL_Y1"}) do put(name,0) end
-- Complete delivery-detail bindings before head-down formats are constructed.
for _,name in ipairs({'HUD_AG_CCIP_RANGE_NM','HUD_AG_CCIP_TOF_SEC','F22_AG_LAR_RANGE_M',
 'F22_AG_LAR_MIN_M','F22_AG_LAR_MAX_M','F22_AG_LAR_REASON'})do h(name)end
clear()
put('F22_AG_BOMB_REQUEST_VALID',0)
function post_initialize()
	local ok, t = pcall(require, "terrain")
	if ok and type(t) == "table" and type(t.GetHeight) == "function" then
		terrain = t
	end
	sequence = 0
	last_ground = nil
	last_mode = nil
	last_type = nil
	pending=nil;last_activity=nil;last_bay=nil
	clear()
    put('F22_AG_BOMB_REQUEST_VALID',0)
end
function update()
	clear()
	local mode = get("HUD_AG_SUBMODE")
	if get("MAIN_POWER") < 0.5 or get("HUD_MODE") ~= 7 or get("EFM_HUD_VALID") < 0.5 or not terrain then
		last_mode = nil;last_motion=nil;pending=nil;last_activity=nil;last_bay=nil;put('F22_AG_BOMB_REQUEST_VALID',0)
		return
	end
	local now = type(get_model_time) == "function" and get_model_time() or 0
	local n, u, e = base.getSelfCoordinates()
	if not finite(now) or not finite(n) or not finite(u) or not finite(e) then
		pending=nil;put('F22_AG_BOMB_REQUEST_VALID',0)
		return
	end
	local target_seq = get("F22_AG_TARGET_SEQUENCE")
	local changed = mode ~= last_mode
		or get("F22_AG_WEAPON_TYPE4") ~= last_type
        or get("F22_AG_WEAPON_TYPE3") ~= last_type3
        or get("F22_WEAPON_STATION") ~= last_station
		or (mode == 3 and target_seq ~= last_target)
	if changed then
		last_ground = nil;pending=nil;put('F22_AG_BOMB_REQUEST_VALID',0)
	end
	last_mode = mode
    last_station = get("F22_WEAPON_STATION")
    last_type3 = get("F22_AG_WEAPON_TYPE3")
	last_type = get("F22_AG_WEAPON_TYPE4")
	last_target = target_seq
	local point, fall
	if mode == 1 then
        pending=nil;last_activity=nil;last_bay=nil;put('F22_AG_BOMB_REQUEST_VALID',0)
        put('F22_AG_OWN_N',n);put('F22_AG_OWN_U',u);put('F22_AG_OWN_E',e)
        put("F22_AG_GUN_REQUEST_TIME", now)
        put("F22_AG_GUN_REQUEST_VALID", 1)
        dispatch_action(nil, 10851, .05)
		local age = now - get("F22_AG_GUN_RESULT_TIME")
		if get("F22_AG_GUN_NATIVE_VALID") > 0.5 and age >= 0 and age <= 0.2 then
			local points = {}
			local count = math.min(81, get("F22_AG_GUN_POINT_COUNT"))
			for i = 0, count - 1 do
				local p = string.format("F22_AG_GUN_%02d_", i)
				points[#points + 1] = { n = get(p .. "N"), u = get(p .. "U"), e = get(p .. "E") }
			end
			point = delivery.ground(points, height)
			fall = point and point.t
		end
	else
		if get("F22_AG_BOMB_SELECTED") < 0.5 then
			pending=nil;put('F22_AG_BOMB_REQUEST_VALID',0);return
		end
        local source=get('F22_AG_DELIVERY_TARGET_SOURCE')
        local target=source>0 and get('F22_AG_DELIVERY_TARGET_VALID')>.5 or source==0 and get('HUD_AG_TARGET_VALID')>.5
        local target_point={n=source>0 and get('F22_AG_DELIVERY_TARGET_N')or get('HUD_AG_MARK_NORTH'),u=source>0 and get('F22_AG_DELIVERY_TARGET_U')or get('HUD_AG_MARK_ALT'),e=source>0 and get('F22_AG_DELIVERY_TARGET_E')or get('HUD_AG_MARK_EAST')}
        if mode==3 and not target then pending=nil;put('F22_AG_BOMB_REQUEST_VALID',0);return end
        local ground=mode==3 and target_point.u or last_ground or height(n,e)
		if not ground then
			pending=nil;put('F22_AG_BOMB_REQUEST_VALID',0);return
		end
        -- dispatch_action is queued by DCS. Consume the single frozen request
        -- from a prior activity before issuing its successor. Do not infer
        -- synchronous execution from a unit-test stub.
        if get('F22_AG_BOMB_ASYNC_SUPPORTED')~=2 then
            pending=nil;put('F22_AG_BOMB_REQUEST_VALID',0);dispatch_action(nil,10851,.05);return
        end
        local authority=1
        if get('EFM_VEHICLE_VALID')>.5 then local supply=get('EFM_ACTUATOR_AVAILABLE');authority=finite(supply)and math.max(0,math.min(1,supply))or 0 end
        local travel=mode==2 and get('BAY_C_ARG')<.98 and math.max(0,math.min(1,1-get('BAY_C_ARG')))or 0
        if travel>0 and authority<=0 then pending=nil;put('F22_AG_BOMB_REQUEST_VALID',0);return end
        local delay=travel>0 and travel/(2.5*authority)or 0
        -- Long extrapolations during pressure loss are not a qualified aim cue.
        if delay>1 then pending=nil;put('F22_AG_BOMB_REQUEST_VALID',0);return end
        put('F22_AG_BAY_PREDICTION_VALID',1)
        local velocity={n=get('EFM_HUD_VN'),u=get('EFM_HUD_VU'),e=get('EFM_HUD_VE')}
        local acceleration={n=0,u=0,e=0}
        if last_motion and now-last_motion.time>=.015 and now-last_motion.time<=.2 then
            for _,axis in ipairs({'n','u','e'})do acceleration[axis]=math.max(-30,math.min(30,(velocity[axis]-last_motion[axis])/(now-last_motion.time)))end
        end
        last_motion={n=velocity.n,u=velocity.u,e=velocity.e,time=now}
        local guided=get('F22_AG_GUIDED_SELECTED')>.5 or get('F22_AG_WEAPON_TYPE3')==36
        local context={mode=mode,station=get('F22_WEAPON_STATION'),type3=get('F22_AG_WEAPON_TYPE3'),type4=get('F22_AG_WEAPON_TYPE4'),
            target_source=source,target_sequence=get('F22_AG_DELIVERY_TARGET_SEQUENCE'),target_valid=target and 1 or 0,
            target_n=target_point.n,target_u=target_point.u,target_e=target_point.e}
        local q=pending;local consumed
        if q then
            local same=true;for key,value in pairs(context)do if q.context[key]~=value then same=false end end
            local elapsed=now-q.time
            if not same or elapsed<0 or elapsed>.12 then pending=nil
            elseif get('F22_AG_BOMB_RESPONSE_SEQUENCE')==q.sequence then
                pending=nil
                local stamp=get('F22_AG_BOMB_RESULT_TIME')
                local native_age=stamp-q.time
                local lead=now-stamp
                local valid=get('F22_AG_BOMB_NATIVE_VALID')>.5 and get('F22_AG_BOMB_RESPONSE_SCHEMA')==2
                    and get('F22_AG_BOMB_RESPONSE_STATION')==q.context.station
                    and get('F22_AG_BOMB_RESPONSE_TYPE3')==q.context.type3 and get('F22_AG_BOMB_RESPONSE_TYPE4')==q.context.type4
                    and math.abs(get('F22_AG_BOMB_RESPONSE_REQUEST_TIME')-q.time)<.000001
                    and native_age>=-.01 and native_age<=.12 and lead>=-.01 and lead<=.12
                    and math.abs(elapsed-q.step)<=.025
                if valid then
                    local candidate={n=get('F22_AG_BOMB_IMPACT_N'),u=get('F22_AG_BOMB_IMPACT_U'),e=get('F22_AG_BOMB_IMPACT_E')}
                    local floor=height(candidate.n,candidate.e)
                    if floor then
                        if guided then point=candidate;fall=get('F22_AG_BOMB_FALL_TIME')
                        elseif get('F22_AG_BOMB_TRAJECTORY_READY')>.5 and get('F22_AG_BOMB_POINT_COUNT')==17 then
                            local points={}
                            for i=0,16 do local prefix=string.format('F22_AG_BOMB_%02d_',i);points[#points+1]={n=get(prefix..'N'),u=get(prefix..'U'),e=get(prefix..'E'),t=get(prefix..'T')}end
                            point=delivery.ground(points,height);fall=point and point.t
                            put('F22_AG_TERRAIN_PATH_VALID',point and 1 or 0)
                        end
                        -- A final plane above a falling valley cannot bracket
                        -- first contact. Refine below its actual terrain on the
                        -- next real response; retain ridge intersections now.
                        if not guided then last_ground=floor-5 end
                    end
                    if point and fall then consumed=q;consumed.native_time=stamp end
                end
            end
        end
        local step=dt
        if last_activity and now-last_activity>=.015 and now-last_activity<=.1 then step=now-last_activity end
        local opening=last_bay and get('BAY_C_ARG')>last_bay+.0001
        last_activity=now;last_bay=get('BAY_C_ARG')
        if not pending then
            -- Retained native handles outlive device recreation. Never reuse
            -- an old identity even if the mission/model clock resets to the
            -- identical timestamp, station and weapon type.
            local requested,responded=get('F22_AG_BOMB_REQUEST_SEQUENCE'),get('F22_AG_BOMB_RESPONSE_SEQUENCE')
            if not finite(requested)or not finite(responded)or requested<0 or responded<0 or requested~=math.floor(requested)or responded~=math.floor(responded)then put('F22_AG_BOMB_REQUEST_VALID',0);return end
            sequence=math.max(sequence,requested,responded)+1
            if sequence>=9007199254740991 then put('F22_AG_BOMB_REQUEST_VALID',0);return end
            put('F22_AG_BOMB_REQUEST_VALID',0)
            -- Forecast to next activity plus remaining physical bay travel.
            -- When the bay is already moving, that travel elapses during the
            -- callback wait; do not count the same interval a second time.
            local horizon=step+math.max(0,delay-(opening and step or 0))
            local request={time=now,sequence=sequence,context=context,step=step,delay=delay,horizon=horizon,origin={},velocity={}}
            local own={n=n,u=u,e=e}
            for _,axis in ipairs({'n','u','e'})do
                request.origin[axis]=own[axis]+velocity[axis]*horizon+.5*acceleration[axis]*horizon*horizon
                request.velocity[axis]=velocity[axis]+acceleration[axis]*horizon
                put('F22_AG_BOMB_REQUEST_'..string.upper(axis),request.origin[axis])
                put('F22_AG_BOMB_REQUEST_V'..string.upper(axis),request.velocity[axis])
                put('F22_AG_BOMB_REQUEST_W'..string.upper(axis),get('EFM_HUD_W'..string.upper(axis)))
            end
            put('F22_AG_BOMB_REQUEST_SCHEMA',2);put('F22_AG_BOMB_REQUEST_TIME',now);put('F22_AG_BOMB_REQUEST_SEQUENCE',sequence)
            put('F22_AG_BOMB_REQUEST_STATION',context.station);put('F22_AG_BOMB_REQUEST_TYPE3',context.type3);put('F22_AG_BOMB_REQUEST_TYPE4',context.type4)
            put('F22_AG_BOMB_REQUEST_GROUND_LEVEL',guided and ground or last_ground or ground)
            put('F22_AG_BOMB_REQUEST_TRAJECTORY',guided and 0 or 1);put('F22_AG_BOMB_REQUEST_VALID',1)
            pending=request;dispatch_action(nil,10851,.05)
        end
        if consumed then
            for _,axis in ipairs({'n','u','e'})do put('F22_AG_OWN_'..string.upper(axis),consumed.origin[axis]);put('F22_AG_RELEASE_V'..string.upper(axis),consumed.velocity[axis])end
            put('F22_AG_BOMB_RELEASE_DELAY',consumed.delay);put('F22_AG_RELEASE_VELOCITY_VALID',1)
            put('F22_AG_SOLUTION_REQUEST_TIME',consumed.time);put('F22_AG_SOLUTION_NATIVE_TIME',consumed.native_time)
            put('F22_AG_SOLUTION_MEASUREMENT_AGE_SEC',now-consumed.time);put('F22_AG_SOLUTION_NATIVE_LATENCY_SEC',consumed.native_time-consumed.time)
            put('F22_AG_SOLUTION_PREDICTION_SEC',consumed.horizon);put('F22_AG_SOLUTION_SEQUENCE',consumed.sequence)
            put('F22_AG_SOLUTION_DELAY',consumed.delay)
            for _,key in ipairs({'valid','source','sequence','n','u','e'})do put('F22_AG_SOLUTION_TARGET_'..string.upper(key),consumed.context['target_'..key])end
        end
		if not consumed then return end
	end
	if not point or not fall then
		return
	end
    if mode~=1 then
        put('F22_AG_SOLUTION_IMPACT_N',point.n);put('F22_AG_SOLUTION_IMPACT_U',point.u);put('F22_AG_SOLUTION_IMPACT_E',point.e)
        put('F22_AG_SOLUTION_FALL_TIME',fall)
        put('F22_AG_BOMB_TERRAIN_FALL_TIME',fall)
    end
    local az, el, r =
		geom.project(point.n - n, point.e - e, point.u - u, -base.getHeading(), base.getPitch(), base.getRoll())
	if not az or not el or not r or r < 10 then
		return
	end
    put('F22_AG_SOLUTION_SCHEMA',2)
	put("F22_AG_SOLUTION_VALID", 1)
	put("F22_AG_SOLUTION_TIME", mode==1 and now or get('F22_AG_SOLUTION_REQUEST_TIME'))
    put('F22_AG_SOLUTION_PUBLICATION_TIME',now)
    put("F22_AG_SOLUTION_STATION", get("F22_WEAPON_STATION"))
	put("HUD_AG_CCIP_EST_VALID", 1)
	put("HUD_AG_CCIP_TOF_SEC", fall)
	put("HUD_AG_CCIP_RANGE_NM", r / 1852)
	put("HUD_AG_CCIP_AZ_RAD", az)
	put("HUD_AG_CCIP_EL_RAD", el)
    local ccip_x,ccip_y=projection.planar(az,el)
    put("HUD_AG_CCIP_X_SLOPE",ccip_x);put("HUD_AG_CCIP_Y_SLOPE",ccip_y)
	put("HUD_AG_CCIP_CUE_VALID", math.abs(az) < math.rad(13) and math.abs(el) < math.rad(13) and 1 or 0)
	local fpaz, fpel = geom.project(
		get("EFM_HUD_VN"),
		get("EFM_HUD_VE"),
		get("EFM_HUD_VU"),
		-base.getHeading(),
		base.getPitch(),
		base.getRoll()
	)
	local fpx,fpy=projection.planar(fpaz,fpel)
    put("HUD_AG_DIL_X0",fpx or 0)
    put("HUD_AG_DIL_Y0",(fpy or 0)+optical)
    put("HUD_AG_DIL_X1",ccip_x)
    put("HUD_AG_DIL_Y1",ccip_y+optical)
    if mode==3 then
        local source=get('F22_AG_DELIVERY_TARGET_SOURCE')
        local target={n=source>0 and get('F22_AG_DELIVERY_TARGET_N')or get('HUD_AG_MARK_NORTH'),u=source>0 and get('F22_AG_DELIVERY_TARGET_U')or get('HUD_AG_MARK_ALT'),e=source>0 and get('F22_AG_DELIVERY_TARGET_E')or get('HUD_AG_MARK_EAST')}
        local guided=get('F22_AG_GUIDED_SELECTED')>.5 or get('F22_AG_WEAPON_TYPE3')==36
        local solution
        if guided then
            solution=delivery.guided({n=n,u=u,e=e},point,target,get('EFM_HUD_VN'),get('EFM_HUD_VU'),get('EFM_HUD_VE'),fall)
            put('F22_AG_LAR_ESTIMATED',1)
            if solution then
                put('F22_AG_LAR_MIN_M',solution.minimum);put('F22_AG_LAR_MAX_M',solution.maximum);put('F22_AG_LAR_RANGE_M',solution.range)
                put('F22_AG_LAR_REASON',solution.reason)
                put('F22_AG_LAR_READY',solution.ready and 1 or 0)
            end
        else solution=delivery.release(point,target,get('EFM_HUD_VN'),get('EFM_HUD_VE'),fall)end
        if solution then
            put('HUD_AG_CCRP_EST_VALID',1);put('HUD_AG_CCRP_TIME_SEC',solution.seconds)
            put('F22_AG_CROSS_TRACK_M',solution.cross)
            put('F22_AG_RELEASE_CUE_Y',math.max(-.38,math.min(.45,solution.seconds*.035)))
            put('F22_AG_STEERING_X',math.max(-.45,math.min(.45,-solution.cross*.0008)))
            put('F22_AG_AUTO_RELEASE',solution.ready and math.abs(base.getRoll())<math.rad(guided and 30 or 20)and 1 or 0)
        end
    end
    if now>=next_telemetry and log and log.write then
        next_telemetry=now+1
        log.write('F22_AG_SOLUTION',log.INFO,string.format('t=%.3f station=%.0f type=%.0f mode=%.0f own=(%.3f,%.3f,%.3f) release=(%.3f,%.3f,%.3f) predicted=(%.3f,%.3f,%.3f) tof=%.3f pitch=%.4f bank=%.4f terrain_path=%.0f lar_estimated=%.0f lar_ready=%.0f',now,get('F22_WEAPON_STATION'),get('F22_AG_WEAPON_TYPE4'),mode,n,u,e,get('F22_AG_OWN_N'),get('F22_AG_OWN_U'),get('F22_AG_OWN_E'),point.n,point.u,point.e,fall,base.getPitch(),base.getRoll(),get('F22_AG_TERRAIN_PATH_VALID'),get('F22_AG_LAR_ESTIMATED'),get('F22_AG_LAR_READY')))
    end
end
need_to_be_closed = false
