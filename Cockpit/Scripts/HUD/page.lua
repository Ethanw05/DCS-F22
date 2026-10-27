-- GPL-3.0-or-later: derivative within Grinnelli Designs F-22A project.
-- Historical 2002 F-22 counter-pointer layout + an intentionally borrowed
-- C-130-style heading strip. UNVERIFIED optical alignment and tactical modes.
dofile(LockOn_Options.common_script_path.."elements_defs.lua")
dofile(LockOn_Options.script_path.."fonts.lua")
SetScale(MILLYRADIANS)
local green = "F22_HUD_GREEN"
local hud_style=dofile(LockOn_Options.script_path.."HUD/style.lua")
local pi = math.pi
local layout = dofile(LockOn_Options.script_path.."HUD/layout.lua")
-- Explicit angular units: layout math uses radians, DCS elements use mrad.
local layout_scale = layout.angular_scale
local drawing_scale = layout_scale * 1000
local native_unit_scale = GetScale()
if log and log.write then
    log.write("F22_HUD_GEOMETRY", log.INFO, string.format("units=mrad native_scale=%.9f",native_unit_scale))
end
-- stringdefs are already final scaled metrics, unlike vertex coordinates.
-- Native HUD Common_page_defs.lua multiplies glyph units by GetScale().
local font_scale = layout.font_scale
local font_width_scale = layout.font_width_scale
local hud_font = "F22_HUD_OWN_STROKE"
local hud_level = 8
local active_draw_level = hud_level
local mask = CreateElement "ceMeshPoly"
mask.name = "F22_HUD_APERTURE"
mask.primitivetype = "triangles"
local glass = dofile(LockOn_Options.script_path.."HUD/glass.lua")
local glass_vertices = {}
for i, v in ipairs(glass.vertices) do
    -- Native ceMeshPoly accepts three coordinates and swaps X/Z internally.
    -- The unanchored indicator origin is (1,0,0), not (0,0,0).
    glass_vertices[i] = {v[3]/native_unit_scale, v[2]/native_unit_scale,
        (v[1]-1)/native_unit_scale}
end
mask.vertices = glass_vertices
mask.indices = glass.indices
mask.material = green
mask.blend_mode = blend_mode.IBM_NO_WRITECOLOR
mask.h_clip_relation = h_clip_relations.REWRITE_LEVEL
mask.level = hud_level
mask.isvisible = false
mask.change_opacity = false
mask.collimated = false
Add(mask)
local function add_base(e, name, parent, has_controllers)
    e.name = name
    e.isdraw = true
    e.additive_alpha = hud_style.additive_alpha
    e.collimated = true
    e.h_clip_relation = h_clip_relations.COMPARE
    e.level = active_draw_level
    -- DCS element properties are write interfaces, not ordinary Lua tables.
    if not has_controllers then
        e.material = green
        e.element_params = {"HUD_POWER"}
        e.controllers = {{"opacity_using_parameter",0}}
    end
    if parent then e.parent_element = parent end
    Add(e)
    return e
end
local counter = 0
local function id(prefix)
    counter = counter + 1
    return prefix.."_"..counter
end
local function line(x1,y1,x2,y2,w,parent,name)
    x1,y1,x2,y2,w = x1*drawing_scale,y1*drawing_scale,
        x2*drawing_scale,y2*drawing_scale,w*drawing_scale
    local dx,dy = x2-x1,y2-y1
    local length = math.sqrt(dx*dx+dy*dy)
    if length < 0.000001 then return end
    local ox,oy = -dy*w/(2*length),dx*w/(2*length)
    local e = CreateElement "ceMeshPoly"
    e.primitivetype = "triangles"
    e.vertices = {{x1+ox,y1+oy},{x2+ox,y2+oy},{x2-ox,y2-oy},{x1-ox,y1-oy}}
    e.indices = {0,1,2,2,3,0}
    add_base(e,name or id("HUD_LINE"),parent)
end
local function label(x,y,param,fmt,h,parent,alignment)
    local e = CreateElement "ceStringSLine"
    e.material = hud_font
    e.init_pos = {x*drawing_scale,y*drawing_scale,0}
    e.alignment = alignment or "CenterCenter"
    e.stringdefs = {h*font_scale,h*font_scale*font_width_scale,h*font_scale*0.2,0}
    e.formats = {fmt}
    e.element_params = {param,"HUD_POWER"}
    e.controllers = {{"text_using_parameter",0,0},{"opacity_using_parameter",1}}
    add_base(e,id("HUD_TEXT"),parent,true)
