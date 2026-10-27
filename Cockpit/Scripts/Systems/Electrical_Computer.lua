-- Small estimated electrical reserve, integrated only by Engine_System.
-- 12 Ah, 18 A essential load, 80 A APU-start load and 8 A recharge are mod
-- parameters. Public evidence does not establish a production F-22 bus deck.
local M = {}
function M.new()
    local self = {soc=1, capacity_ah=12, volts=0, battery=0, essential=0}
    function self:available(requested, failed)
        return requested and not failed and self.soc > .02
    end
    function self:update(dt, requested, main_available, apu_starting, failed)
        dt = type(dt)=="number" and dt==dt and math.max(0,dt) or 0
        local amps = 0
        if not failed then
            if main_available then amps = -8
            elseif requested then amps = 18 + (apu_starting and 80 or 0) end
        end
        self.soc = math.max(0, math.min(1, self.soc - amps * dt / (3600*self.capacity_ah)))
        self.battery = requested and not failed and (main_available or self.soc > .02) and 1 or 0
        self.essential = (main_available or self.battery==1) and 1 or 0
        self.volts = main_available and 28 or (self.battery==1 and 24+4*self.soc or 0)
    end
    return self
end
return M
