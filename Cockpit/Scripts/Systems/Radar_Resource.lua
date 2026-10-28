-- GPL-3.0-or-later. Current physical envelope and owned array resource only.
-- Thermal limits and freshness thresholds are declared simulation policies.
local Snapshot = dofile(LockOn_Options.script_path .. "Systems/Physical_Snapshot.lua")
local M = { minimum_resource = .1, maximum_stall = .25 }
M.__index = M
local fields = { "EFM_MISSION_POWER_AVAILABLE", "F22_ELECTRICAL_VALID",
    "EFM_ENVIRONMENT_VALID", "EFM_EQUIPMENT_TEMP_C", "EFM_THERMAL_FAULT" }

function M.new(get)
    return setmetatable({ get = get, physical = Snapshot.new(get, fields), resource = 0,
        power_known = false, thermal_known = false, array_known = false, health_known = false }, M)
end
function M:clear_health()
    self.resource = 0
    self.power_known, self.thermal_known, self.array_known, self.health_known = false, false, false, false
end
function M:reset(require_progress)
    self.last_world, self.progress_world = nil, nil
    if not require_progress then self.generation, self.stamp = nil, nil end
    self.require_progress = require_progress == true
    self:clear_health()
end
function M:progressing(now, snapshot)
    if not Snapshot.finite(now) or now < 0 then return false end
    local changed = self.generation ~= snapshot.generation or self.stamp ~= snapshot.stamp
    if self.last_world and now < self.last_world then
        self.last_world, self.progress_world = now, now
        self.generation, self.stamp = snapshot.generation, snapshot.stamp
        self.require_progress = true
        return false
    end
    if changed then
        self.generation, self.stamp = snapshot.generation, snapshot.stamp
        self.progress_world = now
        self.require_progress = false
    end
    self.last_world = now
    -- Compare elapsed progress only, never World time against a spawn epoch.
    return not self.require_progress and self.progress_world ~= nil and now - self.progress_world <= M.maximum_stall
end
local function power_state(values)
    local mission, electrical = values.EFM_MISSION_POWER_AVAILABLE, values.F22_ELECTRICAL_VALID
    local known = Snapshot.boolean(mission) and Snapshot.boolean(electrical)
    return known, mission == 1 and electrical == 1
end
local function thermal_resource(values)
    local temperature, fault = values.EFM_EQUIPMENT_TEMP_C, values.EFM_THERMAL_FAULT
    if values.EFM_ENVIRONMENT_VALID ~= 1 or not Snapshot.finite(temperature)
        or not Snapshot.boolean(fault) then return nil end
    if fault == 1 then return 0 end
    return math.max(0, math.min(1, (100 - temperature) / 40))
end
local function array_resource(get)
    local array = get("F22_AESA_ARRAY_HEALTH")
    if get("F22_AESA_ARRAY_KNOWN") ~= 1 or not Snapshot.finite(array)
        or array < 0 or array > 1 then return nil end
    return array
end
function M:update(now, powered)
    self:clear_health()
    local physical = self.physical:update()
    if not physical.valid or not self:progressing(now, physical) then return 0 end
    local power_available
    self.power_known, power_available = power_state(physical.values)
    if not self.power_known then return 0 end
    local thermal = thermal_resource(physical.values)
    if thermal == nil then return 0 end
    self.thermal_known = true
    local array = array_resource(self.get)
    if array == nil then return 0 end
    self.array_known, self.health_known = true, true
    if not powered or not power_available then return 0 end
    self.resource = math.min(array, thermal)
    return self.resource
end
local function flag(value) return value and 1 or 0 end
function M:publish(put)
    put("F22_RADAR_SERVICE_RESOURCE", self.resource)
    put("F22_RADAR_SERVICE_HEALTH_KNOWN", flag(self.health_known))
    put("F22_RADAR_RESOURCE_POWER_KNOWN", flag(self.power_known))
    put("F22_RADAR_RESOURCE_THERMAL_KNOWN", flag(self.thermal_known))
    put("F22_RADAR_RESOURCE_ARRAY_KNOWN", flag(self.array_known))
    local state = self.resource < M.minimum_resource and 0 or self.resource < .999 and 2 or 1
    put("F22_RADAR_SERVICE_STATE", state)
end
return M
