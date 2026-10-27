-- GPL-3.0-or-later. Independent transcription of the observed Hornet branch:
-- MC 0x1803B7F98..0x1803B80C8. Mod attitude is positive right bank.
local M = {}
function M.new()
    local self = {}
    function self:reset()
        self.vertical_since, self.oblique_since, self.clock = nil, nil, nil
    end
    function self:update(now, vertical_intercepts, oblique_intercepts, roll)
        if self.clock and now < self.clock then self:reset() end
        self.clock = now
        if vertical_intercepts then
            self.vertical_since = self.vertical_since or now
        else self.vertical_since = nil end
        if oblique_intercepts then
            self.oblique_since = self.oblique_since or now
        else self.oblique_since = nil end
        if not vertical_intercepts or not oblique_intercepts then
            return { threat = false }
        end
        -- These are onset timestamps across predictions, not time-to-impact.
        -- Equal onsets select oblique, as in the native <= comparison.
        local mode = self.vertical_since <= self.oblique_since and 1 or 0
        local call = "pull_up"
        if mode == 0 then
            if roll > math.pi / 4 then call = "roll_left"
            elseif roll < -math.pi / 4 then call = "roll_right" end
        end
        return { threat = true, mode = mode, call = call }
    end
    return self
end
return M
