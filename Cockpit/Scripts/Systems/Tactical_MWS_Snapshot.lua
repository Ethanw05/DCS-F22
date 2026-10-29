-- GPL-3.0-or-later. Only complete missile-warning batches enter fusion.
local M = {}
local function finite(v)
    return type(v)=='number' and v==v and math.abs(v)<1e12
end
local function committed(sequence, schema)
    return schema==1 and finite(sequence) and sequence>=2 and sequence<=16000000 and sequence%2==0
end
local function fresh(now, stamp)
    return finite(stamp) and now-stamp>=-.01 and now-stamp<=.25
end
function M.read(get, now)
    if not finite(now) or now<0 then return end
    local sequence = get('F22_MWS_PUBLISH_SEQUENCE')
    local epoch, stamp = get('F22_MWS_EPOCH'), get('F22_MWS_PUBLISH_TIME')
    if not finite(epoch) or epoch<1 or epoch>4294967295 or epoch%1~=0 then return end
    if not committed(sequence, get('F22_MWS_PUBLISH_SCHEMA')) or not fresh(now, stamp) then return end
    local batch = {sequence=sequence, epoch=epoch, time=stamp, contacts={}}
    for i=1,16 do
        local p = string.format('F22_MWS_%02d_', i)
        if get(p..'VALID')==1 then
            batch.contacts[#batch.contacts+1] = {source=get(p..'SOURCE'), age=get(p..'AGE'),
                az=get(p..'AZ'), el=get(p..'EL'), epoch=epoch}
        end
    end
    if sequence~=get('F22_MWS_PUBLISH_SEQUENCE') or epoch~=get('F22_MWS_EPOCH')
        or stamp~=get('F22_MWS_PUBLISH_TIME') then return end
    return batch
end
return M
