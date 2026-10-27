-- GPL-3.0-or-later. Identity evidence ages are independent of bearing/range age.
local M = {}
M.__index = M
local sources = {{'radar', 'RADAR'}, {'rf', 'RF'}, {'datalink', 'DONOR'}}
local fields = {'VALID', 'KIND', 'FRIENDLY', 'HOSTILE', 'AGE', 'AGE_KNOWN',
    'FRIEND_AGE', 'FRIEND_AGE_KNOWN', 'HOSTILE_AGE', 'HOSTILE_AGE_KNOWN',
    'RECEIVE_AGE', 'RECEIVE_AGE_KNOWN'}
local empty_evidence = { kind = 0, friendly = false, hostile = false, time_known = false }

local function finite(value)
    return type(value) == 'number' and value == value and math.abs(value) < 1e12
end

local function age(time, now, known)
    if not known or not finite(time) or time < 0 or not finite(now) or now < time - 0.05 then
        return 999, false
    end
    return math.max(0, now - time), true
end

local function publish_flag(put, name, value)
    put(name, value and 1 or 0)
end

local function publish_age(put, name, known_name, time, now, known)
    local seconds, valid = age(time, now, known)
    put(name, seconds)
    publish_flag(put, known_name, valid)
end

local function publish(put, names, evidence, now)
    local record = evidence or empty_evidence
    publish_flag(put, names.VALID, evidence ~= nil)
    put(names.KIND, record.kind or 0)
    publish_flag(put, names.FRIENDLY, record.friendly)
    publish_flag(put, names.HOSTILE, record.hostile)
    publish_age(put, names.AGE, names.AGE_KNOWN, record.time, now, record.time_known)
    publish_age(put, names.FRIEND_AGE, names.FRIEND_AGE_KNOWN, record.time, now,
        record.friendly and record.time_known)
    publish_age(put, names.HOSTILE_AGE, names.HOSTILE_AGE_KNOWN, record.hostile_time, now,
        record.hostile and record.time_known)
    publish_age(put, names.RECEIVE_AGE, names.RECEIVE_AGE_KNOWN, record.received, now, evidence ~= nil)
end

function M.new(put, prefix)
    local self = setmetatable({ put = put, names = {} }, M)
    for index = 1, #sources do
        local names = {}
        for field = 1, #fields do
            local key = fields[field]
            names[key] = prefix..sources[index][2]..'_'..key
        end
        self.names[index] = names
    end
    self:update(nil, nil) -- Declare all display handles at owner construction.
    return self
end

function M:update(track, now)
    local evidence = track and track.identity_evidence
    for index = 1, #sources do
        publish(self.put, self.names[index], evidence and evidence[sources[index][1]], now)
    end
end

return M
