return function(page_parameter,prefix,detail_parameter)
-- GPL-3.0-or-later. Core radar video, with separate scale/cursor symbology.
dofile(LockOn_Options.script_path .. "PMFD_CENTER/definitions.lua")
dofile(LockOn_Options.script_path .. "fonts.lua")
SetScale(FOV)
local scale = GetScale()
local geometry = dofile(LockOn_Options.script_path .. "Systems/AG_Radar_Computer.lua")
local aspect = GetAspect and GetAspect() or 1
local display = dofile(LockOn_Options.script_path .. "MFD_COMMON/display_layout.lua").for_display(page_parameter,aspect,scale)
local plot_layout = display.ground_plot
local content_x, content_y = plot_layout.x_scale, plot_layout.y_scale
local content = math.min(content_x,content_y) -- Symbol/font size only.
local colors = {
	green = MakeMaterial(nil, { 0, 255, 0, 255 }),
	white = MakeMaterial(nil, { 240, 247, 246, 255 }),
	blue = MakeMaterial(nil, { 113, 188, 240, 255 }),
	background = MakeMaterial(nil, {3,3,3,255}),
	grid = MakeMaterial(nil, { 0, 105, 48, 170 }),
	video = "render_target_9", -- Registered by our ccIndicator before this consumer.
}
local fonts = { green = "F22_LCD_FONT_GREEN", white = "F22_LCD_FONT_WHITE", blue = "F22_LCD_FONT_BLUE" }
local root = "F22_AG_RADAR_FORMAT"
local seq = 0
local function add(e, parent, name)
	seq = seq + 1
	e.name = prefix..(name or "F22_AG_RDR_ELEMENT_" .. seq)
	e.parent_element = prefix..(parent or root)
	e.collimated = false
	e.additive_alpha = false
	e.h_clip_relation = h_clip_relations.COMPARE
	e.level = 20
	Add(e)
end
local base = CreateElement("ceSimple")
base.name = prefix..root
base.element_params = { "MFD_OPACITY", page_parameter, "HUD_MODE" }
base.controllers =
	{ { "opacity_using_parameter", 0 }, { "parameter_in_range", 1, 0.9, 1.1 }, { "parameter_in_range", 2, 6.9, 7.1 } }
base.collimated = false
base.h_clip_relation = h_clip_relations.COMPARE
base.level = 20
Add(base)
local bg = CreateElement("ceMeshPoly")
bg.material = colors.background
bg.primitivetype = "triangles"
bg.vertices = { { -1, -aspect }, { 1, -aspect }, { 1, aspect }, { -1, aspect } }
bg.indices = { 0, 1, 2, 2, 3, 0 }
add(bg)
local function group(name, params, controllers, parent)
	local e = CreateElement("ceSimple")
	e.element_params = params
	local scaled = {}
	for i, c in ipairs(controllers) do
		local row = {}
		for k, v in ipairs(c) do
			row[k] = v
		end
		if row[1] == "move_left_right_using_parameter" or row[1] == "move_up_down_using_parameter" then
			row[3] = row[3] * scale * (row[1] == "move_left_right_using_parameter" and content_x or content_y)
		end
		scaled[i] = row
	end
	e.controllers = scaled
	add(e, parent, name)
end
local function line(x1, y1, x2, y2, color, parent)
	local e = CreateElement("ceSMultiLine")
	e.material = colors[color or "blue"]
	e.vertices = { { x1 * content_x, y1 * content_y }, { x2 * content_x, y2 * content_y } }
	e.indices = { 0, 1 }
	e.thickness = 1.6
	e.fuzziness = 0.25
	e.draw_as_wire = false
	add(e, parent)
end
local function text(value, x, y, param, color, parent, size, alignment, screen)
	local e = CreateElement("ceStringSLine")
	e.material = fonts[color or "white"]
	e.init_pos = { screen and x or x * content_x, screen and y or y * content_y, 0 }
	e.alignment = alignment or "CenterCenter"
	local h = (size or 0.0045) * (screen and .95 * math.min(1,aspect) or content)
	e.stringdefs = { h, (h) * 0.60, h * 0.08, 0 }
	if param then
		e.formats = { value }
		e.element_params = { param }
		e.controllers = { { "text_using_parameter", 0, 0 } }
	else
		e.value = value
	end
	add(e, parent)
end
local function gate(name, param, value, parent)
	group(name, { param }, { { "parameter_in_range", 0, value - 0.1, value + 0.1 } }, parent)
	return name
