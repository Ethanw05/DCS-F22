-- GPL-3.0-or-later. Rigid body/world frames for delayed native gun responses.
local M = {}
local function dot(a, b)
    return a[1] * b[1] + a[2] * b[2] + a[3] * b[3]
end
local function cross(a, b)
    return { a[2] * b[3] - a[3] * b[2], a[3] * b[1] - a[1] * b[3], a[1] * b[2] - a[2] * b[1] }
end
local function unit(v)
    local n = math.sqrt(dot(v, v))
    if n < 1e-8 or n ~= n then
        return
    end
    return { v[1] / n, v[2] / n, v[3] / n }
end
function M.from_pose(p)
    local ch, sh = math.cos(p.heading), math.sin(p.heading)
    local cp, sp = math.cos(p.pitch), math.sin(p.pitch)
    local cr, sr = math.cos(p.roll), math.sin(p.roll)
    return {
        { cp * ch, sp, cp * sh },
        { -sp * cr * ch - sr * sh, cp * cr, -sp * cr * sh + sr * ch },
        { sp * sr * ch - cr * sh, -cp * sr, sp * sr * sh + cr * ch },
    }
end
function M.body(frame, world)
    return { dot(frame[1], world), dot(frame[2], world), dot(frame[3], world) }
end
function M.world(frame, body)
    local out = {}
    for k = 1, 3 do
        out[k] = frame[1][k] * body[1] + frame[2][k] * body[2] + frame[3][k] * body[3]
    end
    return out
end
local function position_between(a, b, time)
    if not a.position or not b.position or b.time <= a.time then return end
    local fraction = (time - a.time) / (b.time - a.time)
    local out = {}
    for axis = 1, 3 do
        out[axis] = a.position[axis] + (b.position[axis] - a.position[axis]) * fraction
    end
    return out
end
function M.position_at(history, time)
    for index = 1, #history - 1 do
        local a, b = history[index], history[index + 1]
        if time >= a.time and time <= b.time then return position_between(a, b, time) end
    end
    local last, previous = history[#history], history[#history - 1]
    if last and time == last.time then return last.position end
    if last and previous and time > last.time and time - last.time <= .01 then
        return position_between(previous, last, time)
    end
end
function M.at(history, time)
    for i = 1, #history - 1 do
        local a, b = history[i], history[i + 1]
        if time >= a.time and time <= b.time then
            local f = (time - a.time) / (b.time - a.time)
            local forward, up = {}, {}
            for k = 1, 3 do
                forward[k] = a.frame[1][k] * (1 - f) + b.frame[1][k] * f
                up[k] = a.frame[2][k] * (1 - f) + b.frame[2][k] * f
            end
            forward = unit(forward)
            if not forward then
                return
            end
            local projection = dot(up, forward)
            for k = 1, 3 do
                up[k] = up[k] - forward[k] * projection
            end
            up = unit(up)
            if not up then
                return
            end
            return { forward, up, cross(forward, up) }
        end
    end
    local last = history[#history]
    if last and time >= last.time and time - last.time <= 0.01 then
        return last.frame
    end
end
return M
