-- GPL-3.0-or-later. Installed Hornet HUD_common.lua steering-symbol geometry.
return function(api)
    local di=.34/(1000*api.layout_scale)
    local width=.8/(1000*api.layout_scale)
    api.group('HUD_NAV_COURSE_SYMBOL',0,0,{'HUD_NAV_STEER_VALID','HUD_MODE'},
        {{'parameter_in_range',0,.9,1.1},{'parameter_in_range',1,.9,1.1}},'HUD_FPM')
    -- Source: 19 DI per degree, caged at eight degrees by SymbolArrow.
    api.group('HUD_NAV_COURSE_ARROW',0,0,{'HUD_NAV_STEER_ERROR'},
        {{'move_left_right_using_parameter',0,19*di*180/math.pi}},'HUD_NAV_COURSE_SYMBOL')
    -- 124-arrow-up from the installed MDG SVG: 76-DI shaft and 9-DI head.
    api.line(0,-38*di,0,38*di,width,'HUD_NAV_COURSE_ARROW')
    api.line(-4.46*di,29*di,0,38*di,width,'HUD_NAV_COURSE_ARROW')
    api.line(0,38*di,4.46*di,29*di,width,'HUD_NAV_COURSE_ARROW')
    -- Hornet SymbolDots suppresses the reference circles below 1.25 degrees.
    api.group('HUD_NAV_STEER_DOTS',0,0,{'HUD_NAV_STEER_MAG_DEG'},
        {{'parameter_in_range',0,1.2499,180.1}},'HUD_NAV_COURSE_SYMBOL')
    for _,side in ipairs({-1,1})do
        local root='HUD_NAV_STEER_SIDE_'..side
        api.group(root,0,0,{'HUD_NAV_STEER_ERROR'},
            {{'parameter_in_range',0,side<0 and -math.pi or .000001,side<0 and -.000001 or math.pi}},'HUD_NAV_STEER_DOTS')
        for _,angle in ipairs({4,8})do
            local x=side*angle*19*di;local radius=5*di
            for i=0,15 do local a,b=i*math.pi/8,(i+1)*math.pi/8
                api.line(x+radius*math.cos(a),radius*math.sin(a),x+radius*math.cos(b),radius*math.sin(b),width,root)
            end
        end
    end
end
