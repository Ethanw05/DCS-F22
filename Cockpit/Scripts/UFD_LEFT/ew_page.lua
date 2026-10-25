-- GPL-3.0-or-later. Top Mach manual p24 PMFD visual conventions, original code.
-- Heading-up polar display; actual radar and navigation data only at runtime.
dofile(LockOn_Options.script_path .. "UFD_LEFT/definitions.lua")
dofile(LockOn_Options.script_path .. "fonts.lua")
local layout = dofile(LockOn_Options.script_path .. "Systems/Radar_Display.lua")
SetScale(FOV)
local native_page_scale = GetScale()
local aspect = GetAspect and GetAspect() or 1
local content_scale = 0.95 * math.min(1, aspect)
local draw_level = 20
if get_param_handle then
	get_param_handle("F22_UFD_EW_PAGE_SCALE"):set(native_page_scale)
end
local colors = {
	blue = { 113, 188, 240, 255 },
	white = { 240, 247, 246, 255 },
	green = { 0, 255, 0, 255 },
	yellow = { 255, 220, 0, 255 },
	red = { 255, 35, 20, 255 },
	magenta = { 235, 80, 211, 255 },
	background = { 3, 3, 12, 255 },
}
local materials = {}
for n, c in pairs(colors) do
	materials[n] = MakeMaterial(nil, c)
end
-- Original F-22 LCD bitmap atlas. HUD resources are independent.
local fonts =
	{ white = UFD_FONT, blue = UFD_RADAR_BLUE, green = UFD_GRN, yellow = UFD_YEL, red = UFD_RED, magenta = UFD_RADAR_MAGENTA }
-- This page owns its LCD aperture. It does not borrow clipping masks from
-- unrelated MENU/SYS subsets. FOV coordinates use the real connector aspect.
local function mask(name, relation)
	local e = CreateElement("ceMeshPoly")
	e.name = name
	e.material = materials.background
	e.primitivetype = "triangles"
	e.vertices = { { -1, -aspect }, { 1, -aspect }, { 1, aspect }, { -1, aspect } }
	e.indices = { 0, 1, 2, 2, 3, 0 }
	e.h_clip_relation = relation
	e.level = draw_level - 1
	e.collimated = false
	e.isvisible = false
	e.change_opacity = false
	Add(e)
end
mask("F22_RDR_LCD_APERTURE", h_clip_relations.REWRITE_LEVEL)
mask("F22_RDR_LCD_CONTENT", h_clip_relations.INCREASE_IF_LEVEL)
local root = "F22_UFD_EW_FORMAT"
local seq = 0
local function add(e, name, parent)
	e.name = name
	if parent then
		e.parent_element = parent
	end
	e.collimated = false
	e.h_clip_relation = h_clip_relations.COMPARE
	e.level = draw_level
	e.additive_alpha = false
	e.use_mipfilter = true
	Add(e)
end
local main = CreateElement("ceSimple")
main.element_params = { "UFD_OPACITY", "F22_UFD_EW_PAGE" }
main.controllers = { { "opacity_using_parameter", 0 }, { "parameter_in_range", 1, 0.9, 1.1 } }
add(main, root)
local function group(name, params, controllers, parent, x, y)
	local e = CreateElement("ceSimple")
	e.init_pos = { (x or 0) * content_scale, (y or 0) * content_scale, 0 }
	-- DCS matrix controllers bypass SetScale; convert normalized page units
	-- to the same physical units as init_pos and vertices.
	local scaled = {}
	for i, c in ipairs(controllers or {}) do
		local row = {}
		for k, v in ipairs(c) do
			row[k] = v
		end
		if row[1] == "move_left_right_using_parameter" or row[1] == "move_up_down_using_parameter" then
			row[3] = row[3] * native_page_scale * content_scale
		end
		scaled[i] = row
	end
	e.element_params = params
	e.controllers = scaled
	add(e, name, parent or root)
end
local function line(x1, y1, x2, y2, color, parent, width)
	seq = seq + 1
	local e = CreateElement("ceSMultiLine")
	e.material = materials[color or "white"]
	e.vertices = { { x1 * content_scale, y1 * content_scale }, { x2 * content_scale, y2 * content_scale } }
	e.indices = { 0, 1 }
	e.thickness = 1.8
	e.fuzziness = 0.25
	e.draw_as_wire = false
	add(e, "F22_RDR_LINE_" .. seq, parent or root)
