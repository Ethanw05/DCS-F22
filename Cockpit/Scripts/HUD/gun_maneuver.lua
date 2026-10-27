-- GPL-3.0-or-later. Original Hornet/F-16-inspired supplementary maneuver references.
return function(api,parent,reference_y)
    local unit=1/(1000*api.layout_scale)
    local line,group,static=api.line,api.group,api.static
    local root='HUD_GUN_MANEUVER'
    group(root,0,reference_y,{'F22_GUN_MNV_SHOW','HUD_GUN_NATIVE_VALID'},
        {{'parameter_in_range',0,.9,1.1},{'parameter_in_range',1,.9,1.1}},parent)
    local function position(name)
        local id='HUD_GUN_MNV_'..name
        group(id,0,0,{'F22_GUN_MNV_'..name..'_X_SLOPE','F22_GUN_MNV_'..name..'_Y_SLOPE'},
            {{'move_left_right_using_parameter',0,1/api.layout_scale},
             {'move_up_down_using_parameter',1,1/api.layout_scale}},root)
        return id
    end
    local low,high=position('LOW'),position('HIGH')
    -- Identification ticks are suppressed within the primary pipper's clear area.
    local lowmark=low..'_MARK'
    group(lowmark,0,0,{'F22_GUN_MNV_LOW_MARK'},{{'parameter_in_range',0,.9,1.1}},low)
    line(-2*unit,0,2*unit,0,.65*unit,lowmark)
    line(0,-2*unit,0,2*unit,.65*unit,lowmark)
    static(5*unit,0,'1G',.016,lowmark)
    local highmark=high..'_MARK'
    group(highmark,0,0,{'F22_GUN_MNV_HIGH_MARK'},{{'parameter_in_range',0,.9,1.1}},high)
    group(highmark..'_PLANE_ROT',0,0,{'F22_GUN_MNV_PLANE_AXIS_ROT'},{{'rotate_using_parameter',0,1}},highmark)
    line(-2*unit,0,2*unit,0,.65*unit,highmark..'_PLANE_ROT')
    static(6*unit,0,'9G REF',.016,highmark)
    -- Leave the Hornet-style ten-mrad central gap. No fabricated minimum potential width.
    local gap,step=.010,.0015
    for _,name in ipairs({'LEFT','RIGHT'}) do
        local arm='HUD_GUN_MNV_ARM_'..name
        group(arm,0,0,{'F22_GUN_MNV_'..name..'_PLANE_ROT'},{{'rotate_using_parameter',0,1}},low)
        for i=0,55 do
            local segment=arm..'_'..i
            group(segment,0,0,{'F22_GUN_MNV_'..name..'_PLANE_LEN'},
                {{'parameter_in_range',0,gap+(i+1)*step,2}},arm)
            line((gap+i*step)*1000*unit,0,(gap+(i+1)*step)*1000*unit,0,.7*unit,segment)
        end
    end
end
