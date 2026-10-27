-- GPL-3.0-or-later. Directional terrain-recovery presentation from the active prediction.
-- Hornet-inspired cue behavior; no claim of a recovered F-22 implementation.
local M = {}
local function finite(x)
    return type(x) == "number" and x == x and math.abs(x) < 1e9
end
local function wrap(x)
    return (x + math.pi) % (2 * math.pi) - math.pi
end
function M.evaluate(state, recovery)
    local off = { valid = false, rotation = 0, mode = 0 }
    if not state.powered or not state.valid or state.ground or not finite(state.roll)
        or not finite(state.now) or not recovery or not recovery.valid or not recovery.threat
        or not finite(recovery.time) or state.now < recovery.time or state.now - recovery.time > 0.25
        or (recovery.mode ~= 0 and recovery.mode ~= 1) then
        return off
    end
    -- TAWS activates when both modeled paths intersect. The cue identifies the
    -- selected recovery type; it must not fall back merely because neither
    -- path is guaranteed clear (Hornet publisher 0x1803E56E1..0x1803E5738).
    if recovery.mode == 1 then
        return { valid = true, rotation = 0, mode = 2 }
    end
    return { valid = true, rotation = wrap(state.roll), mode = 1 }
end
return M
