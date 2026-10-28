-- GPL-3.0-or-later. Own display computer; no mission/world target enumeration.
-- Target state comes only from our radar observations. Missile state is limited
-- to actual IDs returned by this aircraft's native payload launch interface.
local mathlib=dofile(LockOn_Options.script_path..'Systems/Weapon_Engagement.lua')
local display=dofile(LockOn_Options.script_path..'Systems/Radar_Display.lua')
local launch_zone=dofile(LockOn_Options.script_path..'Systems/Radar_Launch_Zone.lua')
local equipment=dofile(LockOn_Options.script_path..'Systems/Equipment_Profile.lua')
local physical_supply=dofile(LockOn_Options.script_path..'Systems/Weapon_Physical_State.lua').new()
local sensors=get_base_data();local dt=.05;make_default_activity(dt)
local handles={};local function h(n) if not handles[n] then handles[n]=get_param_handle(n) end;return handles[n] end
local function get(n)return h(n):get()end
local function put(n,v)h(n):set(v)end
local ir_feedback=dofile(LockOn_Options.script_path..'Systems/IR_Feedback.lua').new(get)
for _,name in ipairs(launch_zone.segments)do
    for _,field in ipairs({'X1','Y1','X2','Y2','VALID'})do h('F22_RDR_LAR_'..name..'_'..field)end
end
local radar_observations=dofile(LockOn_Options.script_path.."Systems/AESA_Control.lua").new(get,put)
local clock=0;local next_log=0;local last_sequence=0;local missiles={};local files={}
local file_count=0
local function vector(p,a,b,c)return {get(p..a),get(p..b),get(p..c)}end
local function target(id,now)
    local t=files[id];if not t then return nil end
    local age=now-t.time;if age<-.1 or age>20 then return nil end
    return {id=id,position=mathlib.advance(t.position,t.velocity,math.max(0,age)),velocity=t.velocity,age=math.max(0,age)}
end
local function remember(id,position,velocity,time)
    if type(id)~='number'or id<1 or id>=4294967296 or id%1~=0 or not mathlib.finite(time)then
        return false
    end
    for index=1,3 do
        if not mathlib.finite(position[index])or not mathlib.finite(velocity[index])then return false end
    end
    if not files[id] then
        if file_count>=256 then put('F22_FC_TRACK_OVERFLOW',1);return false end
        file_count=file_count+1
    end
    files[id]={position=position,velocity=velocity,time=time}
    return true
end
local function observe(now)
    local observations=radar_observations:read(now)
    if radar_observations.generation_changed then files={};file_count=0 end
    for i=1,#observations do
        local o=observations[i];local id,time=o.native_id,o.observed
        if o.velocity_valid and (not files[id] or time>files[id].time+.01) then
            local accepted=remember(id,{o.north,o.altitude,o.east},{o.vn,o.vu,o.ve},time)
            if not accepted then put('F22_FC_REJECTED_INPUT',1)end
        end
    end
    for id,t in pairs(files) do
        if now-t.time>30 then files[id]=nil;file_count=file_count-1 end
    end
end
local function support_status(id,now,track)
    if get('RADAR_PWR')<.5 or get('F22_RADAR_BACKEND_READY')<.5 or not track or track.age>6 then
        return 3,0
    end
    local publication_age=now-get('F22_RADAR_TACTICAL_TIME')
    if get('F22_RADAR_SUPPORT_ENABLED')>.5 and get('F22_TWS_GUIDANCE_BACKEND_READY')>.5
        and publication_age>=-.05 and publication_age<=.35 then
        for index=1,24 do
            local prefix=string.format('F22_SUPPORT_%02d_',index)
            local age=get(prefix..'AGE')+math.max(0,publication_age)
            if get(prefix..'ID')==id and age>=0 and age<=6 then return 1,2 end
        end
    end
    return 2,0 -- Recent geometry alone cannot establish an active support path.
