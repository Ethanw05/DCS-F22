-- GPL-3.0-or-later. Explicit offboard search request; never a local measurement.
local Snapshot = dofile(LockOn_Options.script_path .. 'Systems/Physical_Snapshot.lua')
local M = { lifetime = 4, maximum_age = 13, lease = .25 }
local fields = {'VALID','TIME','REQUEST','START','SOURCE','EPOCH','OBS_TIME','RECEIVE_TIME',
    'OBSERVATION_KNOWN','N','U','E','VN','VU','VE'}
local donor_keys = {'source','n','u','e','vn','vu','ve','epoch'}
local axes = {{'N','n'},{'U','u'},{'E','e'},{'VN','vn'},{'VU','vu'},{'VE','ve'}}
local function field(donor, key) return donor and donor[key] or 0 end
local function flag(value) return value and 1 or 0 end
local names = {}
for index = 1, #fields do names[index] = 'F22_DONOR_CUE_' .. fields[index] end
M.fields, M.names = fields, names
function M.clock()
    if type(get_model_time) ~= 'function' then return end
    local ok, now = pcall(get_model_time)
    if ok and Snapshot.finite(now) and now >= 0 then return now end
end
function M.fresh(now, stamp, life)
    return Snapshot.finite(now) and Snapshot.finite(stamp) and stamp >= 0
        and now - stamp >= -.01 and now - stamp <= life
end
function M.eligible(donor, now)
    if not donor or (donor.observation_known ~= true and donor.observation_known ~= false)
        or not M.fresh(now, donor.received, M.maximum_age) then return false end
    if donor.observation_known and not M.fresh(now, donor.time, M.maximum_age) then return false end
    for _, key in ipairs(donor_keys) do
        if not Snapshot.finite(donor[key]) then return false end
    end
    return donor.source > 0 and donor.source % 1 == 0 and donor.epoch > 0
        and donor.epoch % 1 == 0 and donor.vn^2 + donor.vu^2 + donor.ve^2 <= 1500^2
end
function M.new(get, put)
    local state = {get=get, put=put, sequence=0, counter=0, values={}}
    local prior = get('F22_DONOR_CUE_REQUEST')
    if Snapshot.finite(prior) and prior >= 0 and prior < 8000000 and prior % 1 == 0 then state.counter = prior end
    state.physical = Snapshot.new(get, {'MAIN_POWER','F22_ELECTRICAL_VALID','EFM_MISSION_POWER_AVAILABLE'})
    function state:cancel(reselect)
        self.started, self.request_source = nil, nil
        put('F22_DONOR_CUE_VALID', 0)
        if reselect then self.donor, self.offered = nil, nil end
    end
    function state:supply()
        local p = self.physical:update()
        local v = p.values
        return p.valid and p.generation == self.generation and v.MAIN_POWER == 1 and v.F22_ELECTRICAL_VALID == 1
            and v.EFM_MISSION_POWER_AVAILABLE == 1
    end
    function state:available(now)
        return self:supply() and self.get('F22_RADAR_DONOR_READY') == 1
            and M.fresh(now, self.get('F22_RADAR_DONOR_TIME'), M.lease)
            and M.fresh(now, self.offered, M.lease) and M.eligible(self.donor, now)
            and self.donor.epoch == self.get('F22_DL_RX_EPOCH') and self.get('F22_DL_RX_SCHEMA') == 2
    end
    function state:command()
        local now = M.clock()
        if not now or not self:available(now) then self:cancel(); return false end
        self.counter = self.counter % 7999999 + 1
        self.started, self.request_source = now, self.donor.source
        self.request_epoch = self.donor.epoch
        return true
    end
    function state:publish(now, active)
        local donor, v = self.donor, self.values
        v.VALID, v.TIME, v.REQUEST = flag(active), now, self.counter
        v.START, v.SOURCE, v.EPOCH = self.started or 0, field(donor,'source'), field(donor,'epoch')
        v.OBS_TIME = donor and donor.observation_known and donor.time or -100
        v.RECEIVE_TIME = field(donor,'received')
        v.OBSERVATION_KNOWN = flag(donor ~= nil and donor.observation_known == true)
        for index = 1, #axes do v[axes[index][1]] = field(donor,axes[index][2]) end
        self.sequence = (self.sequence + 2) % 16000000
        put('F22_DONOR_CUE_SEQUENCE', self.sequence + 1)
        put('F22_DONOR_CUE_SCHEMA', 1)
        for index = 1, #fields do put(names[index], v[fields[index]]) end
        put('F22_DONOR_CUE_SEQUENCE', self.sequence + 2)
    end
    function state:synchronize(now)
        local generation = get('EFM_PHYSICAL_GENERATION')
        if generation ~= self.generation or self.clock and now < self.clock then self:cancel() end
        self.generation, self.clock = generation, now
    end
    function state:intent_valid(now)
        local donor = self.donor
        return donor ~= nil and donor.source == self.request_source and donor.epoch == self.request_epoch
            and M.fresh(now, self.started, M.lifetime)
    end
    function state:update(now, donor, powered)
        if not Snapshot.finite(now) or now < 0 then now = -100; powered = false end
        self:synchronize(now)
        self.donor, self.offered = donor, now
        local available = powered and self:available(now)
        local active = available and self:intent_valid(now)
        if not active then self:cancel() end
        put('F22_DONOR_HANDOFF_AVAILABLE', flag(available))
        self:publish(now, active)
    end
    state:update(-100, nil, false)
    return state
end
return M
