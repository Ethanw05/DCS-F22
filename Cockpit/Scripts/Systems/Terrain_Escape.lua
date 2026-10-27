-- GPL-3.0-or-later. Advisory terrain recovery, no flight-control commands.
-- Hornet response/roll/G phases and vertical/oblique onset selection. Terrain
-- access, wind, low-speed/FCS limits and approach inhibit are mod adaptations.
local M = {
    version = 3, horizon = 30, reaction = 0.8, clearance = 15.24,
    corridor = 15, spacing = 35, max_step = 0.05, max_queries = 12000,
    g_onset = 8, max_g = 6, one_g_eas = 80,
}
local Director = dofile(LockOn_Options.script_path .. "Systems/Terrain_Director.lua")
local g = 9.80665
local function finite(x)
	return type(x) == "number" and x == x and math.abs(x) < 1e9
end
local function clamp(x, a, b)
	return math.max(a, math.min(b, x))
end
local function wrap(x)
	return (x + math.pi) % (2 * math.pi) - math.pi
end
local function approach(x, target, step)
	return x + clamp(target - x, -step, step)
end
local function query(height, visible)
	local cache, traces, count = {}, {}, 0
	local function sample(n, e)
		local key = string.format("%.2f:%.2f", n, e)
		if cache[key] ~= nil then
			return cache[key]
		end
		count = count + 1
		if count > M.max_queries then
			return
		end
		local ok, z = pcall(height, n, e)
		if not ok or not finite(z) then
			return
		end
		cache[key] = z
		return z
	end
	local function trace(a, b)
		local key = string.format("%.2f:%.2f:%.2f:%.2f:%.2f:%.2f", a[1], a[2], a[3], b[1], b[2], b[3])
		if traces[key] ~= nil then
			return traces[key]
		end
		count = count + 1
		if count > M.max_queries then
			return
		end
		local ok, clear = pcall(visible, a[1], a[2], a[3], b[1], b[2], b[3])
		if not ok or type(clear) ~= "boolean" then
			return
		end
		traces[key] = clear
		return clear
	end
	return sample, function()
		return count
	end, type(visible) == "function" and trace or nil
end
-- Constant-speed point-mass prediction, as in the traced Hornet branch.
-- World coordinates replace its geographic coordinates. The turn equation
-- retains g and mirrored roll rates, rather than its signed +70-degree test.
local function simulate(s, height, option, trace)
    local n, u, e = s.n, s.u, s.e
    local wn, wu, we = s.wn or 0, s.wu or 0, s.we or 0
    local vn, vu, ve = s.vn - wn, s.vu - wu, s.ve - we
    local speed = math.sqrt(vn * vn + vu * vu + ve * ve)
    if speed < 20 or speed > 1200 then return { valid = false } end
    local horizontal = math.sqrt(vn * vn + ve * ve)
    local heading = horizontal > 1 and math.atan2(ve, vn) or s.heading
    local initial_heading = heading
    local gamma = math.atan2(vu, horizontal)
    local bank, load, elapsed = wrap(s.roll), s.nz, 0
    local roll_limit = math.rad(math.abs(bank) > 70 * math.pi / 180 and 90 or 60)
    local max_load = math.min(M.max_g, (s.cas / M.one_g_eas) ^ 2)
    if s.fcs_fault then
        max_load, roll_limit = math.min(max_load, 1.5), math.min(roll_limit, math.rad(30))
    end
    local path = {valid = true, minimum = math.huge, name = option or "current",
        bank = option == "level" and 0 or bank,
        direction = option == "level" and wrap(-bank) or 0}
    local initial_clearance, initial_ground, trace_margin, previous_points, previous_time, previous_clearance
    path.terrain_rise = 0
    while elapsed <= M.horizon do
        local cg, sg = math.cos(gamma), math.sin(gamma)
        local hn, he = math.cos(heading), math.sin(heading)
        local ground_n, ground_e = speed * cg * hn + wn, speed * cg * he + we
        local gh = math.sqrt(ground_n * ground_n + ground_e * ground_e)
        local rn, re = -he, hn
        if gh > 1 then rn, re = -ground_e / gh, ground_n / gh end
        local maximum = -math.huge
        for _, side in ipairs({-1, 0, 1}) do
            local z = height(n + rn * M.corridor * side, e + re * M.corridor * side)
            if not z then path.valid = false; return path end
            maximum = math.max(maximum, z)
        end
        local clearance = u - maximum - M.clearance
        path.initial_agl = path.initial_agl or u - maximum
        initial_ground = initial_ground or maximum
        trace_margin = trace_margin or math.min(M.clearance, math.max(0, u - maximum - 5))
        path.terrain_rise = math.max(path.terrain_rise, maximum - initial_ground)
        initial_clearance = initial_clearance or clearance
        path.minimum = math.min(path.minimum, clearance)
        -- Stable low flight alone is not a terrain intersection.
        if not path.impact and clearance < 0 and (clearance < initial_clearance - 5 or u - maximum < 5) then
            path.impact = elapsed
        end
        if trace then
            local points = {}
            for j, side in ipairs({-1, 0, 1}) do
                points[j] = {n + rn * M.corridor * side, u - trace_margin, e + re * M.corridor * side}
                if previous_points then
                    local clear = trace(previous_points[j], points[j])
                    if clear == nil then path.valid = false; return path end
                    if not clear then
                        path.impact = path.impact or previous_time
                        if previous_clearance > trace_margin and u - maximum > trace_margin then path.obstruction = true end
                    end
                end
            end
            previous_points, previous_time, previous_clearance = points, elapsed, u - maximum
        end
        if path.impact and (option or not s.approach) then break end
        if elapsed >= M.horizon - 1e-8 or gamma >= math.pi / 2
            or (option == "oblique" and math.abs(heading - initial_heading) >= math.pi / 2) then break end
        local dt = math.min(M.max_step, M.spacing / math.max(speed, gh), M.horizon - elapsed)
        -- Vertical: response -> roll level at current G -> G onset.
        -- Oblique: response -> G onset at retained bank. No lateral candidates.
        if option and elapsed > M.reaction then
            if option == "level" and math.abs(bank) > 1e-6 then
                bank = approach(bank, 0, roll_limit * dt)
            else
                load = approach(load, max_load, M.g_onset * dt)
            end
        end
        n, u, e = n + ground_n * dt, u + (speed * sg + wu) * dt, e + ground_e * dt
        gamma = gamma + (load * math.cos(bank) - cg) * g / speed * dt
        heading = heading + load * math.sin(bank) * g / (speed * math.max(0.05, math.abs(cg))) * dt
        elapsed = elapsed + dt
    end
    path.safe = not path.impact
    return path
