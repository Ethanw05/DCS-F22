-- GPL-3.0-or-later. Estimated surface intersection of a received RF direction.
-- Mod assumptions: stationary ground emitter, 1-degree angle and 50-m height
-- envelope. No emitter positions or signal-strength-to-distance conversion.
local M = { max_tracks = 16, max_range = 160000, step = 1000,
    lifetime = 6, max_radius = 10000, angle_error = math.rad(1) }
local function finite(value)
    return type(value) == 'number' and value == value and math.abs(value) < 1e9
end
local function position(value)
    return type(value) == 'table' and finite(value.n) and finite(value.u) and finite(value.e)
end
local function direction(world)
    if type(world) ~= 'table' then return false end
    local n, u, e = unpack(world)
    if not finite(n) or not finite(u) or not finite(e) then return false end
    return math.abs(n*n + u*u + e*e - 1) <= .001
end
local function current_origin(origin, stamp, now)
    if not position(origin) or not finite(origin.time) or not finite(stamp) then return false end
    return math.abs(origin.time - stamp) <= .01 and now - stamp >= 0 and now - stamp <= M.lifetime
end
local function received(contact, bearing, now)
    if contact.general ~= 2 or not contact.bearing_compensated or not bearing then return end
    local origin, world = bearing.origin, bearing.world
    if not current_origin(origin, bearing.stamp, now) or not direction(world) then return end
    return origin, world
end
local function clearance(height, origin, world, distance)
    local n = origin.n + distance * world[1]
    local e = origin.e + distance * world[3]
    local ok, ground = pcall(height, n, e)
    if not ok or not finite(ground) then return nil end
    return origin.u + distance * world[2] - ground
end
local function bracket(height, origin, world)
    local first = clearance(height, origin, world, 0)
    if not first or first <= 1 then return nil, nil, 2 end
    for i = 1, M.max_range / M.step do
        local distance = i * M.step
        local gap = clearance(height, origin, world, distance)
        if not gap then return nil, nil, 2 end
        if gap <= 0 then return distance - M.step, distance end
    end
    return nil, nil, 3
end
local function request_valid(origin, world)
    return position(origin) and finite(origin.time) and direction(world)
end
local function estimate_radius(distance, vertical)
    local radius = (distance * math.tan(M.angle_error) + 50) / -vertical + M.step / 1024
    if distance < 500 or radius > M.max_radius or radius > distance * .5 then return end
    return radius
end
function M.solve(height, origin, world)
    if type(height) ~= 'function' then return nil, 1 end
    if not request_valid(origin, world) then return nil, 4 end
    -- Shallow rays amplify elevation/antenna-height error beyond a useful fix.
    if -world[2] < math.sin(math.rad(3)) then return nil, 4 end
    local lower, upper, reason = bracket(height, origin, world)
    if not lower then return nil, reason end
    for _ = 1, 10 do
        local middle = (lower + upper) * .5
        local gap = clearance(height, origin, world, middle)
        if not gap then return nil, 2 end
        if gap > 0 then lower = middle else upper = middle end
    end
    local distance = (lower + upper) * .5
    local radius = estimate_radius(distance, world[2])
    if not radius then return nil, 4 end
    return { n = origin.n + distance * world[1], u = origin.u + distance * world[2],
        e = origin.e + distance * world[3], time = origin.time, radius = radius,
        method = 2, schema = 1 }, 0
end
local function current_fix(fix, now)
    if not position(fix) or fix.method ~= 2 or fix.schema ~= 1 then return false end
    if not finite(now) or not finite(fix.time) then return false end
    return now - fix.time >= 0 and now - fix.time <= M.lifetime
end
function M.current(fix, now)
    if not current_fix(fix, now) then return end
    if not finite(fix.radius) or fix.radius <= 0 or fix.radius > M.max_radius then return end
    local out = { n = fix.n, u = fix.u, e = fix.e, time = fix.time, method = 2, schema = 1 }
    out.age = now - fix.time
    out.radius = fix.radius + 30 * out.age
    if out.radius <= M.max_radius then return out end
end
local function agrees(fix, origin, world)
    local n, u, e = fix.n - origin.n, fix.u - origin.u, fix.e - origin.e
    local distance = math.sqrt(n*n + u*u + e*e)
    return distance >= 500 and (n*world[1] + u*world[2] + e*world[3]) / distance >= math.cos(math.rad(2))
end
local function prune(tracks, seen)
    for source in pairs(tracks) do
        if not seen[source] then tracks[source] = nil end
    end
end
local function prepare(tracks, contact, origin, world, now)
    local track = tracks[contact.source] or { attempt = -1 }
    tracks[contact.source] = track
    if track.fix and not agrees(track.fix, origin, world) then track.fix = nil end
    contact.geolocation = M.current(track.fix, now)
    if track.stamp ~= origin.time then
        return { track = track, contact = contact, origin = origin, world = world }
    end
end
local function collect(tracks, contacts, bearings, now)
    local seen, candidate = {}, nil
    for index = 1, math.min(#contacts, M.max_tracks) do
        local contact = contacts[index]
        local origin, world = received(contact, bearings[contact.source], now)
        if origin and not contact.geolocation then
            seen[contact.source] = true
            local item = prepare(tracks, contact, origin, world, now)
            if item and (not candidate or item.track.attempt < candidate.track.attempt) then candidate = item end
        end
    end
    prune(tracks, seen)
    return candidate
end
function M.new(height)
    local state = { tracks = {}, status = 0 }
    function state:reset()
        self.tracks = {}; self.clock = nil; self.status = 0
    end
    function state:update(now, contacts, bearings)
        if not finite(now) then self:reset(); return end
        if self.clock and (now < self.clock or now - self.clock > .25) then self:reset() end
        self.clock = now
        local candidate = collect(self.tracks, contacts, bearings, now)
        -- At most one ray per 50-ms owner callback: 171 checked terrain reads.
        if candidate then
            local item = candidate
            item.track.fix, self.status = M.solve(height, item.origin, item.world)
            item.track.attempt = now; item.track.stamp = item.origin.time
            item.contact.geolocation = M.current(item.track.fix, now)
        end
    end
    return state
end
return M
