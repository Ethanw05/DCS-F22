-- GPL-3.0-or-later. Fused awareness metadata; never a radar or release input.
local Labels = dofile(LockOn_Options.script_path .. 'Systems/RWR_Computer.lua')
local M = {}

local function finite(value)
    return type(value) == 'number' and value == value and math.abs(value) < 1e9
end

local function current(age, limit)
    return finite(age) and age >= 0 and age <= limit
end

local function valid_header(sequence, epoch, schema, stamp, now)
    if not finite(sequence) or sequence <= 0 or sequence % 2 ~= 0 then return false end
    if not finite(epoch) or epoch < 0 or schema ~= 2 then return false end
    return finite(now) and finite(stamp) and now >= stamp and now - stamp <= .25
end

local function record(get, prefix)
    local signal, age = get(prefix .. 'RF_SIGNAL'), get(prefix .. 'RF_AGE')
    if not finite(signal) or signal < 1 or signal > 3 then signal = 0 end
    local mask = get(prefix .. 'SOURCES')
    if not finite(mask) or mask < 0 or mask > 31 then mask = 0 end
    return {
        label = get(prefix .. 'LABEL_CODE'),
        signal = current(age, signal > 1 and 3.5 or 6) and signal or 0,
        source = get(prefix .. 'SOURCE'),
        sources = mask,
        affiliation = get(prefix .. 'AFFILIATION'),
        conflict = get(prefix .. 'IDENTITY_CONFLICT') == 1,
        datalink = get(prefix .. 'DATALINK'),
        irst = mask % 32 >= 16 and current(get(prefix .. 'IRST_AGE'), 2.5),
        mws = get(prefix .. 'OPTICAL') == 1 and current(get(prefix .. 'OPTICAL_AGE'), .5),
    }
end

function M.read(get, now, radar_epoch)
    local result = {}
    local sequence = get('F22_TACTICAL_SEQUENCE')
    local epoch = get('F22_TACTICAL_EPOCH')
    local schema, stamp = get('F22_TACTICAL_SCHEMA'), get('F22_TACTICAL_TIME')
    if not valid_header(sequence, epoch, schema, stamp, now) then
        return result
    end
    for index = 1, 64 do
        local prefix = string.format('F22_TACTICAL_%02d_', index)
        local source = get(prefix .. 'RADAR_SOURCE')
        if get(prefix .. 'VALID') == 1 and finite(source) and source > 0
            and get(prefix .. 'RADAR_EPOCH') == radar_epoch then
            result[source] = record(get, prefix)
        end
    end
    if sequence ~= get('F22_TACTICAL_SEQUENCE') or epoch ~= get('F22_TACTICAL_EPOCH') then
        return {}
    end
    return result
end

function M.affiliation(local_identity, correlated)
    if not correlated then return local_identity end
    local identity = correlated.affiliation
    if identity == 3 or identity == 1 or identity == 0 then return identity end
    return local_identity
end

function M.label(track, correlated)
    local label = Labels.label(track and track.type_name, 1)
    if label == 'U' and correlated and finite(correlated.label) then return correlated.label end
    return Labels.label_code(label)
end

return M
