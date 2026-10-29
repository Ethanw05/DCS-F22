-- Advisory received approach only. These display sensitivities are adaptations.
local M={}
local function normalized(value,full_scale)
    if value~=nil then return math.max(-1,math.min(1,value/full_scale))end
end
local function enabled(get,received)
    local selected=get('F22_NAV_SOURCE')==2 and get('HUD_MODE')==1
    return received:powered() and (selected or get('HUD_LANDING_CONFIG')==1)
end
function M.publish(get,set,received)
    set('HUD_ILS_LOC_VALID',0);set('HUD_ILS_GS_VALID',0)
    local show=enabled(get,received)
    set('HUD_ILS_DISPLAY_ENABLE',show and 1 or 0)
    local loc,gs=received:ils()
    -- avILS supplies 0.6 times angular error; positive GS means aircraft high.
    -- Full scale +/-2.5deg LOC and +/-0.7deg GS; not facility/F-22 calibration.
    loc=show and normalized(loc,.6*math.rad(2.5)) or nil
    gs=show and normalized(gs,-.6*math.rad(.7)) or nil
    if loc~=nil then set('HUD_ILS_LOC',loc);set('HUD_ILS_LOC_VALID',1)end
    if gs~=nil then set('HUD_ILS_GS',gs);set('HUD_ILS_GS_VALID',1)end
end
return M
