-- GPL-3.0-or-later. TSD layers over the existing common radar map.
return function(api, _layout, gain, root)
	local group, line, text = api.group, api.line, api.text
	local identity=dofile(LockOn_Options.script_path..'Systems/Tactical_Identity.lua')
	local function offboard_warnings(prefix,parent)
		group(parent..'_RF_ONLY',{prefix..'MWS_CURRENT'},{{'parameter_in_range',0,-.1,.1}},parent)
		for signal,label in pairs({[2]='LOCK',[3]='LAUNCH'})do
			local warning=parent..'_RF_WARNING_'..signal
			group(warning,{prefix..'RF_SIGNAL'},{{'parameter_in_range',0,signal-.1,signal+.1}},parent..'_RF_ONLY')
			text(label,0,.08,nil,signal==3 and 'red' or 'yellow',warning,.0028)
		end
		group(parent..'_MWS',{prefix..'MWS_CURRENT'},{{'parameter_in_range',0,.9,1.1}},parent)
		text('MISSILE',0,.08,nil,'red',parent..'_MWS',.0028)
	end
	group("F22_TSD_OVERLAY", { "F22_TSD_VALID" }, { { "parameter_in_range", 0, 0.9, 1.1 } }, root)
	local parent = "F22_TSD_OVERLAY"
    dofile(LockOn_Options.script_path..'Systems/ECM_Indicator.lua')(
        api,.68,-.82,parent,'F22_TSD_OWN_ECM',.0033)
	-- Both pictures are published by the RWR owner. Its independent MFD
	-- watchdog also withdraws these estimates if that owner stops updating.
	group("F22_TSD_GEO_CURRENT", { "F22_DEF_OV_CURRENT" }, { { "parameter_in_range", 0, .9, 1.1 } }, parent)
	for i=1,24 do
		local p=string.format('F22_TSD_DL_%02d_',i)
		local name='F22_TSD_DL_'..i
		group(name,{p..'X',p..'Y',p..'VALID'},{{'move_left_right_using_parameter',0,1},
			{'move_up_down_using_parameter',1,1},{'parameter_in_range',2,.9,1.1}},'F22_TSD_GEO_CURRENT')
		for _,style in ipairs(identity.styles)do
			local colored=name..'_ID_'..style[1]
			group(colored,{p..'AFFILIATION'},{{'parameter_in_range',0,style[1]-.1,style[1]+.1}},name)
			line(-.022,.022,.022,.022,style[2],colored);line(.022,.022,.022,-.022,style[2],colored)
			line(.022,-.022,-.022,-.022,style[2],colored);line(-.022,-.022,-.022,.022,style[2],colored)
			for link,label in ipairs({'IFDL','L16'})do
				local kind=colored..'_LINK_'..link
				group(kind,{p..'LINK'},{{'parameter_in_range',0,link-.1,link+.1}},colored)
				text(label,.065,.025,nil,style[2],kind,.0029)
			end
		end
		group(name..'_COAST',{p..'COAST'},{{'parameter_in_range',0,.9,1.1}},name)
		text('C',.03,-.027,nil,'yellow',name..'_COAST',.0028)
		group(name..'_IRST',{p..'IRST'},{{'parameter_in_range',0,.9,1.1}},name)
		text('IR',-.04,-.04,nil,'white',name..'_IRST',.0028)
		group(name..'_CONFLICT',{p..'IDENTITY_CONFLICT'},{{'parameter_in_range',0,.9,1.1}},name)
		text('ID?',.065,-.04,nil,'yellow',name..'_CONFLICT',.0028)
		group(name..'_RF',{p..'RF_SIGNAL'},{{'parameter_in_range',0,.9,3.1}},name)
		text('RF',-.04,.04,nil,'white',name..'_RF',.0028)
		offboard_warnings(p,name)
        group(name..'_SA',{p..'SA_SELECTED'},{{'parameter_in_range',0,.9,1.1}},name)
        for _,side in ipairs({-1,1})do
            line(side*.04,-.04,side*.04,.04,'white',name..'_SA')
            line(side*.04,.04,side*.02,.04,'white',name..'_SA')
            line(side*.04,-.04,side*.02,-.04,'white',name..'_SA')
        end
		group(name..'_OFFSCALE',{p..'OFFSCALE',p..'ROT'},{{'parameter_in_range',0,.9,1.1},{'rotate_using_parameter',1,1}},name)
		line(-.025,.035,0,.07,'white',name..'_OFFSCALE');line(0,.07,.025,.035,'white',name..'_OFFSCALE')
	end
	for i=1,8 do
		local p=string.format('F22_TSD_GEO_%02d_',i)
		local name='F22_TSD_GEO_'..i
		group(name,{p..'X',p..'Y',p..'VALID'},{{'move_left_right_using_parameter',0,1},
			{'move_up_down_using_parameter',1,1},{'parameter_in_range',2,.9,1.1}},'F22_TSD_GEO_CURRENT')
		for _,style in ipairs(identity.styles)do
			local colored=name..'_ID_'..style[1]
			group(colored,{p..'AFFILIATION'},{{'parameter_in_range',0,style[1]-.1,style[1]+.1}},name)
			line(0,.022,.022,0,style[2],colored);line(.022,0,0,-.022,style[2],colored)
			line(0,-.022,-.022,0,style[2],colored);line(-.022,0,0,.022,style[2],colored)
			text('RF EST',.065,.025,nil,style[2],colored,.0029)
		end
		for _,axis in ipairs({'H','V'})do
			local e=CreateElement('ceSimpleLineObject')
			e.material=api.materials.yellow;e.vertices={{0,0},{.001,0}};e.primitivetype='lines';e.width=.0015*gain
			local q=p..axis..'_'
			e.element_params={q..'X1',q..'Y1',q..'X2',q..'Y2',q..'VALID'}
			e.controllers={{'line_object_set_point_using_parameters',0,0,1,gain,gain},
				{'line_object_set_point_using_parameters',1,2,3,gain,gain},{'parameter_in_range',4,.9,1.1}}
			api.add(e,name..'_ERROR_'..axis,'F22_TSD_GEO_CURRENT')
		end
	end
	text("TSD", -0.72, 0.78, nil, "blue", parent, 0.0042)
    group('F22_DONOR_DETAIL',{'F22_DONOR_VALID'},{{'parameter_in_range',0,.9,1.1}},parent)
    text('SA %.0f',-.70,.70,'F22_DONOR_SOURCE','white','F22_DONOR_DETAIL',.0028)
    text('RX %.1fS',-.70,.64,'F22_DONOR_RECEIVE_AGE','white','F22_DONOR_DETAIL',.0028)
    group('F22_DONOR_UNKNOWN_AGE',{'F22_DONOR_OBSERVATION_KNOWN'},
        {{'parameter_in_range',0,-.1,.1}},'F22_DONOR_DETAIL')
    text('OBS AGE ?',-.70,.58,nil,'yellow','F22_DONOR_UNKNOWN_AGE',.0028)
    group('F22_DONOR_KNOWN_AGE',{'F22_DONOR_OBSERVATION_KNOWN'},
        {{'parameter_in_range',0,.9,1.1}},'F22_DONOR_DETAIL')
    text('OBS %.1fS',-.70,.58,'F22_DONOR_OBSERVATION_AGE','white','F22_DONOR_KNOWN_AGE',.0028)
    for state,label in ipairs({'CUE QUEUED','CUE SEARCH'})do
        local name='F22_DONOR_CUE_'..state
        group(name,{'F22_RADAR_DONOR_STATUS'},{{'parameter_in_range',0,state-.1,state+.1}},'F22_DONOR_DETAIL')
        text(label,-.70,.52,nil,'white',name,.0028)
    end
	-- Navigation remains its own producer; these are reprojected real route
	-- segments, never a second route computer or a mission-object sensor.
	for i = 1, 32 do
		local p = string.format("F22_TSD_NAV_LEG_%02d_", i)
		local e = CreateElement("ceSimpleLineObject")
		e.material = api.materials.blue
		e.vertices = { { 0, 0 }, { 0.001, 0 } }
		e.primitivetype = "lines"
		e.width = 0.002 * gain
		e.element_params = { p .. "X1", p .. "Y1", p .. "X2", p .. "Y2", p .. "VALID" }
		e.controllers = {
			{ "line_object_set_point_using_parameters", 0, 0, 1, gain, gain },
			{ "line_object_set_point_using_parameters", 1, 2, 3, gain, gain },
			{ "parameter_in_range", 4, 0.9, 1.1 },
		}
		api.add(e, "F22_TSD_ROUTE_" .. i, parent)
	end
	for i, entry in ipairs({ { "RADAR", "R" }, { "RF", "RF" }, { "OPTICAL", "MSL" }, { "IRST", "IR" } }) do
		local name = "F22_TSD_SELECTED_" .. entry[1]
		group(name, { name }, { { "parameter_in_range", 0, 0.9, 1.1 } }, parent)
		text(entry[2], 0.49 + i * 0.10, 0.79, nil, "blue", name, 0.0033)
	end
end
