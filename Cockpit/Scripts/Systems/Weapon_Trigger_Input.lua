-- GPL-3.0-or-later. Fixed command-source ownership for momentary gun detents.
local M = {}
M.__index = M
local decode = dofile(LockOn_Options.script_path..'Systems/Input_Value.lua')
local slots = {[10021] = 1, [10801] = 2, [10022] = 3, [10802] = 4}

local function down(value, device)
    if type(value) ~= 'number' or value ~= value or math.abs(value) == math.huge then return nil end
    local normalized = decode(value, device)
    if math.abs(normalized) <= .0001 then return false end
    if math.abs(normalized - 1) <= .0001 then return true end
    return nil
end

function M.new(device)
    local self = setmetatable({device = device, sources = {}}, M)
    for index = 1, 4 do self.sources[index] = {down = false, accepted = false} end
    return self
end

function M:reset()
    for index = 1, 4 do
        self.sources[index].down = false
        self.sources[index].accepted = false
    end
end

function M:cancel()
    -- Keep physical down ownership: restoration/repeated down is not a new press.
    for index = 1, 4 do self.sources[index].accepted = false end
end

function M:input(command, value, permitted)
    local index = slots[command]
    if not index then return false end
    local source = self.sources[index]
    local pressed = down(value, self.device)
    if pressed == nil then source.accepted = false; return true end
    if pressed and not source.down then source.accepted = permitted == true end
    if not pressed then source.accepted = false end
    source.down = pressed
    return true
end

function M:state()
    local first = self.sources[1].accepted or self.sources[2].accepted
    local second = self.sources[3].accepted or self.sources[4].accepted
    return first and 1 or 0, second and 1 or 0
end

return M
