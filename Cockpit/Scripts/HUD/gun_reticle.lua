-- GPL-3.0-or-later. Original conventional pipper presentation.
-- Display range scale only: the arc is not RMAX, dispersion or hit probability.
return function(api,parent)
    local unit=1/(1000*api.layout_scale) -- milliradians into page layout units
    local line,group=api.line,api.group
    -- A 3 mrad cross gives an exact aim center without the former large gap.
    line(-1.5*unit,0,1.5*unit,0,.75*unit,parent)
    line(0,-1.5*unit,0,1.5*unit,.75*unit,parent)
    local radius=8*unit
    -- Fixed index marks remain legible without a complete decorative circle.
    for i=0,3 do
        local a=i*math.pi/2
        line(radius*math.cos(a),radius*math.sin(a),
            (radius+1.5*unit)*math.cos(a),(radius+1.5*unit)*math.sin(a),.75*unit,parent)
    end
    -- Stronger open corners help locate the small aim mark without enlarging it.
    for _,sx in ipairs({-1,1}) do for _,sy in ipairs({-1,1}) do
        line(sx*10*unit,sy*10*unit,sx*7*unit,sy*10*unit,1*unit,parent)
        line(sx*10*unit,sy*10*unit,sx*10*unit,sy*7*unit,1*unit,parent)
    end end
    local rangeRoot='HUD_GUN_MEASURED_RANGE_ARC'
    group(rangeRoot,0,0,{'HUD_GUN_TARGET_VALID'},
        {{'parameter_in_range',0,.9,1.1}},parent)
    -- Clockwise from twelve o'clock, full scale 2000 m. Saturates above 2 km.
    for i=1,32 do
        local name='HUD_GUN_RANGE_SEGMENT_'..i
        group(name,0,0,{'F22N_RADAR_STT_RANGE'},
            {{'parameter_in_range',0,i*2000/32,300000}},rangeRoot)
        local a=math.pi/2-(i-1)*2*math.pi/32
        local b=math.pi/2-i*2*math.pi/32
        line(radius*math.cos(a),radius*math.sin(a),
            radius*math.cos(b),radius*math.sin(b),.75*unit,name)
    end
end
