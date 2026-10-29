-- GPL-3.0-or-later. One bounded ground packet, World seconds and source epoch.
local M = {}
local fields = {"F22_AG_GMT_READY", "F22_AG_GMT_LAST_TIME", "F22_AG_GMT_COUNT",
    "F22_AG_NATIVE_MAP", "F22_AG_NATIVE_SEA",
    "F22_AG_AGR_VALID", "F22_AG_AGR_TIME", "F22_AG_AGR_RANGE_FT", "F22_AG_AGR_VELOCITY_KT"}
local track_fields = {"VALID", "ID", "TYPE", "TIME", "N", "U", "E", "VN", "VU", "VE",
    "VELOCITY_VALID", "ASSOCIATION_VALID", "ACQUIRING", "MEMORY", "ASPECT", "REQUEST_SEQUENCE"}
local mover_fields = {"ID", "TIME", "N", "U", "E", "VN", "VU", "VE", "AZ", "RANGE", "ASSOCIATION_VALID"}
local bool_fields={"F22_AG_GMT_READY","F22_AG_AGR_VALID","F22_AG_NATIVE_MAP","F22_AG_NATIVE_SEA",
    "F22_AG_NATIVE_TRACK_VALID",
    "F22_AG_NATIVE_TRACK_VELOCITY_VALID","F22_AG_NATIVE_TRACK_ASSOCIATION_VALID",
    "F22_AG_NATIVE_TRACK_ACQUIRING","F22_AG_NATIVE_TRACK_MEMORY"}
local function finite(value)
    return type(value) == "number" and value == value and math.abs(value) < 1e12
end
local function integer(value, lo, hi)
    return finite(value) and value >= lo and value <= hi and value % 1 == 0
end
local function committed(value)
    return integer(value, 2, 16777214) and value % 2 == 0
end
function M.new(raw_get, put)
    local s = { values = {}, protected = {}, movers = {}, epoch = 0, sequence = 0, depth = 0,
        coherent = false, ready = false, raw_get = raw_get, put = put }
    s.fields = {}
    for i = 1, #fields do s.fields[#s.fields + 1] = fields[i] end
    for i = 1, #track_fields do s.fields[#s.fields + 1] = "F22_AG_NATIVE_TRACK_"..track_fields[i] end
    for i = 1, #s.fields do s.protected[s.fields[i]], s.values[s.fields[i]] = true, 0 end
    for i = 1, 64 do
        local names = {}
        for j = 1, #mover_fields do
            names[j] = "F22_AG_GMT_"..i.."_"..mover_fields[j]
            s.protected[names[j]] = true
            s.values[names[j]] = 0
        end
        s.movers[i] = names
    end
    s.get = function(name)
        if s.protected[name] then return s.ready and s.values[name] or 0 end
        return raw_get(name)
    end
    return setmetatable(s, {__index = M})
end
function M:copy_fields(names)
    for i = 1, #names do
        local value = self.raw_get(names[i])
        if not finite(value) then return false end
        self.values[names[i]] = value
    end
    return true
end
function M:flags_valid()
    for i=1,#bool_fields do
        local value=self.values[bool_fields[i]]
        if value~=0 and value~=1 then return false end
    end
    return true
end
function M:header()
    local get=self.raw_get
    local sequence=get("F22_AG_NATIVE_SEQUENCE")
    if not committed(sequence) or get("F22_AG_NATIVE_SCHEMA")~=1 then return end
    local epoch=get("F22_AG_NATIVE_SOURCE_EPOCH")
    if not integer(epoch,1,16777215) then return end
    return sequence,epoch
end
function M:copy_movers(count)
    if not integer(count,0,64) then return false end
    for i=1,count do
        if not self:copy_fields(self.movers[i]) then return false end
        local valid=self.values[self.movers[i][#mover_fields]]
        if valid~=0 and valid~=1 then return false end
    end
    return true
end
function M:read(now)
    local get = self.raw_get
    self.coherent, self.ready = false, false
    local before,epoch=self:header()
    if not before or not self:copy_fields(self.fields) or not self:flags_valid()
        or not self:copy_movers(self.values.F22_AG_GMT_COUNT) then return false end
    if before ~= get("F22_AG_NATIVE_SEQUENCE") or epoch ~= get("F22_AG_NATIVE_SOURCE_EPOCH") then return false end
    self.epoch, self.coherent = epoch, true
    local stamp = self.values.F22_AG_GMT_LAST_TIME
    self.ready = self.values.F22_AG_GMT_READY == 1 and finite(now)
        and now >= stamp and now - stamp <= .5
    return true
end
function M:begin(now)
    if self.depth >= 8 then self.packet_healthy = false; return false end
    if self.depth == 0 then
        self.sequence = self.sequence >= 16777212 and 2 or self.sequence + 2
        self.put("F22_AG_NATIVE_CONTROL_SEQUENCE", self.sequence - 1)
        self.producer_time = now
        self.packet_healthy = true
    end
    self.depth = self.depth + 1
    return true
end
function M:finish(healthy)
    self.packet_healthy = self.packet_healthy and healthy
    self.depth = self.depth - 1
    if self.depth ~= 0 then return end
    local valid_clock = finite(self.producer_time) and self.producer_time >= 0
    if not self.packet_healthy or not valid_clock then
        self.put("F22_AG_RADAR_OPERATING", 0)
        self.put("F22_AG_TRACK_REQUEST_ACTIVE", 0)
        self.put("F22_AG_VIDEO_ENABLE", 0)
        self.put("F22_AG_DESIGNATION_VALID", 0)
        self.put("F22_AG_DESIGNATION_LIVE", 0)
        self.put("F22_AG_TRACK_VALID", 0)
    end
    self.put("F22_AG_NATIVE_CONTROL_SCHEMA", 1)
    self.put("F22_AG_NATIVE_CONTROL_EPOCH", self.epoch)
    self.put("F22_AG_NATIVE_CONTROL_TIME", valid_clock and self.producer_time or -100)
    self.put("F22_AG_NATIVE_CONTROL_SEQUENCE", self.sequence)
end
M.finite = finite
return M
