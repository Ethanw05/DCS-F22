-- GPL-3.0-or-later. Owned C++ sensor mailbox and acquisition authority.
local M = {}
local metadata = dofile(LockOn_Options.script_path.."Systems/Radar_Track_Metadata.lua")
local axes = {PN="north",PU="altitude",PE="east",VN="vn",VU="vu",VE="ve"}
local prefixes, priorities, support_flags, support_ids = {}, {}, {}, {}
for i = 1, 64 do prefixes[i] = string.format("F22A_%02d_",i) end
for i = 1, 10 do priorities[i] = string.format("F22_AESA_PRIORITY_%02d",i) end
for i = 1, 8 do
    support_flags[i] = string.format("F22_MSL_%02d_SUPPORT_REQUIRED",i)
    support_ids[i] = string.format("F22_MSL_%02d_TARGET",i)
end
local function finite(v)
    return type(v) == "number" and v == v and math.abs(v) < 1e9
end
function M.new(get, put)
    return setmetatable({get=get,put=put,sequence=0,emitting=false,observations={},samples={}}, {__index=M})
end
function M:set_power(value) self.emitting = value == true end
function M:reset()
    self.locked, self.acquiring, self.started, self.emitting = nil, nil, nil, false
    self.generation, self.ready = nil, false
    for i = 1, #self.samples do self.samples[i].observed = nil end
end
function M:command(command, computer, now)
    if command == 510 or self.locked then
        self.locked, self.acquiring = nil, nil
    elseif command == 509 and not self.acquiring then
        local t = computer.acquire_id and computer.tracks[computer.acquire_id]
        if t and t.native_id then self.acquiring, self.started = t.native_id, now end
    end
end
function M:read(now, pose, display)
    local get, out = self.get, self.observations
    self.ready = false
    self.generation_changed = false
    for i = 1, #out do out[i] = nil end
    local sequence, stamp = get("F22_AESA_SEQUENCE"), get("F22_AESA_TIME")
    local generation = get("F22_AESA_GENERATION")
    if not finite(now) or get("F22_AESA_READY") ~= 1 or not finite(sequence) or sequence < 2 or sequence % 2 ~= 0
        or not finite(stamp) or now-stamp < -.01 or now-stamp > .5
        or not finite(generation) or generation < 1 or generation % 1 ~= 0 then return out end
    local count = 0
    for i = 1, 64 do
        local p = prefixes[i]
        local id, time = get(p.."ID"), get(p.."TIME")
        local n, u, e = get(p.."N"), get(p.."U"), get(p.."E")
        if get(p.."VALID") == 1 and finite(id) and id > 0 and id % 1 == 0
            and finite(time) and now-time >= -.01 and now-time <= 12
            and finite(n) and finite(u) and finite(e) then
            count = count + 1
            local o = self.samples[count] or {}; self.samples[count] = o
            if self.generation ~= generation or o.native_id ~= id or o.observed ~= time then metadata.read(get,p,o) end
            o.native_id, o.observed, o.age = id, time, math.max(0,now-time)
            o.north, o.altitude, o.east = n, u, e
            o.vn, o.vu, o.ve = get(p.."VN"), get(p.."VU"), get(p.."VE")
            o.velocity_valid = get(p.."VELOCITY_VALID") == 1 and finite(o.vn) and finite(o.vu) and finite(o.ve)
            o.velocity_valid = o.velocity_valid and o.filter_valid and finite(o.velocity_sigma_mps)
                and o.velocity_sigma_mps > 0 and o.velocity_sigma_mps <= 100
            o.measurement_source, o.iff = 2, -1
            o.model_hits = get(p.."HITS")
            o.range_sigma_m, o.angle_sigma_rad = get(p.."RANGE_SIGMA_M"), get(p.."ANGLE_SIGMA_RAD")
            if pose and display then o.range, o.az, o.el = display.body_observation(o,pose,o.age) end
            out[count] = o
        end
    end
    if sequence ~= get("F22_AESA_SEQUENCE") then
        for i = 1, #out do self.samples[i].observed = nil; out[i] = nil end
    else
        self.ready = true
        self.generation_changed = self.generation ~= nil and self.generation ~= generation
        self.generation = generation
    end
    return out
