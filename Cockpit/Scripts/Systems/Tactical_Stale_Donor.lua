-- GPL-3.0-or-later. Confirm delayed donor/radar matches before removing a duplicate.
-- Simulator policy: three independent radar observations spanning half a second.
-- Projection is association-only; it never refreshes or moves the displayed donor.
local M = {capacity = 64, samples = 3, span = .5}
local positions, velocities = {'n', 'u', 'e'}, {'vn', 'vu', 've'}
local function finite(v)
    return type(v) == 'number' and v == v and math.abs(v) < 1e9
end
local function pair(a, b)
    if a.sensor == 'radar' and b.sensor == 'datalink' then return a, b end
    if b.sensor == 'radar' and a.sensor == 'datalink' then return b, a end
end
local function age(report, now)
    local stamp = report.time
    if report.observation_known == false then stamp = report.received end
    if finite(stamp) then return now - stamp end
end
local function precise(r, now)
    return finite(r.time) and now - r.time >= 0 and now - r.time <= 1 and r.velocity_valid == true
        and finite(r.position_sigma_m) and r.position_sigma_m >= 0 and r.position_sigma_m <= 100
        and finite(r.velocity_sigma_mps) and r.velocity_sigma_mps >= 0 and r.velocity_sigma_mps <= 25
end
local function residual(r, d, elapsed, now)
    local distance, velocity = 0, 0
    for index = 1, 3 do
        local p, v = positions[index], velocities[index]
        if not finite(r[p]) or not finite(r[v]) or not finite(d[p]) or not finite(d[v]) then return end
        local delta = r[p] + r[v] * (now - r.time) - d[p] - d[v] * elapsed
        distance = distance + delta ^ 2
        velocity = velocity + (r[v] - d[v]) ^ 2
    end
    return distance, velocity
end
function M.score(a, b, now)
    local radar, donor = pair(a, b)
    if not radar then return end
    local r, d = radar.observation, donor.observation
    local elapsed = age(d, now)
    if not elapsed or elapsed <= 13 or elapsed > 26 or not precise(r, now) then return end
    local distance, velocity = residual(r, d, elapsed, now)
    if not distance then return end
    -- A stale extrapolation must fit more tightly than ordinary fresh reports.
    -- Reciprocal uniqueness and repeated independent samples are also required.
    local margin = 250 + 2 * r.position_sigma_m
    if distance > margin ^ 2 or velocity > 50 ^ 2 then return nil, nil, true, true end
    return distance / margin ^ 2 + .1 * velocity / 50 ^ 2, true, false, true
end
function M.new()
    -- Retain at most 64 candidates; at most 128 records during frame rollover.
    local s = {records = {}, active = {}, count = 0}
    function s:reset()
        self.records, self.active, self.count = {}, {}, 0
    end
    function s:begin()
        for key in pairs(self.active) do self.active[key] = nil end
        self.count = 0
    end
    function s:accept(a, b)
        local radar, donor = pair(a, b)
        if not radar then return false end
        local key = radar.key .. '/' .. donor.key
        if not self.active[key] then
            if self.count == M.capacity then return false end
            self.active[key] = true
            self.count = self.count + 1
        end
        local stamp = radar.observation.time
        local old = self.records[key]
        if not old or not donor.unchanged or stamp < old.last then
            old = {first = stamp, last = stamp, count = 1}
            self.records[key] = old
        elseif stamp > old.last then
            old.count = math.min(M.samples, old.count + 1)
            old.last = stamp
        end
        return old.count >= M.samples and stamp - old.first >= M.span
    end
    function s:finish()
        for key in pairs(self.records) do
            if not self.active[key] then self.records[key] = nil end
        end
    end
    return s
end
return M
