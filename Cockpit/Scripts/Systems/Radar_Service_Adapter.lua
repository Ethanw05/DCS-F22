-- GPL-3.0-or-later. Native-only provider boundary and optional health contract.
local Service = dofile(LockOn_Options.script_path .. "Systems/Radar_Service_State.lua")
local M = {}
local function finite(v)
    return type(v) == "number" and v == v and math.abs(v) < 1e9
end
local function fraction(v)
    return finite(v) and v >= 0 and v <= 1
end
function M.new()
    return setmetatable({ service = Service.new(), priorities = {}, eligible = {}, admitted = {} }, { __index = M })
end
-- Schema 0 explicitly retains legacy MAIN_POWER supply; cooling/damage are UNKNOWN.
-- Schema 1 is a coherent, timestamped normalized achieved-resource publication.
function M:health(get, now, powered)
    self.health_known = false
    if not powered then return 0 end
    local schema = get("F22_RADAR_RESOURCE_SCHEMA")
    if schema == 0 then return 1 end
    if schema ~= 1 then return 0 end
    local sequence, stamp = get("F22_RADAR_RESOURCE_SEQUENCE"), get("F22_RADAR_RESOURCE_TIME")
    local supply, cooling = get("F22_RADAR_RESOURCE_SUPPLY"), get("F22_RADAR_RESOURCE_COOLING")
    local array = get("F22_RADAR_RESOURCE_ARRAY")
    if not finite(sequence) or sequence < 1 or sequence % 1 ~= 0 or not finite(stamp)
        or now - stamp < -0.01 or now - stamp > 0.5 or not fraction(supply)
        or not fraction(cooling) or not fraction(array) or get("F22_RADAR_RESOURCE_VALID") ~= 1
        or sequence ~= get("F22_RADAR_RESOURCE_SEQUENCE") then return 0 end
    self.health_known = true
    return math.min(supply, cooling, array)
end
function M:reset(now)
    self.service:reset(now)
    self.mode, self.native_mode = nil, nil
end
function M:process(now, computer, observations, native_mode, resource)
    if self.mode ~= computer.mode or self.native_mode ~= native_mode then
        self:reset(now)
        self.mode, self.native_mode = computer.mode, native_mode
    end
    -- STT is dedicated native sensing and keeps its existing low-latency contract.
    if native_mode == 3 then return observations end
    for id in pairs(self.priorities) do self.priorities[id] = nil end
    for _, t in pairs(computer.tracks) do
        if t.native_id and (t.id == computer.selected or t.id == computer.secondary or t.designated) then
            self.priorities[t.native_id] = 2
        end
    end
    for i = 1, #(self.required or {}) do self.priorities[self.required[i]] = 3 end
    local count = 0
    for i = 1, math.min(64, #observations) do
        if computer:inside(observations[i]) then count = count + 1; self.eligible[count] = observations[i] end
    end
    local plan = computer.effective_scan
    local width = plan and math.deg(plan.half_az) * 2 or computer.azimuth * 2
    local height = plan and math.deg(plan.half_el) * 2 or computer.vertical_span
    local output, size = self.service:update(now, self.eligible, count, self.priorities, resource, width * height / 600)
    -- One completed result per activity, never a catch-up burst after a pause.
    self.admitted[1] = size == 1 and output[1] or nil
    return self.admitted
end
function M:publish(put, resource, enabled, native_mode, surface, ready)
    local s = self.service
    put("F22_RADAR_SERVICE_ENABLED", enabled and 1 or 0)
    put("F22_RADAR_SERVICE_RESOURCE", resource)
    put("F22_RADAR_SERVICE_HEALTH_KNOWN", self.health_known and 1 or 0)
    local state = resource < Service.minimum_resource and 0 or resource < 0.999 and 2 or 1
    put("F22_RADAR_SERVICE_STATE", state)
    put("F22_RADAR_SERVICE_PENDING", s.pending or 0)
    put("F22_RADAR_SERVICE_DROPPED", s.dropped or 0)
    put("F22_RADAR_SERVICE_ACCEPTED", s.accepted or 0)
    put("F22_RADAR_SERVICE_WORK_S", s.busy and s.work or 0)
    put("F22_RADAR_SERVICE_PROCESSING_S", resource > 0 and Service.processing_s / resource or 0)
    -- Capability readback, not an inference that a native pointing command moved a beam.
    put("F22_RADAR_NATIVE_RESTRICTED", 1)
    local background = ready and not surface and (native_mode == 1 or native_mode == 6)
        and resource >= Service.minimum_resource
    put("F22_RADAR_BACKGROUND_AVAILABLE", background and 1 or 0)
    put("F22_RADAR_AIR_SURFACE_CONCURRENT", 0)
end
return M
