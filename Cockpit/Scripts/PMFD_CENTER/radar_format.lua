-- GPL-3.0-or-later. Top Mach manual p24 PMFD visual conventions, original code.
-- Heading-up polar display; actual radar and navigation data only at runtime.
dofile(LockOn_Options.script_path .. "PMFD_CENTER/definitions.lua")
dofile(LockOn_Options.script_path .. "fonts.lua")
local layout = dofile(LockOn_Options.script_path .. "Systems/Radar_Display.lua")
SetScale(FOV)
local native_page_scale = GetScale()
local aspect = GetAspect and GetAspect() or 1
local content_scale = 0.95 * math.min(1, aspect)
local draw_level = 20
if get_param_handle then
	get_param_handle("F22_RADAR_PAGE_SCALE"):set(native_page_scale)
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
local root = "F22_RADAR_FORMAT"
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
main.element_params = { "MFD_OPACITY", "PMFD_RDR_PAGE" }
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
local function clipped(x1, y1, x2, y2, color, width)
	local dx, dy = x2 - x1, y2 - y1
	local lo, hi = 0, 1
	local p = { -dx, dx, -dy, dy }
	local q = { x1 + 0.965, 0.965 - x1, y1 + 0.925, 0.985 - y1 }
	for i = 1, 4 do
		if math.abs(p[i]) < 1e-10 then
			if q[i] < 0 then
				return
			end
		elseif p[i] < 0 then
			lo = math.max(lo, q[i] / p[i])
		else
			hi = math.min(hi, q[i] / p[i])
		end
	end
	if lo <= hi then
		line(x1 + lo * dx, y1 + lo * dy, x1 + hi * dx, y1 + hi * dy, color, nil, width)
	end
end
local bg = CreateElement("ceMeshPoly")
bg.material = materials.background
bg.primitivetype = "triangles"
bg.vertices = { { -1, -aspect }, { 1, -aspect }, { 1, aspect }, { -1, aspect } }
bg.indices = { 0, 1, 2, 2, 3, 0 }
add(bg, "F22_RDR_BACKGROUND", root)
-- The manual uses a forward compass arc and a half-range ring, not a B-scope grid.
for _, spec in ipairs({ { layout.radius, -48, 48 }, { layout.half_radius, -180, 180 } }) do
	for a = spec[2], spec[3] - 1 do
		local p, q = math.rad(a), math.rad(a + 1)
		local r = spec[1]
		local gap = (spec[1] == layout.radius and a >= 26 and a <= 34)
			or (spec[1] == layout.half_radius and a >= 27 and a <= 41)
		if not gap then
			clipped(
				r * math.sin(p),
				layout.origin_y + r * math.cos(p),
				r * math.sin(q),
				layout.origin_y + r * math.cos(q),
				"blue",
				0.0028
			)
		end
	end
end
for i = 1, 19 do
	local p = string.format("F22_COMPASS_%02d_", i)
	local name = "F22_RDR_COMPASS_" .. i
	group(
		name,
		{ p .. "X", p .. "Y", p .. "ROT", p .. "TICK_VISIBLE" },
		{
			{ "move_left_right_using_parameter", 0, 1 },
			{ "move_up_down_using_parameter", 1, 1 },
			{ "rotate_using_parameter", 2, 1 },
			{ "parameter_in_range", 3, 0.9, 1.1 },
		}
	)
	line(0, 0, 0, -0.026, "blue", name)
	group(name .. "_MAJOR", { p .. "MAJOR" }, { { "parameter_in_range", 0, 0.9, 1.1 } }, name)
	line(0, -0.026, 0, -0.055, "blue", name .. "_MAJOR")
	group(
		name .. "_LABEL",
		{ p .. "LABEL_X", p .. "LABEL_Y", p .. "VISIBLE", p .. "MAJOR" },
		{
			{ "move_left_right_using_parameter", 0, 1 },
			{ "move_up_down_using_parameter", 1, 1 },
			{ "parameter_in_range", 2, 0.9, 1.1 },
			{ "parameter_in_range", 3, 0.9, 1.1 },
		}
	)
	group(name .. "_NUMERIC", { p .. "CARDINAL" }, { { "parameter_in_range", 0, -0.1, 0.1 } }, name .. "_LABEL")
	text("%02.0f", 0, 0, p .. "LABEL_NUMBER", "blue", name .. "_NUMERIC", 0.0055)
	for code, letter in ipairs({ "N", "E", "S", "W" }) do
		group(
			name .. "_CARDINAL_" .. code,
			{ p .. "CARDINAL" },
			{ { "parameter_in_range", 0, code - 0.1, code + 0.1 } },
			name .. "_LABEL"
		)
		text(letter, 0, 0, nil, "blue", name .. "_CARDINAL_" .. code, 0.0055)
	end
