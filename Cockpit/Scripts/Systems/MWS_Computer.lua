-- GPL-3.0-or-later. Bounded native optical-warning memory; no aircraft IRST.
local M = { memory_seconds = 3, fresh_seconds = 0.5, capacity = 16, hold_seconds = 5 }
M.__index = M

function M.finite(value)
    return type(value) == 'number' and value == value and math.abs(value) < 1e12
end

function M.sector(az)
    local clock = math.floor(az / (math.pi / 6) + 0.5) % 12
    return clock == 0 and 12 or clock
end

local function valid_source(source)
    return M.finite(source) and source >= 1 and source <= 4294967295 and source % 1 == 0
end

local function valid_time(time, now)
    return M.finite(time) and time >= 0 and time <= now + 0.05 and now - time <= M.fresh_seconds
end

local function valid_direction(o)
    return M.finite(o.az) and math.abs(o.az) <= math.pi + 0.001
        and M.finite(o.el) and math.abs(o.el) <= math.pi / 2 + 0.001
end

local function remove(self, track)
    self.tracks[track.source] = nil
    track.source = 0
end

local function clear(self)
    for index = 1, M.capacity do
        remove(self, self.slots[index])
        self.contacts[index] = nil
    end
end

local function slot(self, time)
    local oldest = self.slots[1]
    for index = 1, M.capacity do
        local candidate = self.slots[index]
        if candidate.source == 0 then return candidate end
        if candidate.time < oldest.time then oldest = candidate end
    end
    self.overflow = true
    if time < oldest.time then return nil end
    remove(self, oldest)
    self.evictions = math.min(16777215, self.evictions + 1)
    return oldest
end

local function ingest(self, o, now)
    if type(o) ~= 'table' or not valid_source(o.source) or not valid_time(o.time, now) then return end
    local old = self.tracks[o.source]
    if o.threat == false then
        if old and o.time >= old.time then remove(self, old) end
        return
    end
    if not valid_direction(o) or old and o.time <= old.time then return end
    local track = old or slot(self, o.time)
    if not track then return end
    track.source, track.time, track.az, track.el = o.source, o.time, o.az, o.el
    track.held, track.decision, track.evidence_time = o.decision == 5, o.decision, o.evidence_time
    self.tracks[o.source] = track
end

local function order(a, b)
    if a.coast ~= b.coast then return not a.coast end
    if (a.held == true) ~= (b.held == true) then return a.held ~= true end
    if a.time ~= b.time then return a.time > b.time end
    return a.source < b.source
end

function M.new()
    local self = setmetatable({ tracks = {}, contacts = {}, slots = {}, clock = 0,
        overflow = false, input_truncated = false, evictions = 0 }, M)
    for index = 1, M.capacity do self.slots[index] = { source = 0, time = 0, az = 0, el = 0 } end
    return self
end

function M:update(now, observations, enabled)
    self.overflow, self.input_truncated = false, false
    if not M.finite(now) or now < 0 then clear(self); return end
    if now < self.clock or not enabled then clear(self) end
    self.clock = now
    for index = 1, M.capacity do
        local track = self.slots[index]
        if track.source > 0 and now - track.time > M.memory_seconds then remove(self, track) end
        if track.held and (not M.finite(track.evidence_time)
            or now - track.evidence_time > M.hold_seconds or now < track.evidence_time - .05) then
            remove(self, track)
        end
        self.contacts[index] = nil
    end
    if enabled and type(observations) == 'table' then
        self.input_truncated = observations[M.capacity + 1] ~= nil
        for index = 1, M.capacity do ingest(self, observations[index], now) end
    end
    for index = 1, M.capacity do
        local track = self.slots[index]
        if track.source > 0 then
            track.age = math.max(0, now - track.time)
            track.coast = track.age > M.fresh_seconds
            self.contacts[#self.contacts + 1] = track
        end
    end
    table.sort(self.contacts, order)
end

return M
