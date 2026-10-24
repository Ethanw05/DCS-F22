-- GPL-3.0-or-later; F-22 DCS independent navigation producer.
-- Uses real mission-editor route, ownship coordinates and attitude.
-- Does NOT synthesize radar contacts or A/G weapon target designations.
local dev = GetSelf()
local base = get_base_data()
dofile(LockOn_Options.script_path.."command_defs.lua")
local geom = dofile(LockOn_Options.script_path.."Systems/NavGeometry.lua")
local dt=0.05
make_default_activity(dt)
local p={
    power=get_param_handle("MAIN_POWER"),
    waypoint=get_param_handle("HUD_WP_VALID"),
    cue=get_param_handle("HUD_WP_CUE_VALID"),
    az=get_param_handle("HUD_WP_AZ_RAD"),
    el=get_param_handle("HUD_WP_EL_RAD"),
    distance=get_param_handle("HUD_WP_RANGE_NM"),
    index=get_param_handle("HUD_WP_INDEX"),
    bearing=get_param_handle("HUD_WP_BEARING_DEG"),
    bearingValid=get_param_handle("HUD_WP_BRG_VALID"),
}
local nextSteer=Keys.PlaneChangeTarget
local prevSteer=1315 -- existing ICP previous waypoint command
dev:listen_command(nextSteer)
dev:listen_command(prevSteer)
local route={}
local active=2 -- first waypoint after DCS takeoff/spawn point
local function clear()
    p.waypoint:set(0)
    p.cue:set(0)
    p.az:set(0)
    p.el:set(0)
    p.distance:set(0)
    p.index:set(0)
    p.bearing:set(0)
    p.bearingValid:set(0)
end
local function validPoint(w)
    return type(w)=="table" and type(w.x)=="number" and
        type(w.y)=="number" and type(w.alt)=="number"
end
local function readRoute()
    route={}
    if type(get_mission_route)~="function" then return end
    local ok,results=pcall(get_mission_route)
    if not ok or type(results)~="table" then return end
    for _,entry in ipairs(results.route or results) do
        if validPoint(entry) then route[#route+1]=entry end
    end
    if #route==1 then active=1
    elseif #route>1 then active=2
    else active=0 end
end
local function increment(n)
    if #route<1 then return end
    local first=(#route==1) and 1 or 2
    active=active+n
    if active>#route then active=first end
    if active<first then active=#route end
end
function post_initialize()
    clear()
    readRoute()
end
function SetCommand(command,value)
    -- Only act on positive edges. If a button is momentary we do not double step.
    if value~=nil and value<=0 then return end
    if command==nextSteer then increment(1)
    elseif command==prevSteer then increment(-1) end
end
function update()
    if p.power:get()<0.5 or not validPoint(route[active]) then clear(); return end
    if type(base.getSelfCoordinates)~="function" then clear(); return end
    local ok,x,alt,y=pcall(base.getSelfCoordinates)
    if not ok or type(x)~="number" or type(y)~="number"
            or type(alt)~="number" then clear(); return end
    local w=route[active]
    local dx,dy,dz=w.x-x,w.y-y,w.alt-alt
    -- Project with same compass convention as Avionics.lua HUD heading.
    local head=(2*math.pi - base.getHeading())%(2*math.pi)
    local az,el,range=geom.project(dx,dy,dz,head,base.getPitch(),base.getRoll())
    if not range or range<1 then clear(); return end
    p.index:set(active)
    p.distance:set(range/1852.0)
    -- Bearing from aircraft to the selected waypoint in DCS world coordinates:
    -- horizontal x=north, horizontal map y=east. True/world reference.
    -- Lua 5.1 lacks a portable atan2; handle the quadrants explicitly.
    local horizontal=math.sqrt(dx*dx+dy*dy)
    if horizontal > 1.0 then
        local bearing
        if dx>0 then bearing=math.atan(dy/dx)
        elseif dx<0 then bearing=math.atan(dy/dx)+math.pi
        elseif dy>0 then bearing=math.pi/2
        else bearing=3*math.pi/2 end
        p.bearing:set((bearing*180/math.pi+360)%360)
        p.bearingValid:set(1)
    else
        p.bearing:set(0)
        p.bearingValid:set(0)
    end
    p.waypoint:set(1)
    if az and el and math.abs(az)<math.rad(15) and math.abs(el)<math.rad(12.5) then
        p.az:set(az)
        p.el:set(el)
        p.cue:set(1)
    else
        p.cue:set(0)
    end
end
need_to_be_closed=false
