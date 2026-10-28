-- Common diagnostic protocol only; no DCS registration or implicit activation.
-- The caller supplies an observed wall/render clock, generation and effect port.
local M = { capacity = 64, maximum_hold_seconds = 2 }
local function finite(v)
    return type(v) == 'number' and v == v and math.abs(v) < math.huge
end
function M.new(effect)
    assert(type(effect) == 'function')
    local s = { queue = {}, held = {}, epoch = nil, clock = nil, active = false }
    function s:stop()
        for command in pairs(self.held) do effect(command, 0); self.held[command] = nil end
        self.queue = {}
        self.active = false
    end
    function s:start(epoch, now, explicitly_enabled)
        self:stop()
        if explicitly_enabled ~= true or not finite(epoch) or epoch < 1
            or epoch % 1 ~= 0 or not finite(now) or now < 0 then return false end
        self.epoch, self.clock, self.active = epoch, now, true
        return true
    end
    function s:request(command, value, hold_seconds)
        if not self.active or #self.queue >= M.capacity then return false end
        if not finite(command) or command < 1 or command % 1 ~= 0 or not finite(value)
            or not finite(hold_seconds) or hold_seconds < 0
            or hold_seconds > M.maximum_hold_seconds then return false end
        -- Bound distinct outstanding holds across successive ticks as well as
        -- the queue itself. Pending releases may conservatively occupy a slot.
        local used, count = {}, 0
        for key in pairs(self.held) do used[key] = true; count = count + 1 end
        for i = 1, #self.queue do
            local q = self.queue[i]
            if q.value ~= 0 and not used[q.command] then
                used[q.command] = true; count = count + 1
            end
        end
        if value ~= 0 and not used[command] and count >= M.capacity then return false end
        self.queue[#self.queue + 1] = { command = command, value = value, hold = hold_seconds }
        return true -- Accepted request only; no claim of achieved simulator effect.
    end
    function s:tick(epoch, now, paused)
        if not self.active then return false end
        if epoch ~= self.epoch or not finite(now) or now < self.clock or paused then
            self:stop()
            return false
        end
        self.clock = now
        for command, deadline in pairs(self.held) do
            if now >= deadline then effect(command, 0); self.held[command] = nil end
        end
        for i = 1, #self.queue do
            local q = self.queue[i]
            effect(q.command, q.value)
            if q.value ~= 0 then
                if q.hold == 0 then effect(q.command, 0)
                else self.held[q.command] = now + q.hold end
            else self.held[q.command] = nil end
        end
        self.queue = {}
        return true
    end
    return s
end
return M
