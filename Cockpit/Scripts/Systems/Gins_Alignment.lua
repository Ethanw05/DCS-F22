-- GPL-3.0-or-later. Bounded alignment estimate; not recovered F-22 timing/gyro physics.
-- Normal480s / retained90s / explicit training30s; 5m movement, 5deg heading and
-- 900s retained-memory limits are project estimates. Hornet stored-heading analogue.
local M = { durations = { [0] = 480, [1] = 90, [2] = 30 } }
M.__index = M
local function finite(value)
    return type(value) == 'number' and value == value and math.abs(value) < 1e9
end
local function position(s)
    return finite(s.n) and finite(s.e) and finite(s.heading)
end
local function distance(n, e, s)
    return math.sqrt((n - s.n)^2 + (e - s.e)^2)
end
function M.new(aligned)
    return setmetatable({ progress = aligned and 480 or 0, total = 480, kind = 0,
        ready = aligned == true, phase = aligned and 'NAV' or 'ALIGN', clock = nil }, M)
end
function M:remember(s)
    if not self.ready or not position(s) then return end
    self.saved_n, self.saved_e, self.saved_heading, self.saved_time = s.n, s.e, s.heading, s.now
end
function M:retained(s)
    if not self.saved_time or not position(s) or s.now < self.saved_time or s.now - self.saved_time > 900 then
        return false
    end
    local angle = (s.heading - self.saved_heading + math.pi) % (2 * math.pi) - math.pi
    return distance(self.saved_n, self.saved_e, s) <= 5 and math.abs(angle) <= math.rad(5)
end
function M:request(kind, s)
    if not M.durations[kind] or not finite(s.now) or not s.powered or not s.stationary or not position(s) then
        return false, 'ALIGN NEEDS STATIONARY GROUND'
    end
    self:remember(s)
    if kind == 1 and not self:retained(s) then return false, 'RETAINED HEADING UNAVAILABLE' end
    self.kind, self.total, self.progress, self.ready = kind, M.durations[kind], 0, false
    self.origin_n, self.origin_e, self.phase = s.n, s.e, 'ALIGN'
    return true
end
function M:restore(s)
    if not self.outage then return end
    if s.now - self.outage > 5 then
        self.ready, self.progress = false, 0
        self.kind, self.total = 0, M.durations[0]
        self.origin_n, self.origin_e = nil, nil
    end
    self.outage = nil
end
function M:update(s)
    if not finite(s.now) then self.phase = 'CLOCK INVALID'; return end
    local delta = self.clock and s.now - self.clock or 0
    self.clock = s.now
    if delta < 0 then
        self.ready, self.progress, self.saved_time = false, 0, nil
        self.kind, self.total = 0, M.durations[0]
        self.origin_n, self.origin_e, self.outage = nil, nil, nil
    end
    if not s.powered then
        if not self.outage then self:remember(s); self.outage = s.now end
        self.phase = 'OFF'; return
    end
    self:restore(s)
    if self.ready then self.phase = 'NAV'; self:remember(s); return end
    if not s.stationary or not position(s) then
        self.progress, self.origin_n, self.origin_e, self.phase = 0, nil, nil, 'MOVING / LAND ALIGN'
        return
    end
    if not self.origin_n then self.origin_n, self.origin_e = s.n, s.e end
    if distance(self.origin_n, self.origin_e, s) > 5 then
        self.progress, self.origin_n, self.origin_e, self.phase = 0, nil, nil, 'MOVED / ALIGN RESET'
        return
    end
    self.phase = 'ALIGN'
    self.progress = math.min(self.total, self.progress + math.max(0, math.min(.2, delta)))
    if self.progress >= self.total then self.ready = true; self.phase = 'NAV'; self:remember(s) end
end
return M
