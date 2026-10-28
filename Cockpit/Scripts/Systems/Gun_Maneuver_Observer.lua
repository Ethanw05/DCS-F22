-- GPL-3.0-or-later. Fixed four-axis maneuver observer, not a display filter.
-- Each fitted rate belongs to the center of its measurement window. Estimate
-- its derivative there, then propagate to the current observation epoch.
-- Driving variances are mod estimator policies, not F-22 specifications.
local M = { rotation_driving_variance = .01, tangent_driving_variance = 100 }
M.__index = M

function M.new()
    local self = setmetatable({filters = {}}, M)
    for index = 1, 4 do
        self.filters[index] = {valid = false, time = 0, value = 0, rate = 0,
            variance = 0, cross = 0, rate_variance = 0}
    end
    return self
end

function M:reset()
    for index = 1, 4 do self.filters[index].valid = false end
end

function M:update(index, observed, error, stamp, now, window)
    local filter = self.filters[index]
    local process = index == 4 and M.tangent_driving_variance or M.rotation_driving_variance
    local dt = stamp - filter.time
    if not filter.valid or dt <= 0 or dt > .5 then
        filter.value, filter.rate, filter.time = observed, 0, stamp
        filter.variance, filter.cross = error, 0
        filter.rate_variance = math.max(process, error / window^2)
        filter.valid = true
        return observed
    end
    local variance = filter.variance + 2 * dt * filter.cross
        + dt^2 * filter.rate_variance + process * dt^3 / 3
    local cross = filter.cross + dt * filter.rate_variance + process * dt^2 / 2
    local rate_variance = filter.rate_variance + process * dt
    local innovation = observed - filter.value - filter.rate * dt
    local denominator = math.max(1e-12, variance + error)
    local gain, rate_gain = variance / denominator, cross / denominator
    filter.value = filter.value + filter.rate * dt + gain * innovation
    filter.rate = filter.rate + rate_gain * innovation
    filter.variance, filter.cross = (1 - gain) * variance, (1 - gain) * cross
    filter.rate_variance = math.max(0, rate_variance - rate_gain * cross)
    filter.time = stamp
    return filter.value + filter.rate * (now - stamp)
end

return M
