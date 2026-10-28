"""Engine indications consume qualified achieved values, never native substitutes."""
from cockpit_fixture import runtime, engine_frame

sample = dict(rpm=67, temperature=450, oil=180.9, nozzle=100, flow=.126, hydraulic=3950)
for birth in ('GROUND_HOT', 'AIR_HOT', 'GROUND_COLD'):
    sim = runtime()
    sim.globals().LockOn_Options.init_conditions.birth_place = birth
    sim.execute('''
        local original=get_base_data
        function get_base_data()
            local base=original()
            for _,name in ipairs({'getEngineLeftRPM','getEngineRightRPM',
                'getEngineLeftTemperatureBeforeTurbine','getEngineRightTemperatureBeforeTurbine',
                'getEngineLeftFuelConsumption','getEngineRightFuelConsumption'}) do
                base[name]=function() error('owned engine reading substituted from base data') end
            end
            return base
        end
        dofile(SCRIPT_ROOT..'Systems/Avionics.lua'); post_initialize(); update()
        avionics_update=update
        assert(handles.F22_ENGINE_L_RPM_TEXT==nil)
        assert(handles.F22_ENGINE_L_RPM_VALID:get()==0)
    ''')
    engine_frame(sim, left=sample, right=sample)
    sim.execute('''
        avionics_update()
        assert(handles.RPM_L:get()==67 and handles.RPM_R:get()==67)
        assert(handles.OIL_L:get()==180.9 and handles.L_HYD_VALUE:get()==3950)
        assert(handles.F22_ENGINE_L_RPM_VALID:get()==1)
        assert(math.abs(handles.L_FF_VALUE:get()-.126*2.20462*3600)<1e-8)
        dofile(SCRIPT_ROOT..'Systems/MFD_System.lua'); post_initialize()
        draws[208]=1
        for index=1,2000 do update() end
        assert(handles.OIL_L:get()==180.9 and handles.R_HYD_VALUE:get()==3950)
        -- Neither rotor stop nor a warning/failure flag may integrate pressure.
        handles.EFM_ENGINE_LEFT_RPM_PCT:set(0)
        handles.EFM_ENGINE_LEFT_OIL_PSI:set(220)
        handles.R_HYD_FAILURE=get_param_handle('R_HYD_FAILURE'); handles.R_HYD_FAILURE:set(1)
        avionics_update(); update()
        assert(handles.OIL_L:get()==220 and handles.R_HYD_VALUE:get()==3950)
        assert(handles.L_OIL_COLOR:get()==0)
        handles.EFM_HYD_RIGHT_PSI:set(0); avionics_update()
        assert(handles.R_HYD_VALUE:get()==0 and handles.R_HYD_COLOR:get()==1)
        -- Corrupt one metric only: other engine/circuit readings survive.
        handles.EFM_ENGINE_LEFT_TEMP_C:set(0/0); avionics_update()
        assert(handles.F22_ENGINE_L_EGT_VALID:get()==0 and handles.EGT_L:get()==450)
        assert(handles.F22_ENGINE_R_EGT_VALID:get()==1 and handles.F22_ENGINE_L_OIL_VALID:get()==1)
        handles.EFM_POWER_OWNER:set(0); avionics_update()
        assert(handles.F22_ENGINE_L_RPM_VALID:get()==0 and handles.F22_ENGINE_R_HYD_VALID:get()==0)
    ''')
    engine_frame(sim, left=sample, right=sample, generation=2, stamp=0)
    sim.globals().avionics_update()
    assert sim.globals().handles.F22_ENGINE_L_RPM_VALID.value == 1
    print('Coherent engine indication owner, invalid/recovery and no duplicate pressure:', birth, 'PASS')

# Start and detent commands reach the actual physical guard, without a second
# admission decision based on unavailable host RPM or APU display state.
sim = runtime()
sim.globals().LockOn_Options.init_conditions.birth_place = 'GROUND_COLD'
sim.execute('''
    dofile(SCRIPT_ROOT..'Systems/Engine_System.lua'); post_initialize()
    actions={}
    SetCommand(10028,0); SetCommand(10029,0)
    SetCommand(10028,1); SetCommand(10028,1); SetCommand(10029,1)
    SetCommand(10028,0); SetCommand(10028,0)
    local starts,stops=0,0
    for _,action in ipairs(actions) do
        if action[1]==Keys.LeftEngineStart or action[1]==Keys.RightEngineStart then
            starts=starts+1; assert(action[2]==1)
        elseif action[1]==Keys.LeftEngineStop or action[1]==Keys.RightEngineStop then
            stops=stops+1
        end
    end
    assert(starts==2 and stops==1)
    actions={}; SetCommand(device_commands.Button_9,0)
    assert(#actions==0,'start-button release dispatched another start')
    SetCommand(device_commands.Button_9,1)
    assert(#actions==1 and actions[1][1]==Keys.LeftEngineStart)
    actions={}; SetCommand(Keys.LeftEngineStart,1)
    assert(#actions==0,'global engine command dispatched itself recursively')
    update()
    assert(handles.L_THROTTLE_CUT:get()==1 and handles.R_THROTTLE_CUT:get()==1)
''')
print('Engine request transport: current EFM admission, absolute detents, neutral release and no redispatch PASS')