end
function post_initialize()
    clock,next_log,last_sequence,file_count=0,0,0,0
    missiles,files={},{}
	put('F22_RDR_LAR_VISIBLE',0)
    for _,name in ipairs(launch_zone.segments)do put('F22_RDR_LAR_'..name..'_VALID',0)end
    for i=1,8 do local p=string.format('F22_MSL_%02d_',i)
        for _,field in ipairs({'VALID','PLOT_VALID','SUPPORT_REQUIRED','SUPPORT_STATE','SUPPORT_COAST','SUPPORT_LOST','TRACK_LOST'})do put(p..field,0)end
    end
    for _,n in ipairs({'F22_FC_SUPPORT_DEGRADED','F22_FC_SUPPORT_LOST','F22_FC_TARGET_INPUT_VALID','F22_FC_TARGET_VALID','F22_FC_DLZ_VALID','F22_FC_SHOOT','F22_FC_TIMER_VALID'}) do put(n,0) end
end
function update()
    physical_supply:update()
    local diagnostic_truth=equipment.supports('diagnostic_weapon_truth')
    put('F22_FC_DIAGNOSTIC_TRUTH',diagnostic_truth and 1 or 0)
    local now=type(get_model_time)=='function' and get_model_time() or clock+dt
    if now<clock-.1 then missiles={};files={};last_sequence=0;file_count=0 end;clock=now
    observe(now)
    local n,u,e=sensors.getSelfCoordinates();local own={n,u,e}
    local ov=vector('EFM_HUD_','VN','VU','VE')
    local pose={north=n,altitude=u,east=e,pitch=sensors.getPitch(),roll=sensors.getRoll(),heading=(2*math.pi-sensors.getHeading())%(2*math.pi)}
    local id=get('F22_RADAR_WEAPON_TARGET_ID');local t=target(id,now)
    local valid=t and t.age<=6 and get('RADAR_PWR')>.5 and physical_supply.mission
    local mode=get('HUD_MODE');local missile_mode=mode==2 or mode==3
    ir_feedback:update(mode==3 and physical_supply.mission,now)
    put('F22_FC_TARGET_VALID',valid and 1 or 0);put('F22_FC_TARGET_INPUT_VALID',valid and 1 or 0)
    put('F22_FC_TARGET_INPUT_ID',valid and id or 0);put('F22_FC_OWN_ALTITUDE',u)
    put('F22_FC_OWN_PITCH',pose.pitch);put('F22_FC_OWN_ROLL',pose.roll);put('F22_FC_OWN_HEADING',pose.heading)
    local range=0;local az,el=0,0;local closure=0
    if valid then
        local d=mathlib.sub(t.position,own);range=mathlib.norm(d)
        closure=range>1 and mathlib.dot(mathlib.sub(ov,t.velocity),d)/range or 0
        local temp={north=t.position[1],altitude=t.position[2],east=t.position[3]}
        _,az,el=display.body_observation(temp,pose,0)
        for i,axis in ipairs({'N','U','E'}) do put('F22_FC_TARGET_D'..axis,d[i]);put('F22_FC_TARGET_V'..axis,t.velocity[i]) end
    end
    put('F22_FC_RANGE_NM',range/1852);put('F22_FC_CLOSURE_KTS',closure*1.943844492)
    local native_dlz=valid and missile_mode and get('F22_DLZ_NATIVE_VALID')>.5 and get('F22_DLZ_TARGET_ID')==id
    local fallback=valid and missile_mode and get('F22_MISSILE_DATA_VALID')>.5
    local minimum=native_dlz and get('F22_DLZ_RMIN') or get('F22_MISSILE_NATIVE_MIN')
    local maximum=native_dlz and get('F22_DLZ_RMAX') or get('F22_MISSILE_NATIVE_MAX')
    local turn=native_dlz and get('F22_DLZ_RTR') or nil
    local zone=(native_dlz or fallback) and mathlib.zone(range,minimum,maximum,turn)
    put('F22_FC_DLZ_VALID',zone and 1 or 0);put('F22_FC_DLZ_DYNAMIC',native_dlz and 1 or 0)
    put('F22_FC_MIN_NM',minimum/1852);put('F22_FC_MAX_NM',maximum/1852);put('F22_FC_TURN_NM',(turn or 0)/1852)
    local scale=math.max(range*1.2,maximum*1.2,1852)
    put('F22_FC_DLZ_SCALE_NM',scale/1852)
    put('F22_FC_DLZ_MIN_Y',minimum/scale*.46);put('F22_FC_DLZ_MAX_Y',maximum/scale*.46)
    put('F22_FC_DLZ_TURN_Y',(turn or 0)/scale*.46);put('F22_FC_DLZ_RANGE_Y',range/scale*.46)
    local radar_mode=get('F22_RADAR_MODE_CODE')
    local lar_kind=get('F22N_RADAR_MODE')==3 and 'STT'
        or (radar_mode==2 or radar_mode==3) and get('F22_SOI')==2 and 'TWS' or nil
    -- The radar's LAR uses a real target-specific solution, rather than the
    -- HUD's nominal weapon-range fallback. TWS/LTWS is TDC-assigned only.
    local lar=native_dlz and valid and lar_kind and launch_zone.project(mathlib.sub(t.position,own),pose.heading,
        minimum,maximum,turn,get('F22_RADAR_RANGE_NM')*1852,display,lar_kind)
    put('F22_RDR_LAR_VISIBLE',lar and 1 or 0)
    for _,name in ipairs(launch_zone.segments)do
        local p='F22_RDR_LAR_'..name..'_';local line=lar and lar[name]
        put(p..'VALID',line and 1 or 0)
        if line then
            put(p..'X1',line[1]);put(p..'Y1',line[2]);put(p..'X2',line[3]);put(p..'Y2',line[4])
        end
    end
    local friendly=get('F22_RADAR_SELECTED_FRIENDLY')>.5
    local blocker=get('WoW')>.5 and 1
        or physical_supply.utility<=0 and 3
        or get('F22_WEAPON_SELECTED_VALID')>.5 and get('F22_WEAPON_SUPPORTED')<.5 and 4
        or not physical_supply.mission and 5 or 0
    put('F22_FC_RELEASE_BLOCKER',blocker)
    put('F22_FC_SHOOT_ANTICIPATORY',1) -- Doors may open after the pilot requests release.
    local ready=blocker==0 and valid and get('MASTER_ARM')>.5 and get('F22_WEAPON_COUNT')>0 and not friendly
    -- A real uncaged IR lock supplies its own per-seeker gimbal eligibility;
    -- the radar missile steering gate must not truncate AIM-9X to 30 degrees.
    local alignment=mode==3 or math.abs(az)<math.rad(30) and math.abs(el)<math.rad(30)
    local shoot=ready and zone and zone.inside and alignment
    if mode==3 then
        shoot=shoot and ir_feedback.locked and get('F22_IR_CAGED')<.5
    end
    put('F22_FC_SHOOT',missile_mode and shoot and 1 or 0);put('F22_FC_TURN_WINDOW',shoot and zone.turn and 1 or 0)
    put('F22_FC_TOO_CLOSE',zone and zone.too_close and 1 or 0)
    put('F22_FC_WAIT_VALID',zone and range>maximum and closure>5 and 1 or 0)
    put('F22_FC_WAIT_SECONDS',closure>5 and math.max(0,(range-maximum)/closure) or 0)
    -- Read only real launch records. Pickle holds, empty stations and denied
    -- releases cannot create a flyout or retarget an existing missile slot.
    local newest=get('F22_LAUNCH_SEQUENCE')
    if newest<last_sequence then missiles={};last_sequence=0 end
    local events={}
    for i=1,16 do local p=string.format('F22_SHOT_%02d_',i);local seq=get(p..'SEQUENCE')
        if seq>last_sequence then events[#events+1]={p=p,seq=seq} end
    end
    table.sort(events,function(a,b)return a.seq<b.seq end)
    for _,event in ipairs(events) do
        local p=event.p
        if (get(p..'MODE')==2 or get(p..'MODE')==3) and get(p..'ID')>0 then
            local slot=(event.seq-1)%8+1
            local life=get(p..'LIFETIME');if life<1 or life>1000 then life=1000 end
            missiles[slot]={id=get(p..'ID'),target=get(p..'TARGET'),mode=get(p..'MODE'),sequence=event.seq,p=p,born=get(p..'TIME'),life=life,seen=false,
                estimate_time=get(p..'ESTIMATE_TIME'),launch_tof=get(p..'TOF_VALID')>.5 and get(p..'TOF') or nil,
                estimate_source=get(p..'TOF_SOURCE')==2 and 3 or 1,
                launch_act=get(p..'ACT_VALID')>.5 and get(p..'ACT') or nil}
        end
        last_sequence=math.max(last_sequence,event.seq)
    end
    local timer=nil;local count=0;local degraded_count,lost_count,required_count=0,0,0
    for i=1,8 do
        local p=string.format('F22_MSL_%02d_',i);local m=missiles[i];local alive=false;local supported=false
        if m then
            local real=get(m.p..'SEQUENCE')==m.sequence and get(m.p..'ID')==m.id and get(m.p..'ALIVE')>.5
            local tm=target(m.target,now)
            if real then m.seen=true end
            alive=real or not m.seen and now-m.born<3
            -- Registry disappearance ends the real missile. The frozen
            -- adapter watchdog never inherits a newly selected IR store's life.
            if now-m.born>m.life then alive=false end
            local qualified_state=get(m.p..'STATE_SOURCE')==1 or diagnostic_truth
            m.active=real and qualified_state and get(m.p..'ACTIVE_VALID')>.5 and get(m.p..'ACTIVE')>.5
            -- Emitting alone does not prove the seeker acquired a target.
            m.acquired_ever=m.acquired_ever or real and get(m.p..'SEEKER_ACQUIRED_EVER')>.5
            m.guiding=real and qualified_state and m.active and get(m.p..'CURRENT_LOCK_VALID')>.5
                and get(m.p..'SEEKER_VALID')>.5 and get(m.p..'SEEKER_TRACK')>.5
            m.tta=not m.active and mathlib.countdown(m.launch_act,m.estimate_time,now) or nil
            m.ttg=mathlib.countdown(m.launch_tof,m.estimate_time,now)
            m.tta_source=m.tta and 1 or 0;m.ttg_source=m.ttg and m.estimate_source or 0
            if diagnostic_truth and real and tm then
                local pos=vector(m.p,'N','U','E');local vel=vector(m.p,'VN','VU','VE')
                local relative=mathlib.sub(tm.position,pos);local rv=mathlib.sub(tm.velocity,vel)
                local ttg=mathlib.intercept(relative,tm.velocity,mathlib.norm(vel))
                local tta=not m.active and mathlib.time_to_active(relative,rv,get(m.p..'ACTIVE_RANGE')) or nil
                -- Shared launch TOF includes acceleration/drag. Constant
                -- current-speed geometry is the separately tagged fallback;
                -- it must not replace a still-valid trajectory countdown.
                if ttg and not m.ttg then m.ttg=ttg;m.ttg_source=2 end
                if tta then m.tta=tta;m.tta_source=2 end
                local temp={north=pos[1],altitude=pos[2],east=pos[3]};local rr,aa=display.body_observation(temp,pose,0)
                local x,y=display.point(rr,aa,get('F22_RADAR_RANGE_NM')*1852)
                put(p..'X',x);put(p..'Y',y);put(p..'PLOT_VALID',alive and math.abs(x)<.95 and y>-.93 and y<.90 and 1 or 0)
            else put(p..'PLOT_VALID',0) end
            supported=alive and m.mode==2 and not m.guiding
            if alive then count=count+1;if not timer or m.target==id and timer.target~=id or m.sequence>timer.sequence and (m.target==id)==(timer.target==id) then timer=m end end
        else put(p..'PLOT_VALID',0) end
        local support_state,support_source=0,0
        if supported then
            required_count=required_count+1
            local tm=target(m.target,now)
            support_state,support_source=support_status(m.target,now,tm)
            if support_state==3 then lost_count=lost_count+1
            elseif support_state==2 then degraded_count=degraded_count+1 end
        end
        put(p..'SUPPORT_STATE',support_state)
        put(p..'SUPPORT_SOURCE',support_source)
        put(p..'SUPPORT_COAST',support_state==2 and 1 or 0)
        put(p..'SUPPORT_LOST',support_state==3 and 1 or 0)
        put(p..'VALID',alive and 1 or 0);put(p..'TARGET',m and m.target or 0);put(p..'ID',m and m.id or 0)
        put(p..'SEQUENCE',m and m.sequence or 0);put(p..'SUPPORT_REQUIRED',supported and 1 or 0)
        put(p..'ACTIVE',m and m.active and 1 or 0);put(p..'SELF_GUIDING',m and m.guiding and 1 or 0);put(p..'TTA_VALID',m and m.tta and 1 or 0);put(p..'TTA',m and m.tta or 0)
        put(p..'SEEKER_ACQUIRED_EVER',m and m.acquired_ever and 1 or 0)
        put(p..'CURRENT_LOCK_VALID',m and get(m.p..'CURRENT_LOCK_VALID')>.5 and 1 or 0)
        put(p..'STATE_SOURCE',m and get(m.p..'STATE_SOURCE')or 0)
        put(p..'TTG_VALID',m and m.ttg and 1 or 0);put(p..'TTG',m and m.ttg or 0)
        put(p..'TTA_SOURCE',m and m.tta_source or 0);put(p..'TTG_SOURCE',m and m.ttg_source or 0)
        put(p..'TRACK_LOST',support_state==3 and 1 or 0)
    end
    local uncovered=required_count>0 and get('F22_RADAR_SCAN_UNCOVERED')>0
    put('F22_FC_SUPPORT_DEGRADED',(degraded_count>0 or lost_count>0 or uncovered) and 1 or 0)
    put('F22_FC_SUPPORT_LOST',lost_count>0 and 1 or 0)
    put('F22_FC_SUPPORT_COAST_COUNT',degraded_count);put('F22_FC_SUPPORT_LOST_COUNT',lost_count)
    put('F22_FC_MISSILES',count);put('F22_FC_TIMER_VALID',timer and 1 or 0)
    put('F22_FC_TIMER_ACTIVE',timer and timer.guiding and 1 or 0)
    put('F22_FC_TIMER_EMITTING',timer and timer.active and 1 or 0)
    put('F22_FC_TIMER_SEQUENCE',timer and timer.sequence or 0)
    put('F22_FC_TIMER_MODE',timer and timer.mode or 0)
    put('F22_FC_TIMER_TARGETMATCH',timer and timer.target==id and 1 or 0)
    put('F22_FC_TTA_VALID',timer and timer.tta and 1 or 0);put('F22_FC_TTA',timer and timer.tta or 0)
    put('F22_FC_TTG_VALID',timer and timer.ttg and 1 or 0);put('F22_FC_TTG',timer and timer.ttg or 0)
    if now>=next_log and log and log.write then next_log=now+1
        log.write('F22_ENGAGEMENT',log.INFO,string.format('target=%d valid=%s range=%.1f closure=%.1f dynamic=%s min=%.0f max=%.0f turn=%.0f shoot=%s missiles=%d active=%s tta=%s ttg=%s support_coast=%d support_lost=%d weapon=%q type=%.0f station=%.0f count=%.0f tof_valid=%.0f tof_source=%.0f tof=%.2f az=%.4f el=%.4f',
            id,tostring(valid),range,closure,tostring(native_dlz),minimum,maximum,turn or 0,tostring(shoot),count,tostring(timer and timer.active),tostring(timer and timer.tta),tostring(timer and timer.ttg),degraded_count,lost_count,
            tostring(get('F22_WEAPON_NAME')),get('F22_WEAPON_TYPE4'),get('F22_WEAPON_STATION'),get('F22_WEAPON_COUNT'),get('F22_TOF_NATIVE_VALID'),get('F22_TOF_SOURCE'),get('F22_TOF_SECONDS'),az,el))
    end
end
need_to_be_closed=false