end
-- Native RBM uses an orthographic square one selected range wide and deep.
-- Its mapping matches Model.project: x=right/range*1.65, y=-.76+forward/range*1.52.
-- Apply one per-axis display transform to video, cursor, tracks and overlays.
local video = CreateElement("ceTexPoly")
video.material = colors.video
video.vertices = {{-.825*content_x,-.76*content_y},{.825*content_x,-.76*content_y},
	{.825*content_x,.76*content_y},{-.825*content_x,.76*content_y}}
video.indices = {0,1,2,0,2,3}
video.tex_coords = {{.09,.91},{.91,.91},{.91,.09},{.09,.09}}
video.element_params = {"F22_AG_VIDEO_READY", "F22_AG_RADAR_OPERATING","F22_AG_MAP_VIDEO_SHOW"}
-- This is a foreign MFD material in the PMFD parser. Its ordinary zeroed
-- ceTexPoly parameters otherwise select BW with brightness/contrast 0/0.
-- The common forced-color controller populates the same MFD parameter slots:
-- colored=1, brightness=.5, contrast=.5 (neutral), third value=1. These are
-- material inputs, not an RGB tint. No global parser/material state is changed.
video.controllers = {{"parameter_in_range",0,.9,1.1},{"parameter_in_range",1,.9,1.1},{"parameter_in_range",2,.9,1.1},
	{"change_color_when_parameter_equal_to_number",0,1,.5,.5,1}}
add(video,nil,"F22_AG_RADAR_VIDEO")
local plot=gate("F22_AG_PLOT","F22_AG_PLOT_SHOW",1)
local ordinary=gate("F22_AG_ORDINARY_PLOT","F22_AG_EXPANSION",0,plot)
local grid_parent=gate("F22_AG_GRID_VISIBLE","F22_AG_DECLUTTER",0,ordinary)
local function plot_line(x1,y1,x2,y2)
	-- Clip grid geometry before creation; no stencil state escapes this format.
	local t0,t1=0,1
	local dx,dy=x2-x1,y2-y1
	for _,edge in ipairs({{-dx,x1+.825},{dx,.825-x1},{-dy,y1+.76},{dy,.76-y1}}) do
		local p,q=edge[1],edge[2]
		if p==0 then if q<0 then return end
		else
			local r=q/p
			if p<0 then t0=math.max(t0,r) else t1=math.min(t1,r) end
			if t0>t1 then return end
		end
	end
	line(x1+t0*dx,y1+t0*dy,x1+t1*dx,y1+t1*dy,"grid",grid_parent)
end
for _,radius in ipairs({.25,.5,.75,1}) do
	for angle=-60,59,2 do
		local a,b=math.rad(angle),math.rad(angle+2)
		plot_line(math.sin(a)*radius*1.65,-.76+math.cos(a)*radius*1.52,
			math.sin(b)*radius*1.65,-.76+math.cos(b)*radius*1.52)
	end
end
for _,angle in ipairs({-60,-30,0,30,60}) do
	local a=math.rad(angle)
	plot_line(0,-.76,math.sin(a)*1.65,-.76+math.cos(a)*1.52)
end
line(-.825,-.76,.825,-.76,"grid",plot)
line(-.825,.76,.825,.76,"grid",plot)
line(-.825,-.76,-.825,.76,"grid",plot)
line(.825,-.76,.825,.76,"grid",plot)
line(-.04,-.81,0,-.76,"white",ordinary)
line(0,-.76,.04,-.81,"white",ordinary)
-- One compact readout row outside the image. The active mode already
-- appears on its physical bezel key, so it needs no second title row.
local function readout(value,x,param,color,parent,alignment)
 text(value,x,plot_layout.readout_y,param,color,parent,.0037,alignment,true)
end
readout('EL %+.0f',-plot_layout.half_width,'F22_AG_ANTENNA_DEG','white',nil,'LeftCenter')
readout('GAIN %.0f',-.08,'F22_AG_GAIN_INDEX','green')
readout('FTT',.28,nil,'white',gate('F22_AG_FTT_TITLE','F22_AG_FIXED_TRACK',1))
readout('%.0f NM',plot_layout.half_width,'F22_AG_RADAR_RANGE_NM','white',plot,'RightCenter')
local function status(value,parent)
 text(value,-plot_layout.half_width,plot_layout.status_y,nil,'white',parent,.0037,'LeftCenter',true)
