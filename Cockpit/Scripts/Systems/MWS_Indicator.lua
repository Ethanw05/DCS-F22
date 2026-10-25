-- GPL-3.0-or-later. Optical missile bearings remain separate from RF symbols.
return function(api, cx, cy, scale, parent, compact)
	for i = 1, 16 do
		local p = string.format("F22_MWS_%02d_", i)
		local name = parent .. "_OPTICAL_MISSILE_" .. i
		api.group(
			name,
			{ p .. "X", p .. "Y", p .. "VALID", "F22_MWS_POWER", "F22_MWS_READY", "F22_MWS_BLINK" },
			{
				{ "move_left_right_using_parameter", 0, scale },
				{ "move_up_down_using_parameter", 1, scale },
				{ "parameter_in_range", 2, 0.9, 1.1 },
				{ "parameter_in_range", 3, 0.9, 1.1 },
				{ "parameter_in_range", 4, 0.9, 1.1 },
				{ "parameter_in_range", 5, 0.9, 1.1 },
			},
			parent,
			cx,
			cy
		)
		local r = compact and 0.025 or 0.05
		api.line(0, r, -r, -r, "red", name)
		api.line(-r, -r, r, -r, "red", name)
		api.line(r, -r, 0, r, "red", name)
		api.text("M", 0, 0, nil, "red", name, compact and 0.0027 or 0.0045)
	end
end
