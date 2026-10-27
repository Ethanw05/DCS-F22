-- GPL-3.0-or-later. Same existing HUD font; the warning owns only this cue.
return function(api)
	api.group(
		"HUD_PILOT_WARNING",
		0,
		0,
		{ "HUD_POWER", "F22_PILOT_WARNING_VALID" },
		{ { "opacity_using_parameter", 0 }, { "parameter_in_range", 1, 0.9, 1.1 } }
	)
	api.group("HUD_WARNING_TEXT_ONLY", 0, 0, { "F22_TAWS_CUE_VALID" },
		{ { "parameter_in_range", 0, -0.1, 0.1 } }, "HUD_PILOT_WARNING")
	api.label(0, -0.13, "F22_PILOT_WARNING_TEXT", "%s", 0.027, "HUD_WARNING_TEXT_ONLY")
	api.group("HUD_TAWS_RECOVERY", 0, 0, { "HUD_POWER", "F22_TAWS_CUE_VALID", "F22_TAWS_CUE_ROT_RAD" },
		{ { "opacity_using_parameter", 0 }, { "parameter_in_range", 1, 0.9, 1.1 },
		  { "rotate_using_parameter", 2, 1 } })
	-- Independent outline, using the measured Hornet cue's angular dimensions.
	-- Keep the tail notch recognizable if the head is outside the HUD aperture.
	local points = { {0,76.5}, {42.5,25.5}, {23.8,25.5}, {23.8,-76.5},
		{0,-45.9}, {-23.8,-76.5}, {-23.8,25.5}, {-42.5,25.5}, {0,76.5} }
	local gain = 1 / (1000 * api.layout_scale)
	for i = 1, #points - 1 do
		local a, b = points[i], points[i+1]
		api.line(a[1]*gain, a[2]*gain, b[1]*gain, b[2]*gain,
			1.1*gain, "HUD_TAWS_RECOVERY", "HUD_TAWS_RECOVERY_LINE_"..i)
	end
	api.group("HUD_TAWS_WARNING_TEXT", 0, 0, { "HUD_POWER", "F22_TAWS_CUE_VALID", "F22_PILOT_WARNING_VALID" },
		{ { "opacity_using_parameter", 0 }, { "parameter_in_range", 1, 0.9, 1.1 },
		  { "parameter_in_range", 2, 0.9, 1.1 } })
	api.label(0, -0.45, "F22_PILOT_WARNING_TEXT", "%s", 0.027, "HUD_TAWS_WARNING_TEXT")
	api.group(
		"HUD_TAWS_UNAVAILABLE",
		0,
		0,
		{ "HUD_POWER", "F22_TAWS_INOPERATIVE", "F22_PILOT_WARNING_VALID" },
		{ { "opacity_using_parameter", 0 }, { "parameter_in_range", 1, 0.9, 1.1 }, { "parameter_in_range", 2, -0.1, 0.1 } }
	)
	api.static(0, -0.13, "TAWS N/A", 0.014, "HUD_TAWS_UNAVAILABLE")
end
