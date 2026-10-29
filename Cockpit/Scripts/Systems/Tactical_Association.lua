-- GPL-3.0-or-later. Awareness association; never grants weapon authority.
-- At most 176 observations, 15,400 geometry pairs and 30,976 union checks/update.
local M = { maximum = 176 }
local Geometry = dofile(LockOn_Options.script_path .. 'Systems/Tactical_Association_Geometry.lua')
local History = dofile(LockOn_Options.script_path .. 'Systems/Tactical_Radar_History.lua')
local Stale = dofile(LockOn_Options.script_path .. 'Systems/Tactical_Stale_Donor.lua')
local order = {'radar', 'rf', 'mws', 'datalink', 'irst'}
local evidence_fields = {'time', 'received', 'n', 'u', 'e', 'vn', 'vu', 've'}

local function clear(buffer)
    for k in pairs(buffer) do buffer[k] = nil end
end

local function group(sensor, o)
    if sensor ~= 'datalink' then return sensor end
    -- One report per stream may describe one fused aircraft. PPLI is separate.
    return sensor .. ':' .. tostring(o.link) .. ':' .. tostring(o.reporter)
        .. ':' .. ((o.ppli == true or o.ppli == 1) and 'ppli' or 'track')
end

local function key(sensor, o)
    return group(sensor, o) .. ':' .. tostring(o.epoch) .. ':' .. o.source
end

local function root(entries, index)
    for _ = 1, M.maximum do
        local parent = entries[index].parent
        if parent == index then return index end
        index = parent
    end
end

local function conflict(entries, left, right, work)
    for _, a in ipairs(left.members) do
        for _, b in ipairs(right.members) do
            if work.remaining == 0 then return true end
            work.remaining = work.remaining - 1
            if entries[a].conflicts[b] then return true end
        end
    end
    return false
end

