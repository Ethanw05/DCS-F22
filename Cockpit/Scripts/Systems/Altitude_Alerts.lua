-- GPL-3.0-or-later. Separate radar-low, barometric-floor and landing-minima events.
-- ED Hornet guide (24 March 2024), p70: repeating gear-up radar low, distinct disable/reset,
-- and one gear-down crossing. 100 ft rearm / 5 s pending expiry are mod policies.
local M = {}
M.__index = M
local function finite(value)
    return type(value) == 'number' and value == value and math.abs(value) < 1e9
end
local function available(value, limit, valid)
    return valid and finite(value) and finite(limit) and limit > 0
end
function M.new()
    return setmetatable({ low = { active = false, disabled = false, ticket = 0 },
        baro = { armed = false, pending = false, ticket = 0 },
        minima = { armed = false, pending = false, ticket = 0 },
        occurrence = 0, selected = 0, label = '' }, M)
end
function M:raise(state, now)
    if self.occurrence >= 16777215 then state.ticket, state.pending = 0, false; return end
    self.occurrence = self.occurrence + 1
    state.ticket, state.pending, state.until_time = self.occurrence, true, now + 5
end
function M:crossing(state, value, limit, valid, now)
    if not available(value, limit, valid) then
        state.armed, state.pending = false, false
        return
    end
    if state.limit ~= limit then
        state.limit, state.armed, state.pending = limit, value > limit + 100, false
    end
    if value > limit + 100 then state.armed = true end
    if state.armed and value < limit then state.armed = false; self:raise(state, now) end
    if state.pending and now > state.until_time then state.pending = false end
end
function M:radar_low(s, flight, up)
    local low = self.low
    local valid = available(s.radar, s.radar_floor, flight and up and s.radar_valid)
    if valid and s.radar >= s.radar_floor then low.disabled = false end
    local active = valid and s.radar < s.radar_floor and not low.disabled
    if active and not low.active then self:raise(low, s.now) end
    low.active = active
end
function M:update(s, flight)
    local up, down = s.gear_up, s.gear_down
    if up == nil then up = not s.gear end
    if down == nil then down = s.gear == true end
    self:radar_low(s, flight, up)
    self:crossing(self.baro, s.baro, s.baro_floor, flight and up and s.baro_valid, s.now)
    local radar = s.minima_source ~= 1
    local height, valid = s.baro, s.baro_valid
    if radar then height, valid = s.radar, s.radar_valid end
    self:crossing(self.minima, height, s.minima_floor, flight and down and valid, s.now)
    self.selected, self.label = 0, ''
    if self.low.active then self.selected, self.label = self.low.ticket, 'RADAR LOW'
    elseif self.minima.pending then self.selected, self.label = self.minima.ticket, 'MINIMA'
    elseif self.baro.pending then self.selected, self.label = self.baro.ticket, 'BARO FLOOR' end
    return self.selected ~= 0
end
function M:played(ticket)
    if ticket == self.minima.ticket then self.minima.pending = false end
    if ticket == self.baro.ticket then self.baro.pending = false end
    -- Playing/acknowledging an ALTITUDE clip never disables persistent radar-low.
end
function M:disable_current()
    if not self.low.active or self.low.ticket < 1 then return false end
    self.low.disabled, self.low.active = true, false
    return true, self.low.ticket
end
function M:power_lost()
    self.low.active = false
    self.baro.pending, self.baro.armed = false, false
    self.minima.pending, self.minima.armed = false, false
    self.selected, self.label = 0, ''
    -- Keep the disable latch until a qualified height resets it; no action is replayed.
end
return M
