-- SPDX-License-Identifier: GPL-3.0-or-later
local M = {}
function M.Clamp(value, minimum, maximum)
    if type(value) ~= "number" or value ~= value then return minimum end
    return math.max(minimum, math.min(maximum, value))
end
function M.Approach(value, target, rate, dt)
    return value + M.Clamp(target - value, -rate * dt, rate * dt)
end
function M.Lag(value, target, tau, dt)
    return target + (value - target) * math.exp(-dt / math.max(tau, 0.001))
end
function M.Wrap360(value) return value % 360 end
function M.AngleError(target, current) return (target - current + 180) % 360 - 180 end
function M.CounterAngle(value, period) return -(value % period) / period * math.pi * 2 end
function M.FlightPath(vx, vy, vz, limitX, limitY)
    if vx <= 1 or vx * vx + vy * vy + vz * vz < 100 then return 0, 0, false, false end
    local x, y = 1000 * vz / vx, 1000 * vy / vx
    local caged = math.abs(x) > limitX or math.abs(y) > limitY
    return M.Clamp(x, -limitX, limitX), M.Clamp(y, -limitY, limitY), true, caged
end
return M
