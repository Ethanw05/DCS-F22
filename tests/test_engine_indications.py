"""Regression for 0.67 raw RPM causing oil=2 and hydraulic pressure decay."""
from pathlib import Path
import runpy
ROOT=Path(__file__).resolve().parents[1]
runtime=runpy.run_path(str(ROOT/'tests/test_display_startup.py'))['runtime']

for birth in ('GROUND_HOT','AIR_HOT','GROUND_COLD'):
    sim=runtime()
    sim.globals().LockOn_Options.init_conditions.birth_place=birth
    sim.execute('''
        function get_aircraft_property(_) return 0 end
        -- Reproduce the host's fraction-scale raw channel.
        local original=get_base_data
        function get_base_data()
            local data=original()
            data.getEngineLeftRPM=function() return 0.67 end
            data.getEngineRightRPM=function() return 0.67 end
            return data
        end
        get_param_handle('EFM_ENGINE_VALID'):set(1)
        get_param_handle('EFM_ENGINE_LEFT_RPM_PCT'):set(67)
        get_param_handle('EFM_ENGINE_RIGHT_RPM_PCT'):set(67)
        dofile(SCRIPT_ROOT..'Systems/Avionics.lua')
        post_initialize(); update(); avionics_update=update
        assert(handles.RPM_L:get()==67 and handles.RPM_R:get()==67)
        dofile(SCRIPT_ROOT..'Systems/MFD_System.lua')
        post_initialize()
        draws[208]=1 -- Low-pressure annunciator must not disable recovery.
        for i=1,2000 do update() end
        assert(math.abs(handles.OIL_L:get()-180.9)<1e-8)
        assert(math.abs(handles.OIL_R:get()-180.9)<1e-8)
        assert(handles.L_HYD_VALUE:get()==3950 and handles.R_HYD_VALUE:get()==3950)
        assert(handles.L_OIL_COLOR:get()==0 and handles.R_OIL_COLOR:get()==0)
        assert(handles.L_HYD_COLOR:get()==0 and handles.R_HYD_COLOR:get()==0)
        handles.EFM_ENGINE_LEFT_RPM_PCT:set(0)
        for i=1,2000 do update() end
        assert(handles.OIL_L:get()==0 and handles.L_HYD_VALUE:get()==0)
        assert(handles.R_HYD_VALUE:get()==3950)
        assert(handles.L_OIL_COLOR:get()==1 and handles.L_HYD_COLOR:get()==1)
        handles.EFM_ENGINE_LEFT_RPM_PCT:set(67)
        get_param_handle('R_HYD_FAILURE'):set(1)
        for i=1,2000 do update() end
        assert(handles.L_HYD_VALUE:get()==3950 and handles.R_HYD_VALUE:get()==0)
    ''')
    print('Engine percent, hot/cold pressure, recovery and independent failure:',birth,'OK')
