-- GPL-3.0-or-later. Own simulator ECM effect, separate from switch acknowledgement.
local M = { off=0, requested=1, enabled=2, jamming=3, failed=4, unknown=5 }
local function finite(v) return type(v)=='number' and v==v and math.abs(v)<1e9 end
local function identity(sequence,generation)
    return finite(sequence) and sequence>0 and sequence%2==0
        and finite(generation) and generation>0 and generation%1==0
end
local function current(now,stamp,active)
    return finite(now) and finite(stamp) and now>=stamp and now-stamp<=.25 and (active==0 or active==1)
end
function M.effect(get,now)
    local sequence=get('F22_AESA_SEQUENCE')
    local generation=get('F22_NATIVE_ECM_GENERATION')
    local stamp=get('F22_NATIVE_ECM_TIME')
    local active=get('F22_NATIVE_ECM_ACTIVE')
    local valid=get('F22_NATIVE_ECM_VALID')==1
    valid=valid and identity(sequence,generation) and current(now,stamp,active)
    valid=valid and sequence==get('F22_AESA_SEQUENCE')
        and generation==get('F22_NATIVE_ECM_GENERATION')
    return valid,valid and active==1,valid and stamp or -100
end
function M.state(requested,valid,enabled,failed,effect_valid,active)
    if failed then return M.failed end
    if effect_valid and active then return M.jamming end
    if not valid then return M.unknown end
    if requested~=enabled then return M.requested end
    if enabled then return M.enabled end
    return M.off
end
return M
