-- GPL-3.0-or-later. Focus corners only; page selection stays on bezel controls.
return function(focus, definitions)
	dofile(LockOn_Options.script_path .. definitions)
	SetScale(FOV)
	local aspect = GetAspect and GetAspect() or 1
	local inset = 0.016
	local corner_x, corner_y = 1 - inset, aspect - inset
	local length = 0.075 * math.min(1, aspect)
	local prefix = "F22_SCS_" .. focus .. "_"
	local green = MakeMaterial(nil, { 0, 255, 0, 255 })
	for _, relation in ipairs({ h_clip_relations.REWRITE_LEVEL, h_clip_relations.INCREASE_IF_LEVEL }) do
		local mask = CreateElement("ceMeshPoly")
		mask.name = prefix .. "APERTURE_" .. relation
		mask.material = green
		mask.primitivetype = "triangles"
		mask.vertices = { { -1, -aspect }, { 1, -aspect }, { 1, aspect }, { -1, aspect } }
		mask.indices = { 0, 1, 2, 2, 3, 0 }
		mask.h_clip_relation = relation
		mask.level = 30
		mask.collimated = false
		mask.isvisible = false
		Add(mask)
	end
	local root = prefix .. "FOCUS"
	local g = CreateElement("ceSimple")
	g.name = root
	g.element_params = { "MFD_OPACITY", "F22_SOI" }
	g.controllers = { { "opacity_using_parameter", 0 }, { "parameter_in_range", 1, focus - 0.1, focus + 0.1 } }
	g.collimated = false
	g.h_clip_relation = h_clip_relations.COMPARE
	g.level = 31
	Add(g)
	local seq = 0
	local function line(x1, y1, x2, y2)
		seq = seq + 1
		local e = CreateElement("ceSMultiLine")
		e.name = prefix .. "CORNER_" .. seq
		e.parent_element = root
		e.material = green
		e.vertices = { { x1, y1 }, { x2, y2 } }
		e.indices = { 0, 1 }
		e.thickness = 1.8
		e.fuzziness = 0.25
		e.draw_as_wire = false
		e.collimated = false
		e.h_clip_relation = h_clip_relations.COMPARE
		e.level = 31
		e.additive_alpha = false
		Add(e)
	end
	for _, x in ipairs({ -1, 1 }) do
		for _, y in ipairs({ -1, 1 }) do
			line(x * corner_x, y * (corner_y - length), x * corner_x, y * corner_y)
			line(x * (corner_x - length), y * corner_y, x * corner_x, y * corner_y)
		end
	end
end
