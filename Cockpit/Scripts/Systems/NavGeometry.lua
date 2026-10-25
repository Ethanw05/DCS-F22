-- Standalone, deterministic right-handed HUD navigation geometry.
-- World DCS map x=north, map y=east (getSelfCoordinates x, altitude, z).
-- Positive heading = clockwise from north; positive pitch = nose up.
-- Roll convention requires in-game comparison with DCS base sensor values.
local M={}
local pi=math.pi
-- DCS Lua 5.1 math.atan supports one argument; forward is guaranteed positive.
function M.wrap(angle)
    return (angle + 2*pi) % (2*pi)
end
function M.body(dx,dy,dz,heading,pitch,roll)
    for _,v in ipairs({dx,dy,dz,heading,pitch,roll}) do
        if type(v)~='number' or v~=v or math.abs(v)==math.huge then return end
    end
    local sh,ch=math.sin(heading),math.cos(heading)
    local forward0=dx*ch+dy*sh
    local right0=-dx*sh+dy*ch
    local sp,cp=math.sin(pitch),math.cos(pitch)
    local forward=forward0*cp+dz*sp
    local up0=-forward0*sp+dz*cp
    local sr,cr=math.sin(roll),math.cos(roll)
    local right=right0*cr-up0*sr
    local up=right0*sr+up0*cr
    return forward,right,up
end
function M.project(dx,dy,dz,heading,pitch,roll)
    local forward,right,up=M.body(dx,dy,dz,heading,pitch,roll)
    if not forward then return nil,nil,nil end
    local distance=math.sqrt(dx*dx+dy*dy+dz*dz)
    if distance < 0.001 or forward <= 0 then return nil, nil, distance end
    return math.atan(right/forward),math.atan(up/forward),distance
end
return M
