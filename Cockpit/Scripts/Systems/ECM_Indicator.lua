-- GPL-3.0-or-later. Shared own-ECM indication; JAM means qualified game effect.
return function(api,x,y,parent,name,size)
    for _,spec in ipairs({{0,'ECM OFF','white'},{1,'ECM WAIT','yellow'},
        {2,'ECM ON','white'},{3,'JAM','green'},{4,'ECM FAIL','red'},{5,'ECM N/A','yellow'}})do
        local at=name..'_'..spec[1]
        at=api.group(at,{'F22_ECM_DISPLAY_STATE'},{{'parameter_in_range',0,spec[1]-.1,spec[1]+.1}},parent) or at
        api.text(spec[2],x,y,nil,spec[3],at,size)
    end
end