end
text("%03.0f", 0, 0.934, "F22_RADAR_HEADING_DEG", "white", nil, 0.007)
line(-0.092, 0.885, -0.092, 0.984, "blue")
line(-0.092, 0.984, 0.092, 0.984, "blue")
line(0.092, 0.984, 0.092, 0.885, "blue")
line(-0.092, 0.885, 0, 0.844, "blue")
line(0.092, 0.885, 0, 0.844, "blue")
line(0, 0.844, 0, 0.79, "blue")
text("LDR", -0.83, 0.936)
text("30 S", -0.83, 0.875)
for code, value in ipairs({ "OFF", "STBY", "RWS", "TWS", "ACQ", "STT", "BORE", "VACQ", "WIDE", "SENSOR N/A" }) do
	local name = "F22_RDR_MODE_" .. code
	group(name, { "F22_RADAR_MODE_CODE" }, { { "parameter_in_range", 0, code - 1.1, code - 0.9 } })
	text(value, 0.79, 0.936, nil, "white", name)
end
group("F22_RDR_IFF", { "F22_RADAR_IFF_ON" }, { { "parameter_in_range", 0, 0.9, 1.1 } })
text("IFF", 0.79, 0.875, nil, "white", "F22_RDR_IFF")
text("%.0f", 0.72, 0.59, "F22_RADAR_RANGE_NM", "white", nil, 0.006)
text("%.0f", 0.41, -0.065, "F22_RADAR_HALF_RANGE_NM", "blue", nil, 0.0055)
-- Coverage rays originate at ownship; width follows the selected search sector.
for _, side in ipairs({ -1, 1 }) do
	local name = "F22_RDR_COVERAGE_" .. side
	group(name, { "F22_RADAR_COVERAGE_ROT" }, { { "rotate_using_parameter", 0, side } }, nil, 0, layout.origin_y)
	line(0, 0, 0, layout.radius, "white", name, 0.0032)
end
-- White own-aircraft glyph, deliberately distinct from traffic and steerpoints.
local ship = {
	{ 0, 0.058 },
	{ -0.015, 0.018 },
	{ -0.055, -0.017 },
	{ -0.055, -0.031 },
	{ -0.015, -0.019 },
	{ -0.014, -0.057 },
	{ -0.030, -0.073 },
	{ -0.025, -0.083 },
	{ 0, -0.073 },
	{ 0.025, -0.083 },
	{ 0.030, -0.073 },
	{ 0.014, -0.057 },
	{ 0.015, -0.019 },
	{ 0.055, -0.031 },
	{ 0.055, -0.017 },
	{ 0.015, 0.018 },
	{ 0, 0.058 },
}
for i = 1, #ship - 1 do
	line(
		ship[i][1] * 0.8,
		ship[i][2] * 0.8 + layout.origin_y,
		ship[i + 1][1] * 0.8,
		ship[i + 1][2] * 0.8 + layout.origin_y,
		"white",
		nil,
		0.0025
	)