end
local function static(x,y,value,h,parent)
    local e = CreateElement "ceStringSLine"
    e.material = hud_font
    e.init_pos = {x*drawing_scale,y*drawing_scale,0}
    e.alignment = "CenterCenter"
    e.stringdefs = {h*font_scale,h*font_scale*font_width_scale,h*font_scale*0.2,0}
    e.value = value
    e.element_params = {"HUD_POWER"}
    e.controllers = {{"opacity_using_parameter",0}}
    add_base(e,id("HUD_STATIC"),parent,true)
end
local function group(name,x,y,params,controllers,parent)
    local e = CreateElement "ceSimple"
    e.init_pos = {x*drawing_scale,y*drawing_scale,0}
    e.element_params = params or {"HUD_POWER"}
    local scaled = {}
    for i, controller in ipairs(controllers or {{"opacity_using_parameter",0}}) do
        local entry = {}
        for k, v in ipairs(controller) do entry[k] = v end
        if entry[1] == "move_up_down_using_parameter" or
           entry[1] == "move_left_right_using_parameter" then
            -- Native controllers translate the element matrix directly;
            -- unlike init_pos/vertices they do not apply the page scale.
            entry[3] = entry[3] * drawing_scale * native_unit_scale
        end
        scaled[i] = entry
    end
    e.controllers = scaled
    add_base(e,name,parent,true)
end
local function dynamic_line(name,x1,y1,x2,y2,valid1,valid2,parent)
    local e=CreateElement 'ceSimpleLineObject'
    e.material=green;e.vertices={{0,0},{.001,0}};e.primitivetype='lines'
    e.width=.7*native_unit_scale
    local gain=1000*native_unit_scale -- parameters are radians
    e.element_params={x1,y1,x2,y2,valid1,valid2}
    e.controllers={{'line_object_set_point_using_parameters',0,0,1,gain,gain},
        {'line_object_set_point_using_parameters',1,2,3,gain,gain},
        {'parameter_in_range',4,.9,1.1},{'parameter_in_range',5,.9,1.1}}
    add_base(e,name,parent,true)
end

