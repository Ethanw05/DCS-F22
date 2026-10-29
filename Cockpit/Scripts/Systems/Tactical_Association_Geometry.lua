-- GPL-3.0-or-later. Bounded evidence gates for the awareness picture.
-- Distances/cones below are simulator estimates, not authenticated F-22 values.
local M = {}
local RF = dofile(LockOn_Options.script_path .. 'Systems/Tactical_RF_Association.lua')
local Datalink = dofile(LockOn_Options.script_path .. 'Systems/Datalink_Tracks.lua')
local Stale = dofile(LockOn_Options.script_path .. 'Systems/Tactical_Stale_Donor.lua')
local position_axes, velocity_axes = {'n', 'u', 'e'}, {'vn', 'vu', 've'}
local leases = {radar = 6, rf = 12, mws = .5, datalink = 13, irst = 1}

local function finite(v)
    return type(v) == 'number' and v == v and math.abs(v) < 1e9
end

local function fields(o, axes)
    for _, axis in ipairs(axes) do
        if not finite(o[axis]) then return false end
    end
    return true
end

local function current(entry, now)
    local o = entry.observation
    local time = o.time
    if entry.sensor == 'datalink' and o.observation_known == false then time = o.received end
    return finite(time) and now - time >= 0 and now - time <= leases[entry.sensor]
end

function M.position(sensor, o, now)
    if not fields(o, position_axes) or not fields(o, velocity_axes) then return end
    if sensor == 'datalink' then
        if o.observation_known == false and not finite(o.received) then return end
        return Datalink.position(o, now)
    end
    if sensor ~= 'radar' then return end
    local dt = now - o.time
    if dt < 0 or dt > 6 or dt > .25 and o.velocity_valid ~= true then return end
    local p = {}
    for i, axis in ipairs(position_axes) do p[axis] = o[axis] + o[velocity_axes[i]] * dt end
    return p
end

local function object_class(entry)
    if entry.sensor == 'mws' then return 'missile' end
    if entry.sensor == 'rf' then
        if entry.observation.general == 3 then return 'missile' end
        if entry.observation.general == 2 then return 'surface' end
    end
    return 'air'
end

local function angular_score(x, y, cone)
    local az = (x.az - y.az + math.pi) % (2 * math.pi) - math.pi
    if math.abs(az) > cone or math.abs(x.el - y.el) > cone then return end
    return (az ^ 2 + (x.el - y.el) ^ 2) / cone ^ 2
end

local function ppli_rf(a, b, now)
    if a.sensor ~= 'datalink' or b.sensor ~= 'rf' then return end
    local x, y = a.observation, b.observation
    if x.ppli ~= true and x.ppli ~= 1 then return end
    if not x.friendly or x.source ~= x.reporter or x.source ~= y.source then return end
    -- Native cooperative PPLI sender and qualified RWR source are world IDs.
    -- Own radar / reporter-local surveillance IDs never enter this rule.
    local matched = RF.match(x, y, now, nil, true, math.rad(6))
    if matched == true then return -1, true end
    if matched == nil and now - y.time <= 1 and angular_score(x, y, math.rad(6)) then return -1, true end
end

local function position_score(a, b, now)
    local x, y, p, q = a.observation, b.observation, a.position, b.position
    local distance, velocity = 0, 0
    for i, axis in ipairs(position_axes) do
        distance = distance + (p[axis] - q[axis]) ^ 2
        velocity = velocity + (x[velocity_axes[i]] - y[velocity_axes[i]]) ^ 2
    end
    local age = math.max(0, now - x.time) + math.max(0, now - y.time)
    local margin = math.min(1150, 500 + 25 * age)
    if distance > margin ^ 2 or velocity > 100 ^ 2 then return end
    return distance / margin ^ 2 + .1 * velocity / 100 ^ 2, true
end

local function ranged_rf(a, b, now)
    if b.sensor ~= 'rf' or (a.sensor ~= 'radar' and a.sensor ~= 'datalink') then return end
    return RF.match(a.observation, b.observation, now, a.history, a.sensor == 'datalink')
end

local function bearing_score(a, b, now)
    -- Body-angle fallback is only meaningful for current local observations.
    if a.sensor ~= 'datalink' and now - a.observation.time > 1 then return end
    if b.sensor ~= 'datalink' and now - b.observation.time > 1 then return end
    if a.sensor == 'datalink' and not a.position then return end
    if b.sensor == 'datalink' and not b.position then return end
    if angular_score(a.observation, b.observation, math.rad(3)) then return 0, false end
end

local function coasting_report(a, b, now)
    if a.sensor ~= 'datalink' or current(a, now) or not a.unchanged then return false end
    return b.unchanged or current(b, now)
end

function M.continuity(a, b, now)
    -- A slow unchanged report must not create a second aircraft as soon as
    -- prediction expires. Keep its established association, not its freshness.
    -- Source keys include epoch; changed/reused reports cannot inherit this.
    if a.identity ~= b.identity or not a.previous or not b.previous then return end
    if object_class(a) ~= object_class(b) then return end
    -- A fresh geometrically qualified competing report always outranks coast.
    if coasting_report(a, b, now) or coasting_report(b, a, now) then return 4, true end
end

function M.score(a, b, now)
    if object_class(a) ~= object_class(b) then return end
    -- An established unchanged donor already belongs to this object. Its old
    -- straight-line estimate must not split the object when radar sees a turn.
    local coast = M.continuity(a, b, now)
    if coast then return coast, true end
    local delayed, delayed_ranked, veto, confirm = Stale.score(a, b, now)
    if confirm then return delayed, delayed_ranked, veto, true end
    if not current(a, now) or not current(b, now) then return end
    local identity = ppli_rf(a, b, now) or ppli_rf(b, a, now)
    if identity then return identity, true end
    if a.position and b.position then
        local score, ranked = position_score(a, b, now)
        return score, ranked, score == nil
    end
    local matched = ranged_rf(a, b, now)
    if matched == nil then matched = ranged_rf(b, a, now) end
    if matched ~= nil then
        if matched then return 0, false end
        return
    end
    return bearing_score(a, b, now)
end
return M
