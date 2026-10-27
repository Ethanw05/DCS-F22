-- GPL-3.0-or-later. Presentation of DCS's native receiver proximity value.
-- CockpitBase avRWR::getSignalStreigth (0x1802FBA50) returns
-- 1 - distance / effective detection range. avSimpleRWR exports it as POWER.
-- This is relative proximity; the emitter/mode-dependent denominator is not NM.
local M = {}
function M.valid(power)
    return type(power)=='number' and power==power and power>=0 and power<=1
end
function M.radius(power, outer)
    if not M.valid(power) then return end
    return (outer or .84)*math.max(.14,1-power)
end
return M