end
group(
	"F22_RDR_CURSOR",
	{ "F22_RADAR_CURSOR_X", "F22_RADAR_CURSOR_Y", "RADAR_PWR" },
	{ { "move_left_right_using_parameter", 0, 1 }, { "move_up_down_using_parameter", 1, 1 }, {
		"parameter_in_range",
		2,
		0.9,
		1.1,
	} }
)
line(-0.025, -0.025, -0.025, 0.025, "white", "F22_RDR_CURSOR")
line(0.025, -0.025, 0.025, 0.025, "white", "F22_RDR_CURSOR")
for i = 1, 24 do
	local p = string.format("F22_SCOPE_%02d_", i)
	local name = "F22_RDR_TRACK_" .. i
	group(
		name,
		{ p .. "X", p .. "Y", p .. "VALID", "RADAR_PWR" },
		{
			{ "move_left_right_using_parameter", 0, 1 },
			{ "move_up_down_using_parameter", 1, 1 },
			{ "parameter_in_range", 2, 0.9, 1.1 },
			{ "parameter_in_range", 3, 0.9, 1.1 },
		}
	)
	-- Keep identity separate from selection and track-memory state.
	for _, spec in ipairs({ { 1, "green" }, { -1, "yellow" }, { 0, "red" }, { 2, "white" } }) do
		local code, color = spec[1], spec[2]
		local symbol = name .. "_IFF_" .. code
		group(symbol, { p .. "AFFILIATION" }, { { "parameter_in_range", 0, code - 0.1, code + 0.1 } }, name)
		if code == 0 then
			for _, v in ipairs({ { 0, 0.029, 0.029, 0 }, { 0.029, 0, 0, -0.029 }, { 0, -0.029, -0.029, 0 }, {
				-0.029,
				0,
				0,
				0.029,
			} }) do
				line(v[1], v[2], v[3], v[4], color, symbol, 0.002)
			end
		elseif code == 2 then
			line(-0.024, -0.024, 0.024, -0.024, color, symbol)
			line(0.024, -0.024, 0.024, 0.024, color, symbol)
			line(0.024, 0.024, -0.024, 0.024, color, symbol)
			line(-0.024, 0.024, -0.024, -0.024, color, symbol)
		else
			for a = -90, (code == 1 and 255 or 75), 15 do
				local x, y = math.rad(a), math.rad(a + 15)
				line(
					0.029 * math.sin(x),
					0.029 * math.cos(x),
					0.029 * math.sin(y),
					0.029 * math.cos(y),
					color,
					symbol,
					0.002
				)
			end
		end
		group(symbol .. "_ALT", { p .. "ALT_VALID" }, { { "parameter_in_range", 0, 0.9, 1.1 } }, symbol)
		text("%.0f", 0, 0.061, p .. "ALT_FT", color, symbol .. "_ALT", 0.0038)
	end
	-- White 30-second groundspeed vector, clipped by the LCD aperture.
	group(name .. "_VECTOR", { p .. "VECTOR_ROT" }, { { "rotate_using_parameter", 0, 1 } }, name)
	for step = 1, 60 do
		local n = name .. "_VECTOR_" .. step
		group(n, { p .. "VECTOR_LEN" }, { { "parameter_in_range", 0, step / 30 - 1e-5, 1e6 } }, name .. "_VECTOR")
		line(0, (step - 1) / 30, 0, step / 30, "white", n, 0.0009)
	end
	group(name .. "_BUG", { p .. "SELECTED" }, { { "parameter_in_range", 0, 0.9, 1.1 } }, name)
	line(0, 0.047, 0.047, 0, "white", name .. "_BUG")
	line(0.047, 0, 0, -0.047, "white", name .. "_BUG")
	line(0, -0.047, -0.047, 0, "white", name .. "_BUG")
	line(-0.047, 0, 0, 0.047, "white", name .. "_BUG")
	group(name .. "_COAST", { p .. "COAST" }, { { "parameter_in_range", 0, 0.9, 1.1 } }, name)
	text("C", 0.062, 0, nil, "white", name .. "_COAST", 0.0036)
end
group(
	"F22_RDR_WAYPOINT",
	{ "F22_RADAR_WP_X", "F22_RADAR_WP_Y", "F22_RADAR_WP_VALID" },
	{ { "move_left_right_using_parameter", 0, 1 }, { "move_up_down_using_parameter", 1, 1 }, {
		"parameter_in_range",
		2,
		0.9,
		1.1,
	} }
)
for _, v in ipairs({ { 0, 0.034, 0.034, 0 }, { 0.034, 0, 0, -0.034 }, { 0, -0.034, -0.034, 0 }, { -0.034, 0, 0, 0.034 } }) do
	line(v[1], v[2], v[3], v[4], "magenta", "F22_RDR_WAYPOINT", 0.003)
