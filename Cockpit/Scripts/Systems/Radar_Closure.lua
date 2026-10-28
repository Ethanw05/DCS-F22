-- GPL-3.0-or-later. Closing-positive measured world velocity, m/s to knots.
local M = {}
local function finite(value)
    return type(value) == "number" and value == value and math.abs(value) < 1e9
end
local function vector(value, a, b, c)
    return value and finite(value[a]) and finite(value[b]) and finite(value[c])
end
function M.relative(track, pose, own, now)
    if not track or not track.velocity_valid or not finite(now)
        or not finite(track.observed) or now < track.observed
        or not vector(track, "north", "altitude", "east")
        or not vector(track, "vn", "vu", "ve")
        or not vector(pose, "north", "altitude", "east")
        or not vector(own, "vn", "vu", "ve") then return nil end
    local age = now - track.observed
    local n = track.north + track.vn * age - pose.north
    local u = track.altitude + track.vu * age - pose.altitude
    local e = track.east + track.ve * age - pose.east
    local range = math.sqrt(n*n + u*u + e*e)
    if not finite(range) or range <= 40 then return nil end
    local closure = ((own.vn-track.vn)*n + (own.vu-track.vu)*u
        + (own.ve-track.ve)*e) / range * 1.943844492
    return finite(closure) and closure or nil
end
return M
