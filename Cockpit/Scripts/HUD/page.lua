-- SPDX-License-Identifier: GPL-3.0-or-later
-- Original geometry based on R03 Fig.3. This is not a traced/validated production HUD.
dofile(LockOn_Options.common_script_path .. "elements_defs.lua")
dofile(LockOn_Options.script_path .. "fonts.lua")
SetScale(MILLYRADIANS)
local config = dofile(LockOn_Options.script_path .. "HUD/config.lua")
local material = MakeMaterial(nil, {50, 255, 95, 255})
local font = UFD_GRN
local level, serial = 15, 0
local function add(element, parent)
    serial = serial + 1
    element.name = "F22_HUD_" .. serial
    element.parent_element = parent
    element.collimated = true
    element.additive_alpha = true
    element.use_mipfilter = true
    element.h_clip_relation = h_clip_relations.COMPARE
    element.level = level
    Add(element)
    return element
end
local clip = CreateElement "ceMeshPoly"
clip.name = "F22_HUD_CLIP"
clip.vertices = {{-config.halfWidth,-config.halfHeight},{config.halfWidth,-config.halfHeight},
    {config.halfWidth,config.halfHeight},{-config.halfWidth,config.halfHeight}}
clip.indices = {0,1,2,0,2,3}
clip.material = material; clip.isvisible = false; clip.collimated = true
clip.h_clip_relation = h_clip_relations.REWRITE_LEVEL; clip.level = level
Add(clip)
local root = CreateElement "ceSimple"
root.element_params = {"F22_HUD_VISIBLE"}
root.controllers = {{"opacity_using_parameter",0}}
add(root)
local function line(points, parent, params, controllers)
    local e = CreateElement "ceSimpleLineObject"
    e.material = material; e.vertices = points; e.width = 0.6
    e.element_params = params; e.controllers = controllers
    return add(e, parent or root.name)
end
local function text(value,x,y,param,parent,condition)
    local e = CreateElement "ceStringPoly"
    e.material = font; e.init_pos = {x,y,0}; e.alignment = "CenterCenter"
    e.stringdefs = {0.005,0.004,0,0}
    if param then
        e.formats = {value}; e.element_params = {param}; e.controllers = {{"text_using_parameter",0,0}}
    else e.value = value end
    if condition then e.element_params={condition}; e.controllers={{"parameter_in_range",0,0.5,1.5}} end
    return add(e,parent or root.name)
end
local function circle(cx,cy,r,parent)
    local points = {}
    for i = 0, 48 do local a=i/48*math.pi*2; points[#points+1]={cx+r*math.sin(a),cy+r*math.cos(a)} end
    return line(points,parent)
end
-- Counter-pointer gauges: 100 knots / 1000 feet per revolution (R03 Fig.1).
for _, gauge in ipairs({{-145,"F22_HUD_SPEED_POINTER","F22_HUD_IAS","%03.0f"},
                         {145,"F22_HUD_ALT_POINTER","F22_HUD_ALT","%05.0f"}}) do
    local cx, cy, radius = gauge[1], 30, 29
    for i=0,9 do
        local angle=i*math.pi/5
        circle(cx+radius*math.sin(angle),cy+radius*math.cos(angle),0.8)
    end
    text(gauge[4],cx,cy,gauge[3])
    local pointer=CreateElement "ceSimple"
    pointer.init_pos={cx,cy,0}; pointer.element_params={gauge[2]}
    pointer.controllers={{"rotate_using_parameter",0,1}}; add(pointer,root.name)
    line({{0,18},{-2,22},{0,20},{2,22},{0,18}},pointer.name)
end
-- Boresight/waterline and heading readout.
line({{-10,0},{-5,-3},{0,0},{5,-3},{10,0}})
text("%03.0f",0,140,"F22_HUD_HEADING")
line({{-5,132},{0,127},{5,132}})
for index=-3,3 do
    local mark=CreateElement "ceSimple"
    mark.init_pos={0,121,0}
    mark.element_params={"F22_HUD_HDG_X_"..index,"F22_HUD_HDG_VALID_"..index}
    mark.controllers={{"move_left_right_using_parameter",0,1},{"parameter_in_range",1,0.5,1.5}}
    add(mark,root.name)
    line({{0,0},{0,-4}},mark.name)
    text("%03.0f",0,-11,"F22_HUD_HDG_LABEL_"..index,mark.name)
end
text("M %.2f",-145,-25,"F22_HUD_MACH")
text("%.1f G",-145,-40,"F22_HUD_G")
text("A %.1f",-145,-55,"F22_HUD_ALPHA")
text("R %05.0f",145,-25,"F22_HUD_RADALT")
text("NAV",-145,-115)
-- Lower bank scale: layout evidence in R03; dimensions are our approximation.
for _,degrees in ipairs({-60,-30,-20,-10,0,10,20,30,60}) do
    local a=math.rad(degrees)
    line({{55*math.sin(a),-70-55*math.cos(a)},
          {60*math.sin(a),-70-60*math.cos(a)}})
end
local bankPointer=CreateElement "ceSimple"
bankPointer.init_pos={0,-70,0}; bankPointer.element_params={"F22_HUD_BANK_POINTER"}
bankPointer.controllers={{"rotate_using_parameter",0,1}}; add(bankPointer,root.name)
line({{-3,-49},{0,-54},{3,-49}},bankPointer.name)
-- Pitch ladder is independently projected before rotating into the bank angle.
local bank=CreateElement "ceSimple"
bank.element_params={"F22_HUD_ROLL"}; bank.controllers={{"rotate_using_parameter",0,1}}
add(bank,root.name)
for angle=-90,90,5 do
    local origin=CreateElement "ceSimple"
    origin.element_params={"F22_HUD_PITCH_"..angle,"F22_HUD_PITCH_VALID_"..angle}
    origin.controllers={{"move_up_down_using_parameter",0,1},{"parameter_in_range",1,0.5,1.5}}
    add(origin,bank.name)
    local extent=angle==0 and 105 or 65
    if angle<0 then
        for _, sign in ipairs({-1,1}) do
            for j=0,2 do local x=sign*(18+j*16); line({{x,0},{x+sign*9,0}},origin.name) end
        end
    else
        line({{-extent,0},{-18,0}},origin.name); line({{18,0},{extent,0}},origin.name)
    end
    if angle~=0 then text(tostring(math.abs(angle)),-extent-12,0,nil,origin.name); text(tostring(math.abs(angle)),extent+12,0,nil,origin.name) end
end
local fpm=CreateElement "ceSimple"
fpm.element_params={"F22_HUD_FPM_X","F22_HUD_FPM_Y","F22_HUD_FPM_VALID"}
fpm.controllers={{"move_left_right_using_parameter",0,1},{"move_up_down_using_parameter",1,1},{"parameter_in_range",2,0.5,1.5}}
add(fpm,root.name)
circle(0,0,4,fpm.name); line({{-12,0},{-4,0}},fpm.name); line({{4,0},{12,0}},fpm.name); line({{0,4},{0,8}},fpm.name)
text("X",0,-10,nil,fpm.name,"F22_HUD_FPM_CAGED")