end
local live=gate("F22_AG_RDR_LIVE","F22_AG_RADAR_OPERATING",1)
text("STBY",0,.02,nil,"white",gate("F22_AG_RDR_UNAVAILABLE","F22_AG_RADAR_OPERATING",0),.005)
text("LIMIT",0,.1,nil,"white",gate("F22_AG_EXP_LIMIT","F22_AG_VIDEO_QUALIFIED",0,live),.0045)
local agr=gate("F22_AG_AGR_FORMAT","F22_AG_MODE",7,live)
text("RANGE %.0f FT",0,.20,"F22_AG_AGR_RANGE_FT","white",gate("F22_AG_AGR_RANGE","F22_AG_AGR_VALID",1,agr),.005)
text("VEL %.0f KT",0,.10,"F22_AG_AGR_VELOCITY_KT","white",gate("F22_AG_AGR_VEL","F22_AG_AGR_VALID",1,agr),.005)
text("X",0,.15,nil,"white",gate("F22_AG_AGR_INVALID","F22_AG_AGR_VALID",0,agr),.008)
local corral=gate("F22_AG_CORRAL","F22_AG_CORRAL_SHOW",1,live)
for i=1,4 do
 local j=i%4+1;local e=CreateElement("ceSimpleLineObject")
 e.material=colors.white;e.vertices={{0,0},{.001,0}};e.primitivetype="lines";e.width=.00035*content
 e.element_params={"F22_AG_CORRAL_"..i.."_X","F22_AG_CORRAL_"..i.."_Y","F22_AG_CORRAL_"..j.."_X","F22_AG_CORRAL_"..j.."_Y"}
 e.controllers={{"line_object_set_point_using_parameters",0,0,1,scale*content_x,scale*content_y},
  {"line_object_set_point_using_parameters",1,2,3,scale*content_x,scale*content_y}}
 e.thickness=1.6;e.fuzziness=.25;add(e,corral,"F22_AG_CORRAL_EDGE_"..i)
end
group(
	"F22_AG_RDR_CURSOR",
	{ "F22_AG_CURSOR_X", "F22_AG_CURSOR_Y" },
	{ { "move_left_right_using_parameter", 0, 1 }, { "move_up_down_using_parameter", 1, 1 } },
	gate("F22_AG_CURSOR_ENABLED","F22_AG_CURSOR_SHOW",1,live)
)
line(-geometry.cursor_half_width, -geometry.cursor_half_height, -geometry.cursor_half_width, geometry.cursor_half_height, "white", "F22_AG_RDR_CURSOR")
line(geometry.cursor_half_width, -geometry.cursor_half_height, geometry.cursor_half_width, geometry.cursor_half_height, "white", "F22_AG_RDR_CURSOR")
local candidate = gate("F22_AG_RDR_CANDIDATE", "F22_AG_RADAR_CANDIDATE", 1, live)

-- A missing selectable footprint does not establish an empty GPU scan.
local map_mode=gate("F22_AG_MAP_MODE","F22_AG_MODE",1,gate("F22_AG_MAP_SEARCH","F22_AG_EXPANSION",0,live))
-- Hornet MAP designation uses a radial azimuth line and range arc. The shared
-- ccIndicator line_object_set_point_using_parameters controller updates real
-- vertices; no guessed custom controller or fixed discrete range rings.
local azline=CreateElement("ceSimpleLineObject")
azline.material=colors.white;azline.vertices={{0,-.76*content_y},{0,.76*content_y}};azline.indices={0,1}
azline.primitivetype="lines";azline.width=.00035*content
azline.element_params={"F22_AG_CURSOR_AZ_X","F22_AG_CURSOR_AZ_Y"}
azline.controllers={{"line_object_set_point_using_parameters",1,0,1,scale*content_x,scale*content_y}}
azline.thickness=1.6;azline.fuzziness=.25
add(azline,map_mode,"F22_AG_MAP_AZ_CURSOR")
for i=1,60 do
	local arc=CreateElement("ceSimpleLineObject")
	arc.material=colors.white;arc.vertices={{0,0},{.001,0}};arc.primitivetype="lines";arc.width=.00035*content
	arc.element_params={"F22_AG_CURSOR_ARC_"..(i-1).."_X","F22_AG_CURSOR_ARC_"..(i-1).."_Y",
		"F22_AG_CURSOR_ARC_"..i.."_X","F22_AG_CURSOR_ARC_"..i.."_Y"}
	arc.controllers={{"line_object_set_point_using_parameters",0,0,1,scale*content_x,scale*content_y},
		{"line_object_set_point_using_parameters",1,2,3,scale*content_x,scale*content_y}}
	add(arc,map_mode,"F22_AG_MAP_RANGE_CURSOR_"..i)
