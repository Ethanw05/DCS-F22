-- GPL-3.0-or-later. Admit received components; never synthesize radio observations.
local M = {}
local full_scale = math.rad(8) -- Hornet-derived display adaptation; not an F-22 calibration.

local function finite(value)
    return type(value) == 'number' and value == value and math.abs(value) < 1e9
end

function M.bearing(get)
    local mode, value = get('F22_TCN_MODE'), get('F22_TCN_BRG_MAG')
    if mode ~= 1 and mode ~= 2 then return nil end
    if get('F22_TCN_BRG_VALID') ~= 1 or not finite(value) then return nil end
    return value % (2 * math.pi)
end

function M.range(get)
    local mode, value = get('F22_TCN_MODE'), get('F22_TCN_RANGE_M')
    if mode ~= 2 and mode ~= 3 and mode ~= 4 then return nil end
    if get('F22_TCN_RANGE_VALID') ~= 1 or not finite(value) or value < 0 then return nil end
    return value
end

function M.true_bearing(get)
    local bearing, variation = M.bearing(get), get('F22_MAG_DECL')
    if not bearing or get('F22_MAG_VALID') ~= 1 or not finite(variation)
        or math.abs(variation) >= math.pi / 2 then return nil end
    return (bearing + variation) % (2 * math.pi)
end

function M.deviation(bearing, course)
    if not finite(bearing) or not finite(course) then return nil end
    -- Fold about the course line so FROM passage retains the correct side.
    local error = math.asin(math.sin(bearing - course))
    return math.max(-1, math.min(1, error / full_scale)), math.deg(error)
end

function M.publish_data(get, set)
    local bearing, range = M.bearing(get), M.range(get)
    local magnetic = get('F22_NAV_REFERENCE') == 1
    if bearing and not magnetic then
        bearing = M.true_bearing(get)
    end
    set('F22_NAV_TCN_BRG_AVAILABLE', bearing and 1 or 0)
    set('F22_NAV_TCN_RANGE_AVAILABLE', range and 1 or 0)
    set('F22_NAV_TCN_BRG_TEXT', bearing and string.format('BRG %03d%s',
        math.floor(math.deg(bearing) + .5) % 360, magnetic and 'M' or 'T') or 'BRG --')
    set('F22_NAV_TCN_DIST_TEXT', range and string.format('DME %.1fNM', range / 1852) or 'DME --')
end

function M.publish_cdi(set, source, bearing, course, cross)
    local deviation
    if source == 1 then deviation = M.deviation(bearing, course)
    elseif finite(course) and finite(cross) then
        deviation = math.max(-1, math.min(1, -cross / (2 * 1852)))
    end
    set('F22_NAV_CDI_VALID', deviation and 1 or 0)
    set('F22_NAV_CDI', deviation or 0)
    set('F22_NAV_CDI_SCALE_TEXT', deviation and (source == 1 and 'CDI 4/8D' or 'CDI 2NM') or '')
    return deviation ~= nil
end

return M
