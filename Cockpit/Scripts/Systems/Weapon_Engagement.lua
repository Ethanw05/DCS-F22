-- GPL-3.0-or-later. Original kinematic display calculations, in SI units.
-- Timings predict constant velocity; they are not missile trajectory integration.
local M={}
function M.finite(v) return type(v)=='number' and v==v and math.abs(v)<1e9 end
function M.norm(v) return math.sqrt(v[1]^2+v[2]^2+v[3]^2) end
function M.sub(a,b) return {a[1]-b[1],a[2]-b[2],a[3]-b[3]} end
function M.dot(a,b) return a[1]*b[1]+a[2]*b[2]+a[3]*b[3] end
function M.advance(p,v,t) return {p[1]+v[1]*t,p[2]+v[2]*t,p[3]+v[3]*t} end
local function root(a,b,c)
    if math.abs(a)<1e-8 then return math.abs(b)>1e-8 and -c/b>0 and -c/b or nil end
    local d=b*b-4*a*c;if d<0 then return nil end
    local q=math.sqrt(d);local x,y=(-b-q)/(2*a),(-b+q)/(2*a)
    if x>0 and y>0 then return math.min(x,y) end
    return x>0 and x or y>0 and y or nil
end
function M.intercept(relative,target_velocity,speed)
    if not M.finite(speed) or speed<=0 then return nil end
    return root(M.dot(target_velocity,target_velocity)-speed^2,
        2*M.dot(relative,target_velocity),M.dot(relative,relative))
end
function M.time_to_active(relative,relative_velocity,active_range)
    if not M.finite(active_range) or active_range<=0 then return nil end
    if M.norm(relative)<=active_range then return 0 end
    return root(M.dot(relative_velocity,relative_velocity),2*M.dot(relative,relative_velocity),
        M.dot(relative,relative)-active_range^2)
end
-- A launch prediction can expire without the real seeker having switched on.
-- Never turn a timer crossing into an ACTIVE/acquisition state transition.
function M.countdown(total,stamp,now)
    if not (M.finite(total) and M.finite(stamp) and M.finite(now)) or total<0 or total>1000 or now<stamp-.1 then return nil end
    local remaining=total-math.max(0,now-stamp)
    return remaining>=-1 and math.max(0,remaining) or nil
end
function M.zone(range,minimum,maximum,turn)
    if not (M.finite(range) and M.finite(minimum) and M.finite(maximum)) or minimum<0 or maximum<=minimum then return nil end
    return {inside=range>=minimum and range<=maximum,too_close=range<minimum,
        turn=M.finite(turn) and turn>=minimum and turn<=maximum and range>=minimum and range<=turn or false}
end
return M
