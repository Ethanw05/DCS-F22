-- GPL-3.0-or-later. Shared original bearing-only threat symbology.
return function(api, cx, cy, scale, parent, compact)
	local line, text, group = api.line, api.text, api.group
	local symbols = dofile(LockOn_Options.script_path .. "Systems/RWR_Computer.lua").symbols
	local function segment(x, y, u, v, c, p)
		line(cx + x * scale, cy + y * scale, cx + u * scale, cy + v * scale, c, p or parent)
	end
	for _, r in ipairs(compact and { 0.9 } or { 0.4, 0.65, 0.9 }) do
		for deg = 0, 355, 5 do
			local a, b = math.rad(deg), math.rad(deg + 5)
			segment(r * math.sin(a), r * math.cos(a), r * math.sin(b), r * math.cos(b), "blue")
		end
	end
	segment(-0.025, 0, 0.025, 0, "white")
	segment(0, -0.025, 0, 0.025, "white")
	for _, az in ipairs({ 0, 90, 180, 270 }) do
		local a = math.rad(az)
		segment(0.9 * math.sin(a), 0.9 * math.cos(a), 0.99 * math.sin(a), 0.99 * math.cos(a), "white")
	end
	for i = 1, 16 do
		local p = string.format("F22_EW_%02d_", i)
		local name = parent .. "_EMITTER_" .. i
		group(
			name,
			{ p .. "X", p .. "Y", p .. "VALID", "F22_RWR_POWER", "F22_RWR_READY" },
			{
				{ "move_left_right_using_parameter", 0, scale },
				{ "move_up_down_using_parameter", 1, scale },
				{ "parameter_in_range", 2, 0.9, 1.1 },
				{ "parameter_in_range", 3, 0.9, 1.1 },
				{ "parameter_in_range", 4, 0.9, 1.1 },
			},
			parent,
			cx,
			cy
		)
		for signal, color in ipairs({ "yellow", "red", "red" }) do
			local sym = name .. "_STATE_" .. signal
			group(sym, { p .. "SIGNAL" }, { { "parameter_in_range", 0, signal - 0.1, signal + 0.1 } }, name)
			local sz = compact and 0.0027 or 0.0057
			-- Numeric-only formatter ABI. Empty param handles start as numbers;
			-- passing those to a %s format can crash DCS's native text controller.
			for _, id in ipairs({ { -1, "yellow" }, { 0, "red" }, { 1, "green" } }) do
				local identity = sym .. "_ID_" .. id[1]
				group(identity, { p .. "AFFILIATION" }, { { "parameter_in_range", 0, id[1] - 0.1, id[1] + 0.1 } }, sym)
				group(
					identity .. "_NUMBER",
					{ p .. "LABEL_CODE" },
					{ { "parameter_in_range", 0, -0.1, 99.9 } },
					identity
				)
				text("%.0f", 0, 0, p .. "LABEL_CODE", id[2], identity .. "_NUMBER", sz)
				for code, label in ipairs(symbols) do
					local label_parent = identity .. "_SYMBOL_" .. code
					group(
						label_parent,
						{ p .. "LABEL_CODE" },
						{ { "parameter_in_range", 0, 98.9 + code, 99.1 + code } },
						identity
					)
					text(label, 0, 0, nil, id[2], label_parent, sz)
				end
			end
			if signal > 1 then
				local r = compact and 0.026 or 0.052
				line(-r, -r, r, -r, color, sym)
				line(r, -r, r, r, color, sym)
				line(r, r, -r, r, color, sym)
				line(-r, r, -r, -r, color, sym)
				if signal == 3 then
					text("L", 0, r * 1.6, nil, "red", sym, sz)
				end
			end
			group(sym .. "_COAST", { p .. "COAST" }, { { "parameter_in_range", 0, 0.9, 1.1 } }, sym)
			text("C", compact and 0.025 or 0.065, 0, nil, color, sym .. "_COAST", sz * 0.65)
		end
	end
	dofile(LockOn_Options.script_path .. "Systems/MWS_Indicator.lua")(api, cx, cy, scale, parent, compact)
end
