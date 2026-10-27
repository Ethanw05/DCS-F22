-- GPL-3.0-or-later. Offboard reports are situational awareness, never fire control.
local Frames = dofile(LockOn_Options.script_path .. 'Systems/Gun_Frames.lua')
local Bearings = dofile(LockOn_Options.script_path .. 'Systems/RWR_Bearings.lua')
local Geo = dofile(LockOn_Options.script_path .. 'Systems/EW_Geolocation.lua')
-- Native PPLI cadence is about twelve seconds. Retain one missed PPLI cycle;
-- native AI target reports can be about a minute apart. Keep bounded, visibly
-- coasting SA memory across that interval, without renewing observation time.
local M = { lifetime = 75, ppli_lifetime = 26, coast = 13, prediction = 13, max_tracks = 64 }
function M.retention(o)return (o.ppli==true or o.ppli==1)and M.ppli_lifetime or M.lifetime end
local function finite(x)
    return type(x) == 'number' and x == x and math.abs(x) < 1e9
end
local function id(x) return finite(x) and x >= 1 and x % 1 == 0 end
function M.position(o, now)
    if not o or not finite(now) or not finite(o.time) then return end
    local age = now - o.time
    if age < -.05 or age > M.retention(o) then return end
    local dt = math.min(math.max(0, age), M.prediction)
    return { n = o.n + o.vn * dt, u = o.u + o.vu * dt, e = o.e + o.ve * dt,
        age = math.max(0, age), coast = age > M.coast }
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
        local batch = { sequence = self.sequence, time = now, contacts = {} }
        if not power or not finite(now) or self.clock and now < self.clock then
            self:reset()
            return batch
        end
        self.clock = now
        local epoch, seq = get('F22_DL_RX_EPOCH'), get('F22_DL_RX_SEQUENCE')
        if epoch ~= self.epoch then self.records = {}; self.seen = nil; self.epoch = epoch end
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
                if not id(o.source) or not id(o.reporter) or o.source == get('F22_DL_RX_OWN')
                    or (o.link ~= 1 and o.link ~= 2) or not finite(o.time)
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
                local old = records[o.source]
                if not old or o.time > old.time or o.time == old.time and o.link < old.link then
                    records[o.source] = o
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
                    source = source, age = q.age, az = math.atan2(body[3], body[1]),
                    el = math.atan2(body[2], horizontal), n = o.n, u = o.u, e = o.e,
                    vn = o.vn, vu = o.vu, ve = o.ve, link = o.link, reporter = o.reporter,
                    friendly = o.affiliation == 1, hostile = o.affiliation == 0,
                    flight = o.flight == 1, ppli = o.ppli == 1,
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
