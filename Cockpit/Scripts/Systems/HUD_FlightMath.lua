-- GPL-3.0-or-later. Pure HUD computations: SI inputs, angular outputs in radians.
local M={}
local pi=math.pi
function M.finite(v) return type(v)=="number" and v==v and math.abs(v)<1e12 end
function M.atan2(y,x)
    if x>0 then return math.atan(y/x) end
    if x<0 then return math.atan(y/x)+(y>=0 and pi or -pi) end
    if y>0 then return pi/2 elseif y<0 then return -pi/2 end
    return 0
end
function M.clamp(x,a,b) return math.max(a,math.min(b,x)) end
-- Adopted Hornet E-bracket presentation: linear target-minus-measured AoA.
-- Its 10-degree radial limit includes the fixed 60-DI lateral spacing
-- (1 DI = 0.34 mrad); landing.lua owns the matching glyph geometry.
local bracket_lateral_rad = 60 * 0.00034
local bracket_vertical_limit_rad = math.sqrt(math.rad(10)^2 - bracket_lateral_rad^2)
function M.approach_offset(aoa_deg, reference_deg)
    if not M.finite(aoa_deg) or not M.finite(reference_deg) then return nil end
    local error_rad = math.rad(reference_deg - aoa_deg)
    return M.clamp(error_rad, -bracket_vertical_limit_rad, bracket_vertical_limit_rad)
end
function M.project(n,e,u,heading,pitch,roll)
    if not (M.finite(n) and M.finite(e) and M.finite(u)) then return nil end
    local forward=n*math.cos(heading)+e*math.sin(heading)
    local right=-n*math.sin(heading)+e*math.cos(heading)
    local up=-forward*math.sin(pitch)+u*math.cos(pitch)
    forward=forward*math.cos(pitch)+u*math.sin(pitch)
    local body_right=right*math.cos(roll)-up*math.sin(roll)
    local body_up=right*math.sin(roll)+up*math.cos(roll)
    if forward<1 or n*n+e*e+u*u<25 then return nil end
    return M.atan2(body_right,forward),M.atan2(body_up,forward)
end
-- Perfect-gas pitot relations (gamma=1.4), including a normal shock above M1.
-- NASA NACA Report 1135; no position/instrument error is modeled.
function M.pitot_ratio(m)
    if m<=1 then return (1+0.2*m*m)^3.5 end
    return (1.2*m*m)^3.5*(2.4/(2.8*m*m-0.4))^2.5
end
function M.cas(tas,sound,pressure)
    if not (M.finite(tas) and M.finite(sound) and M.finite(pressure))
        or tas<0 or sound<100 or pressure<=0 then return nil end
    local impact=pressure*(M.pitot_ratio(tas/sound)-1)
    local lo,hi=0,10
    if impact>101325*(M.pitot_ratio(hi)-1) then return nil end
    for i=1,45 do
        local mid=(lo+hi)/2
        if 101325*(M.pitot_ratio(mid)-1)<impact then lo=mid else hi=mid end
    end
    return (lo+hi)*0.5*340.293988
end
function M.ttg(distance,speed)
    if not M.finite(distance) or not M.finite(speed) or distance<0 or speed<1 then return nil end
    local sec=math.floor(distance/speed+0.5)
    if sec>359999 then return nil end
    return string.format("%02d:%02d:%02d",math.floor(sec/3600),math.floor(sec/60)%60,sec%60)
end
return M
