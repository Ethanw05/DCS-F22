-- GPL-3.0-or-later. Identity evidence ages are independent of bearing/range age.
local M = {}
M.__index = M
local sources = {{'radar', 'RADAR'}, {'rf', 'RF'}, {'datalink', 'DONOR'}}
local fields = {'VALID', 'KIND', 'FRIENDLY', 'HOSTILE', 'AGE', 'AGE_KNOWN',
    'FRIEND_AGE', 'FRIEND_AGE_KNOWN', 'HOSTILE_AGE', 'HOSTILE_AGE_KNOWN',
    'RECEIVE_AGE', 'RECEIVE_AGE_KNOWN'}

local function finite(value)
    return type(value) == 'number' and value == value and math.abs(value) < 1e12
end

local function age(time, now, known)
    if not known or not finite(time) or time < 0 or not finite(now) or now < time - 0.05 then
        return 999, false
    end
    return math.max(0, now - time), true
end

local function publish(put, names, evidence, now)
    local friendly, hostile = evidence and evidence.friendly, evidence and evidence.hostile
    local time, known = age(evidence and evidence.time, now, evidence and evidence.time_known)
    local friend_time, friend_known = age(evidence and evidence.time, now,
        friendly and evidence.time_known)
    local hostile_time, hostile_known = age(evidence and evidence.hostile_time, now,
        hostile and evidence.time_known)
    local receipt, receipt_known = age(evidence and evidence.received, now, evidence ~= nil)
    put(names.VALID, evidence and 1 or 0)
    put(names.KIND, evidence and evidence.kind or 0)
    put(names.FRIENDLY, friendly and 1 or 0)
    put(names.HOSTILE, hostile and 1 or 0)
    put(names.AGE, time)
    put(names.AGE_KNOWN, known and 1 or 0)
    put(names.FRIEND_AGE, friend_time)
    put(names.FRIEND_AGE_KNOWN, friend_known and 1 or 0)
    put(names.HOSTILE_AGE, hostile_time)
    put(names.HOSTILE_AGE_KNOWN, hostile_known and 1 or 0)
    put(names.RECEIVE_AGE, receipt)
    put(names.RECEIVE_AGE_KNOWN, receipt_known and 1 or 0)
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
