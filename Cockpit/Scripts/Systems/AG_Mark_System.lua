-- GPL-3.0-or-later; game-world A/G markpoint backed by DCS terrain.
-- Markpoint is a terrain LOS coordinate, NOT a JDAM designation, weapon
-- employment calculation, laser spot or F-22 operational avionics feature.
local dev=GetSelf()
local base=get_base_data()
local geom=dofile(LockOn_Options.script_path.."Systems/NavGeometry.lua")
local command=10074 -- dispatched by cockpit ICP MARK while in A/G master mode
dev:listen_command(command)
local dt=0.05
make_default_activity(dt)
local power=get_param_handle("MAIN_POWER")
local mode=get_param_handle("HUD_MODE")
local valid=get_param_handle("HUD_AG_TARGET_VALID")
local cue=get_param_handle("HUD_AG_CUE_VALID")
local azparam=get_param_handle("HUD_AG_TGT_AZ_RAD")
local elparam=get_param_handle("HUD_AG_TGT_EL_RAD")
local rangeparam=get_param_handle("HUD_AG_TGT_RANGE_NM")
local target=nil
local terrain=nil
local function publishInvalid()
    valid:set(0)
    cue:set(0)
    rangeparam:set(0)
end
local function pos()
    if type(base.getSelfCoordinates)~="function" then return nil end
    local ok,x,alt,y=pcall(base.getSelfCoordinates)
    if not ok or type(x)~="number" or type(y)~="number" or
        type(alt)~="number" then return nil end
    return x,alt,y
end
local function intersection(x,alt,y,heading,pitch)
    if not terrain or type(terrain.GetHeight)~="function" then return nil end
    -- DCS terrain axes x=north, z=east, y=altitude.
    local cosPitch=math.cos(pitch)
    local dn=math.cos(heading)*cosPitch
    local de=math.sin(heading)*cosPitch
    local du=math.sin(pitch)
    -- Trace boresight against actual terrain in 250m increments then bisect.
    -- 40km max is a local-mark feature range limit, not a weapon range.
    local previous=0
    for distance=250,40000,250 do
        local north=x+dn*distance
        local east=y+de*distance
        local rayAlt=alt+du*distance
        local ok,height=pcall(terrain.GetHeight,north,east)
        if not ok or type(height)~="number" then return nil end
        if rayAlt <= height then
            local low,high=previous,distance
            local hitHeight=height
            for i=1,12 do
                local mid=(low+high)/2
                local mx,my=x+dn*mid,y+de*mid
                local validSample,sampled=pcall(terrain.GetHeight,mx,my)
                if not validSample or type(sampled)~="number" then return nil end
                if alt+du*mid>sampled then low=mid else high=mid;hitHeight=sampled end
            end
            local hit=(low+high)/2
            return {x=x+dn*hit,y=y+de*hit,alt=hitHeight}
        end
        previous=distance
    end
    return nil
end
function post_initialize()
    publishInvalid()
    local ok,t=pcall(require,"terrain")
    if ok and type(t)=="table" then terrain=t end
end
function SetCommand(id,value)
    if id~=command or (value~=nil and value<=0) then return end
    if power:get()<0.5 or mode:get()~=7 then return end
    -- MARK key toggles the local designation.
    if target then target=nil;publishInvalid();return end
    local x,alt,y=pos()
    if not x then publishInvalid();return end
    local heading=(2*math.pi-base.getHeading())%(2*math.pi)
    target=intersection(x,alt,y,heading,base.getPitch())
    if not target then publishInvalid() end
end
function update()
    if power:get()<0.5 or mode:get()~=7 or not target then
        publishInvalid()
        return
    end
    local x,alt,y=pos()
    if not x then publishInvalid();return end
    local az,el,range=geom.project(target.x-x,target.y-y,target.alt-alt,
        (2*math.pi-base.getHeading())%(2*math.pi),base.getPitch(),base.getRoll())
    if not range or range<1 then publishInvalid();return end
    valid:set(1)
    rangeparam:set(range/1852.0)
    if az and el and math.abs(az)<math.rad(15) and math.abs(el)<math.rad(12.5) then
        azparam:set(az)
        elparam:set(el)
        cue:set(1)
    else
        cue:set(0)
    end
end
need_to_be_closed=false