local function merge(entries, a, b, work)
    a, b = root(entries, a), root(entries, b)
    if not a or not b or a == b then return end
    local left, right = entries[a], entries[b]
    for stream in pairs(left.groups) do
        if right.groups[stream] then return end
    end
    if conflict(entries, left, right, work) then return end
    if right.identity < left.identity then a = b; left, right = right, left end
    right.parent = a
    for stream in pairs(right.groups) do left.groups[stream] = true end
    for _, member in ipairs(right.members) do left.members[#left.members + 1] = member end
end

local function candidate(entry, other, index, score, ranked, confirm)
    local stream = other.group
    local choice = entry.candidates[stream]
    if not choice then
        entry.candidate_count = entry.candidate_count + 1
        choice = entry.candidate_pool[entry.candidate_count] or {}
        entry.candidate_pool[entry.candidate_count] = choice
        choice.score, choice.second, choice.count = math.huge, math.huge, 0
        entry.candidates[stream] = choice
    end
    choice.count = choice.count + 1
    if score < choice.score then
        choice.second = choice.score
        choice.index, choice.score, choice.ranked = index, score, ranked
        choice.confirm = confirm
    else
        choice.second = math.min(choice.second, score)
    end
end

local function decisive(choice)
    if choice.count == 1 or choice.score < 0 then return true end
    -- Distance may resolve a formation; bearing-only evidence may not.
    -- Estimated policy: require both a 2:1 fit and a meaningful score gap.
    return choice.ranked and choice.score * 2 < choice.second
        and choice.second - choice.score > .1
end

local function prepare_entry(entry, o, sensor, id, index, now)
    entry.observation, entry.sensor, entry.identity, entry.parent = o, sensor, id, index
    entry.group, entry.key = group(sensor, o), key(sensor, o)
    clear(entry.candidates)
    entry.candidate_count = 0
    clear(entry.groups)
    clear(entry.members)
    clear(entry.conflicts)
    entry.members[1] = index
    entry.groups[entry.group] = true
    entry.position = Geometry.position(sensor, o, now)
end

local function unchanged(o, previous)
    if not previous then return false end
    for _, field in ipairs(evidence_fields) do
        if o[field] ~= previous[field] then return false end
    end
    return true
end

local function match_pairs(entries, count, now)
    for a = 1, count do
        for b = a + 1, count do
            local left, right = entries[a], entries[b]
            if left.group ~= right.group then
                local score, ranked, veto, confirm = Geometry.score(left, right, now)
                if veto then left.conflicts[b] = true; right.conflicts[a] = true end
                if not score then
                    score, ranked = Geometry.continuity(left, right, now)
                    confirm = false
                end
                if score then
                    candidate(left, right, b, score, ranked, confirm)
                    candidate(right, left, a, score, ranked, confirm)
                end
            end
        end
    end
end

local function join_pairs(entries, count, work, stale)
    stale:begin()
    for a = 1, count do
        local left = entries[a]
        for _, choice in pairs(left.candidates) do
            local right = entries[choice.index]
            local back = right.candidates[left.group]
            if back and back.index == a and decisive(choice) and decisive(back) then
                if not choice.confirm or stale:accept(left, right) then
                    merge(entries, a, choice.index, work)
                end
            end
        end
    end
    stale:finish()
end

function M.new()
    local state = {entries = {}, identities = {}, scratch = {}, used = {},
        evidence = {}, next_evidence = {},
        next_id = 1, history = History.new(), work = {remaining = 0}, stale = Stale.new()}

    function state:allocate()
        local id = self.next_id
        self.next_id = self.next_id % 16000000 + 1
        return id
    end

    function state:reset()
        clear(self.identities)
        clear(self.scratch)
        clear(self.used)
        clear(self.evidence)
        clear(self.next_evidence)
        clear(self.history.tracks)
        self.stale:reset()
    end

    function state:prepare(batches, now, limits)
        self.history:update(batches.radar, now)
        local count = 0
        clear(self.scratch)
        clear(self.next_evidence)
        for _, sensor in ipairs(order) do
            local contacts = batches[sensor] and batches[sensor].contacts or {}
            for _, o in pairs(contacts) do
                if count == M.maximum then break end
                if now - o.time >= 0 and now - o.time <= limits[sensor] and count < M.maximum then
                    count = count + 1
                    local id = self.identities[key(sensor, o)] or self:allocate()
                    local entry = self.entries[count]
                    if not entry then
                        entry = {candidates = {}, candidate_pool = {}, groups = {}, members = {}, conflicts = {}}
                        self.entries[count] = entry
                    end
                    prepare_entry(entry, o, sensor, id, count, now)
                    entry.previous = self.evidence[entry.key]
                    entry.unchanged = unchanged(o, entry.previous)
                    entry.history = sensor == 'radar' and self.history.tracks[o.source] or nil
                end
            end
        end
        return count
    end

    function state:publish(count)
        clear(self.used)
        -- A former fused ID may split. Only one component may retain its ID.
        for index = 1, count do
            local entry = self.entries[index]
            if entry.parent == index then
                if self.used[entry.identity] then entry.identity = self:allocate() end
                self.used[entry.identity] = true
            end
        end
        for index = 1, count do
            local entry = self.entries[index]
            local id = self.entries[root(self.entries, index)].identity
            entry.observation.picture_source = id
            self.scratch[entry.key] = id
            local evidence = entry.previous or {}
            for _, field in ipairs(evidence_fields) do evidence[field] = entry.observation[field] end
            self.next_evidence[entry.key] = evidence
        end
        self.scratch, self.identities = self.identities, self.scratch
        self.next_evidence, self.evidence = self.evidence, self.next_evidence
    end

    function state:associate(batches, now, limits)
        local count = self:prepare(batches, now, limits)
        match_pairs(self.entries, count, now)
        self.work.remaining = M.maximum * M.maximum
        join_pairs(self.entries, count, self.work, self.stale)
        self:publish(count)
    end
    return state
end
return M
