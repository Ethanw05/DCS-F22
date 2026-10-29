-- GPL-3.0-or-later. Compare ranged estimates at actual RF reception epochs.
-- Estimated policy: 3-degree RF cone; six-second radar / 13-second DL motion.
local M = {}
local History = dofile(LockOn_Options.script_path .. 'Systems/Tactical_Radar_History.lua')
local positions, velocities = {'n', 'u', 'e'}, {'vn', 'vu', 've'}

local function finite(v)
    return type(v) == 'number' and v == v and math.abs(v) < 1e9
end

local function motion(o, dt, moving)
    local p = {}
    for i, axis in ipairs(positions) do
        local position, velocity = o[axis], o[velocities[i]]
        if not finite(position) or moving and not finite(velocity) then return end
        p[axis] = position + (moving and velocity * dt or 0)
    end
    return p
end

local function radar_estimate(radar, stamp, history)
    local measured = History.at(history, stamp)
    if measured then return measured, measured.position_sigma_m end
    local dt = stamp - radar.time
    if math.abs(dt) > 6 or math.abs(dt) > .25 and radar.velocity_valid ~= true then return end
    local ps, vs = radar.position_sigma_m, radar.velocity_sigma_mps
    if not finite(ps) or ps < 0 or not finite(vs) or vs < 0 then return end
    local p = motion(radar, dt, radar.velocity_valid)
    return p, math.sqrt(ps ^ 2 + dt ^ 2 * vs ^ 2 + 100 * math.abs(dt) ^ 3 / 3)
end

local function datalink_estimate(report, stamp)
    local base = report.observation_known == false and report.received or report.time
    if not finite(base) then return end
    local dt = stamp - base
    if math.abs(dt) > 13 then return end
    -- Unknown source-clock reports are receive-time estimates. Neither their
    -- clock qualification nor identity evidence is promoted by this projection.
    local p = motion(report, dt, true)
    return p, math.sqrt(150 ^ 2 + (25 * dt) ^ 2)
end

local function aligned(position, sigma, rf, identity_cone)
    if not position then return false end
    local origin, w = rf.bearing_origin, rf.world
    local d = {position.n - origin.n, position.u - origin.u, position.e - origin.e}
    local range = math.sqrt(d[1] ^ 2 + d[2] ^ 2 + d[3] ^ 2)
    if range < 40 then return false end
    local cone = identity_cone
    if not cone then
        -- Broad uncertain prediction cannot identify an emitter. Reciprocal
        -- uniqueness in Tactical_Association must additionally pass.
        if sigma / range > math.rad(3) then return false end
        cone = math.sqrt(math.rad(3) ^ 2 + (3 * sigma / range) ^ 2)
    end
    local cosine = (d[1] * w[1] + d[2] * w[2] + d[3] * w[3]) / range
    return cosine >= math.cos(cone)
end

local function fresh(ranged, rf, now, datalink)
    local time = datalink and ranged.observation_known == false and ranged.received or ranged.time
    if not finite(time) or now - time < 0 or now - time > (datalink and 13 or 6) then return false end
    return now - rf.time >= 0 and now - rf.time <= 12
end

function M.match(ranged, rf, now, history, datalink, identity_cone)
    if rf.general == 2 or rf.general == 3 then return false end
    if not rf.bearing_origin or not rf.world then return nil end
    for _, axis in ipairs(positions) do
        if not finite(ranged[axis]) then return nil end
    end
    if not fresh(ranged, rf, now, datalink) then return false end
    local p, sigma
    if datalink then p, sigma = datalink_estimate(ranged, rf.bearing_origin.time)
    else p, sigma = radar_estimate(ranged, rf.bearing_origin.time, history) end
    return aligned(p, sigma, rf, identity_cone)
end
return M