end
text("STPT %.0f", 0, 0.07, "F22_RADAR_WP_INDEX", "white", "F22_RDR_WAYPOINT", 0.0035)
group("F22_RDR_SELECTED", { "F22_RADAR_SELECTED_VALID" }, { { "parameter_in_range", 0, 0.9, 1.1 } })
text("BUG %.1f NM", -0.69, -0.775, "F22_RADAR_SELECTED_RANGE_NM", "white", "F22_RDR_SELECTED", 0.0042)
group(
	"F22_RDR_CLOSURE",
	{ "F22_RADAR_SELECTED_CLOSURE_VALID" },
	{ { "parameter_in_range", 0, 0.9, 1.1 } },
	"F22_RDR_SELECTED"
)
text("VC %+.0f", -0.69, -0.83, "F22_RADAR_SELECTED_CLOSURE_KTS", "white", "F22_RDR_CLOSURE", 0.0042)
text("RNG IN", -0.77, -0.969, nil, "white", nil, 0.0047)
text("RNG OUT", -0.38, -0.969, nil, "white", nil, 0.0047)
text("MENU", 0, -0.969, nil, "white", nil, 0.0047)
text("EMIT", 0.38, -0.969, nil, "white", nil, 0.0047)
text("RWS/TWS", 0.77, -0.969, nil, "white", nil, 0.0047)

-- Sensor provenance and second designation remain distinct from affiliation.
for i = 1, 24 do
	local p = string.format("F22_SCOPE_%02d_", i)
	local name = "F22_RDR_TRACK_" .. i
	group(name .. "_SEC", { p .. "SECONDARY" }, { { "parameter_in_range", 0, 0.9, 1.1 } }, name)
	line(-0.043, -0.043, 0.043, 0.043, "white", name .. "_SEC")
	line(-0.043, 0.043, 0.043, -0.043, "white", name .. "_SEC")
end
group(
	"F22_SA_SELECTED_SENSOR",
	{ "F22_RADAR_SELECTED_EW_SIGNAL", "F22_RADAR_SELECTED_VALID" },
	{ { "parameter_in_range", 0, 0.9, 3.1 }, { "parameter_in_range", 1, 0.9, 1.1 } }
)
text("SENS R+EW", -0.69, -0.882, nil, "green", "F22_SA_SELECTED_SENSOR", 0.0035)
text("PRI", -0.77, 1.025, nil, "white", nil, 0.004)
text("SEC", -0.38, 1.025, nil, "white", nil, 0.004)
group("F22_SA_SWAP_READY", { "F22_RADAR_SECONDARY_SWAP_AVAILABLE" }, { { "parameter_in_range", 0, 0.9, 1.1 } })
group("F22_SA_SWAP_UNAVAILABLE", { "F22_RADAR_SECONDARY_SWAP_AVAILABLE" }, { { "parameter_in_range", 0, -0.1, 0.1 } })
text("SWAP", 0, 1.025, nil, "white", "F22_SA_SWAP_READY", 0.004)
text("SWAP", 0, 1.025, nil, "blue", "F22_SA_SWAP_UNAVAILABLE", 0.004)
text("CLR2", 0.38, 1.025, nil, "white", nil, 0.004)
text("IFF", 0.77, 1.025, nil, "white", nil, 0.004)

