-- GPL-3.0-or-later: derivative within Grinnelli Designs F-22A project.
-- Historical 2002 F-22 counter-pointer layout + an intentionally borrowed
-- C-130-style heading strip. UNVERIFIED optical alignment and tactical modes.
dofile(LockOn_Options.script_path.."fonts.lua")
local green = MakeMaterial(nil, {40,255,94,255})
local pi = math.pi
local function add_base(e, name, parent)
    e.name = name
    e.material = e.material or green
    e.additive_alpha = true
    e.collimated = true
    e.h_clip_relation = h_clip_relations.COMPARE
    e.level = 0
    if not e.controllers then
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
local function line(x1,y1,x2,y2,w,parent)
    local dx,dy = x2-x1,y2-y1
    local length = math.sqrt(dx*dx+dy*dy)
    if length < 0.000001 then return end
    local ox,oy = -dy*w/(2*length),dx*w/(2*length)
    local e = CreateElement "ceMeshPoly"
    e.primitivetype = "triangles"
    e.vertices = {{x1+ox,y1+oy},{x2+ox,y2+oy},{x2-ox,y2-oy},{x1-ox,y1-oy}}
    e.indices = {0,1,2,2,3,0}
    add_base(e,id("HUD_LINE"),parent)
end
local function label(x,y,param,fmt,h,parent)
    local e = CreateElement "ceStringPoly"
    e.material = UFD_GRN
    e.init_pos = {x,y}
    e.alignment = "CenterCenter"
    e.stringdefs = {h,h*0.74,0,0}
    e.formats = {fmt}
    e.element_params = {param,"HUD_POWER"}
    e.controllers = {{"text_using_parameter",0,0},{"opacity_using_parameter",1}}
    add_base(e,id("HUD_TEXT"),parent)
end
local function static(x,y,value,h,parent)
    local e = CreateElement "ceStringPoly"
    e.material = UFD_GRN
    e.init_pos = {x,y}
    e.alignment = "CenterCenter"
    e.stringdefs = {h,h*0.74,0,0}
    e.value = value
    e.element_params = {"HUD_POWER"}
    e.controllers = {{"opacity_using_parameter",0}}
    add_base(e,id("HUD_STATIC"),parent)
end
local function group(name,x,y,params,controllers,parent)
    local e = CreateElement "ceSimple"
    e.init_pos = {x,y}
    e.element_params = params or {"HUD_POWER"}
    e.controllers = controllers or {{"opacity_using_parameter",0}}
    add_base(e,name,parent)
end

-- Layout is intentionally normalized. Installed physical FOV/eyebox is unknown.
-- Published F-22 figure has circular counter/pointer speed and altitude,
-- not moving vertical tapes.
local function dial(cx,cy,r,n,param)
    for i=0,10 do
        local a = (i/10)*2*pi
        local x,y = cx+r*math.sin(a), cy+r*math.cos(a)
        line(x-0.005,y,x+0.005,y,0.003)
    end
    label(cx,cy+0.035,n,"%04.0f",0.066)
    local name=id("HUD_POINTER_ROOT")
    group(name,cx,cy,{param,"HUD_POWER"},
        {{"rotate_using_parameter",0,1},{"opacity_using_parameter",1}})
    line(0,-0.02,r*0.85,-0.04,0.008,name)
end
dial(-0.71,0.02,0.115,"IAS","HUD_IAS_POINTER")
dial( 0.71,0.02,0.115,"BAROALT","HUD_ALT_POINTER")

-- Geometric attitude reference: moves in pitch, rotates as aircraft rolls.
group("HUD_ATTITUDE",0,0,{"HUD_PITCH","HUD_ROLL","HUD_POWER"},
    {{"move_up_down_using_parameter",0,-1.18},{"rotate_using_parameter",1,1},{"opacity_using_parameter",2}})
