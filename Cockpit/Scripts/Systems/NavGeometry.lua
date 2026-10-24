-- Standalone, deterministic right-handed HUD navigation geometry.
-- World DCS map x=east, y=north (aircraft getSelfCoordinates x, altitude, z).
-- Positive heading = clockwise from north; positive pitch = nose up.
-- Roll convention requires in-game comparison with DCS base sensor values.
local M={}
local pi=math.pi
local atan=math.atan
function M.wrap(angle)
    return (angle + 2*pi) % (2*pi)
end
function M.project(dx,dy,dz,heading,pitch,roll)
    if dx ~= dx or dy ~= dy or dz ~= dz then return nil end
    local sh,ch=math.sin(heading),math.cos(heading)
    local forward0=dx*sh+dy*ch
    local right0=dx*ch-dy*sh
    local sp,cp=math.sin(pitch),math.cos(pitch)
    local forward=forward0*cp+dz*sp
    local up0=-forward0*sp+dz*cp
    local sr,cr=math.sin(roll),math.cos(roll)
    local right=right0*cr-up0*sr
    local up=right0*sr+up0*cr
    local distance=math.sqrt(dx*dx+dy*dy+dz*dz)
    if distance < 0.001 or forward <= 0 then return nil, nil, distance end
    return atan(right,forward),atan(up,forward),distance
end
return M
