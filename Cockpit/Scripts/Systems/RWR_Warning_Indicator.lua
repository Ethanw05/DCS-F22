-- GPL-3.0-or-later. Native RF warning repeater; no inferred missile launch or range.
return function(api, parent, name, x, y, size)
    local function gate(suffix, params, controllers, at)
        local identifier = name .. suffix
        return api.group(identifier, params, controllers, at) or identifier
    end
    local current = gate('_CURRENT', {
        'F22_DEF_OV_CURRENT', 'F22_RWR_POWER', 'F22_RWR_READY', 'F22_EW_01_COAST',
    }, {
        {'parameter_in_range', 0, .9, 1.1},
        {'parameter_in_range', 1, .9, 1.1},
        {'parameter_in_range', 2, .9, 1.1},
        {'parameter_in_range', 3, -.1, .1},
    }, parent)
    local label = dofile(LockOn_Options.script_path .. 'Systems/Contact_Label_Indicator.lua')
    for _, warning in ipairs({{2, 'RADAR LOCK', 'yellow'}, {3, 'RWR LAUNCH', 'red'}}) do
        local at = gate('_STATE_' .. warning[1], {'F22_RWR_ALERT'},
            {{'parameter_in_range', 0, warning[1] - .1, warning[1] + .1}}, current)
        api.text(warning[2], x, y, nil, warning[3], at, size)
        api.text('EMITTER', x - .08, y - .052, nil, warning[3], at, size * .75)
        label(api, 'F22_EW_01_', x + .09, y - .052, at,
            name .. '_EMITTER_' .. warning[1], warning[3], size * .85)
    end
end