end
function M:state(now, computer, observations)
    local put, lock = self.put, nil
    for i = 1, #observations do
        local o = observations[i]
        if self.acquiring == o.native_id and o.observed > (self.started or now)
            and o.age <= .5 and o.velocity_valid and o.model_hits >= 2
            and finite(o.range_sigma_m) and o.range_sigma_m > 0 then
            self.locked, self.acquiring = o.native_id, nil
        end
        if self.locked == o.native_id and o.age <= .5 then lock = o end
    end
    if not computer.power or not self.emitting then self.locked, self.acquiring, lock = nil,nil,nil end
    if self.locked and not lock then self.locked = nil end
    if self.acquiring and now-self.started > 4 then self.acquiring = nil end
    self.mode = lock and 3 or self.acquiring and 2 or computer.power and self.emitting and 1 or 0
    put("F22N_RADAR_MODE", self.mode)
    put("F22_STT_MOTION_VALID", lock and lock.velocity_valid and 1 or 0); put("F22_STT_ACCEL_VALID",0)
    put("F22_STT_ID",lock and lock.native_id or 0); put("F22_STT_TIME",lock and lock.observed or -100)
    for key, field in pairs(axes) do put("F22_STT_"..key,lock and lock[field] or 0) end
    put("F22N_RADAR_STT_AZIMUTH",lock and lock.az or 0)
    put("F22N_RADAR_STT_ELEVATION",lock and lock.el or 0)
    put("F22N_RADAR_STT_RANGE",lock and lock.range or 0)
    put("F22N_RADAR_STT_FRIENDLY",-1)
    put("F22_RADAR_STT_MEASUREMENT_SOURCE",lock and 2 or 0)
    return self.mode
end
function M:publish(now, computer, resource, powered, surface, plan)
    local put = self.put
    self.sequence = (self.sequence+2)%16000000
    put("F22_AESA_CONTROL_SEQUENCE",self.sequence+1)
    put("F22_AESA_REQUEST",powered and 1 or 0); put("F22_AESA_CONTROL_TIME",now)
    put("F22_AESA_CONTROL_EMIT",self.emitting and 1 or 0)
    put("F22_AESA_CONTROL_RESOURCE",resource); put("F22_AESA_CONTROL_SURFACE",surface and 1 or 0)
    put("F22_AESA_CONTROL_SURFACE_HALF_AZ", math.rad(self.get("F22_AG_RADAR_WIDTH_DEG") / 2))
    -- A retained ACM return pattern is a pilot workflow. Once locked, the
    -- array resumes the pilot's search volume between priority revisits.
    local p = not self.locked and not surface and computer:profile() or nil
    put("F22_AESA_CONTROL_AZ",0)
    put("F22_AESA_CONTROL_EL",p and math.rad((p.lo+p.hi)/2) or computer.elevation)
    put("F22_AESA_CONTROL_HALF_AZ",math.rad(p and p.az or computer.azimuth))
    put("F22_AESA_CONTROL_HALF_EL",math.rad(p and (p.hi-p.lo)/2 or computer.vertical_span/2))
    put("F22_AESA_CONTROL_RANGE",p and p.nm*1852 or computer.ranges[computer.range_index]*1852)
    put("F22_AESA_CONTROL_CUE_VALID",plan and plan.rf_cued and 1 or 0)
    put("F22_AESA_CONTROL_CUE_AZ",plan and plan.az or 0); put("F22_AESA_CONTROL_CUE_EL",plan and plan.el or 0)
    local selected = computer.selected and computer.tracks[computer.selected]
    put("F22_AESA_CONTROL_TARGET",not surface and (self.locked
        or computer.mode == "TWS" and computer:supportable(selected) and selected.native_id) or 0)
    put("F22_AESA_PRIORITY_01",self.acquiring or self.locked or selected and selected.native_id or 0)
    local secondary = computer.secondary and computer.tracks[computer.secondary]
    put("F22_AESA_PRIORITY_02",secondary and secondary.native_id or 0)
    for i = 1, 8 do put(priorities[i+2],
        self.get(support_flags[i]) > .5 and self.get(support_ids[i]) or 0) end
    put("F22_AESA_CONTROL_SEQUENCE",self.sequence+2)
    put("F22_RADAR_SERVICE_ENABLED",1)
    put("F22_RADAR_SERVICE_PROCESSING_S",self.get("F22_AESA_PROCESSING_S"))
    put("F22_RADAR_SERVICE_PENDING",self.get("F22_AESA_PENDING"))
    put("F22_RADAR_SERVICE_DROPPED",self.get("F22_AESA_DROPS"))
    put("F22_RADAR_SERVICE_ACCEPTED",self.get("F22_AESA_DETECTIONS"))
    put("F22_RADAR_NATIVE_RESTRICTED",0)
    local ready = powered and self.ready == true
    put("F22_RADAR_BACKGROUND_AVAILABLE",ready and 1 or 0)
    put("F22_RADAR_AIR_SURFACE_CONCURRENT",ready and surface and 1 or 0)
end
return M
