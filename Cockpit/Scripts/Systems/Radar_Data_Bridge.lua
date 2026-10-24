-- GPL-3.0-or-later. Read-only bridge for documented DCS avSimpleRadar
-- STT parameters, *if* a compatible host publishes them. No invented contacts.
-- FC3 inherited radar may not publish these; an empty bridge is intentional.
local dt=0.05
make_default_activity(dt)
local input={
    distance=get_param_handle("RADAR_STT_RANGE"), -- meters
    az=get_param_handle("RADAR_STT_AZIMUTH"), -- radians
    el=get_param_handle("RADAR_STT_ELEVATION"), -- radians
    iff=get_param_handle("RADAR_STT_FRIENDLY"),
    power=get_param_handle("RADAR_PWR"),
    bus=get_param_handle("MAIN_POWER"),
    mode=get_param_handle("HUD_MODE"),
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
}
local lastDistance,lastAz,lastEl = nil,nil,nil
local motionAge=999
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
end
function post_initialize()
    clear()
end
function update()
    if input.power:get()<0.5 or input.bus:get()<0.5 then
        motionAge=999
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
        motionAge=999
        clear()
        return
    end
    if lastDistance==nil or math.abs(distance-lastDistance)>0.005 or
       math.abs(az-lastAz)>1e-6 or math.abs(el-lastEl)>1e-6 then
        motionAge=0
    else
        motionAge=motionAge+dt
    end
    lastDistance,lastAz,lastEl=distance,az,el
    -- A stale external parameter is not proof of a current lock.
    if motionAge>2.0 then clear();return end
    output.source:set(1)
    output.valid:set(1)
    output.gun:set(1)
    output.az:set(az)
    output.el:set(el)
    output.range:set(distance/1852.0)
    local iff=input.iff:get()
    output.iff:set((finite(iff) and (iff==1 or iff==0 or iff==-1)) and iff or -1)
    output.cue:set((math.abs(az)<math.rad(15) and math.abs(el)<math.rad(12.5)) and 1 or 0)
end
need_to_be_closed=false