line(-1.05,0,-0.048,0,0.006,"HUD_ATTITUDE")
line(0.048,0,1.05,0,0.006,"HUD_ATTITUDE")
for step=-3,3 do
    if step ~= 0 then
        local angle = step*5
        local y = (angle*pi/180)*1.18
        if step > 0 then
            line(-0.18,y,-0.06,y,0.005,"HUD_ATTITUDE")
            line(0.06,y,0.18,y,0.005,"HUD_ATTITUDE")
        else
            for j=0,2 do
                local x = 0.07+j*0.055
                line(-x-0.033,y,-x,y,0.005,"HUD_ATTITUDE")
                line(x,y,x+0.033,y,0.005,"HUD_ATTITUDE")
            end
        end
    end
end

-- W-shaped historical cue preserved from the published F-22 Figure 1.
-- Meaning/mode remains unverified; pure reference symbology for now.
line(-0.038,0.365,-0.023,0.348,0.005)
line(-0.023,0.348,-0.008,0.357,0.005)
line(-0.008,0.357,0.008,0.348,0.005)
line(0.008,0.348,0.023,0.357,0.005)
line(0.023,0.357,0.038,0.365,0.005)

-- Aircraft-reference/boresight symbol.
line(-0.065,0, -0.018,0,0.007)
line(0.018,0,0.065,0,0.007)
line(0,-0.02,0,0.012,0.007)
-- Flight-path marker approximation from climb angle/sideslip (requires DCS calibration).
group("HUD_FPM",0,0,{"HUD_FPA","HUD_SLIP","HUD_POWER"},
  {{"move_up_down_using_parameter",0,1.18},{"move_left_right_using_parameter",1,-1.18},{"opacity_using_parameter",2}})
for i=0,15 do
    local a=i*2*pi/16
    line(0.022*math.cos(a),0.022*math.sin(a),
         0.022*math.cos(a+2*pi/16),0.022*math.sin(a+2*pi/16),0.004,"HUD_FPM")
end
line(-0.065,0,-0.022,0,0.004,"HUD_FPM")
line(0.022,0,0.065,0,0.004,"HUD_FPM")
line(0,-0.023,0,-0.057,0.004,"HUD_FPM")

-- C-130J-inspired navigation heading tape. This is an intentional hybrid feature.
-- Tick translation is continuous; label groups update every ten degrees.
static(0,0.82,"HDG",0.037)
label(0,0.75,"NAV","%03.0f",0.058)
line(-0.038,0.71,0.038,0.71,0.004)
line(-0.038,0.71,-0.038,0.79,0.004)
line(0.038,0.71,0.038,0.79,0.004)
group("HUD_HDG_TAPE",0,0,{"HUD_HEADING_OFFSET","HUD_POWER"},
    {{"move_left_right_using_parameter",0,-0.012},{"opacity_using_parameter",1}})
local positions = {
    {-2,"HUD_TICK_M20"},{-1,"HUD_TICK_M10"},{0,"HUD_TICK_C00"},
    {1,"HUD_TICK_P10"},{2,"HUD_TICK_P20"}
}
for _,tick in ipairs(positions) do
    local x=tick[1]*0.12
    line(x,0.67,x,0.70,0.004,"HUD_HDG_TAPE")
    label(x,0.635,tick[2],"%03.0f",0.039,"HUD_HDG_TAPE")
end
line(0,0.70,-0.016,0.675,0.004)
line(0,0.70,0.016,0.675,0.004)

-- Historical flight data blocks. Weapon/tactical cues intentionally excluded.
label(-0.76,-0.19,"MACH","M %.2f",0.047)
label(-0.76,-0.26,"GFORCE","G %.1f",0.047)
label(-0.76,-0.33,"AOA","A %.1f",0.047)
label( 0.76,-0.19,"RADALT","R %.0f",0.047)

-- Lower roll arc, retained as a visual reference only until mode semantics verified.
for i=-6,6 do
    local a=i*pi/24
    local x,y=0.34*math.sin(a),-0.63+0.34*(1-math.cos(a))
    local ox,oy=0.34*math.sin(a),-0.63+0.34*(1-math.cos(a))+0.025
    line(x,y,ox,oy,0.004)
end
line(-0.02,-0.61,0,-0.65,0.004)
line(0,-0.65,0.02,-0.61,0.004)

-- Isolated per-mode presentation and sensor-validity markers.
local drawTacticalHud = dofile(LockOn_Options.script_path.."HUD/tactical_page.lua")
drawTacticalHud({line=line, label=label, static=static, group=group})
