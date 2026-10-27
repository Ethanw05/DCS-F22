-- GPL-3.0-or-later. Original lock-associated director and conventional pipper.
-- Motion comes from the selected owned AESA measured track.
local M = {}
local Motion = dofile(LockOn_Options.script_path .. "Systems/Gun_Motion.lua")
local Frames = dofile(LockOn_Options.script_path .. "Systems/Gun_Frames.lua")
local function finite(v)
    return type(v) == "number" and v == v and math.abs(v) < 1e9
end
local function norm(v)
    return math.sqrt(v[1] ^ 2 + v[2] ^ 2 + v[3] ^ 2)
end
local function dot(a, b)
    return a[1] * b[1] + a[2] * b[2] + a[3] * b[3]
end
local function cross(a, b)
    return { a[2] * b[3] - a[3] * b[2], a[3] * b[1] - a[1] * b[3], a[1] * b[2] - a[2] * b[1] }
end
local function unit(v)
    local n = norm(v)
    if not finite(n) or n < 1e-8 then
        return
    end
    return { v[1] / n, v[2] / n, v[3] / n }
end
-- Rotate required gun direction onto actual bore. At a solved firing attitude,
-- the pipper coincides with the visible target, not its future position.
function M.pipper(aim, bore, los)
    aim, bore, los = unit(aim), unit(bore), unit(los)
    if not aim or not bore or not los then
        return
    end
    local c = dot(aim, bore)
    if c < -0.9 then
        return
    end
    local v = cross(aim, bore)
    local vp = cross(v, los)
    local vv = cross(v, vp)
    local out = {}
    for k = 1, 3 do
        out[k] = los[k] + vp[k] + vv[k] / (1 + c)
    end
    return out
end
-- Reference solutions are supplementary; they never substitute for primary aim.
function M.project_maneuver(cues, aim, bore, los, frame)
    local out = {}
    for _, name in ipairs({"LOW", "HIGH", "LEFT", "RIGHT"}) do
        local adjusted = M.pipper(cues.base, aim, cues[name])
        local sight = adjusted and M.pipper(adjusted, bore, los)
        if not sight then return end
        local b = Frames.body(frame, sight)
        if b[1] <= 0 then return end
        local az, el = math.atan2(b[3], b[1]), math.atan2(b[2], b[1])
        if math.abs(az)>math.rad(30) or math.abs(el)>math.rad(30) then return end
        out[name] = {az, el}
    end
    return out
