-- GPL-3.0-or-later. Hornet HUD_common.lua geometry, converted from DIs.
-- Installed MDG_units.lua: 1 display increment = 0.34 milliradians.
return function(api)
    local di=.34/(1000*api.layout_scale)
    local width=.8/(1000*api.layout_scale)
    -- Complete E-bracket from the installed 146-E-bracket SVG: 100-DI
    -- spine, 15-DI outer prongs, 8-DI center prong, at the Lua's 1.2 scale.
    -- It remains visible at on-speed instead of disappearing into two flags.
    api.group('HUD_EBRACKET',-60*di,0,{'HUD_EBRACKET_OFFSET','HUD_EBRACKET_VALID'},
        {{'move_up_down_using_parameter',0,1/api.layout_scale},{'parameter_in_range',1,.9,1.1}},'HUD_FPM')
    local bracket_di=1.2*di
    api.line(0,-50*bracket_di,0,50*bracket_di,width,'HUD_EBRACKET','HUD_EBRACKET_SPINE')
    api.line(0,50*bracket_di,15*bracket_di,50*bracket_di,width,'HUD_EBRACKET','HUD_EBRACKET_TOP')
    api.line(0,0,8*bracket_di,0,width,'HUD_EBRACKET','HUD_EBRACKET_CENTER')
    api.line(0,-50*bracket_di,15*bracket_di,-50*bracket_di,width,'HUD_EBRACKET','HUD_EBRACKET_BOTTOM')
end
