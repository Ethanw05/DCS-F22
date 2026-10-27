-- GPL-3.0-or-later. Read-only physical envelope, spawn-relative clock kind 1.
-- Freshness limits are adapter policies, not aircraft sensor specifications.
local M = { maximum_age = .25, future_tolerance = .05 }
M.__index = M

function M.finite(value)
    return type(value) == 'number' and value == value and math.abs(value) < math.huge
end

function M.boolean(value)
    return value == 0 or value == 1
end

function M.fresh(stamp, clock)
    if not M.finite(stamp) or not M.finite(clock) or stamp < 0 or clock < 0 then return false end
    local age = clock - stamp
    return age >= -M.future_tolerance and age <= M.maximum_age
end

function M.new(get, fields)
    assert(#fields <= 64, 'Physical snapshot field budget exceeded')
    local self = setmetatable({ get = get, fields = fields, values = {},
        owned = false, valid = false, generation = 0, stamp = 0, clock = 0 }, M)
    for index = 1, #fields do self.values[fields[index]] = 0; get(fields[index]) end
    for _, key in ipairs({ 'EFM_POWER_OWNER', 'EFM_PHYSICAL_VALID', 'EFM_PHYSICAL_GENERATION',
        'EFM_PHYSICAL_STAMP', 'EFM_PHYSICAL_CLOCK_KIND', 'F22_AP_CLOCK' }) do get(key) end
    return self
end
local function coherent(get, owner, valid, generation, stamp, kind)
    return owner == 1 and get('EFM_POWER_OWNER') == 1 and valid == 1
        and get('EFM_PHYSICAL_VALID') == 1 and kind == 1 and get('EFM_PHYSICAL_CLOCK_KIND') == 1
        and generation == get('EFM_PHYSICAL_GENERATION') and stamp == get('EFM_PHYSICAL_STAMP')
end

function M:update()
    local get = self.get
    self.valid = false
    local owner = get('EFM_POWER_OWNER')
    if owner == 1 then self.owned = true end
    if not self.owned then return self end
    local valid = get('EFM_PHYSICAL_VALID')
    local generation = get('EFM_PHYSICAL_GENERATION')
    local stamp, kind = get('EFM_PHYSICAL_STAMP'), get('EFM_PHYSICAL_CLOCK_KIND')
    for index = 1, #self.fields do
        local key = self.fields[index]
        self.values[key] = get(key)
    end
    local clock = get('F22_AP_CLOCK')
    if not coherent(get, owner, valid, generation, stamp, kind) then return self end
    if not M.finite(generation) or generation < 1 or generation > 4294967295
        or generation % 1 ~= 0 or not M.fresh(stamp, clock) then return self end
    self.valid, self.generation, self.stamp, self.clock = true, generation, stamp, clock
    return self
end

return M
