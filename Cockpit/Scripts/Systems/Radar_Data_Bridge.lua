-- GPL-3.0-or-later. HUD consumer of the radar owner's timestamped snapshots.
-- Search designations remain display cues; only fresh confirmed STT supplies
-- weapon/gun target validity. Native polar caches are never a fallback.
local dt=.05
make_default_activity(dt)
local project=dofile(LockOn_Options.script_path..'Systems/HUD_TargetMath.lua').new(
    dofile(LockOn_Options.script_path..'HUD/glass.lua'))
local stt=dofile(LockOn_Options.script_path..'Systems/Radar_STT.lua')
local handles={}
local function h(n)if not handles[n]then handles[n]=get_param_handle(n)end;return handles[n]end
local function get(n)return h(n):get()end
local function put(n,v)h(n):set(v)end
local clock=0
local function finite(v)return type(v)=='number' and v==v and math.abs(v)<1e9 end
local function clear()
    for _,name in ipairs({'HUD_AA_TARGET_VALID','HUD_AA_CUE_VALID','HUD_GUN_TARGET_VALID',
        'HUD_RADAR_TRACK_SOURCE','HUD_AA_TGT_RANGE_NM','HUD_AA_CLOSURE_VALID','HUD_AA_TGT_CLOSURE_KTS',
        'HUD_TD_VALID','HUD_TD_BOX_VALID','HUD_TD_ARROW_VALID','HUD_TD_LOCKED','HUD_TD_COAST',
        'HUD_TD_FRIENDLY','HUD_DT2_VALID'})do put(name,0)end
    put('HUD_AA_TGT_IFF',-1)
end
function post_initialize()clear()end
function update()
    clock=type(get_model_time)=='function' and get_model_time() or clock+dt
    clear()
    local mode=get('HUD_MODE')
    if not finite(clock) or get('RADAR_PWR')<.5 or get('MAIN_POWER')<.5 or
        get('F22_RADAR_BACKEND_READY')<.5 or mode<1 or mode>6 then return end
    local locked=get('F22N_RADAR_MODE')==3
    local track=stt.read(get,clock)
    local r,a,e,age
    if locked then
        if not track then return end
        r,a,e,age=track.range,track.az,track.el,track.age
    else
        if get('F22_RADAR_DESIGNATION_VALID')<.5 then return end
        r,a,e,age=get('F22_RADAR_DESIGNATION_RANGE'),get('F22_RADAR_DESIGNATION_AZ'),
            get('F22_RADAR_DESIGNATION_EL'),get('F22_RADAR_DESIGNATION_AGE')
    end
    if not finite(r) or r<40 or r>300000 or not finite(a) or not finite(e) or
        math.abs(a)>math.pi or math.abs(e)>math.pi/2 or not finite(age) or age<0 or age>10 then return end
    local p=project(a,e)
    local friendly=locked and track.iff==1 or not locked and get('F22_RADAR_SELECTED_FRIENDLY')>.5
    for name,value in pairs({HUD_TD_VALID=1,HUD_TD_FRIENDLY=friendly and 1 or 0,HUD_TD_LOCKED=locked and 1 or 0,
        HUD_TD_COAST=age>1 and 1 or 0,HUD_TD_BOX_VALID=p.visible and 1 or 0,
        HUD_TD_ARROW_VALID=p.visible and 0 or 1,HUD_TD_X=p.x,HUD_TD_Y=p.y,
        HUD_TD_ARROW_X=p.arrow_x,HUD_TD_ARROW_Y=p.arrow_y,HUD_TD_ARROW_ROT=p.rotation,
        HUD_TD_ANGLE_DEG=p.angle,HUD_TD_RANGE_NM=r/1852})do put(name,value)end
    if get('F22_RADAR_SECONDARY_VALID')>.5 then
        local sa,se=get('F22_RADAR_SECONDARY_AZ'),get('F22_RADAR_SECONDARY_EL')
        if finite(sa)and finite(se)then
            local q=project(sa,se)
            put('HUD_DT2_VALID',(q.visible or clock%1<.5)and 1 or 0)
            put('HUD_DT2_OFFSCREEN',q.visible and 0 or 1)
            put('HUD_DT2_X',q.visible and q.x or q.arrow_x);put('HUD_DT2_Y',q.visible and q.y or q.arrow_y)
        end
    end
    if not track or mode<2 then return end
    put('HUD_RADAR_TRACK_SOURCE',1);put('HUD_AA_TARGET_VALID',1);put('HUD_GUN_TARGET_VALID',1)
    put('HUD_AA_TGT_AZ_RAD',track.az)
    put('HUD_AA_TGT_EL_RAD',math.atan2(math.sin(track.el),math.cos(track.el)*math.cos(track.az)))
    put('HUD_AA_TGT_RANGE_NM',track.range/1852);put('HUD_AA_TGT_IFF',track.iff)
    put('HUD_AA_CUE_VALID',p.visible and 1 or 0)
    if track.closure_valid and finite(track.closure)then
        put('HUD_AA_CLOSURE_VALID',1);put('HUD_AA_TGT_CLOSURE_KTS',track.closure)
    end
end
need_to_be_closed=false
