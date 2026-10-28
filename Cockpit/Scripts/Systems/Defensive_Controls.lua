-- GPL-3.0-or-later. Operational DEF controls; programming is explicit setup.
local M = {}
local function command(label, device, code)
    return {label = label, device = device, command = code}
end
local function primary(c, get)
    c[1] = command('PROG', 'EW_SYSTEM', 11105)
    c[2] = command('MODE', 'EW_SYSTEM', 11107)
    c[10] = {label = 'SETUP', action = 'view', value = 1}
    c[18] = command('MUTE', 'RWR_SYSTEM', 10901)
    c[18].selected = get('F22_RWR_MUTE') > .5
    local awaiting = get('F22_CM_AWAITING_CONSENT') > .5
    if get('F22_CM_READY') > .5 and (awaiting or get('F22_CM_MODE') == 3) then
        if get('F22_CM_AUTHORIZED') > .5 then
            c[3] = command('REVOKE', 'EW_SYSTEM', 11112)
        else
            c[3] = command('CONSENT', 'EW_SYSTEM', 11111)
        end
    end
    if awaiting or get('F22_CM_PROGRAM_RUNNING') > .5 then
        c[4] = command('STOP', 'EW_SYSTEM', 11113)
    end
end
local function setup(c, get)
    for key, spec in ipairs({{'BANK', 10910}, {'CHAFF', 10911}, {'FLARE', 10912},
        {'INTVL', 10913}, {'CYCLES', 10914}}) do
        c[key] = command(spec[1], 'EW_SYSTEM', spec[2])
    end
    for _, spec in ipairs({{8, 'SAVE', 11103}, {9, 'CANCEL', 11104}, {11, 'DIRECT', 11106},
        {16, 'CM TEST', 11109}, {17, 'CM PWR', 11108}}) do
        c[spec[1]] = command(spec[2], 'EW_SYSTEM', spec[3])
    end
    c[12] = {label = 'RTN', action = 'view', value = 0}
    c[14] = {label = 'RNG+', action = 'def_range', value = 1}
    c[15] = {label = 'RNG-', action = 'def_range', value = -1}
    c[19] = command('RWR PWR', 'RWR_SYSTEM', 10900)
    c[19].selected = get('F22_RWR_POWER') > .5
    c[20] = command(get('F22_RWR_FILTER') > .5 and 'THRT' or 'ALL', 'RWR_SYSTEM', 10902)
end
function M.for_page(view, get)
    local controls = {[13] = {label = 'MENU', action = 'menu'}}
    if view == 1 then setup(controls, get) else primary(controls, get) end
    return controls
end
return M
