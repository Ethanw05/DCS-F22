-- GPL-3.0-or-later. Compact launch cues; existing HUD font and flight dials.
return function(api)
	local group, line, label, static = api.group, api.line, api.label, api.static
    local readouts = dofile(LockOn_Options.script_path..'HUD/readouts.lua')
    local envelope = readouts.envelope
    local envelope_gain = envelope.height/envelope.source_height
	-- RF warning states remain distinct from the optical MISSILE cue below.
	group('HUD_RF_WARNING',0,0,
		{'HUD_POWER','F22_DEF_OV_CURRENT','F22_RWR_POWER','F22_RWR_READY','F22_RWR_HUD_ENABLED'},
		{{'opacity_using_parameter',0},{'parameter_in_range',1,.9,1.1},
		 {'parameter_in_range',2,.9,1.1},{'parameter_in_range',3,.9,1.1},
		 {'parameter_in_range',4,.9,1.1}})
	for _, warning in ipairs({{2,'RADAR LOCK'},{3,'RWR LAUNCH'}})do
		local name='HUD_RF_WARNING_'..warning[1]
		group(name,0,0,{'F22_RWR_ALERT'},
			{{'parameter_in_range',0,warning[1]-.1,warning[1]+.1}},'HUD_RF_WARNING')
		static(0,-.43,warning[2],.027,name)
	end
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
	static(envelope.x,readouts.weapon_state,"MSL SUP LOST",0.021,lost,'RightCenter')
	group(
		"HUD_MISSILE_SUPPORT_COAST",
		0,
		0,
		{ "F22_FC_SUPPORT_DEGRADED", "F22_FC_SUPPORT_LOST" },
		{ { "parameter_in_range", 0, 0.9, 1.1 }, { "parameter_in_range", 1, -0.1, 0.1 } },
		"HUD_MISSILE_SUPPORT"
	)
	static(envelope.x,readouts.weapon_state,"MSL SUP COAST",0.021,"HUD_MISSILE_SUPPORT_COAST",'RightCenter')
	for _, mode in ipairs({ 2, 3, 4, 5, 6 }) do
		local root = "HUD_ENGAGEMENT_" .. mode
		group(
			root,
			0,
			0,
			{ "HUD_MODE", "HUD_POWER" },
			{ { "parameter_in_range", 0, mode - 0.1, mode + 0.1 }, { "opacity_using_parameter", 1 } }
		)
		local target = gate(root .. "_TARGET", "F22_FC_TARGET_VALID", 1, root)
		label(readouts.right,readouts.target_range,"F22_FC_RANGE_NM","RNG %.1f",0.021,target,"RightCenter")
		label(readouts.right,readouts.closing_velocity,"F22_FC_CLOSURE_KTS","VC %+.0f",0.021,target,"RightCenter")
		if mode == 2 or mode == 3 then
			local dlz = gate(root .. "_DLZ", "F22_FC_DLZ_VALID", 1, root)
			local x, y = envelope.x, envelope.bottom
			line(x,y,x,y+envelope.height,0.003,dlz)
			line(x-.009,y+envelope.height,x+.009,y+envelope.height,0.003,dlz)
			label(x,y+envelope.height+.035*envelope_gain,"F22_FC_DLZ_SCALE_NM","%.1f NM",0.019,dlz,"CenterCenter")
			for _, s in ipairs({ { "MIN", -0.016 }, { "MAX", -0.026 }, { "TURN", -0.020 } }) do
				local name = root .. "_TICK_" .. s[1]
				local parent = s[1] == "TURN" and gate(root .. "_TURN_NATIVE", "F22_FC_DLZ_DYNAMIC", 1, dlz) or dlz
				group(
					name,
					x,
					y,
					{ "F22_FC_DLZ_" .. s[1] .. "_Y" },
					-- The producer retains its .46-unit range mapping; resize presentation only.
					{ { "move_up_down_using_parameter", 0, envelope_gain } },
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
				{ { "move_up_down_using_parameter", 0, envelope_gain } },
				dlz
			)
			line(0.024, 0.012, 0, 0, 0.003, pointer)
			line(0, 0, 0.024, -0.012, 0.003, pointer)
			local wait = gate(root .. "_WAIT", "F22_FC_WAIT_VALID", 1, dlz)
			label(envelope.x,readouts.weapon_timer,"F22_FC_WAIT_SECONDS","IN %.0f",0.021,wait,"RightCenter")
			local close = gate(root .. "_CLOSE", "F22_FC_TOO_CLOSE", 1, dlz)
			static(envelope.x,readouts.weapon_timer,"MIN RNG",0.021,close,'RightCenter')
		end
		if mode == 3 then
            local timer=gate(root..'_TIMER','F22_FC_TIMER_VALID',1,root)
            timer=gate(root..'_IR_TIMER','F22_FC_TIMER_MODE',3,timer)
            local ttg=gate(root..'_TTG','F22_FC_TTG_VALID',1,timer)
            label(readouts.right,readouts.weapon_timer,'F22_FC_TTG','TTG E%.0f',.021,ttg,'RightCenter')
        elseif mode == 2 then
			local timer = gate(root .. "_TIMER", "F22_FC_TIMER_VALID", 1, root)
            timer=gate(root..'_RADAR_TIMER','F22_FC_TIMER_MODE',2,timer)
			local pre = gate(root .. "_PREACTIVE", "F22_FC_TIMER_ACTIVE", 0, timer)
			local act = gate(root .. "_ACT", "F22_FC_TTA_VALID", 1, pre)
			label(readouts.right,readouts.weapon_state,"F22_FC_TTA","ACT E%.0f",0.021,act,"RightCenter")
			local unknown = gate(root .. "_ACT_UNKNOWN", "F22_FC_TTA_VALID", 0, pre)
			local inactive = gate(root .. "_NOT_EMITTING", "F22_FC_TIMER_EMITTING", 0, unknown)
			static(readouts.right,readouts.weapon_state,"ACT --",0.021,inactive,'RightCenter')
			local emitting = gate(root .. "_EMITTING", "F22_FC_TIMER_EMITTING", 1, unknown)
			static(readouts.right,readouts.weapon_state,"SIM EMIT",0.021,emitting,'RightCenter')
			local active = gate(root .. "_ACTIVE", "F22_FC_TIMER_ACTIVE", 1, timer)
			local ttg = gate(root .. "_TTG", "F22_FC_TTG_VALID", 1, active)
			label(readouts.right,readouts.weapon_state,"F22_FC_TTG","TTG E%.0f",0.021,ttg,"RightCenter")
			label(readouts.right,readouts.weapon_timer,"F22_FC_TIMER_SEQUENCE","MSL %.0f",0.021,timer,"RightCenter")
		end
	end
end