end
local function text(value, x, y, param, color, parent, size)
	seq = seq + 1
	local e = CreateElement("ceStringPoly")
	e.material = fonts[color or "white"]
	e.init_pos = { x * content_scale, y * content_scale, 0 }
	e.alignment = "CenterCenter"
	local h = (size or 0.0052) * content_scale
	e.stringdefs = { h, h, h * 0.08, 0 }
	if param then
		e.formats = { value }
		e.element_params = { param }
		e.controllers = { { "text_using_parameter", 0, 0 } }
	else
		e.value = value
	end
	add(e, "F22_RDR_TEXT_" .. seq, parent or root)
end
-- Segment clipping keeps the partial circles/rays inside the flat LCD window.
local bg = CreateElement("ceMeshPoly")
bg.material = materials.background
bg.primitivetype = "triangles"
bg.vertices = { { -1, -aspect }, { 1, -aspect }, { 1, aspect }, { -1, aspect } }
bg.indices = { 0, 1, 2, 2, 3, 0 }
add(bg, "F22_RDR_BACKGROUND", root)

text("EW", 0, 0.92, nil, "green", nil, 0.006)
group("F22_UFD_EW_OFF", { "F22_RWR_POWER" }, { { "parameter_in_range", 0, -0.1, 0.1 } })
text("RWR OFF", 0, 0.78, nil, "yellow", "F22_UFD_EW_OFF", 0.005)
for _, v in ipairs({ { 0, "OPR" }, { 1, "OPR" }, { 2, "TRACK" }, { 3, "MISSILE" } }) do
	local n = "F22_UFD_EW_WARNING_" .. v[1]
	group(
		n,
		{ "F22_RWR_ALERT", "F22_RWR_POWER", "F22_MWS_ALERT" },
		{ { "parameter_in_range", 0, v[1] - 0.1, v[1] + 0.1 }, { "parameter_in_range", 1, 0.9, 1.1 }, {
			"parameter_in_range",
			2,
			-0.1,
			0.1,
		} }
	)
	text(v[2], 0, 0.78, nil, v[1] > 1 and "red" or "green", n, 0.005)
end
group("F22_UFD_OPTICAL_WARNING", { "F22_MWS_BLINK" }, { { "parameter_in_range", 0, 0.9, 1.1 } })
text("MISSILE", 0, 0.78, nil, "red", "F22_UFD_OPTICAL_WARNING", 0.006)
text("%.0f CLOCK", 0, 0.64, "F22_MWS_CLOCK", "red", "F22_UFD_OPTICAL_WARNING", 0.0048)
group(
	"F22_UFD_MWS_UNAVAILABLE",
	{ "F22_MWS_POWER", "F22_MWS_READY" },
	{ { "parameter_in_range", 0, 0.9, 1.1 }, { "parameter_in_range", 1, -0.1, 0.1 } }
)
text("MWS N/A", 0, 0.64, nil, "yellow", "F22_UFD_MWS_UNAVAILABLE", 0.0048)
group("F22_UFD_EW_MUTED", { "F22_RWR_MUTE" }, { { "parameter_in_range", 0, 0.9, 1.1 } })
text("MUTE", 0.7, 0.9, nil, "yellow", "F22_UFD_EW_MUTED", 0.0038)
group("F22_UFD_EW_CRIT", { "F22_RWR_FILTER" }, { { "parameter_in_range", 0, 0.9, 1.1 } })
text("THRT", -0.7, 0.9, nil, "yellow", "F22_UFD_EW_CRIT", 0.0038)
dofile(LockOn_Options.script_path .. "Systems/EW_Indicator.lua")(
	{ line = line, text = text, group = group },
	0,
	0,
	0.75,
	root,
	false
)
-- Retain urgent aircraft warnings while the status page is hidden.
for _, spec in ipairs({
	{ "HYD_LIGHT", "HYD", -0.62, "red" },
	{ "OIL_LIGHT", "OIL", -0.2, "red" },
	{ "CAUTION_LIGHT", "CAUTION", 0.4, "yellow" },
}) do
	local n = "F22_UFD_EW_" .. spec[1]
	group(n, { spec[1] }, { { "parameter_in_range", 0, 0.5, 2 } })
	text(spec[2], spec[3], -0.82, nil, spec[4], n, 0.0047)
end
line(-0.93, -0.89, 0.93, -0.89, "green")
text("STATUS", -0.62, -0.98, nil, "white", nil, 0.0044)
text("PWR", -0.2, -0.98, nil, "green", nil, 0.0044)
group("F22_UFD_HUD_EW_ON", { "F22_RWR_HUD_ENABLED" }, { { "parameter_in_range", 0, 0.9, 1.1 } })
line(0.10, -1.02, 0.30, -1.02, "green", "F22_UFD_HUD_EW_ON")
text("HUD", 0.2, -0.98, nil, "green", nil, 0.0044)
text("THRT", 0.62, -0.98, nil, "green", nil, 0.0044)
