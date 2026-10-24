-- Display-only point-mass impact prediction (NOT a functional F-22
-- CCIP/CCRP weapons computer and NOT valid for JDAM guidance/release).
local dev=GetSelf()
local data=get_base_data()
local ballistic=dofile(LockOn_Options.script_path.."Systems/Ballistic_Point_Mass.lua")
local project=dofile(LockOn_Options.script_path.."Systems/NavGeometry.lua")
local ccrp=dofile(LockOn_Options.script_path.."Systems/AG_Release_Geometry.lua")
local cadence=0.10
make_default_activity(cadence)
local power=get_param_handle("MAIN_POWER")
local mode=get_param_handle("HUD_MODE")
local submode=get_param_handle("HUD_AG_SUBMODE")
local estimate=get_param_handle("HUD_AG_CCIP_EST_VALID")
local cue=get_param_handle("HUD_AG_CCIP_CUE_VALID")
local azOut=get_param_handle("HUD_AG_CCIP_AZ_RAD")
local elOut=get_param_handle("HUD_AG_CCIP_EL_RAD")
local tofOut=get_param_handle("HUD_AG_CCIP_TOF_SEC")
local rangeOut=get_param_handle("HUD_AG_CCIP_RANGE_NM")
local markValid=get_param_handle("HUD_AG_TARGET_VALID")
local markNorth=get_param_handle("HUD_AG_MARK_NORTH")
local markEast=get_param_handle("HUD_AG_MARK_EAST")
local markAlt=get_param_handle("HUD_AG_MARK_ALT")
local ccrpValid=get_param_handle("HUD_AG_CCRP_EST_VALID")
local ccrpSeconds=get_param_handle("HUD_AG_CCRP_TIME_SEC")
local terrain=nil
local previous=nil
local previousTime=nil
local function clear()
    estimate:set(0)
    cue:set(0)
    ccrpValid:set(0)
    tofOut:set(0)
    rangeOut:set(0)
end
local function coords()
    if type(data.getSelfCoordinates)~="function" then return nil end
    local ok,n,h,e=pcall(data.getSelfCoordinates)
    if not ok or type(n)~="number" or type(h)~="number"
       or type(e)~="number" then return nil end
    return {n=n,h=h,e=e}
end
function post_initialize()
    clear()
    previous=nil
    previousTime=nil
    local ok,t=pcall(require,"terrain")
    if ok and type(t)=="table" and type(t.GetHeight)=="function" then terrain=t end
end
function update()
    local now=type(get_model_time)=="function" and get_model_time() or
        ((previousTime or 0)+cadence)
    local pos=coords()
    if not pos then clear();return end
    if not previous or not previousTime or now<=previousTime or now-previousTime>1.0 then
        previous=pos
        previousTime=now
        clear()
        return
    end
    local dt=now-previousTime
    local vn=(pos.n-previous.n)/dt
    local ve=(pos.e-previous.e)/dt
    local vu=(pos.h-previous.h)/dt
    previous=pos
    previousTime=now
    if power:get()<0.5 or mode:get()~=7 or dt<0.02 or
       math.sqrt(vn*vn+ve*ve)<30 then
        clear()
        return
    end
    if submode:get()==3 then
        clear()
        if markValid:get()<0.5 then return end
        local solution=ccrp.timeToRelease(pos.n,pos.e,pos.h,vn,ve,vu,
            markNorth:get(),markEast:get(),markAlt:get())
        if solution then
            ccrpValid:set(1)
            ccrpSeconds:set(solution.seconds)
        end
        return
    end
    if submode:get()~=2 or not terrain then clear();return end
    local result=ballistic.impact(pos.n,pos.e,pos.h,vn,ve,vu,
        function(n,e) return terrain.GetHeight(n,e) end)
    if not result then clear();return end
    local heading=(2*math.pi-data.getHeading())%(2*math.pi)
    local az,el,range=project.project(result.north-pos.n,
        result.east-pos.e,result.alt-pos.h,heading,data.getPitch(),data.getRoll())
    if not range or not az or not el then clear();return end
    estimate:set(1)
    tofOut:set(result.fall_time)
    rangeOut:set(result.slant/1852)
    if math.abs(az)<math.rad(15) and math.abs(el)<math.rad(12.5) then
        azOut:set(az)
        elOut:set(el)
        cue:set(1)
    else
        cue:set(0)
    end
end
need_to_be_closed=false
