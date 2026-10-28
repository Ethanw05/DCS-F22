-- GPL-3.0-or-later. Offboard state directs RF search; no track/acquisition authority.
local Link = dofile(LockOn_Options.script_path .. 'Systems/Radar_Donor_Link.lua')
local Tasking = dofile(LockOn_Options.script_path .. 'Systems/Radar_Sensor_Tasking.lua')
local M = {}
local function finite(value) return type(value)=='number' and value==value and math.abs(value)<1e9 end
local function header(get, now)
    local sequence = get('F22_DONOR_CUE_SEQUENCE')
    if not finite(sequence) or sequence < 2 or sequence % 2 ~= 0
        or get('F22_DONOR_CUE_SCHEMA') ~= 1 or get('F22_DONOR_CUE_VALID') ~= 1
        or not Link.fresh(now, get('F22_DONOR_CUE_TIME'), Link.lease) then return end
    return sequence
end
local function positive_integer(value) return value > 0 and value % 1 == 0 end
local function request_clock(p, now)
    if not Link.fresh(now, p.START, Link.lifetime) or not Link.fresh(now,p.RECEIVE_TIME,Link.maximum_age)
        or p.RECEIVE_TIME > p.TIME + .01 then return false end
    if p.OBSERVATION_KNOWN == 0 then return p.OBS_TIME == -100 end
    return p.OBS_TIME <= p.RECEIVE_TIME + .05 and Link.fresh(now,p.OBS_TIME,Link.maximum_age)
end
local function packet_valid(p, now, epoch)
    return (p.OBSERVATION_KNOWN == 0 or p.OBSERVATION_KNOWN == 1)
        and positive_integer(p.REQUEST) and p.REQUEST < 8000000
        and positive_integer(p.SOURCE) and positive_integer(p.EPOCH) and p.EPOCH == epoch
        and request_clock(p,now) and p.VN^2 + p.VU^2 + p.VE^2 <= 1500^2
end
local function position_valid(pose)
    return pose ~= nil and finite(pose.north) and finite(pose.altitude) and finite(pose.east)
end
local function search_margin(known, age, range)
    if not known then return math.rad(20), math.min(160*1852,range+5000) end
    local error = 200+25*age
    return math.min(math.rad(20),math.max(math.rad(4),math.atan2(error,range))), math.min(160*1852,range+3*error)
end
local function project(packet, now, pose, cue)
    if not position_valid(pose) then return end
    local known = packet.OBSERVATION_KNOWN == 1
    local age = known and math.max(0, now - packet.OBS_TIME) or 0
    local n, u, e = packet.N + packet.VN*age - pose.north,
        packet.U + packet.VU*age - pose.altitude, packet.E + packet.VE*age - pose.east
    local range = math.sqrt(n*n+u*u+e*e)
    if range < 40 or range > 160*1852 then return end
    cue.wn, cue.wu, cue.we = n/range, u/range, e/range
    cue.az, cue.el = Tasking.project(cue, pose)
    if not cue.az or math.abs(cue.az) > Tasking.limit or math.abs(cue.el) > Tasking.limit then return end
    -- Donor uncertainty is not supplied by this interface. This bounded search
    -- margin is a declared game policy, not a fire-control covariance.
    cue.half, cue.range = search_margin(known,age,range)
    cue.request, cue.started = packet.REQUEST*2, packet.START
    return cue
end
local function fill_plan(plan, base, computer)
    for key in pairs(plan) do plan[key] = nil end
    if base then for key, value in pairs(base) do plan[key] = value end
    else
        plan.az, plan.el = 0, computer.elevation
        plan.half_az, plan.half_el = math.rad(computer.azimuth), math.rad(computer.vertical_span/2)
        plan.range = computer:range()
        plan.obligations, plan.uncovered, plan.support_count = 0, 0, 0
        plan.support_overdue, plan.revisit_remaining = 0, 0
    end
end
function M.new(get, put)
    local state = {packet={}, cue={}, plan={}, get=get, put=put}
    function state:reset(now)
        self.put('F22_RADAR_DONOR_READY', 0); self.put('F22_RADAR_DONOR_TIME', now or -100)
        self.put('F22_RADAR_DONOR_STATUS', 0); self.put('F22_RADAR_DONOR_SOURCE', 0)
    end
    function state:retire(now)
        self.blocked = get('F22_DONOR_CUE_REQUEST')
        self:reset(now)
    end
    function state:read(now, pose)
        local sequence = header(get, now)
        if not sequence then return end
        local packet = self.packet
        for index = 1, #Link.fields do
            local value = get(Link.names[index])
            if not finite(value) then return end
            packet[Link.fields[index]] = value
        end
        if packet.REQUEST == self.blocked or not packet_valid(packet, now, get('F22_DL_RX_EPOCH'))
            or sequence ~= get('F22_DONOR_CUE_SEQUENCE') then return end
        return project(packet, now, pose, self.cue)
    end
    function state:apply(now, pose, base, enabled, computer)
        if not enabled or not finite(now) or now < 0 then self:retire(now); return base end
        put('F22_RADAR_DONOR_TIME', now)
        put('F22_RADAR_DONOR_READY', 1)
        put('F22_RADAR_DONOR_STATUS', 0); put('F22_RADAR_DONOR_SOURCE', 0)
        local cue = self:read(now, pose)
        if not cue then return base end
        local plan = self.plan
        fill_plan(plan,base,computer)
        plan.rf_cued, plan.cue_az, plan.cue_el = true, cue.az, cue.el
        plan.cue_half_az, plan.cue_half_el, plan.cue_request = cue.half, cue.half, cue.request
        plan.cue_range = cue.range
        local searched = get('F22_AESA_CUE_REQUEST') == cue.request
            and Link.fresh(now, get('F22_AESA_CUE_TIME'), .5) and get('F22_AESA_CUE_TIME') >= cue.started
        put('F22_RADAR_DONOR_STATUS', searched and 2 or 1)
        put('F22_RADAR_DONOR_SOURCE', self.packet.SOURCE)
        return plan
    end
    state:retire(-100)
    return state
end
return M