end
function M.new(sensors, get, put, dispatch, display, device_id)
    local axes = { "N", "U", "E" }
    local self =
        { stable = 0, acc = { 0, 0, 0 }, motion = Motion.new(), history = {}, sequence = 0 }
    -- Complete render-plane schema before native HUD elements bind. Keep
    -- existing angular telemetry and native solver buffers unchanged.
    for _,name in ipairs({"LOW","HIGH","LEFT","RIGHT"}) do
        local prefix="F22_GUN_MNV_"..name
        for _,suffix in ipairs({"_X_SLOPE","_Y_SLOPE","_PLANE_LEN","_PLANE_ROT"}) do put(prefix..suffix,0) end
    end
    for _,name in ipairs({"F22_GUN_MNV_PLANE_AXIS_ROT","F22_GUN_MNV_SHOW","F22_GUN_DIRECTOR_VALID"}) do put(name,0) end
    local function vector(prefix)
        return { get(prefix .. "N"), get(prefix .. "U"), get(prefix .. "E") }
    end
    local function reset()
        self.id = nil
        self.stamp = nil
        self.stable = 0
        self.last = nil
        self.own_check = nil
        self.own_consistent = nil
        self.pending = nil
        self.solution = nil
        self.history = {}
        self.senttime = nil
        self.motion:reset()
        put("F22_GUN_REQUEST_VALID", 0)
        put("F22_GUN_DIRECTOR_VALID", 0)
        put("F22_GUN_MNV_SHOW", 0)
        put("F22_GUN_MOTION_SOURCE", 0)
        put("F22_GUN_PENDING", 0)
    end
    -- The command queue can deliver results after this Lua update has returned.
    -- Publish one request at a time; consume its acknowledged result before sending another.
    local function consume(now, id)
        local pending = self.pending
        if not pending then
            return
        end
        if get("F22_GUN_RESPONSE_SEQUENCE") == pending.sequence then
            self.pending = nil
            self.solution = nil
            local time = get("F22_GUN_RESULT_TIME")
            if
                get("F22_GUN_SOLUTION_VALID") > 0.5
                and get("F22_GUN_SOLUTION_SEQUENCE") == pending.sequence
                and get("F22_GUN_RESULT_TRACK_ID") == id
                and pending.id == id
                and finite(time)
                and time <= now + 0.01
                and now - time <= 0.1
            then
                local frame = Frames.at(self.history, time)
                if frame then
                    self.solution = {
                        time = time,
                        id = id,
                        aim = vector("F22_GUN_AIM_"),
                        bore = Frames.body(frame, vector("F22_GUN_BORE_")),
                    }
                local cue_time = get("F22_GUN_MNV_TIME")
                if get("F22_GUN_MNV_VALID")>.5 and get("F22_GUN_MNV_ID")==id and
                    finite(cue_time) and cue_time<=time+.01 and time-cue_time<=.2 then
                    local cues = {time=cue_time,base=vector("F22_GUN_MNV_BASE_")}
                    for _,name in ipairs({"LOW","HIGH","LEFT","RIGHT"}) do
                        cues[name]=vector("F22_GUN_MNV_"..name.."_")
                    end
                    self.solution.cues=cues
                end
                end
            end
        elseif now - pending.time > 0.15 then
            self.pending = nil
            self.solution = nil
        end
    end
    put("F22_GUN_RESPONSE_SEQUENCE", 0)
    put("F22_GUN_SOLUTION_VALID", 0)
    function self:update(enabled)
        put("F22_GUN_DIRECTOR_VALID", 0)
        put("F22_GUN_MNV_SHOW", 0)
        put("F22_GUN_REQUEST_VALID", 0)
        put("F22_GUN_MOTION_SOURCE", 0)
        put("F22_GUN_DISPLAY_REASON", 1)
        if
            not enabled
            or type(get_model_time) ~= "function"
            or get("F22_RADAR_STT_VALID") < 0.5
            or get("F22_STT_MOTION_VALID") < 0.5
            or get("EFM_HUD_VALID") < 0.5
        then
            reset()
            return
        end
        local now, stamp, id = get_model_time(), get("F22_STT_TIME"), get("F22_STT_ID")
        if not finite(now) or not finite(stamp) or not finite(id) or id < 1 then
            reset()
            return
        end
        local age = now - stamp
        if age < -0.01 or age > 0.15 then
            reset()
            return
        end
        local n, u, e = sensors.getSelfCoordinates()
        local heading = sensors.getHeading()
        if not finite(heading) then
            reset()
            return
        end
        local pose = {
            north = n,
            altitude = u,
            east = e,
            heading = (2 * math.pi - heading) % (2 * math.pi),
            pitch = sensors.getPitch(),
            roll = sensors.getRoll(),
        }
        for _, key in ipairs({ "north", "altitude", "east", "heading", "pitch", "roll" }) do
            if not finite(pose[key]) then
                reset()
                return
            end
        end
        if self.last and now < self.last then
            reset()
            return
        end
        local dt = self.last and now - self.last or 0
        self.last = now
        local frame = Frames.from_pose(pose)
        local last = self.history[#self.history]
        if not last or last.time ~= now then
            self.history[#self.history + 1] = { time = now, frame = frame }
        end
        while #self.history > 2 and now - self.history[1].time > 0.3 do
            table.remove(self.history, 1)
        end
        local velocity = vector("F22_STT_V")
        if self.id ~= id then
            self.id = id
            self.stamp = stamp
            self.stable = 0
            self.acc = { 0, 0, 0 }
            self.pending = nil
            self.solution = nil
            self.motion:reset()
            self.motion:update(stamp, velocity)
            return
        end
        if self.stamp ~= stamp then
            local elapsed = stamp - self.stamp
            if elapsed <= 0 or elapsed > 0.3 then
                reset()
                return
            end
            self.stable = self.stable + elapsed
            self.stamp = stamp
            local acceleration = self.motion:update(stamp, velocity)
            if not acceleration then
                reset()
                return
            end
            self.acc = acceleration
        end
        put("F22_GUN_DISPLAY_REASON", 2)
        if self.stable < 0.1 then
            return
        end
        age = math.max(0, age)
        local measured = vector("F22_STT_P")
        local position = {}
        for k = 1, 3 do
            if not finite(measured[k]) or not finite(velocity[k]) then
                reset()
                return
            end
            position[k] = measured[k] + velocity[k] * age + 0.5 * self.acc[k] * age * age
        end
        if norm(velocity) > 1500 or norm(self.acc) > 150 then
            reset()
            return
        end
        local sr, az, el =
            get("F22N_RADAR_STT_RANGE"),
            get("F22N_RADAR_STT_AZIMUTH"),
            get("F22N_RADAR_STT_ELEVATION")
        if not finite(sr) or sr < 100 or sr > 2000 or not finite(az) or not finite(el) then
            return
        end
        local observation = { range = sr, az = az, el = el }
        display.world_observation(observation, pose)
        local mismatch = norm({
            position[1] - observation.north,
            position[2] - observation.altitude,
            position[3] - observation.east,
        })
        put("F22_GUN_DISPLAY_REASON", 3)
        if mismatch > math.max(20, sr * 0.01) then
            reset()
            return
        end
        local own = self.own_check
        if not own then
            self.own_check = { t = now, p = { n, u, e } }
        elseif now - own.t >= 0.15 then
            local interval = now - own.t
            local discrepancy = {}
            local own_position = { n, u, e }
            for k, axis in ipairs(axes) do
                discrepancy[k] = (own_position[k] - own.p[k]) / interval - get("EFM_HUD_V" .. axis)
            end
            self.own_check = { t = now, p = own_position }
            self.own_consistent = norm(discrepancy) < 60
        end
        if self.own_consistent == false then
            return
        end
        consume(now, id)
        put("F22_GUN_REQUEST_VALID", 1)
        if not self.pending and self.senttime ~= now then
            self.sequence = self.sequence + 1
            self.pending = { sequence = self.sequence, id = id, time = now }
            self.senttime = now
            for k, axis in ipairs(axes) do
                put("F22_GUN_TARGET_" .. axis, measured[k])
                put("F22_GUN_V" .. axis, velocity[k])
                put("F22_GUN_A" .. axis, self.acc[k])
            end
            put("F22_GUN_OWN_N", n)
            put("F22_GUN_OWN_U", u)
            put("F22_GUN_OWN_E", e)
            put("F22_GUN_DEVICE_ID", device_id)
            put("F22_GUN_MEASUREMENT_AGE", age)
            put("F22_GUN_REQUEST_TIME", now)
            put("F22_GUN_TRACK_ID", id)
            put("F22_GUN_REQUEST_SEQUENCE", self.sequence)
            dispatch(nil, 10851, dt)
            consume(now, id) -- Also support synchronous hosts without requiring synchronous dispatch.
        end
        put("F22_GUN_PENDING", self.pending and 1 or 0)
        put("F22_GUN_DISPLAY_REASON", 4)
        local solution = self.solution
        if not solution or solution.id ~= id or now - solution.time > 0.1 then
            self.solution = nil
            return
        end
        local bore = Frames.world(frame, solution.bore)
        local p =
            M.pipper(solution.aim, bore, { position[1] - n, position[2] - u, position[3] - e })
        if not p then
            return
        end
        local body = Frames.body(frame, p)
        local pa, projected = math.atan2(body[3], body[1]), math.atan2(body[2], body[1])
        put("F22_GUN_DISPLAY_REASON", 6)
        if math.abs(pa) > math.rad(20) or math.abs(projected) > math.rad(20) then
            return
        end
        put("F22_GUN_DIRECTOR_VALID", 1)
        put("F22_GUN_MOTION_SOURCE", 1)
        put("F22_GUN_DISPLAY_REASON", 0)
        put("F22_GUN_RESPONSE_AGE", now - solution.time)
        put("F22_GUN_DIRECTOR_AZ", pa)
        put("F22_GUN_DIRECTOR_EL", projected)
        if solution.cues and now-solution.cues.time<=.2 then
            local points=M.project_maneuver(solution.cues,solution.aim,bore,
                {position[1]-n,position[2]-u,position[3]-e},frame)
            if points then
                for name,point in pairs(points) do
                    put("F22_GUN_MNV_"..name.."_AZ",point[1]);put("F22_GUN_MNV_"..name.."_EL",point[2])
                    put("F22_GUN_MNV_"..name.."_X_SLOPE",math.tan(point[1]));put("F22_GUN_MNV_"..name.."_Y_SLOPE",math.tan(point[2]))
                end
                local low,high=points.LOW,points.HIGH
                local dx,dy=high[1]-low[1],high[2]-low[2]
                put("F22_GUN_MNV_AXIS_ROT",math.atan2(dy,dx)+math.pi/2)
                put("F22_GUN_MNV_PLANE_AXIS_ROT",math.atan2(math.tan(high[2])-math.tan(low[2]),math.tan(high[1])-math.tan(low[1]))+math.pi/2)
                for _,name in ipairs({"LEFT","RIGHT"}) do
                    dx,dy=points[name][1]-low[1],points[name][2]-low[2]
                    put("F22_GUN_MNV_"..name.."_LEN",math.sqrt(dx*dx+dy*dy))
                    put("F22_GUN_MNV_"..name.."_ROT",math.atan2(dy,dx))
                    local px,py=math.tan(points[name][1])-math.tan(low[1]),math.tan(points[name][2])-math.tan(low[2])
                    put("F22_GUN_MNV_"..name.."_PLANE_LEN",math.sqrt(px*px+py*py))
                    put("F22_GUN_MNV_"..name.."_PLANE_ROT",math.atan2(py,px))
                end
                for _,name in ipairs({"LOW","HIGH"}) do
                    dx,dy=points[name][1]-pa,points[name][2]-projected
                    put("F22_GUN_MNV_"..name.."_MARK",dx*dx+dy*dy>=.012^2 and 1 or 0)
                end
                put("F22_GUN_MNV_SHOW",1)
            end
        end
        return pa, projected
    end
    return self
end
return M
