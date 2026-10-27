-- GPL-3.0-or-later. Shared timestamped STT contract; never trust cached polar
-- numbers merely because the native mode still says STT.
local M={max_age=.5}
local function finite(v)
    return type(v)=='number' and v==v and math.abs(v)<1e9
end
function M.fresh(now,stamp)
    return finite(now) and finite(stamp) and now-stamp>=-.05 and now-stamp<=M.max_age
end
function M.read(get,now)
    local stamp,id=get('F22_RADAR_STT_TIME'),get('F22_RADAR_STT_SOURCE_ID')
    if get('MAIN_POWER')<.5 or get('RADAR_PWR')<.5 or get('F22_RADAR_BACKEND_READY')<.5 or
        get('F22N_RADAR_MODE')~=3 or get('F22_RADAR_STT_VALID')<.5 or
        get('F22_STT_MOTION_VALID')<.5 or not M.fresh(now,stamp) or not M.fresh(now,get('F22_STT_TIME')) or
        not finite(id) or id<=0 or get('F22_STT_ID')~=id then return end
    local r,a,e=get('F22_RADAR_STT_RANGE'),get('F22_RADAR_STT_AZIMUTH'),get('F22_RADAR_STT_ELEVATION')
    if not finite(r) or r<40 or r>300000 or not finite(a) or not finite(e) or
        math.abs(a)>math.pi/2 or math.abs(e)>math.pi/2 then return end
    return {id=id,time=stamp,age=math.max(0,now-stamp),range=r,az=a,el=e,
        iff=(get('F22_RADAR_STT_IFF')==1 or get('F22_RADAR_STT_IFF')==0) and get('F22_RADAR_STT_IFF') or -1,
        closure_valid=get('F22_RADAR_STT_CLOSURE_VALID')>.5,
        closure=get('F22_RADAR_STT_CLOSURE_KTS')}
end
return M
