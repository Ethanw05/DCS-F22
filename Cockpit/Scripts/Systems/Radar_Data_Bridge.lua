-- GPL-3.0-or-later. Read-only bridge for documented DCS avSimpleRadar
-- STT parameters, *if* a compatible host publishes them. No invented contacts.
-- Only our prefixed native sensor in confirmed STT may supply a targeting cue.
local dt=0.05
make_default_activity(dt)
local project=dofile(LockOn_Options.script_path..'Systems/HUD_TargetMath.lua').new(
    dofile(LockOn_Options.script_path..'HUD/glass.lua'))
local input={
    distance=get_param_handle("F22N_RADAR_STT_RANGE"), -- meters
    az=get_param_handle("F22N_RADAR_STT_AZIMUTH"), -- radians
    el=get_param_handle("F22N_RADAR_STT_ELEVATION"), -- radians
    iff=get_param_handle("F22N_RADAR_STT_FRIENDLY"),
    power=get_param_handle("RADAR_PWR"),
    bus=get_param_handle("MAIN_POWER"),
    mode=get_param_handle("HUD_MODE"),
    nativeMode=get_param_handle("F22N_RADAR_MODE"),
    backend=get_param_handle("F22_RADAR_BACKEND_READY"),
}
local output={
    source=get_param_handle("HUD_RADAR_TRACK_SOURCE"),
    valid=get_param_handle("HUD_AA_TARGET_VALID"),
    cue=get_param_handle("HUD_AA_CUE_VALID"),
    gun=get_param_handle("HUD_GUN_TARGET_VALID"),
    az=get_param_handle("HUD_AA_TGT_AZ_RAD"),
    el=get_param_handle("HUD_AA_TGT_EL_RAD"),
    range=get_param_handle("HUD_AA_TGT_RANGE_NM"),
    iff=get_param_handle("HUD_AA_TGT_IFF"),
    closureValid=get_param_handle("HUD_AA_CLOSURE_VALID"),
    closure=get_param_handle("HUD_AA_TGT_CLOSURE_KTS"),
}
local previousSampleDistance,previousSampleAz,previousSampleEl=nil,nil,nil
local previousSampleTime=nil
local measuredClosure=0
local canMeasureClosure=false
local clock=0
local function finite(x)
    return type(x)=="number" and x==x and math.abs(x)<1e9
end
local function clear()
    output.valid:set(0)
    output.cue:set(0)
    output.gun:set(0)
    output.source:set(0)
    output.range:set(0)
    output.iff:set(-1)
    output.closureValid:set(0)
end
local td_names={'HUD_TD_VALID','HUD_TD_BOX_VALID','HUD_TD_ARROW_VALID','HUD_TD_LOCKED','HUD_TD_COAST','HUD_TD_FRIENDLY'}
local function clear_td()
    for _,name in ipairs(td_names) do get_param_handle(name):set(0) end
end
local function present_target()
    clear_td()
    local mode=input.mode:get()
    if input.power:get()<.5 or input.bus:get()<.5 or input.backend:get()<.5 or mode<1 or mode>6 then return end
    local locked=input.nativeMode:get()==3
    local r,a,e=input.distance:get(),input.az:get(),input.el:get()
    local age=0
    if not locked then
        if get_param_handle('F22_RADAR_DESIGNATION_VALID'):get()<.5 then return end
        r=get_param_handle('F22_RADAR_DESIGNATION_RANGE'):get()
        a=get_param_handle('F22_RADAR_DESIGNATION_AZ'):get()
        e=get_param_handle('F22_RADAR_DESIGNATION_EL'):get()
        age=get_param_handle('F22_RADAR_DESIGNATION_AGE'):get()
    end
    if not finite(r) or r<40 or r>300000 or not finite(a) or not finite(e) or
        math.abs(a)>math.pi or math.abs(e)>math.pi/2 or not finite(age) or age<0 or age>10 then return end
    local p=project(a,e)
    local friendly=get_param_handle('F22_RADAR_SELECTED_FRIENDLY'):get()>.5 or locked and input.iff:get()==1
    for name,value in pairs({HUD_TD_VALID=1,HUD_TD_FRIENDLY=friendly and 1 or 0,HUD_TD_LOCKED=locked and 1 or 0,
        HUD_TD_COAST=age>1 and 1 or 0,HUD_TD_BOX_VALID=p.visible and 1 or 0,
        HUD_TD_ARROW_VALID=p.visible and 0 or 1,HUD_TD_X=p.x,HUD_TD_Y=p.y,
        HUD_TD_ARROW_X=p.arrow_x,HUD_TD_ARROW_Y=p.arrow_y,
        HUD_TD_ARROW_ROT=p.rotation,HUD_TD_ANGLE_DEG=p.angle,HUD_TD_RANGE_NM=r/1852}) do get_param_handle(name):set(value) end
