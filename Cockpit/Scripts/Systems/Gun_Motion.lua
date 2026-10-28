-- GPL-3.0-or-later. Gun maneuver estimate from measured track velocity history.
-- A bounded velocity fit carries the radar uncertainty into a maneuver observer.
-- Window/observer settings are mod estimator policies, not F-22 parameters.
local M = {maximum_interval = .5, window = .24, capacity = 32}

local Observer = dofile(LockOn_Options.script_path .. 'Systems/Gun_Maneuver_Observer.lua')

local function finite(value)
    return type(value) == 'number' and value == value and math.abs(value) < 1e8
end

local function norm(v)
    return math.sqrt(v[1]^2 + v[2]^2 + v[3]^2)
end

local function valid_sample(time, velocity, sigma)
    if not finite(time) or type(velocity) ~= 'table' then return false end
    if sigma ~= nil and (not finite(sigma) or sigma < 0 or sigma > 100) then return false end
    for axis = 1, 3 do
        if not finite(velocity[axis]) then return false end
    end
    return norm(velocity) <= 1500
end

local function slot(self, offset)
    return self.samples[(self.first + offset - 1) % M.capacity + 1]
end

local function append(self, time, velocity, speed, sigma)
    if self.count == M.capacity then
        self.first = self.first % M.capacity + 1
        self.count = self.count - 1
    end
    local value = slot(self, self.count)
    value.time, value.speed, value.sigma = time, speed, sigma or 0
    for axis = 1, 3 do value.v[axis] = velocity[axis] end
    self.count = self.count + 1
    -- Retain the report bracketing the window, including two slower reports.
    while self.count > 2 and time - slot(self, 1).time >= self.window do
        self.first = self.first % M.capacity + 1
        self.count = self.count - 1
    end
end

-- A smooth correlated posterior can have small fit residuals while retaining
-- substantial uncertainty. Never let those residuals erase the radar's sigma.
local function fit_error(self, time, mean_time, mean_speed, tangent, denominator)
    local error, speed_error, floor = self.error, 0, 0
    for axis = 1, 3 do error[axis] = 0 end
    for index = 0, self.count - 1 do
        local value = slot(self, index)
        local delta = value.time - time - mean_time
        floor = math.max(floor, value.sigma^2)
        speed_error = speed_error + (value.speed - mean_speed - tangent * delta)^2
        for axis = 1, 3 do
            local residual = value.v[axis] - self.mean[axis] - self.slope[axis] * delta
            error[axis] = error[axis] + residual * residual
        end
    end
    local degrees = math.max(1, self.count - 2)
    for axis = 1, 3 do error[axis] = math.max(error[axis] / degrees, floor) / denominator end
    self.speed_error = math.max(speed_error / degrees, floor) / denominator
end

local function fit(self, time)
    local mean_time, mean_speed = 0, 0
    local mean, slope = self.mean, self.slope
    for axis = 1, 3 do mean[axis], slope[axis] = 0, 0 end
    for index = 0, self.count - 1 do
        local value = slot(self, index)
        mean_time = mean_time + value.time - time
        mean_speed = mean_speed + value.speed
        for axis = 1, 3 do mean[axis] = mean[axis] + value.v[axis] end
    end
    mean_time, mean_speed = mean_time / self.count, mean_speed / self.count
    self.sample_time = time + mean_time
    for axis = 1, 3 do mean[axis] = mean[axis] / self.count end
    local denominator, tangent = 0, 0
    for index = 0, self.count - 1 do
        local value = slot(self, index)
        local delta = value.time - time - mean_time
        denominator = denominator + delta * delta
        tangent = tangent + delta * (value.speed - mean_speed)
        for axis = 1, 3 do slope[axis] = slope[axis] + delta * (value.v[axis] - mean[axis]) end
    end
    if denominator <= 1e-12 then return end
    for axis = 1, 3 do slope[axis] = slope[axis] / denominator end
    tangent = tangent / denominator
    fit_error(self, time, mean_time, mean_speed, tangent, denominator)
    return tangent
end

local function rotation(self)
    local mean, slope, omega = self.mean, self.slope, self.raw_omega
    local square = mean[1]^2 + mean[2]^2 + mean[3]^2
    if square < 1e-8 then
        for axis = 1, 3 do omega[axis], self.variance[axis] = 0, 0 end
        return
    end
    local variance, error = self.variance, self.error
    variance[1] = (mean[2]^2 * error[3] + mean[3]^2 * error[2]) / square^2
    variance[2] = (mean[3]^2 * error[1] + mean[1]^2 * error[3]) / square^2
    variance[3] = (mean[1]^2 * error[2] + mean[2]^2 * error[1]) / square^2
    omega[1] = (mean[2]*slope[3] - mean[3]*slope[2]) / square
    omega[2] = (mean[3]*slope[1] - mean[1]*slope[3]) / square
    omega[3] = (mean[1]*slope[2] - mean[2]*slope[1]) / square
