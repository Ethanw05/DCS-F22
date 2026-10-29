-- GPL-3.0-or-later. Deterministic fusion with independent source clocks.
local Threat = dofile(LockOn_Options.script_path .. 'Systems/Tactical_Threat.lua')
local Geolocation = dofile(LockOn_Options.script_path .. 'Systems/EW_Geolocation.lua')
local Identification = dofile(LockOn_Options.script_path .. 'Systems/Identification_State.lua')
local M = {}
local order = {'radar','rf','mws','datalink','irst'}
local rank = {radar=5, irst=4, mws=3, rf=2, datalink=1}
local fresh = {radar=1, irst=.5, mws=.5, rf=6, datalink=13}
local function preferred(o, old)
    if not old then return true end
    if o.ppli ~= old.ppli then return o.ppli == true end
    if o.time ~= old.time then return o.time > old.time end
    if o.link ~= old.link then return (o.link or 0) < (old.link or 0) end
    return (o.reporter or 0) < (old.reporter or 0)
end
local function direction(t, o, sensor, now)
    local score = (now-o.time <= fresh[sensor] and 100 or 0) + rank[sensor]
    if not t.direction or score > t.direction_score
        or score == t.direction_score and o.time > t.direction.time then
        t.direction, t.direction_sensor, t.direction_score = o, sensor, score
        t.az, t.el, t.uncertainty = o.az, o.el, o.uncertainty
    end
end
local function fields(t, o, sensor, age, now)
    if sensor == 'datalink' then
        t.datalink, t.datalink_age = o, age
    elseif sensor == 'rf' then
        t.signal, t.label, t.geolocation_status = o.signal or 1, o.label, o.geolocation_status
        if Geolocation.current(o.geolocation, now) then t.geolocation = o.geolocation end
    elseif sensor == 'mws' then
        t.optical = true
    elseif sensor == 'radar' then
        if not t.label or t.label == 'U' then t.label = o.label end
        t.selected, t.radar_age = o.selected, age
        t.range_estimated = o.estimated or age > .001
        if age <= 6 then t.range, t.measured_range, t.range_time = o.range, o.measured_range, o.time end
    elseif sensor == 'irst' then
        t.irst_age = age
    end
end
local function join(t, o, sensor, age, now, bits)
    local old = t.observations[sensor]
    if not old then t.mask = t.mask + bits[sensor] end
    local representative = preferred(o, old)
    local previous_evidence = t.identity_evidence and t.identity_evidence[sensor]
    -- All donor identities protect friendlies, while one representative supplies
    -- geometry and selection. Multiple donors never add the same source bit twice.
    Identification.evidence(t, o, sensor)
    if not representative and t.identity_evidence then
        t.identity_evidence[sensor] = previous_evidence
    elseif not o.friendly and not o.hostile and t.identity_evidence then
        t.identity_evidence[sensor] = nil
    end
    t.flight = t.flight or o.flight == true
    t.age = math.min(t.age, age)
    if o.friendly then t.affiliation = 1
    elseif o.hostile and t.affiliation ~= 1 then t.affiliation = 0 end
    if not representative then return end
    t.observations[sensor] = o
    fields(t, o, sensor, age, now)
    direction(t, o, sensor, now)
end
local function finish(t, now)
    if t.flight then t.affiliation = 3 end
    t.rf_age = Threat.age(t.observations.rf, now)
    t.rf_coast = t.observations.rf and Threat.coast(t.observations.rf, 'rf', t.signal, now) or false
    t.optical_age = Threat.age(t.observations.mws, now)
    t.optical_coast = t.observations.mws and Threat.coast(t.observations.mws, 'mws', 0, now) or false
    t.threat_priority = Threat.priority(t, now)
end
local function priority(a, b)
    local selected_a, selected_b = a.selected == true, b.selected == true
    if selected_a ~= selected_b then return selected_a end
    if a.threat_priority ~= b.threat_priority then return a.threat_priority > b.threat_priority end
    return a.source < b.source
end
function M.build(batches, now, limits, bits)
    local joined, contacts = {}, {}
    for _, sensor in ipairs(order) do
        local batch = batches[sensor]
        for _, o in pairs(batch and batch.contacts or {}) do
            local age, id = math.max(0, now-o.time), o.picture_source
            if id and age <= limits[sensor] then
                local t = joined[id] or {source=id, mask=0, observations={}, affiliation=-1,
                    signal=0, age=math.huge}
                joined[id] = t
                join(t, o, sensor, age, now, bits)
            end
        end
    end
    for _, t in pairs(joined) do finish(t, now); contacts[#contacts+1] = t end
    table.sort(contacts, priority)
    return contacts
end
return M