end
function post_initialize()
    clear()
    clear_td()
end
function update()
    clock=clock+dt
    present_target()
    get_param_handle('HUD_DT2_VALID'):set(0)
    local mode=input.mode:get()
    if input.power:get()>.5 and input.bus:get()>.5 and input.backend:get()>.5 and mode>=1 and mode<=6 and
        get_param_handle('F22_RADAR_SECONDARY_VALID'):get()>.5 then
        local a=get_param_handle('F22_RADAR_SECONDARY_AZ'):get()
        local e=get_param_handle('F22_RADAR_SECONDARY_EL'):get()
        if finite(a) and finite(e) then
            local p=project(a,e)
            get_param_handle('HUD_DT2_VALID'):set((p.visible or clock%1<.5) and 1 or 0)
            get_param_handle('HUD_DT2_OFFSCREEN'):set(p.visible and 0 or 1)
            get_param_handle('HUD_DT2_X'):set(p.visible and p.x or p.arrow_x)
            get_param_handle('HUD_DT2_Y'):set(p.visible and p.y or p.arrow_y)
        end
    end
    if input.power:get()<0.5 or input.bus:get()<0.5 or input.backend:get()<.5 or input.nativeMode:get()~=3 then
        previousSampleDistance=nil
        canMeasureClosure=false
        clear()
        return
    end
    local mode=input.mode:get()
    if mode<2 or mode>6 then
        clear()
        return
    end
    local distance,az,el=input.distance:get(),input.az:get(),input.el:get()
    -- avSimpleRadar reports STT only; native FC3 may leave these handles zero.
    -- Do not silently treat nonzero mode selection as target acquisition.
    if not finite(distance) or distance<40 or distance>300000 or
       not finite(az) or not finite(el) or math.abs(az)>math.pi/2 or
       math.abs(el)>math.pi/2 then
        previousSampleDistance=nil
        canMeasureClosure=false
        clear()
        return
    end
    do
        if previousSampleDistance and previousSampleTime then
            local interval=clock-previousSampleTime
            if interval>=dt and interval<4 then
                local relativeRangeRate=(previousSampleDistance-distance)/interval
                local angularAz=(az-previousSampleAz)/interval
                local angularEl=(el-previousSampleEl)/interval
                if math.abs(relativeRangeRate)<1500 and math.abs(angularAz)<1.5 and
                    math.abs(angularEl)<1.5 then
                    measuredClosure=relativeRangeRate*1.943844492
                    canMeasureClosure=true
                else
                    canMeasureClosure=false
                end
            end
        end
        previousSampleDistance=distance
        previousSampleAz=az
        previousSampleEl=el
        previousSampleTime=clock
    end
    -- Confirmed native STT remains valid for an unchanging stationary LOS.
    output.source:set(1)
    output.valid:set(1)
    output.gun:set(1)
    output.az:set(az)
    -- Native elevation is atan2(up,horizontal); HUD uses atan2(up,forward).
    output.el:set(math.atan2(math.sin(el),math.cos(el)*math.cos(az)))
    output.range:set(distance/1852.0)
    output.closureValid:set(canMeasureClosure and 1 or 0)
    output.closure:set(measuredClosure)
    local iff=input.iff:get()
    output.iff:set((finite(iff) and (iff==1 or iff==0 or iff==2 or iff==-1)) and iff or -1)
    output.cue:set(project(az,el).visible and 1 or 0)
end
need_to_be_closed=false
