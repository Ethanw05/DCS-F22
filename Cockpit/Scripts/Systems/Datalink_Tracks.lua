-- GPL-3.0-or-later. Offboard reports are situational awareness, never fire control.
local Frames = dofile(LockOn_Options.script_path .. 'Systems/Gun_Frames.lua')
local Bearings = dofile(LockOn_Options.script_path .. 'Systems/RWR_Bearings.lua')
local Geo = dofile(LockOn_Options.script_path .. 'Systems/EW_Geolocation.lua')
-- Retention/prediction are mod policies for sparse common-terminal reports.
-- Unknown source clocks stay unknown; receive-time motion is only an estimate.
local M = { lifetime = 75, ppli_lifetime = 26, coast = 13, prediction = 13, max_tracks = 64 }
function M.retention(o)return (o.ppli==true or o.ppli==1)and M.ppli_lifetime or M.lifetime end
local function finite(x)
    return type(x) == 'number' and x == x and math.abs(x) < 1e9
end
local function id(x) return finite(x) and x >= 1 and x % 1 == 0 end
local motion_keys = {'n','u','e','vn','vu','ve'}
local function valid_motion(o, now)
    if not o or not finite(now) or not finite(o.time) then return false end
    if now - o.time < -.05 or now - o.time > M.retention(o) then return false end
    for _, key in ipairs(motion_keys) do
        if not finite(o[key]) then return false end
    end
    return true
end
local function motion_clock(o, now)
    if o.observation_known == false then
        if not finite(o.received) or now < o.received - .05 then return end
        return math.max(0, now - o.received)
    end
    return math.max(0, now - o.time)
end
local function position_state(unknown, motion_age)
    if motion_age > M.prediction then return 3 end
    if unknown or motion_age > 0 then return 2 end
    return 1
end
function M.position(o, now)
    if not valid_motion(o, now) then return end
    local motion_age = motion_clock(o, now)
    if not motion_age then return end
    local age, unknown = math.max(0, now - o.time), o.observation_known == false
    local receive_age = finite(o.received) and math.max(0, now - o.received) or nil
    local dt = math.min(motion_age, M.prediction)
    return { n = o.n + o.vn * dt, u = o.u + o.vu * dt, e = o.e + o.ve * dt,
        age = age, coast = unknown or age > M.coast,
        state = position_state(unknown, motion_age),
        estimated = unknown or dt > 0, motion_age = dt, receive_age = receive_age,
        observation_known = not unknown, received = o.received }
end
function M.new(get, sensors)
    local s = { records = {}, sequence = 0 }
    function s:reset()
        self.records = {}
        self.seen = get('F22_DL_RX_SEQUENCE')
        self.epoch = get('F22_DL_RX_EPOCH')
        self.clock = nil
        self.received = nil
    end
    function s:update(now, power)
        self.sequence = self.sequence + 1
        local batch = { sequence = self.sequence, time = now, epoch = self.epoch, contacts = {} }
        if not power or not finite(now) or self.clock and now < self.clock then
            self:reset()
            batch.epoch = self.epoch
            return batch
        end
        self.clock = now
        local epoch, seq = get('F22_DL_RX_EPOCH'), get('F22_DL_RX_SEQUENCE')
        batch.epoch = epoch
        if epoch ~= self.epoch then
            self.records = {}; self.seen = nil; self.received = nil; self.epoch = epoch
        end
        local stamp, count = get('F22_DL_RX_TIME'), get('F22_DL_RX_COUNT')
        if finite(seq) and seq > 0 and seq ~= self.seen and finite(stamp)
            and now - stamp >= -.05 and now - stamp <= 1.5 and (not self.received or stamp >= self.received)
            and id(get('F22_DL_RX_OWN'))
            and finite(count) and count >= 0 and count <= M.max_tracks and count % 1 == 0 then
            local records = {}
            local valid = true
            for i = 1, count do
                local p = string.format('F22_DL_RX_%02d_', i)
                local o = {}
                for _, k in ipairs({'SOURCE','REPORTER','LINK','TIME','N','U','E','VN','VU','VE','AFFILIATION','FLIGHT','PPLI'}) do
                    o[k:lower()] = get(p .. k)
                end
                local schema = get('F22_DL_RX_SCHEMA')
                o.observation_known = schema == 2 and get(p .. 'OBSERVATION_KNOWN') == 1
                o.observation_time = o.observation_known and get(p .. 'OBSERVATION_TIME') or nil
                o.received = schema == 2 and get(p .. 'RECEIVE_TIME') or o.time
                o.epoch = epoch
                if not id(o.source) or not id(o.reporter) or (o.ppli==1 or o.link==2) and o.source == get('F22_DL_RX_OWN')
                    or (o.link ~= 1 and o.link ~= 2) or not finite(o.time)
                    or not finite(o.received) or o.received > stamp + .05
                    or o.observation_known and (not finite(o.observation_time)
                        or math.abs(o.time-o.observation_time)>.05)
                    or stamp - o.time < -.05 or stamp - o.time > M.retention(o)
                    or not finite(o.n) or not finite(o.u) or not finite(o.e)
                    or not finite(o.vn) or not finite(o.vu) or not finite(o.ve)
                    or o.vn^2 + o.vu^2 + o.ve^2 > 1500^2
                    or (o.affiliation ~= -1 and o.affiliation ~= 0 and o.affiliation ~= 1)
                    or (o.flight ~= 0 and o.flight ~= 1) or (o.ppli ~= 0 and o.ppli ~= 1)
                    or o.flight == 1 and (o.link ~= 1 or o.ppli ~= 1 or o.affiliation ~= 1)
                    or o.ppli == 1 and (o.source ~= o.reporter or o.affiliation ~= 1) then
                    valid = false; break
                end
                local identity=o.link..':'..o.reporter..':'..o.source..':'..o.ppli
                local old = records[identity]
                if not old or o.time > old.time or o.time == old.time and o.link < old.link then
                    records[identity] = o
                end
            end
            if valid and seq == get('F22_DL_RX_SEQUENCE') and epoch == get('F22_DL_RX_EPOCH') then
                self.records = records; self.seen = seq; self.received = stamp
            end
        end
        local own, frame = Geo.position(sensors), Bearings.frame(sensors)
        if not own or not frame then return batch end
        for source, o in pairs(self.records) do
            local q = M.position(o, now)
            if not q then self.records[source] = nil
            else
                local body = Frames.body(frame, {q.n - own.n, q.u - own.u, q.e - own.e})
                local horizontal = math.sqrt(body[1]^2 + body[3]^2)
                batch.contacts[#batch.contacts + 1] = {
                    source = o.source, age = q.age, az = math.atan2(body[3], body[1]),
                    el = math.atan2(body[2], horizontal), n = o.n, u = o.u, e = o.e,
                    vn = o.vn, vu = o.vu, ve = o.ve, link = o.link, reporter = o.reporter,
                    friendly = o.affiliation == 1, hostile = o.affiliation == 0,
                    flight = o.flight == 1, ppli = o.ppli == 1,
                    received = o.received, observation_known = o.observation_known,
                    observation_time = o.observation_time, epoch = o.epoch,
                    estimated_position = q.estimated, receive_age = q.receive_age,
                }
            end
        end
        table.sort(batch.contacts, function(a,b) return a.source < b.source end)
        return batch
    end
    s:reset()
    return s
end
return M
