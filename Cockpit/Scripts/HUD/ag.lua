-- GPL-3.0-or-later. Original ground-attack cues using the existing HUD font/optics.
return function(api)
	local group, line, label, static = api.group, api.line, api.label, api.static
    local readouts = dofile(LockOn_Options.script_path..'HUD/readouts.lua')
	local unit = 1 / (1000 * api.layout_scale)
	local frl = dofile(LockOn_Options.script_path .. "HUD/optics.lua").frl_elevation / api.layout_scale
	local function gate(name, param, lo, hi, parent)
		group(name, 0, 0, { param }, { { "parameter_in_range", 0, lo, hi } }, parent)
		return name
	end
	local root = "HUD_AG_ROOT"
	group(
		root,
		0,
		0,
		{ "HUD_MODE", "HUD_POWER" },
		{ { "parameter_in_range", 0, 6.9, 7.1 }, { "opacity_using_parameter", 1 } }
	)
	local function angular(name, az, el, valid, parent)
		group(
			name,
			0,
			frl,
			{ az, el, valid },
			{
				{ "move_left_right_using_parameter", 0, 1 / api.layout_scale },
				{ "move_up_down_using_parameter", 1, 1 / api.layout_scale },
				{ "parameter_in_range", 2, 0.9, 1.1 },
			},
			parent or root
		)
	end
	for mode, name in ipairs({ "GUN", "CCIP", "AUTO" }) do
		local parent = gate("HUD_AG_MODE_" .. mode, "HUD_AG_SUBMODE", mode - 0.1, mode + 0.1, root)
		static(readouts.right,mode==1 and readouts.weapon_name or readouts.weapon_state,
            name,0.023,parent,'RightCenter')
	end
	label(readouts.right,readouts.weapon_name,'F22_WEAPON_NAME','%s',0.021,
        gate('HUD_AG_WEAPON_ID','HUD_AG_SUBMODE',1.9,3.1,root),'RightCenter')
	label(
		readouts.right,
		readouts.weapon_count,
		"F22_WEAPON_COUNT",
		"QTY %.0f",
		0.021,
		gate("HUD_AG_BOMB_COUNT", "HUD_AG_SUBMODE", 1.9, 3.1, root),
        'RightCenter'
	)
	label(
		readouts.right,
		readouts.weapon_count,
		"F22_GUN_AMMO_COUNT",
		"AMMO %.0f",
		0.021,
		gate("HUD_AG_GUN_COUNT", "HUD_AG_SUBMODE", 0.9, 1.1, root),
        'RightCenter'
	)
	local valid = gate("HUD_AG_SOLUTION", "F22_AG_SOLUTION_VALID", 0.9, 1.1, root)
	label(readouts.right,readouts.closing_velocity,"HUD_AG_CCIP_TOF_SEC","TOF %.1f",0.021,valid,'RightCenter')
	label(readouts.right,readouts.target_range,"HUD_AG_CCIP_RANGE_NM","RNG %.1f",0.021,valid,'RightCenter')
	local none = gate("HUD_AG_NO_SOLUTION", "F22_AG_SOLUTION_VALID", -0.1, 0.1, root)
	static(readouts.right,readouts.radar_mode,"NO SOLUTION",0.021,none,'RightCenter')
	local visual = gate("HUD_AG_VISUAL_STATUS", "HUD_AG_SUBMODE", 0.9, 2.1, valid)
	static(
		readouts.right,
		readouts.weapon_state-.038,
		"PIPPER OFF HUD",
		0.019,
		gate("HUD_AG_OFFSCREEN_STATUS", "HUD_AG_CCIP_CUE_VALID", -0.1, 0.1, visual),
        'RightCenter'
	)
	local auto = gate("HUD_AG_AUTO", "HUD_AG_SUBMODE", 2.9, 3.1, root)
	static(0, -0.54, "NO DESIGNATION", 0.021, gate("HUD_AG_NO_TARGET", "HUD_AG_TARGET_VALID", -0.1, 0.1, auto))
	local target = gate("HUD_AG_TARGET", "HUD_AG_TARGET_VALID", 0.9, 1.1, root)
	angular("HUD_AG_MARKER", "HUD_AG_TGT_X_SLOPE", "HUD_AG_TGT_Y_SLOPE", "HUD_AG_CUE_VALID", target)
	local r = 7 * unit
	for _, v in ipairs({ { 0, r, r, 0 }, { r, 0, 0, -r }, { 0, -r, -r, 0 }, { -r, 0, 0, r } }) do
		line(v[1], v[2], v[3], v[4], 0.75 * unit, "HUD_AG_MARKER")
	end
	angular(
		"HUD_AG_CCIP_PIPPER",
		"HUD_AG_CCIP_X_SLOPE",
		"HUD_AG_CCIP_Y_SLOPE",
		"HUD_AG_CCIP_CUE_VALID",
		gate("HUD_AG_VISUAL", "HUD_AG_SUBMODE", 0.9, 2.1, root)
	)
	line(-2 * unit, 0, 2 * unit, 0, 0.75 * unit, "HUD_AG_CCIP_PIPPER")
	line(0, -2 * unit, 0, 2 * unit, 0.75 * unit, "HUD_AG_CCIP_PIPPER")
	for i = 0, 23 do
		local a, b = i * math.pi / 12, (i + 1) * math.pi / 12
		line(
			8 * unit * math.cos(a),
			8 * unit * math.sin(a),
			8 * unit * math.cos(b),
			8 * unit * math.sin(b),
			0.75 * unit,
			"HUD_AG_CCIP_PIPPER"
		)
	end
	-- The bomb fall line joins the flight reference to the native impact point.
	if api.dynamic_line then
		api.dynamic_line(
			"HUD_AG_BOMB_FALL_LINE",
			"HUD_AG_DIL_X0",
			"HUD_AG_DIL_Y0",
			"HUD_AG_DIL_X1",
			"HUD_AG_DIL_Y1",
			"HUD_AG_CCIP_CUE_VALID",
			"F22_AG_BOMB_SELECTED",
			gate("HUD_AG_FALL_LINE_MODE", "HUD_AG_SUBMODE", 1.9, 2.1, root)
		)
	end
	local steer = gate("HUD_AG_AUTO_STEERING", "HUD_AG_CCRP_EST_VALID", 0.9, 1.1, auto)
	group("HUD_AG_AUTO_ASL", 0, 0, { "F22_AG_STEERING_X" }, { { "move_left_right_using_parameter", 0, 1 } }, steer)
	line(0, -0.45, 0, 0.40, 0.75 * unit, "HUD_AG_AUTO_ASL")
	group(
		"HUD_AG_AUTO_RELEASE_CUE",
		0,
		0,
		{ "F22_AG_RELEASE_CUE_Y" },
		{ { "move_up_down_using_parameter", 0, 1 } },
		"HUD_AG_AUTO_ASL"
	)
	line(-0.10, 0, 0.10, 0, 1 * unit, "HUD_AG_AUTO_RELEASE_CUE")
	label(readouts.right,readouts.weapon_timer,"HUD_AG_CCRP_TIME_SEC","REL %+.1f",0.021,steer,'RightCenter')
	static(0, -0.66, "CONSENT", 0.021, gate("HUD_AG_CONSENT", "F22_AG_RELEASE_CONSENT", 0.9, 1.1, auto))
	static(0, -0.61, "RELEASE", 0.021, gate("HUD_AG_RELEASE_WINDOW", "F22_AG_AUTO_RELEASE", 0.9, 1.1, auto))
	local ccip = gate("HUD_AG_GUIDED_CCIP", "HUD_AG_SUBMODE", 1.9, 2.1, root)
	static(
		0,
		-0.59,
		"JDAM AUTO ONLY",
		0.021,
		gate("HUD_AG_GUIDED_CCIP_INHIBIT", "F22_AG_GUIDED_SELECTED", 0.9, 1.1, ccip)
	)
end
