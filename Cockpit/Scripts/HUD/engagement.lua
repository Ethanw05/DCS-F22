-- GPL-3.0-or-later. Compact launch cues; existing HUD font and flight dials.
return function(api)
	local group, line, label, static = api.group, api.line, api.label, api.static
	local function gate(name, param, value, parent)
		group(name, 0, 0, { param }, { { "parameter_in_range", 0, value - 0.1, value + 0.1 } }, parent)
		return name
	end
	group(
		"HUD_MWS_WARNING",
		0,
		0,
		{ "HUD_POWER", "F22_MWS_BLINK" },
		{ { "opacity_using_parameter", 0 }, { "parameter_in_range", 1, 0.9, 1.1 } }
	)
	static(0, -0.60, "MISSILE", 0.035, "HUD_MWS_WARNING")
	label(0, -0.66, "F22_MWS_CLOCK", "%.0f CLOCK", 0.024, "HUD_MWS_WARNING", "CenterCenter")
	for _, v in ipairs({ { -1, "LOW" }, { 1, "HIGH" } }) do
		local n = gate("HUD_MWS_ELEVATION_" .. v[1], "F22_MWS_ELEVATION", v[1], "HUD_MWS_WARNING")
		static(0.18, -0.66, v[2], 0.024, n)
	end
	group('HUD_MWS_MEMORY', 0, 0, {'HUD_POWER', 'F22_MWS_COAST', 'F22_MWS_POWER'},
        {{'opacity_using_parameter', 0}, {'parameter_in_range', 1, .9, 1.1},
            {'parameter_in_range', 2, .9, 1.1}})
	local memory = 'HUD_MWS_MEMORY'
	static(-0.18, -0.66, "MEM", 0.021, memory)
    label(0, -0.66, 'F22_MWS_CLOCK', '%.0f CLOCK', 0.024, memory, 'CenterCenter')
	-- An airborne missile's support obligation survives weapon/master-mode changes.
	group(
		"HUD_MISSILE_SUPPORT",
		0,
		0,
		{ "HUD_POWER", "F22_FC_MISSILES" },
		{ { "opacity_using_parameter", 0 }, { "parameter_in_range", 1, 0.5, 8.5 } }
	)
	local lost = gate("HUD_MISSILE_SUPPORT_LOST", "F22_FC_SUPPORT_LOST", 1, "HUD_MISSILE_SUPPORT")
	static(0.60, -0.506, "MSL SUP LOST", 0.021, lost)
	group(
		"HUD_MISSILE_SUPPORT_COAST",
		0,
		0,
		{ "F22_FC_SUPPORT_DEGRADED", "F22_FC_SUPPORT_LOST" },
		{ { "parameter_in_range", 0, 0.9, 1.1 }, { "parameter_in_range", 1, -0.1, 0.1 } },
		"HUD_MISSILE_SUPPORT"
	)
	static(0.60, -0.506, "MSL SUP COAST", 0.021, "HUD_MISSILE_SUPPORT_COAST")
	for _, mode in ipairs({ 2, 3, 5 }) do
		local root = "HUD_ENGAGEMENT_" .. mode
		group(
			root,
			0,
			0,
			{ "HUD_MODE", "HUD_POWER" },
			{ { "parameter_in_range", 0, mode - 0.1, mode + 0.1 }, { "opacity_using_parameter", 1 } }
		)
		local target = gate(root .. "_TARGET", "F22_FC_TARGET_VALID", 1, root)
		label(0.72, -0.242, "F22_FC_RANGE_NM", "RNG %.1f", 0.021, target, "RightCenter")
		label(0.72, -0.280, "F22_FC_CLOSURE_KTS", "VC %+.0f", 0.021, target, "RightCenter")
		if mode ~= 5 then
			local prediction=gate(root..'_PREDICTION','F22_TOF_NATIVE_VALID',1,root)
            prediction=gate(root..'_PREDICTION_IDLE','F22_FC_TIMER_VALID',0,prediction)
            label(.72,-.462,'F22_TOF_SECONDS','TOF E%.0f',.021,prediction,'RightCenter')
			local dlz = gate(root .. "_DLZ", "F22_FC_DLZ_VALID", 1, root)
			local x, y = 0.40, -0.58
			line(x, y, x, y + 0.46, 0.003, dlz)
			line(x - 0.009, y + 0.46, x + 0.009, y + 0.46, 0.003, dlz)
			label(x, y + 0.495, "F22_FC_DLZ_SCALE_NM", "%.1f NM", 0.019, dlz, "CenterCenter")
			for _, s in ipairs({ { "MIN", -0.016 }, { "MAX", -0.026 }, { "TURN", -0.020 } }) do
				local name = root .. "_TICK_" .. s[1]
				local parent = s[1] == "TURN" and gate(root .. "_TURN_NATIVE", "F22_FC_DLZ_DYNAMIC", 1, dlz) or dlz
				group(
					name,
					x,
					y,
					{ "F22_FC_DLZ_" .. s[1] .. "_Y" },
					-- Values are page-layout distances; group() applies the optical scale.
					{ { "move_up_down_using_parameter", 0, 1 } },
					parent
				)
				line(s[2], 0, 0, 0, 0.003, name)
				if s[1] == "TURN" then
					line(s[2], -0.008, s[2], 0.008, 0.003, name)
				end
			end
			local pointer = root .. "_RANGE"
			group(
				pointer,
				x,
				y,
				{ "F22_FC_DLZ_RANGE_Y" },
				{ { "move_up_down_using_parameter", 0, 1 } },
				dlz
			)
			line(0.024, 0.012, 0, 0, 0.003, pointer)
			line(0, 0, 0.024, -0.012, 0.003, pointer)
			local wait = gate(root .. "_WAIT", "F22_FC_WAIT_VALID", 1, dlz)
			label(0.72, -0.326, "F22_FC_WAIT_SECONDS", "IN %.0f", 0.021, wait, "RightCenter")
			local close = gate(root .. "_CLOSE", "F22_FC_TOO_CLOSE", 1, dlz)
			static(0.61, -0.326, "MIN RNG", 0.021, close)
		end
		if mode == 3 then
            local timer=gate(root..'_TIMER','F22_FC_TIMER_VALID',1,root)
            timer=gate(root..'_IR_TIMER','F22_FC_TIMER_MODE',3,timer)
            local ttg=gate(root..'_TTG','F22_FC_TTG_VALID',1,timer)
            label(.72,-.424,'F22_FC_TTG','TTG E%.0f',.021,ttg,'RightCenter')
        elseif mode == 2 then
			local timer = gate(root .. "_TIMER", "F22_FC_TIMER_VALID", 1, root)
            timer=gate(root..'_RADAR_TIMER','F22_FC_TIMER_MODE',2,timer)
			local pre = gate(root .. "_PREACTIVE", "F22_FC_TIMER_ACTIVE", 0, timer)
			local act = gate(root .. "_ACT", "F22_FC_TTA_VALID", 1, pre)
			label(0.72, -0.424, "F22_FC_TTA", "ACT E%.0f", 0.021, act, "RightCenter")
			local unknown = gate(root .. "_ACT_UNKNOWN", "F22_FC_TTA_VALID", 0, pre)
			local inactive = gate(root .. "_NOT_EMITTING", "F22_FC_TIMER_EMITTING", 0, unknown)
			static(0.60, -0.424, "ACT --", 0.021, inactive)
			local emitting = gate(root .. "_EMITTING", "F22_FC_TIMER_EMITTING", 1, unknown)
			static(0.60, -0.424, "SIM EMIT", 0.021, emitting)
			local active = gate(root .. "_ACTIVE", "F22_FC_TIMER_ACTIVE", 1, timer)
			local ttg = gate(root .. "_TTG", "F22_FC_TTG_VALID", 1, active)
			label(0.72, -0.424, "F22_FC_TTG", "TTG E%.0f", 0.021, ttg, "RightCenter")
			label(0.72, -0.462, "F22_FC_TIMER_SEQUENCE", "MSL %.0f", 0.021, timer, "RightCenter")
		end
	end
end
