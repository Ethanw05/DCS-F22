-- GPL-3.0-or-later. Pilot intent and achieved manual recovery; no flight-control authority.
-- Climb threshold 2 m/s and captured-needle window .35 are simulation policies.
local M = {}
local function finite(value)
    return type(value) == 'number' and value == value and math.abs(value) < 1e9
end
local function captured(get)
    local loc, gs = get('HUD_ILS_LOC'), get('HUD_ILS_GS')
    return get('HUD_ILS_LOC_VALID') == 1 and get('HUD_ILS_GS_VALID') == 1
        and finite(loc) and finite(gs) and math.abs(loc) < .35 and math.abs(gs) < .35
end
local function approach_phase(s,intent,get)
    if not finite(s.vu) or not finite(s.cas) then return 'RECOVERY DATA INVALID',false end
    if s.vu>2 then return 'GO AROUND',false end
    if intent==2 then return 'VISUAL APPROACH',true end
    if intent==1 then
        if captured(get)then return 'ILS APPROACH',true end
        return get('HUD_ILS_LOC_VALID')==1 and 'LOCALIZER / NO GS' or 'ILS NOT CAPTURED',false
    end
    return 'MANUAL GEAR DOWN',false
end
local function phase(s,intent,get)
    if not s.powered or not s.valid then return 'RECOVERY UNAVAILABLE',false end
    if s.ground then return intent>0 and 'TOUCHDOWN' or 'GROUND',false end
    local down=s.gear_down
    if down==nil then down=s.gear==true end
    if not down then return intent>0 and 'RECONFIGURE / GO AROUND' or 'AIRBORNE',false end
    return approach_phase(s,intent,get)
end
function M.update(s, get, put)
    local intent = get('F22_RECOVERY_INTENT')
    if intent ~= 1 and intent ~= 2 then intent = 0 end
    local text, eligible = phase(s, intent, get)
    put('F22_RECOVERY_STATE_TEXT', text)
    put('F22_RECOVERY_APPROACH_ELIGIBLE', eligible and 1 or 0)
    return eligible
end
return M