end

-- The fitted velocity belongs to sample_time, just like its maneuver rate.
-- Rotate it to the report epoch with that same estimated turn. Passing the
-- raw radar velocity beside a filtered acceleration bypasses this estimate.
local function current_velocity(self, mean_speed)
    local w, mean, velocity = self.turn, self.mean, self.velocity
    for axis = 1, 3 do w[axis] = self.observer:integral(axis, self.t) end
    local angle = norm(w)
    local sinc = math.abs(angle) < 1e-5 and 1 - angle^2 / 6 or math.sin(angle) / angle
    local cosc = math.abs(angle) < 1e-5 and .5 - angle^2 / 24 or (1 - math.cos(angle)) / angle^2
    local along = w[1]*mean[1] + w[2]*mean[2] + w[3]*mean[3]
    velocity[1] = mean[1]*math.cos(angle) + (w[2]*mean[3]-w[3]*mean[2])*sinc + w[1]*along*cosc
    velocity[2] = mean[2]*math.cos(angle) + (w[3]*mean[1]-w[1]*mean[3])*sinc + w[2]*along*cosc
    velocity[3] = mean[3]*math.cos(angle) + (w[1]*mean[2]-w[2]*mean[1])*sinc + w[3]*along*cosc
    local length = norm(velocity)
    if length > 1e-6 then
        local speed = math.max(0, mean_speed + self.observer:integral(4, self.t))
        for axis = 1, 3 do velocity[axis] = velocity[axis] * speed / length end
    end
    return norm(velocity)
end

local function acceleration(self, mean_speed, tangent)
    rotation(self)
    for axis = 1, 3 do
        self.omega[axis] = self.observer:update(axis, self.raw_omega[axis], self.variance[axis],
            self.sample_time, self.t, self.window)
    end
    self.tangent = self.observer:update(4, tangent, self.speed_error, self.sample_time, self.t, self.window)
    self.warmed = true
    local speed = current_velocity(self, mean_speed)
    local w, a, velocity = self.omega, self.a, self.velocity
    a[1] = w[2]*velocity[3] - w[3]*velocity[2]
    a[2] = w[3]*velocity[1] - w[1]*velocity[3]
    a[3] = w[1]*velocity[2] - w[2]*velocity[1]
    if speed > 1e-6 then
        for axis = 1, 3 do a[axis] = a[axis] + self.tangent * velocity[axis] / speed end
    end
    return a
end

function M.new()
    local state = {observer = Observer.new(), error = {0,0,0}, variance = {0,0,0}, samples = {},
        first = 1, count = 0, tangent = 0, warmed = false, window = M.window, mean = {0,0,0}, slope = {0,0,0},
        raw_omega = {0,0,0}, omega = {0,0,0}, a = {0,0,0}, velocity = {0,0,0}, turn = {0,0,0}}
    for index = 1, M.capacity do state.samples[index] = {time = 0, speed = 0, sigma = 0, v = {0,0,0}} end
    function state:reset()
        self.t, self.count, self.first = nil, 0, 1
        self.tangent, self.warmed = 0, false
        self.observer:reset()
        for axis = 1, 3 do self.omega[axis], self.a[axis] = 0, 0 end
    end
    function state:update(time, velocity, sigma)
        if not valid_sample(time, velocity, sigma) then self:reset(); return end
        if self.t == time then
            if self.warmed then return self.a end
            return
        end
        local speed = norm(velocity)
        local dt = self.t and time - self.t or 0
        if dt <= 0 or dt > M.maximum_interval then self:reset() end
        self.t = time
        -- Endpoint derivative fit: use a shorter history when velocity is
        -- precise. This bias/variance policy is a mod estimate, not radar data.
        self.window = math.max(.06, math.min(M.window, M.window*((sigma or 0)/2.34)^.4))
        append(self, time, velocity, speed, sigma)
        if self.count < 2 then return end
        local tangent = fit(self, time)
        if not tangent then self:reset(); return end
        local mean_speed = 0
        for index = 0, self.count - 1 do mean_speed = mean_speed + slot(self, index).speed end
        local value = acceleration(self, mean_speed / self.count, tangent)
        if norm(value) > 150 then self:reset(); return end
        return value
    end
    return state
end
return M
