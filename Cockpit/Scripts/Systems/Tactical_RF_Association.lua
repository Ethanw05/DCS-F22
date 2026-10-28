-- GPL-3.0-or-later. Compare a radar estimate at the actual RF reception epoch.
-- Estimates/game policy: 3 degree RF cone, six-second CV prediction memory.
local M={}
local History=dofile(LockOn_Options.script_path..'Systems/Tactical_Radar_History.lua')
local function finite(v) return type(v)=='number' and v==v and math.abs(v)<1e9 end
local function estimate(radar,stamp,history)
    local measured=History.at(history,stamp)
    if measured then return measured,measured.position_sigma_m end
    local dt=stamp-radar.time
    if math.abs(dt)>6 or math.abs(dt)>.25 and radar.velocity_valid~=true then return end
    local ps,vs=radar.position_sigma_m,radar.velocity_sigma_mps
    if not finite(ps) or ps<0 or not finite(vs) or vs<0 then return end
    local p={}
    for i,axis in ipairs({'n','u','e'})do
        local position,velocity=radar[axis],radar[({'vn','vu','ve'})[i]]
        if not finite(position) or radar.velocity_valid and not finite(velocity) then return end
        p[axis]=position+(radar.velocity_valid and velocity*dt or 0)
    end
    return p,math.sqrt(ps^2+dt^2*vs^2+100*math.abs(dt)^3/3)
end
function M.match(radar,rf,now,history)
    local origin,w=rf.bearing_origin,rf.world
    if not origin or not w then return nil end -- old direction-only input
    if not finite(radar.n) or not finite(radar.u) or not finite(radar.e)then return nil end
    if now-radar.time<0 or now-radar.time>1 or now-rf.time<0 or now-rf.time>12 then return false end
    local p,sigma=estimate(radar,origin.time,history)
    if not p then return false end
    local d={p.n-origin.n,p.u-origin.u,p.e-origin.e}
    local range=math.sqrt(d[1]^2+d[2]^2+d[3]^2)
    if range<40 then return false end
    -- A broad uncertain prediction cannot identify an emitter. Keep it separate;
    -- the reciprocal uniqueness test in Tactical_Association still must pass.
    if sigma/range>math.rad(3) then return false end
    local cosine=(d[1]*w[1]+d[2]*w[2]+d[3]*w[3])/range
    return cosine>=math.cos(math.sqrt(math.rad(3)^2+(3*sigma/range)^2))
end
return M
