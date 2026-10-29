-- GPL-3.0-or-later. Coherent native optical reports, World time and body radians.
local M = { capacity = 16, maximum_age = .35, hold_seconds = 5 }
local function finite(v)
    return type(v) == 'number' and v == v and math.abs(v) < 1e12
end
local function integer(v, low, high)
    return finite(v) and v >= low and v <= high and v % 1 == 0
end
local function fresh(now, time, age)
    return finite(now) and finite(time) and time >= 0 and now - time >= -.05 and now - time <= age
end
local function boolean(v)
    return v == 0 or v == 1
end
local function admissible(row, now, stamp)
    if not integer(row.source, 1, 4294967295) or not fresh(now, row.time, .5) then return false end
    if row.time > stamp + .05 or not finite(row.az) or not finite(row.el) then return false end
    if math.abs(row.az) > math.pi + .001 or math.abs(row.el) > math.pi / 2 + .001 then return false end
    if not boolean(row.threat_code) or not integer(row.decision, 0, 8) then return false end
    if row.threat_code == 0 then return true end
    if not fresh(now, row.evidence_time, M.hold_seconds) or row.evidence_time > row.time + .05 then
        return false
    end
    return row.decision == 4 or row.decision == 5
end
local function clear_contacts(s)
    for i = #s.contacts, 1, -1 do s.contacts[i] = nil end
end
local function capture(s, get, now, stamp)
    for i = 1, M.capacity do
        local row = s.rows[i]
        for key, name in pairs(row.names) do row[key] = get(name) end
        if row.valid == 1 and admissible(row, now, stamp) then
            row.threat = row.threat_code == 1
            s.contacts[#s.contacts + 1] = row
        end
    end
end
local function committed(get, header, sequence, epoch, stamp)
    return sequence == get(header.SEQUENCE) and epoch == get(header.EPOCH)
        and stamp == get(header.TIME) and get(header.READY) == 1 and get(header.SCHEMA) == 1
end
function M.new(get)
    local prefix = 'F22_MWS_NATIVE_'
    local s = { contacts = {}, rows = {}, ready = false, epoch = 0, time = 0, sequence = 0 }
    local header = {}
    for _, key in ipairs({ 'SEQUENCE', 'SCHEMA', 'EPOCH', 'READY', 'TIME' }) do
        header[key] = prefix .. key
        get(header[key])
    end
    local fields = { VALID = 'valid', SOURCE = 'source', TIME = 'time', AZ = 'az', EL = 'el',
        THREAT = 'threat_code', DECISION = 'decision', EVIDENCE_TIME = 'evidence_time' }
    for i = 1, M.capacity do
        local row = { names = {} }
        for suffix, key in pairs(fields) do
            row.names[key] = string.format('%s%02d_%s', prefix, i, suffix)
            get(row.names[key])
        end
        s.rows[i] = row
    end
    function s:read(now)
        self.ready = false
        clear_contacts(self)
        local sequence = get(header.SEQUENCE) -- Commit marker precedes protected payload.
        if not integer(sequence, 2, 16000000) or sequence % 2 ~= 0 then return self end
        local schema, epoch = get(header.SCHEMA), get(header.EPOCH)
        local ready, stamp = get(header.READY), get(header.TIME)
        if schema ~= 1 or not integer(epoch, 1, 15999999) or ready ~= 1
            or not fresh(now, stamp, M.maximum_age) then return self end
        capture(self, get, now, stamp)
        if not committed(get, header, sequence, epoch, stamp) then
            clear_contacts(self)
            return self
        end
        self.ready, self.epoch, self.time, self.sequence = true, epoch, stamp, sequence
        return self
    end
    return s
end
return M