end
local function valid(s, height)
    if type(height) ~= "function" then return false, 1 end
    for _, k in ipairs({"n", "u", "e", "vn", "vu", "ve", "roll", "heading", "cas", "nz"}) do
        if not finite(s[k]) then return false, 2 end
    end
    for _, k in ipairs({"wn", "wu", "we", "roll_rate"}) do
        if s[k] ~= nil and not finite(s[k]) then return false, 2 end
    end
    if s.cas < 35 or s.cas > 1000 or s.nz < -4 or s.nz > 12 or math.abs(s.roll) > 2 * math.pi then return false, 2 end
    return true
end
local function direct(result, director, now, roll)
    if not result.valid or result.landing then director:reset(); return result end
    local paths = result.paths
    local d = director:update(now, paths[1].impact ~= nil, paths[2].impact ~= nil, wrap(roll))
    result.threat, result.mode, result.call = d.threat, d.mode, d.call
    result.priority = d.threat and 3 or 0
    result.best = d.mode == 0 and paths[1] or d.mode == 1 and paths[2]
        or (paths[1].safe and paths[1] or paths[2])
    result.escape_valid = paths[1].safe or paths[2].safe
    result.no_escape = not paths[1].safe and not paths[2].safe
    return result
end
function M.solve(s, height, director, visible)
    local ready, reason = valid(s, height)
    if not ready then return {valid = false, reason = reason} end
    local terrain, count, trace = query(height, visible)
    local current = simulate(s, terrain, nil, trace)
    if not current.valid then return {valid = false, reason = 3, queries = count()} end
    -- Explicit manual recovery context, restricted to stable flat approach.
    if s.approach and s.gear and s.cas >= 70 and s.cas <= 180 and s.vu <= -1 and s.vu >= -12
        and math.abs(s.roll) < math.rad(20) and s.nz >= 0.7 and s.nz <= 1.4
        and current.terrain_rise <= 5 and not current.obstruction then
        if type(director) == "table" then director:reset() end
        return {valid = true, threat = false, landing = true, queries = count(), current = current}
    end
    local vertical = simulate(s, terrain, "level", trace)
    local oblique = simulate(s, terrain, "oblique", trace)
    if not vertical.valid or not oblique.valid then return {valid = false, reason = 3, queries = count()} end
    local result = {valid = true, paths = {vertical, oblique}, current = current, queries = count(),
        impact = current.impact or vertical.impact or oblique.impact, trace = trace ~= nil,
        recovery_margin = vertical.safe or oblique.safe}
    director = type(director) == "table" and director or Director.new()
    return direct(result, director, finite(s.now) and s.now or 0, s.roll)
end
function M.new()
    local self = {director = Director.new()}
    function self:update(state, height, visible)
        local now = state.now
        local ready, reason = valid(state, height)
        if not finite(now) or not ready then
            self.result, self.time, self.state = nil, nil, nil
            self.director:reset()
            return {valid = false, reason = reason or 2}
        end
        local refresh = not self.time or now < self.time or now - self.time >= 0.2
            or self.height ~= height or self.visible ~= visible
        if self.state then
            refresh = refresh or math.abs(wrap(state.roll - self.state.roll)) > math.rad(12)
                or math.sqrt((state.n-self.state.n)^2+(state.u-self.state.u)^2+(state.e-self.state.e)^2) > 150
                or math.abs(state.cas-self.state.cas) > 5 or math.abs(state.nz-self.state.nz) > 0.5
                or math.abs(state.vu-self.state.vu) > 5 or state.fcs_fault ~= self.state.fcs_fault
                or state.gear ~= self.state.gear or state.approach ~= self.state.approach
        end
        if refresh then
            local result = M.solve(state, height, self.director, visible)
            result.time = now
            self.result, self.time = result, now
            self.state = {n=state.n,u=state.u,e=state.e,roll=state.roll,cas=state.cas,nz=state.nz,
                vu=state.vu,fcs_fault=state.fcs_fault,gear=state.gear,approach=state.approach}
            self.height, self.visible = height, visible
            if not result.valid then self.director:reset() end
        end
        -- Roll/PULL transition follows live bank, even between terrain queries.
        return direct(self.result, self.director, now, state.roll)
    end
    return self
end
return M
