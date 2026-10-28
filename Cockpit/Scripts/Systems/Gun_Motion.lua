-- GPL-3.0-or-later. Gun maneuver estimate from measured track velocity history.
-- A short velocity fit avoids differentiating individual noisy radar reports.
-- Window and damping are mod estimator policy, not recovered F-22 parameters.
local M = {maximum_interval = .5, window = .24, capacity = 32}

local function finite(value)
    return type(value) == 'number' and value == value and math.abs(value) < 1e8
end

local function norm(v)
    return math.sqrt(v[1]^2 + v[2]^2 + v[3]^2)
end

local function valid_sample(time, velocity)
    if not finite(time) or type(velocity) ~= 'table' then return false end
    for axis = 1, 3 do
        if not finite(velocity[axis]) then return false end
    end
    return norm(velocity) <= 1500
end

local function slot(self, offset)
    return self.samples[(self.first + offset - 1) % M.capacity + 1]
end

local function append(self, time, velocity, speed)
    if self.count == M.capacity then
        self.first = self.first % M.capacity + 1
        self.count = self.count - 1
    end
    local value = slot(self, self.count)
    value.time, value.speed = time, speed
    for axis = 1, 3 do value.v[axis] = velocity[axis] end
    self.count = self.count + 1
    -- Retain the report bracketing the window, including two slower reports.
    while self.count > 2 and time - slot(self, 1).time >= M.window do
        self.first = self.first % M.capacity + 1
        self.count = self.count - 1
    end
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
    return tangent / denominator
end

local function rotation(self)
    local mean, slope, omega = self.mean, self.slope, self.raw_omega
    local square = mean[1]^2 + mean[2]^2 + mean[3]^2
    if square < 1e-8 then
        for axis = 1, 3 do omega[axis] = 0 end
        return
    end
    omega[1] = (mean[2]*slope[3] - mean[3]*slope[2]) / square
    omega[2] = (mean[3]*slope[1] - mean[1]*slope[3]) / square
    omega[3] = (mean[1]*slope[2] - mean[2]*slope[1]) / square
end

local function acceleration(self, velocity, speed, tangent, dt)
    rotation(self)
    local gain = self.warmed and 1 - math.exp(-dt/.12) or 1
    for axis = 1, 3 do
        self.omega[axis] = self.omega[axis] + gain * (self.raw_omega[axis] - self.omega[axis])
    end
    self.tangent = self.tangent + gain * (tangent - self.tangent)
    self.warmed = true
    local w, a = self.omega, self.a
    a[1] = w[2]*velocity[3] - w[3]*velocity[2]
    a[2] = w[3]*velocity[1] - w[1]*velocity[3]
    a[3] = w[1]*velocity[2] - w[2]*velocity[1]
    if speed > 1e-6 then
        for axis = 1, 3 do a[axis] = a[axis] + self.tangent * velocity[axis] / speed end
    end
    return a
end

function M.new()
    local state = {samples = {}, first = 1, count = 0, tangent = 0, warmed = false,
        mean = {0,0,0}, slope = {0,0,0}, raw_omega = {0,0,0}, omega = {0,0,0}, a = {0,0,0}}
    for index = 1, M.capacity do state.samples[index] = {time = 0, speed = 0, v = {0,0,0}} end
    function state:reset()
        self.t, self.count, self.first = nil, 0, 1
        self.tangent, self.warmed = 0, false
        for axis = 1, 3 do self.omega[axis], self.a[axis] = 0, 0 end
    end
    function state:update(time, velocity)
        if not valid_sample(time, velocity) then self:reset(); return end
        if self.t == time then
            if self.warmed then return self.a end
            return
        end
        local speed = norm(velocity)
        local dt = self.t and time - self.t or 0
        if dt <= 0 or dt > M.maximum_interval then self:reset() end
        self.t = time
        append(self, time, velocity, speed)
        if self.count < 2 then return end
        local tangent = fit(self, time)
        if not tangent then self:reset(); return end
        local value = acceleration(self, velocity, speed, tangent, dt)
        if norm(value) > 150 then self:reset(); return end
        return value
    end
    return state
end
return M
