-- GPL-3.0-or-later. Project body rays onto the collimator's focal plane.
-- Native linear matrix translations consume right/forward and up/forward
-- slopes, not atan angles. Keep solver/telemetry angular contracts unchanged.
local M={}
local halfpi=math.pi/2
local function finite(v)return type(v)=='number' and v==v and math.abs(v)<math.huge end
function M.planar(az,el)
    -- Independent horizontal/vertical planar angles (atan(right/forward),
    -- atan(up/forward)); not spherical azimuth/elevation.
    if not finite(az)or not finite(el)or math.abs(az)>=halfpi or math.abs(el)>=halfpi then return end
    return math.tan(az),math.tan(el)
end
function M.polar(az,el)
    -- Spherical LOS (radar/native seeker): the vertical slope also depends on
    -- azimuth. Rear-hemisphere rays cannot be reflected onto the forward HUD.
    if not finite(az)or not finite(el)or math.abs(el)>halfpi then return end
    local forward=math.cos(el)*math.cos(az)
    if forward<=1e-6 then return end
    return math.cos(el)*math.sin(az)/forward,math.sin(el)/forward
end
return M
