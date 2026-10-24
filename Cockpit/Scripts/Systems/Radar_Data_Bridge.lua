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
-- Search returns are a display-only B-scope: unlike a correlated TWS track,
-- the native contact parameter can represent more than one echo per aircraft.
local search={}
local countParam=get_param_handle("HUD_RADAR_SEARCH_RETURNS")
for idx=1,12 do
    local prefix=string.format("RADAR_CONTACT_%02d_",idx)
    local out=string.format("HUD_RWS_%02d_",idx)
    search[idx]={
        range=get_param_handle(prefix.."RANGE"),
        az=get_param_handle(prefix.."AZIMUTH"),
        time=get_param_handle(prefix.."TIME"),
        x=get_param_handle(out.."X"),
        y=get_param_handle(out.."Y"),
        valid=get_param_handle(out.."VALID"),
        lastRange=nil,lastAz=nil,lastTime=nil,age=999
    }
end
local lastDistance,lastAz,lastEl = nil,nil,nil
local motionAge=999
local function finite(x)
    return type(x)=="number" and x==x and math.abs(x)<1e9
end
local function clearSearch()
    countParam:set(0)
    for _,contact in ipairs(search) do
        contact.valid:set(0)
        contact.age=999
    end
end
local function updateSearch()
    local count=0
    for _,contact in ipairs(search) do
        local r,a,t=contact.range:get(),contact.az:get(),contact.time:get()
        local validReturn=finite(r) and finite(a) and finite(t) and
            r>40 and r<80*1852 and math.abs(a)<math.rad(60) and t>=0
        if validReturn then
            if contact.lastRange==nil or math.abs(r-contact.lastRange)>0.005 or
                math.abs(a-contact.lastAz)>1e-6 or
                math.abs(t-contact.lastTime)>0.005 then
                contact.age=0
            else
                contact.age=contact.age+dt
            end
            contact.lastRange,contact.lastAz,contact.lastTime=r,a,t
        else
            contact.age=999
            contact.lastRange=nil
        end
        if validReturn and contact.age<=2 then
            -- Scope normalized to fixed ±60-degree field and 80-NM radial range.
            contact.x:set((a/math.rad(60))*0.76)
            contact.y:set(0.61-1.18*(r/(80*1852)))
            contact.valid:set(1)
            count=count+1
        else
            contact.valid:set(0)
        end
    end
    countParam:set(count)
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
    clearSearch()
end
function update()
    if input.power:get()<0.5 or input.bus:get()<0.5 then
        motionAge=999
        clear()
        clearSearch()
        return
    end
    updateSearch()
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
