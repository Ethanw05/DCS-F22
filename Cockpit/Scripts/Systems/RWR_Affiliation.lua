-- GPL-3.0-or-later. DCS coalition metadata for already received emitters.
-- This is game identification, not an IFF waveform or a radar/RF ID join.
local M = {}
local function finite(v)
    return type(v) == 'number' and v == v and math.abs(v) < 1e12
end
local function current(sequence, stamp, now)
    return finite(now) and finite(sequence) and sequence > 0 and sequence % 2 == 0
        and finite(stamp) and now >= stamp and now - stamp <= .25
end
local function identified(source, side, time, now)
    return finite(source) and source > 0 and source < 4294967296 and source % 1 == 0
        and (side == 0 or side == 1) and finite(time) and now >= time and now - time <= 12
end
function M.read(get, now)
    local result = {}
    local sequence, stamp = get('F22_RWR_META_SEQUENCE'), get('F22_RWR_META_TIME')
    if not current(sequence, stamp, now) or get('F22_RWR_META_READY') ~= 1 then return result end
    for i = 1, 16 do
        local p = string.format('F22_RWR_META_%02d_', i)
        local source, side, time = get(p .. 'SOURCE'), get(p .. 'AFFILIATION'), get(p .. 'SAMPLE_TIME')
        if identified(source, side, time, now) then
            result[source] = {class = side, time = time}
        end
    end
    if sequence ~= get('F22_RWR_META_SEQUENCE') then return {} end
    return result
end
return M
