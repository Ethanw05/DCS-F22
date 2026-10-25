-- GPL-3.0-or-later. Six connected segments per rail, gated on unlocked GUN.
return function(api,parent,reference_y)
    local root='HUD_GUN_FUNNEL'
    api.group(root,0,reference_y,{'HUD_GUN_FUNNEL_VALID','HUD_GUN_TARGET_VALID'},
        {{'parameter_in_range',0,.9,1.1},{'parameter_in_range',1,-.1,.1}},parent)
    for i=1,6 do for _,side in ipairs({'L','R'}) do
        local a=string.format('HUD_FUNNEL_%02d_',i)
        local b=string.format('HUD_FUNNEL_%02d_',i+1)
        api.dynamic_line(root..'_'..side..'_'..i,a..side..'_X',a..side..'_Y',
            b..side..'_X',b..side..'_Y',a..'VALID',b..'VALID',root)
    end end
    api.label(-.40,-.74,'F22_GUN_WINGSPAN_M','SPAN %.0f M',.019,parent)
end
