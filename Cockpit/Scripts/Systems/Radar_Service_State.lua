-- GPL-3.0-or-later. Bounded service of timestamped NATIVE measurements.
-- This is a game processing/resource policy, not an RF detector or APG-77 schedule.
local M = {
    capacity = 64, max_input = 64, maximum_age_s = 10,
    work_s = 0.025, processing_s = 0.050, maximum_step_s = 0.5,
    minimum_resource = 0.1, background_interval = 4,
}
local fields = {
    "native_id", "observed", "north", "east", "altitude", "vn", "vu", "ve",
    "velocity_valid", "range", "az", "el", "iff", "measurement_source",
}
local function finite(v)
    return type(v) == "number" and v == v and math.abs(v) < 1e9
end
local function copy(out, value)
    for i = 1, #fields do
        local key = fields[i]
        out[key] = value[key]
    end
end
local function source_valid(o, now, floor)
    return finite(o.native_id) and o.native_id > 0
        and o.native_id % 1 == 0 and finite(o.observed) and o.observed >= floor
        and now - o.observed >= -0.001 and now - o.observed <= M.maximum_age_s
end
local function geometry_valid(o)
    return finite(o.range) and o.range >= 40 and o.range <= 160 * 1852
        and finite(o.az) and finite(o.el) and math.abs(o.az) <= math.rad(60)
        and math.abs(o.el) <= math.rad(60) and finite(o.north)
        and finite(o.east) and finite(o.altitude)
end
local function valid(o, now, floor)
    return type(o) == "table" and source_valid(o, now, floor) and geometry_valid(o)
end
local function input_valid(now, observations, count, priorities, resource)
    return finite(now) and finite(resource) and resource >= M.minimum_resource
        and type(observations) == "table" and type(priorities) == "table"
        and finite(count) and count >= 0 and count % 1 == 0
end
function M.new()
    local s = { slots = {}, output = {}, job = {}, clock = nil, floor = -1e8 }
    for i = 1, M.capacity do
        s.slots[i] = { sample = {}, id = 0, seen = -1e8, pending = false }
        s.output[i] = {}
    end
    setmetatable(s, { __index = M })
    s:reset()
    return s
end
function M:reset(floor)
    for i = 1, M.capacity do
        local slot = self.slots[i]
        slot.id, slot.seen, slot.pending = 0, -1e8, false
    end
    self.busy, self.count, self.turn, self.pending = false, 0, 0, 0
    self.dropped, self.accepted, self.clock = 0, 0, nil
    self.floor = finite(floor) and floor or -1e8
end
function M:find(id, now)
    local free
    for i = 1, M.capacity do
        local slot = self.slots[i]
        if slot.id == id then return slot end
        if not free and (slot.id == 0 or (not slot.pending and now - slot.seen > M.maximum_age_s)) then
            free = slot
        end
    end
    if free then
        free.id, free.seen, free.pending = id, -1e8, false
    end
    return free
end
function M:ingest(now, observations, count, priorities)
    for i = 1, math.min(M.max_input, count) do
        local o = observations[i]
        if valid(o, now, self.floor) then
            local slot = self:find(o.native_id, now)
            if not slot then
                self.dropped = self.dropped + 1
            elseif o.observed > slot.seen + 0.01 then
                if not slot.pending then slot.queued = now end
                slot.pending, slot.seen = true, o.observed
                slot.priority = priorities[o.native_id] or 1
                copy(slot.sample, o)
            end
        end
    end
end
function M:choose(now, priorities)
    local best, background
    self.pending = 0
    for i = 1, M.capacity do
        local slot = self.slots[i]
        if slot.pending and now - slot.sample.observed > M.maximum_age_s then slot.pending = false end
        if slot.pending then
            self.pending = self.pending + 1
            slot.priority = priorities[slot.id] or 1
            if not best or slot.priority > best.priority
                or (slot.priority == best.priority and slot.queued < best.queued) then best = slot end
            if slot.priority == 1 and (not background or slot.queued < background.queued) then background = slot end
        end
    end
    if self.turn % M.background_interval == M.background_interval - 1 and background then return background end
    return best
end
function M:start(now, resource, area, slot)
    if not slot then return end
    copy(self.job, slot.sample)
    self.job.measurement_source = 1 -- native detection; never scene truth
    slot.pending = false
    self.pending = math.max(0, self.pending - 1)
    self.turn = (self.turn + 1) % M.background_interval
    local off_axis = 1 + math.max(math.abs(self.job.az), math.abs(self.job.el)) / math.rad(60)
    self.work = M.work_s * area * off_axis / resource
    self.completed = now + self.work
    self.release = self.completed + M.processing_s / resource
    self.busy = true
end
function M:update(now, observations, count, priorities, resource, area)
    self.count = 0
    if not input_valid(now, observations, count, priorities, resource) then
        self:reset(finite(now) and now or nil)
        return self.output, 0
    end
    if self.clock and (now < self.clock or now - self.clock > M.maximum_step_s) then self:reset(now) end
    -- A live partial fault reduces remaining service, never completes work at
    -- a previously healthy rate. Outage cancels the job in the guard above.
    if self.busy and self.resource and resource < self.resource and self.clock then
        local remaining = math.max(0, self.release - now)
        self.release = now + remaining * self.resource / resource
    end
    local advanced = not self.clock or now > self.clock
    self.clock = now
    self.resource = resource
    resource = math.min(1, resource)
    area = finite(area) and math.max(1, math.min(8, area)) or 8
    self:ingest(now, observations, count, priorities)
    local slot = self:choose(now, priorities)
    if self.busy and now >= self.release and advanced then
        if valid(self.job, now, self.floor) then
            copy(self.output[1], self.job)
            self.count, self.accepted = 1, (self.accepted or 0) + 1
        end
        self.busy = false
    end
    if not self.busy and advanced then self:start(now, resource, area, slot) end
    return self.output, self.count
end
return M
