-- GPL-3.0-or-later. I-NAV-001 selected altitude admission, schema 1.
-- Ages are transport policies in World/model seconds, not aircraft sensor specs.
local M = { maximum_age = .2, future_tolerance = .01 }
M.__index = M
local function finite(v)
    return type(v) == 'number' and v == v and math.abs(v) < math.huge
end
local function integer(v, minimum, maximum)
    return finite(v) and v >= minimum and v <= maximum and v % 1 == 0
end
local function fresh(stamp, now)
    return finite(stamp) and stamp >= 0 and now - stamp >= -M.future_tolerance
        and now - stamp <= M.maximum_age
end
function M.clock()
    if type(get_model_time) ~= 'function' then return nil end
    local ok, now = pcall(get_model_time)
    if ok and finite(now) and now >= 0 then return now end
end
function M.new(get)
    local self = setmetatable({ get = get, valid = false, sources = {},
        last_generation = 0, last_clock = nil, blocked_generation = nil }, M)
    for _, name in ipairs({'BARO','RADAR','STANDBY'}) do
        local prefix = 'F22_ALT_'..name
        self.sources[name] = { valid = false, value = 0, stamp = 0,
            valid_key = prefix..'_VALID', value_key = prefix..'_FT', stamp_key = prefix..'_STAMP' }
        get(prefix..'_VALID'); get(prefix..'_FT'); get(prefix..'_STAMP')
    end
    return self
end
function M:capture()
    local get = self.get
    local before = get('F22_ALT_SNAPSHOT_SEQUENCE')
    if not integer(before, 2, 16777214) or before % 2 ~= 0 then return false end
    self.schema = get('F22_ALT_SNAPSHOT_SCHEMA')
    self.generation = get('F22_ALT_SNAPSHOT_GENERATION')
    self.kind = get('F22_ALT_SNAPSHOT_CLOCK_KIND')
    self.published = get('F22_ALT_SNAPSHOT_TIME')
    self.selection = get('F22_ALT_SNAPSHOT_SELECTION')
    for _, source in pairs(self.sources) do
        source.flag = get(source.valid_key)
        source.value = get(source.value_key)
        source.stamp = get(source.stamp_key)
    end
    return before == get('F22_ALT_SNAPSHOT_SEQUENCE')
end
function M:current(generation, physical_valid, now)
    if physical_valid ~= true or not integer(generation, 1, 4294967295)
        or not finite(now) or now < 0 or generation < self.last_generation then return false end
    if generation == self.last_generation and self.last_clock and now < self.last_clock then
        self.blocked_generation = generation
    end
    self.last_generation, self.last_clock = generation, now
    return self.blocked_generation ~= generation
end
local function header(self, generation, now)
    return self.schema == 1 and self.generation == generation and self.kind == 2
        and fresh(self.published, now) and integer(self.selection, 0, 2)
end
local function qualify_source(name, source, now)
    local minimum, maximum = -3000 * 3.280839895, 32000 * 3.280839895
    if name == 'RADAR' then minimum, maximum = 0, 20000 * 3.280839895 end
    source.valid = source.flag == 1 and finite(source.value)
        and source.value >= minimum and source.value <= maximum and fresh(source.stamp, now)
end
function M:update(generation, physical_valid, now)
    self.valid = false
    for _, source in pairs(self.sources) do source.valid = false end
    if not self:current(generation,physical_valid,now) then return false end
    local ok, coherent = pcall(self.capture, self)
    if not ok or not coherent or not header(self,generation,now) then return false end
    for name, source in pairs(self.sources) do
        qualify_source(name,source,now)
    end
    self.valid = true
    return true
end
function M:selected()
    if not self.valid then return nil, 'ALT --', false end
    local key, label = 'BARO', 'BARO'
    if self.selection == 1 then
        if self.sources.RADAR.valid then key, label = 'RADAR', 'RDR'
        else label = 'BARO FB' end
    elseif self.selection == 2 then key, label = 'STANDBY', 'STBY' end
    local source = self.sources[key]
    return source.valid and source.value or nil, label, source.valid
end
return M
