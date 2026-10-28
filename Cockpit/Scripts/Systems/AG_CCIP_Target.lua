-- GPL-3.0-or-later. Guided CCIP captures the qualified pipper at consent.
-- This is a mod delivery policy, not a recovered F-22/JDAM procedure.
local M = {}
local function finite(value)
    return type(value) == 'number' and value == value and math.abs(value) < 1e7
end
local function current_time(get, now, station)
    local stamp = get('F22_AG_SOLUTION_TIME')
    return finite(now) and finite(stamp) and now >= stamp and now - stamp <= .2 and station >= 0
end
local function qualified_solution(get, station)
    return get('F22_AG_SOLUTION_VALID') == 1 and get('F22_AG_SOLUTION_SCHEMA') == 2
        and get('F22_AG_SOLUTION_STATION') == station
        and get('HUD_AG_CCIP_CUE_VALID') == 1 and get('F22_AG_TERRAIN_PATH_VALID') == 1
end
local function valid_point(n, u, e)
    return finite(n) and finite(u) and finite(e) and u >= -1000 and u < 20000
end
function M.capture(get, now, station)
    local sequence = get('F22_AG_SOLUTION_SEQUENCE')
    if not current_time(get, now, station) or not qualified_solution(get, station)
        or not finite(sequence) or sequence <= 0 or sequence % 1 ~= 0 then
        return nil
    end
    local n = get('F22_AG_SOLUTION_IMPACT_N')
    local u = get('F22_AG_SOLUTION_IMPACT_U')
    local e = get('F22_AG_SOLUTION_IMPACT_E')
    if not valid_point(n, u, e) then
        return nil
    end
    return {n = n, u = u, e = e, sequence = sequence}
end
return M