-- Selected-weapon launch zone, sharing the real engagement producer with HUD.
group("F22_RDR_DLZ", { "F22_FC_DLZ_VALID" }, { { "parameter_in_range", 0, 0.9, 1.1 } })
text("MAX %.1f", 0.68, 0.44, "F22_FC_MAX_NM", "white", "F22_RDR_DLZ", 0.0037)
text("MIN %.1f", 0.68, 0.38, "F22_FC_MIN_NM", "white", "F22_RDR_DLZ", 0.0037)
group("F22_RDR_DLZ_DYNAMIC", { "F22_FC_DLZ_DYNAMIC" }, { { "parameter_in_range", 0, 0.9, 1.1 } }, "F22_RDR_DLZ")
text("RTR %.1f", 0.68, 0.32, "F22_FC_TURN_NM", "blue", "F22_RDR_DLZ_DYNAMIC", 0.0037)
group("F22_RDR_SHOOT", { "F22_FC_SHOOT" }, { { "parameter_in_range", 0, 0.9, 1.1 } }, "F22_RDR_DLZ")
text("SHOOT", 0.67, 0.23, nil, "green", "F22_RDR_SHOOT", 0.0042)
group("F22_RDR_TIMER", { "F22_FC_TIMER_VALID" }, { { "parameter_in_range", 0, 0.9, 1.1 } })
group(
	"F22_RDR_PREACTIVE",
	{ "F22_FC_TIMER_ACTIVE", "F22_FC_TTA_VALID" },
	{ { "parameter_in_range", 0, -0.1, 0.1 }, { "parameter_in_range", 1, 0.9, 1.1 } },
	"F22_RDR_TIMER"
)
text("ACT E%.0f", 0.63, -0.775, "F22_FC_TTA", "white", "F22_RDR_PREACTIVE", 0.0042)
group(
	"F22_RDR_ACTIVE",
	{ "F22_FC_TIMER_ACTIVE", "F22_FC_TTG_VALID" },
	{ { "parameter_in_range", 0, 0.9, 1.1 }, { "parameter_in_range", 1, 0.9, 1.1 } },
	"F22_RDR_TIMER"
)
text("TTG E%.0f", 0.63, -0.775, "F22_FC_TTG", "white", "F22_RDR_ACTIVE", 0.0042)
text("MSL %.0f", 0.63, -0.83, "F22_FC_TIMER_SEQUENCE", "blue", "F22_RDR_TIMER", 0.0038)
for i = 1, 8 do
	local p = string.format("F22_MSL_%02d_", i)
	local name = "F22_RDR_MISSILE_" .. i
	group(
		name,
		{ p .. "X", p .. "Y", p .. "PLOT_VALID" },
		{ { "move_left_right_using_parameter", 0, 1 }, { "move_up_down_using_parameter", 1, 1 }, {
			"parameter_in_range",
			2,
			0.9,
			1.1,
		} }
	)
	line(0, 0.017, 0.017, -0.012, "blue", name)
	line(0.017, -0.012, -0.017, -0.012, "blue", name)
	line(-0.017, -0.012, 0, 0.017, "blue", name)
	text("%.0f", 0.04, 0.015, p .. "SEQUENCE", "white", name, 0.0033)
	group(name .. "_LOST", { p .. "TRACK_LOST" }, { { "parameter_in_range", 0, 0.9, 1.1 } }, name)
	text("LOST", 0.04, -0.025, nil, "red", name .. "_LOST", 0.0031)
	group(name .. "_COAST", { p .. "SUPPORT_STATE" }, { { "parameter_in_range", 0, 1.9, 2.1 } }, name)
	text("MEM", 0.04, -0.025, nil, "yellow", name .. "_COAST", 0.0031)
end

-- Support warnings remain visible independently of the selected weapon/target.
group("F22_RDR_SUPPORT_WARN", { "F22_FC_MISSILES" }, { { "parameter_in_range", 0, 0.5, 8.5 } })
group(
	"F22_RDR_SUPPORT_LOST",
	{ "F22_FC_SUPPORT_LOST" },
	{ { "parameter_in_range", 0, 0.9, 1.1 } },
	"F22_RDR_SUPPORT_WARN"
)
text("SUPPORT LOST", 0, -0.89, nil, "red", "F22_RDR_SUPPORT_LOST", 0.0036)
group(
	"F22_RDR_SUPPORT_COAST",
	{ "F22_FC_SUPPORT_DEGRADED", "F22_FC_SUPPORT_LOST" },
	{ { "parameter_in_range", 0, 0.9, 1.1 }, { "parameter_in_range", 1, -0.1, 0.1 } },
	"F22_RDR_SUPPORT_WARN"
)
text("SUPPORT COAST", 0, -0.89, nil, "yellow", "F22_RDR_SUPPORT_COAST", 0.0036)