end
local unqualified = gate("F22_AG_RDR_MAP_UNAVAILABLE", "F22_AG_VIDEO_GEOMETRY_QUALIFIED", 0, map_mode)
status("VIDEO",unqualified)
group("F22_AG_GMT_MODE",{"F22_AG_MODE"},{{"parameter_in_range",0,1.9,5.1}},live)
local gmt="F22_AG_GMT_MODE"


status("ACQ",gate("F22_AG_GMT_ACQ_LABEL","F22_AG_TRACK_ACQUIRING",1,live))
for i=1,64 do
	local p="F22_AG_GMT_DISPLAY_"..i.."_";local name="F22_AG_GMT_BRICK_"..i
	group(name,{p.."X",p.."Y",p.."VALID",p.."ALPHA"},{{"move_left_right_using_parameter",0,1},
		{"move_up_down_using_parameter",1,1},{"parameter_in_range",2,.9,1.1},{"opacity_using_parameter",3}},gmt)
	local brick=CreateElement("ceMeshPoly");brick.material=colors.green;brick.primitivetype="triangles"
	brick.vertices={{-.012*content_x,-.005*content_y},{.012*content_x,-.005*content_y},{.012*content_x,.005*content_y},{-.012*content_x,.005*content_y}}
	brick.indices={0,1,2,0,2,3};add(brick,name)
end
group("F22_AG_GMT_SELECTED",{"F22_AG_TRACK_X","F22_AG_TRACK_Y","F22_AG_TRACK_VALID"},
	{{"move_left_right_using_parameter",0,1},{"move_up_down_using_parameter",1,1},{"parameter_in_range",2,.9,1.1}},live)
for i=1,4 do local y=2*(i-2.5)/840*1.52;line(-15/840*1.65,y,15/840*1.65,y,"white","F22_AG_GMT_SELECTED")end
group("F22_AG_GMT_VECTOR",{"F22_AG_TRACK_VECTOR_ROT"},{{"rotate_using_parameter",0,1}},"F22_AG_GMT_SELECTED")
line(0,0,0,20/840*1.52,"white","F22_AG_GMT_VECTOR")
local tracked=gate("F22_AG_GMT_DATA","F22_AG_TRACK_VALID",1,live)
text("%.0f",-.05,0,"F22_AG_TRACK_SPEED","white","F22_AG_GMT_SELECTED",.0037,"RightCenter")
text("%03.0f°",.05,0,"F22_AG_TRACK_HEADING","white","F22_AG_GMT_SELECTED",.0037,"LeftCenter")
status("MEM",gate("F22_AG_GMT_COAST_LABEL","F22_AG_TRACK_COAST",1,tracked))
status("TRACK",gate("F22_AG_GMT_TRACK_LABEL","F22_AG_TRACK_COAST",0,tracked))
group("F22_AG_RDR_TARGET", { "F22_AG_MAP_TARGET_X", "F22_AG_MAP_TARGET_Y", "F22_AG_MAP_TARGET_VALID" }, {
	{ "move_left_right_using_parameter", 0, 1 },
	{ "move_up_down_using_parameter", 1, 1 },
	{ "parameter_in_range", 2, 0.9, 1.1 },
}, live)
local target = "F22_AG_RDR_TARGET"
line(-.04,0,-.012,0,"white",target)
line(.012,0,.04,0,"white",target)
line(0,-.04,0,-.012,"white",target)
line(0,.012,0,.04,"white",target)
-- Same lower-corner tactical-area cut as Hornet RDR_AG.lua (43px/218px
-- on an840px plot), adapted to this display's physical aspect ratio.
for _,sign in ipairs({-1,1})do
	local cut=CreateElement("ceMeshPoly");cut.material=colors.background;cut.primitivetype="triangles"
	cut.vertices={{sign*.825*content_x,-.76*content_y},{sign*43/840*1.65*content_x,-.76*content_y},
		{sign*.825*content_x,(-.76+218/840*1.52)*content_y}}
	cut.indices=sign>0 and {0,1,2} or {0,2,1};add(cut,ordinary)
end

end