-- Layout is intentionally normalized. Installed physical FOV/eyebox is unknown.
-- Published F-22 figure has circular counter/pointer speed and altitude,
-- not moving vertical tapes.
group("HUD_AIRDATA",0,0,{"HUD_AIRDATA_VALID"},{{"parameter_in_range",0,0.9,1.1}})
group("HUD_NO_AIRDATA",0,0,{"HUD_AIRDATA_VALID"},{{"parameter_in_range",0,-0.1,0.1}})
group('HUD_ALT_DATA',0,0,{'HUD_ALT_VALID'},{{'parameter_in_range',0,.9,1.1}})
group('HUD_NO_ALT_DATA',0,0,{'HUD_ALT_VALID'},{{'parameter_in_range',0,-.1,.1}})
local function dial(cx,cy,r,n,param,available,missing)
    available=available or 'HUD_AIRDATA';missing=missing or 'HUD_NO_AIRDATA'
    for i=0,9 do
        local a = (i/10)*2*pi
        local e=CreateElement "ceMeshPoly"
        e.primitivetype="triangles"
        local x,y=cx+r*math.sin(a),cy+r*math.cos(a)
        local vertices={{x*drawing_scale,y*drawing_scale}}
        local indices={}
        for k=0,8 do
            local theta=k*2*pi/8
            vertices[#vertices+1]={(x+0.0055*math.cos(theta))*drawing_scale,
                (y+0.0055*math.sin(theta))*drawing_scale}
            if k>0 then
                indices[#indices+1]=0;indices[#indices+1]=k;indices[#indices+1]=k+1
            end
        end
        e.vertices=vertices;e.indices=indices
        add_base(e,id("HUD_DIAL_DOT"))
    end
    label(cx,cy,n,n=="HUD_ALT_FT" and "%.0f" or "%03.0f",0.045,available)
    static(cx,cy,"---",0.045,missing)
    local name=id("HUD_POINTER_ROOT")
    group(name,cx,cy,{param,"HUD_POWER"},
        {{"rotate_using_parameter",0,1},{"opacity_using_parameter",1}},available)
    -- Keep the pointer outside the counter/dots; five-digit altitudes must
    -- never be crossed by a needle passing through the numerical field.
    line(0,r*1.05,0,r*1.28,0.007,name)
end
local counter_x=0.62
dial(-counter_x,0.02,0.085,"HUD_CAS","HUD_IAS_POINTER")
dial(counter_x,0.02,0.115,"HUD_ALT_FT","HUD_ALT_POINTER","HUD_ALT_DATA","HUD_NO_ALT_DATA")
label(counter_x,-.16,'HUD_ALT_SOURCE_TEXT','%s',.020)
group('HUD_PRESSURE_CONFIRM',0,0,{'HUD_QNH_VISIBLE'},{{'parameter_in_range',0,.9,1.1}})
label(counter_x,-.21,'F22_ALT_DISPLAY_TEXT','%s',.018,'HUD_PRESSURE_CONFIRM')

-- Geometric attitude reference: moves in pitch, rotates as aircraft rolls.
-- Every conformal cue shares the fixed nose-reference origin.
local boresight_y=layout.boresight_y
group("HUD_ATTITUDE_ROLL",0,boresight_y,{"HUD_ROLL","HUD_POWER",'HUD_REFERENCE_ATTITUDE_VALID'},
    {{"rotate_using_parameter",0,1},{"opacity_using_parameter",1},{'parameter_in_range',2,.9,1.1}})
group("HUD_ATTITUDE",0,0,{"HUD_PITCH"},
    {{"move_up_down_using_parameter",0,-1/layout_scale}},"HUD_ATTITUDE_ROLL")
group("HUD_HORIZON",0,0,{"HUD_HORIZON_VISIBLE"},
    {{"parameter_in_range",0,0.9,1.1}},"HUD_ATTITUDE")
line(-0.27,0,-0.09,0,0.004,"HUD_HORIZON")
line(0.09,0,0.27,0,0.004,"HUD_HORIZON")
for step=-18,18 do
    if step ~= 0 then
        local angle = step*5
        local y = (angle*pi/180)/layout_scale
        local step_root="HUD_PITCH_STEP_"..step
        group(step_root,0,0,{"HUD_LADDER_"..step},
            {{"parameter_in_range",0,0.9,1.1}},"HUD_ATTITUDE")
        if step > 0 then
            line(-0.20,y,-0.055,y,0.004,step_root)
            line(0.055,y,0.20,y,0.004,step_root)
            line(-0.20,y,-0.20,y+0.022,0.004,step_root)
            line(0.20,y,0.20,y+0.022,0.004,step_root)
        else
            for j=0,2 do
                local x = 0.065+j*0.05
                line(-x-0.033,y,-x,y,0.005,step_root)
                line(x,y,x+0.033,y,0.005,step_root)
            end
            line(-0.198,y,-0.198,y-0.022,0.004,step_root)
            line(0.198,y,0.198,y-0.022,0.004,step_root)
        end
        static(-0.24,y,tostring(angle),0.031,step_root)
        static(0.24,y,tostring(angle),0.031,step_root)
    end
end

-- Symmetric aircraft-reference W; the previous six-point polyline was skewed.
line(-0.055,boresight_y+0.015,-0.0275,boresight_y-0.015,0.004)
line(-0.0275,boresight_y-0.015,0,boresight_y+0.010,0.004)
line(0,boresight_y+0.010,0.0275,boresight_y-0.015,0.004)
line(0.0275,boresight_y-0.015,0.055,boresight_y+0.015,0.004)
-- No second dash-and-stem boresight symbol under the flight-path marker.
-- World velocity projected into the same boresight frame as the fixed W.
group("HUD_FPM",0,boresight_y,{"HUD_FPM_Y_SLOPE","HUD_FPM_X_SLOPE","HUD_POWER","HUD_FPM_VALID"},
  {{"move_up_down_using_parameter",0,1/layout_scale},{"move_left_right_using_parameter",1,1/layout_scale},
   {"opacity_using_parameter",2},{"parameter_in_range",3,0.9,1.1}})
for i=0,15 do
    local a=i*2*pi/16
    line(0.022*math.cos(a),0.022*math.sin(a),
         0.022*math.cos(a+2*pi/16),0.022*math.sin(a+2*pi/16),0.004,"HUD_FPM")
end
line(-0.065,0,-0.022,0,0.004,"HUD_FPM")
line(0.022,0,0.065,0,0.004,"HUD_FPM")
-- NAV cage retains the measured vector as a compact ghost. Optical dimensions
-- are presentation estimates on the existing collimator plane.
group('HUD_FPM_GHOST',0,boresight_y,{'HUD_FPM_GHOST_Y','HUD_FPM_GHOST_X','HUD_POWER','HUD_FPM_GHOST_VALID'},
  {{'move_up_down_using_parameter',0,1/layout_scale},{'move_left_right_using_parameter',1,1/layout_scale},
   {'opacity_using_parameter',2},{'parameter_in_range',3,.9,1.1}})
line(-.013,0,.013,0,.003,'HUD_FPM_GHOST')
line(0,-.013,0,.013,.003,'HUD_FPM_GHOST')
group('HUD_FPM_LIMIT',0,0,{'HUD_FPM_OFFGLASS'},{{'parameter_in_range',0,.9,1.1}})
static(0,-.76,'FPM LIMIT',.020,'HUD_FPM_LIMIT')

-- Compact heading presentation measured from the supplied F-22 reference.
-- Current heading is a separate box above the scale. Moving degree labels
-- remain visible through the centre; only the scale's outer edges limit them.
group("HUD_HEADING",0,layout.heading_y_offset,{'HUD_REFERENCE_HEADING_VALID'},{{'parameter_in_range',0,.9,1.1}})
group('HUD_NO_HEADING',0,0,{'HUD_REFERENCE_HEADING_VALID'},{{'parameter_in_range',0,-.1,.1}})
static(0,.61,'HDG --',.025,'HUD_NO_HEADING')
group('HUD_NO_ATTITUDE',0,0,{'HUD_REFERENCE_ATTITUDE_VALID'},{{'parameter_in_range',0,-.1,.1}})
static(-.62,.23,'ATT --',.020,'HUD_NO_ATTITUDE')
label(0,0.74,"NAV","%03.0f",0.035,"HUD_HEADING")
local box_x,box_bottom,box_top=0.08,0.7075,0.7725
local baseline=0.59
line(-box_x,box_bottom,box_x,box_bottom,0.004,"HUD_HEADING")
line(-box_x,box_top,box_x,box_top,0.004,"HUD_HEADING")
line(-box_x,box_bottom,-box_x,box_top,0.004,"HUD_HEADING")
line(box_x,box_bottom,box_x,box_top,0.004,"HUD_HEADING")
static(0,0.53,"^",0.027,"HUD_HEADING")
local heading_step=layout.heading_mrad_per_degree/drawing_scale
local window=15*heading_step
line(-window,baseline,window,baseline,0.0035,"HUD_HEADING")
group("HUD_HDG_TAPE",0,0,{"HUD_HEADING_OFFSET","HUD_POWER"},
    {{"move_left_right_using_parameter",0,-heading_step},{"opacity_using_parameter",1}},"HUD_HEADING")
for index=-4,6 do
    local degrees=index*5
    local x=degrees*heading_step
    local name="HUD_HEADING_GRAD_"..index
    group(name,0,0,{"HUD_HEADING_OFFSET"},
        {{"parameter_in_range",0,degrees-15+0.001,degrees+15}},"HUD_HDG_TAPE")
    local height=index%2==0 and 0.040 or 0.025
    line(x,baseline,x,baseline-height,0.0045,name)
end
local positions={{-20,"HUD_TICK_M20"},{-10,"HUD_TICK_M10"},
    {0,"HUD_TICK_C00"},{10,"HUD_TICK_P10"},{20,"HUD_TICK_P20"}}
for _,tick in ipairs(positions) do
    local x=tick[1]*heading_step
    local root="HUD_HEADING_LABEL_"..tick[1]
    group(root,0,0,{"HUD_HEADING_OFFSET"},
        {{"parameter_in_range",0,(x-window+0.045)/heading_step,
            (x+window-0.045)/heading_step}},"HUD_HDG_TAPE")
    label(x,0.64,tick[2],"%03.0f",0.024,root)
end

-- Navigation bearing caret follows the compass scale, including 359/000 wrap.
group('HUD_NAV_STEERING_BUG',0,0,{'HUD_NAV_BUG_DEG','HUD_NAV_BUG_VALID','HUD_MODE'},
    {{'move_left_right_using_parameter',0,heading_step},{'parameter_in_range',1,.9,1.1},
     {'parameter_in_range',2,.9,1.1}},'HUD_HEADING')
group('HUD_NAV_COMMAND_MARK',0,0,{'F22_NAV_DESIGNATED'},{{'parameter_in_range',0,-.1,.1}},'HUD_NAV_STEERING_BUG')
line(0,.590,0,.555,.0035,'HUD_NAV_COMMAND_MARK')
line(-.004,.590,-.004,.555,.002,'HUD_NAV_COMMAND_MARK')
line(.004,.590,.004,.555,.002,'HUD_NAV_COMMAND_MARK')
group('HUD_TARGET_COMMAND_MARK',0,0,{'F22_NAV_DESIGNATED'},{{'parameter_in_range',0,.9,1.1}},'HUD_NAV_STEERING_BUG')
line(0,.595,.020,.575,.003,'HUD_TARGET_COMMAND_MARK')
line(.020,.575,0,.555,.003,'HUD_TARGET_COMMAND_MARK')
line(0,.555,-.020,.575,.003,'HUD_TARGET_COMMAND_MARK')
line(-.020,.575,0,.595,.003,'HUD_TARGET_COMMAND_MARK')
for _,edge in ipairs({-1,1})do
 local name='HUD_NAV_BUG_EDGE_'..edge
 group(name,0,0,{'HUD_NAV_BUG_EDGE'},{{'parameter_in_range',0,edge-.1,edge+.1}},'HUD_NAV_STEERING_BUG')
 line(0,.61,edge*.030,.625,.0035,name);line(edge*.030,.625,0,.64,.0035,name)
end
group('HUD_SELECTED_HEADING_BUG',0,0,{'HUD_HDG_BUG_DEG','HUD_HDG_BUG_VALID'},
    {{'move_left_right_using_parameter',0,heading_step},{'parameter_in_range',1,.9,1.1}},'HUD_HEADING')
line(-.025,.665,-.025,.683,.003,'HUD_SELECTED_HEADING_BUG')
line(-.025,.683,.025,.683,.003,'HUD_SELECTED_HEADING_BUG')
line(.025,.683,.025,.665,.003,'HUD_SELECTED_HEADING_BUG')
label(.105,.74,'HUD_HEADING_REFERENCE','%s',.016,'HUD_HEADING')
label(-.72,-.45,'F22_AP_STATUS_TEXT','%s',.018,nil,'LeftCenter')

dofile(LockOn_Options.script_path..'HUD/navigation.lua')({group=group,line=line,layout_scale=layout_scale})

dofile(LockOn_Options.script_path..'HUD/landing.lua')({group=group,line=line,layout_scale=layout_scale})

-- Historical flight data blocks. Weapon/tactical cues intentionally excluded.
group("HUD_GROUND_DATA",0,0,{"HUD_GS_VALID"},{{"parameter_in_range",0,0.9,1.1}})
local left_edge,right_edge=-0.72,0.72
label(left_edge,-0.120,"HUD_GS_KTS","GS %.0f",0.021,"HUD_GROUND_DATA","LeftCenter")
label(left_edge,-0.158,"HUD_TAS","T %.0f",0.021,"HUD_AIRDATA","LeftCenter")
label(left_edge,-0.196,"MACH","M %.2f",0.021,nil,"LeftCenter")
label(left_edge,-0.288,"GFORCE","G %.1f",0.021,nil,"LeftCenter")
label(left_edge,-0.326,"HUD_AOA_DEG","A %.1f",0.021,nil,"LeftCenter")
label(left_edge,-0.402,"HUD_G_MAX","%.1f",0.021,nil,"LeftCenter")
label(right_edge,-0.140,"VV","VV %.0f",0.021,nil,"RightCenter")
label(right_edge,-0.174,"RADALT","R %.0f",0.021,nil,"RightCenter")
group("HUD_NAV_INFO",0,0,{"HUD_MODE"},{{"parameter_in_range",0,.9,1.1}})
label(right_edge,-0.242,"HUD_WP_INFO","%s",0.021,"HUD_NAV_INFO","RightCenter")
label(right_edge,-0.310,"HUD_WP_TTG_TEXT","TTG %s",0.021,"HUD_NAV_INFO","RightCenter")

-- Signed vertical-speed arc around the altitude instrument.
for _,sign in ipairs({-1,1}) do
    for i=1,32 do
        local name="HUD_VS_ARC_"..sign.."_"..i
        group(name,counter_x,0.02,{"HUD_VS_ARC_COUNT","HUD_VS_SIGN"},
            {{"parameter_in_range",0,i-0.1,32.1},{"parameter_in_range",1,sign-0.1,sign+0.1}})
        -- Start at nine o'clock: climb grows up the left side, descent down.
        local a,b=-pi/2+sign*(i-1)*2*pi/32,-pi/2+sign*i*2*pi/32
        line(0.145*math.sin(a),0.145*math.cos(a),0.145*math.sin(b),0.145*math.cos(b),0.003,name)
    end
end

group("HUD_WIND",counter_x,0.32,{"HUD_WIND_VALID"},{{"parameter_in_range",0,0.9,1.1}})
label(0,0.04,"HUD_WIND_DEG","%03.0fT",0.021,"HUD_WIND")
label(0,-0.02,"HUD_WIND_KTS","%.0f KT",0.021,"HUD_WIND")
group("HUD_WIND_ARROW",-0.16,0,{"HUD_WIND_ROT",'HUD_WIND_ARROW_VALID'},
    {{"rotate_using_parameter",0,1},{'parameter_in_range',1,.9,1.1}},"HUD_WIND")
line(0,-0.04,0,0.04,0.004,"HUD_WIND_ARROW")
line(0,0.04,-0.018,0.015,0.004,"HUD_WIND_ARROW")
line(0,0.04,0.018,0.015,0.004,"HUD_WIND_ARROW")

-- The legacy lower arc sits directly over the approach FPM at this aircraft's
-- 12-degree AOA. Clear that area for the E-bracket and received ILS guidance.
group('HUD_BANK_SCALE',0,0,{'HUD_LANDING_CONFIG','HUD_REFERENCE_ATTITUDE_VALID'},
    {{'parameter_in_range',0,-.1,.1},{'parameter_in_range',1,.9,1.1}})
for i=-4,4 do
    local a=i*pi/12 -- calibrated 15-degree marks through +/-60 degrees
    -- Radial marks share the pointer's centre; they are not screen-vertical.
    local x,y=0.328*math.sin(a),-0.45-0.328*math.cos(a)
    local ox,oy=0.352*math.sin(a),-0.45-0.352*math.cos(a)
    line(x,y,ox,oy,0.004,'HUD_BANK_SCALE')
end
group("HUD_BANK_POINTER",0,-0.45,{"HUD_BANK_RAD"},{{"rotate_using_parameter",0,1}},'HUD_BANK_SCALE')
line(-0.018,-0.405,0,-0.37,0.004,"HUD_BANK_POINTER")
line(0,-0.37,0.018,-0.405,0.004,"HUD_BANK_POINTER")
line(-0.018,-0.405,0.018,-0.405,0.004,"HUD_BANK_POINTER")
group("HUD_SLIP_POINTER",0,-0.45,{"HUD_BANK_RAD"},{{"rotate_using_parameter",0,1}},'HUD_BANK_SCALE')
group("HUD_SLIP_BAR",0,-0.43,{"HUD_BANK_SLIP"},
    {{"move_left_right_using_parameter",0,1}},"HUD_SLIP_POINTER")
line(-0.018,0,0.018,0,0.005,"HUD_SLIP_BAR")

-- Isolated per-mode presentation and sensor-validity markers.
local drawTacticalHud = dofile(LockOn_Options.script_path.."HUD/tactical_page.lua")
drawTacticalHud({line=line, label=label, static=static, group=group,dynamic_line=dynamic_line,
    layout_scale=layout_scale,boresight_y=boresight_y})
