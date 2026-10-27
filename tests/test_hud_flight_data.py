"""Physical invariants and device lifecycle checks for independent HUD data."""
from pathlib import Path
import math
import runpy
from lupa.lua51 import LuaRuntime

ROOT=Path(__file__).resolve().parents[1]
lua=LuaRuntime(unpack_returned_tuples=True)
m=lua.execute((ROOT/'Cockpit/Scripts/Systems/HUD_FlightMath.lua').read_text())
for heading in (0,math.pi/2,math.pi,3*math.pi/2):
    az,el=m.project(100*math.cos(heading),100*math.sin(heading),0,heading,0,0)
    assert abs(az)<1e-12 and abs(el)<1e-12
az,el=m.project(100,0,0,0,math.radians(10),0)
assert abs(el+math.radians(10))<1e-12 and abs(az)<1e-12
az,el=m.project(100,10,0,0,0,0)
assert abs(az-math.atan(0.1))<1e-12 and abs(el)<1e-12
assert m.project(0,0,0,0,0,0) is None
assert m.project(-100,0,0,0,0,0) is None
assert m.project(float('nan'),0,0,0,0,0) is None
for mach in (0,0.1,0.7,0.99,1,1.01,1.5,2.5):
    assert abs(m.cas(mach*340.293988,340.293988,101325)-mach*340.293988)<1e-8
assert abs(m.pitot_ratio(1-1e-7)-m.pitot_ratio(1+1e-7))<2e-6
assert m.cas(200,300,0) is None
assert m.cas(200,300,50000)<m.cas(200,300,100000)
assert m.ttg(18520,100)=='00:03:05'
assert m.ttg(18520,0) is None
print('HUD geometry: cardinal headings, pitch/velocity separation, crosswind, invalids OK')
print('HUD air data: sea-level identity through sonic transition, pressure response, TTG OK')

runtime=runpy.run_path(str(ROOT/'tests/test_display_startup.py'))['runtime']
lua=runtime()
lua.execute('''
    pitch=math.rad(10);roll=0;aoa=10;g=1;gear=1;wow=0
    function get_base_data() return {
        getPitch=function() return pitch end,getRoll=function() return roll end,
        getHeading=function() return 0 end,getAngleOfSlide=function() return 0.02 end,
        getVerticalAcceleration=function() return g end,
        getAngleOfAttack=function() return math.rad(aoa) end,
        getVerticalVelocity=function() return 0 end,
        getWOW_NoseLandingGear=function() return wow end,
        getBarometricAltitude=function() return 1000 end,
    } end
    function get_aircraft_draw_argument_value(_) return gear end
    local values={EFM_HUD_VALID=1,EFM_HUD_VN=100,EFM_HUD_VE=0,EFM_HUD_VU=0,
        EFM_HUD_WN=0,EFM_HUD_WE=10,EFM_HUD_TAS=100.5,
        EFM_HUD_SOUND=340.293988,EFM_HUD_PRESSURE=101325,F22_ALT_BARO_VALID=1,F22_ALT_BARO_FT=3280.839895}
    for k,v in pairs(values) do get_param_handle(k):set(v) end
    dofile(SCRIPT_ROOT..'Systems/HUD_Flight_Data.lua')
    post_initialize();update()
    assert(handles.HUD_FPM_VALID:get()==1)
    assert(math.abs(handles.HUD_FPM_Y_RAD:get()+math.rad(10))<1e-9)
    assert(handles.HUD_APPROACH_LOW:get()==1)
    aoa=12;update();assert(handles.HUD_APPROACH_LOW:get()==0 and handles.HUD_APPROACH_HIGH:get()==0)
    aoa=14;update();assert(handles.HUD_APPROACH_HIGH:get()==1)
    gear=0;update();assert(handles.HUD_APPROACH_HIGH:get()==0)
    g=5;update();g=1;update();assert(handles.HUD_G_MAX:get()==5)
    post_initialize();update();assert(handles.HUD_G_MAX:get()==1)
    roll=0.4;update();assert(handles.HUD_BANK_RAD:get()==0.4)
    assert(math.abs(handles.HUD_WIND_DEG:get()-270)<1e-9)
    assert(handles.HUD_IAS_POINTER:get()<=0 and handles.HUD_ALT_POINTER:get()<=0 and handles.HUD_ALT_VALID:get()==1)
    get_param_handle('EFM_HUD_SOUND'):set(0);update()
    assert(handles.HUD_ALT_VALID:get()==1 and handles.HUD_AIRDATA_VALID:get()==0,'CAS failure hid independent valid pressure altitude')
    get_param_handle('EFM_HUD_SOUND'):set(340.293988);update()
    get_param_handle('F22_ALT_BARO_VALID'):set(0);update()
    assert(handles.HUD_ALT_VALID:get()==0 and handles.HUD_AIRDATA_VALID:get()==1,'invalid pressure hides altitude only; CAS is independent')
    get_param_handle('F22_ALT_BARO_VALID'):set(1);update()
    pitch=math.rad(8);roll=math.rad(25);update()
    assert(handles.HUD_LADDER_2:get()==1, '10-degree rung was hidden above the old narrow band')
    assert(handles.HUD_LADDER_1:get()==1)
    assert(handles.HUD_HORIZON_VISIBLE:get()==1)
    assert(handles['HUD_LADDER_-1']:get()==1, 'negative rung was hidden below the old narrow band')
    assert(handles.HUD_LADDER_3:get()==0, 'keep the heading band free of ladder labels')
    handles.EFM_HUD_VALID:set(0);update()
    assert(handles.HUD_FPM_VALID:get()==0 and handles.HUD_AIRDATA_VALID:get()==0)
''')
print('HUD device: gear/AoA gating, peak-G reset, bank, wind, clockwise needles, missing bridge OK')
lua.execute('''
    get_param_handle('MAIN_POWER'):set(1);handles.EFM_HUD_VALID:set(1)
    pitch=0;roll=0;handles.EFM_HUD_VN:set(100);handles.EFM_HUD_VE:set(10);update()
    assert(handles.HUD_FPM_COMPUTED_VALID:get()==1 and handles.HUD_FPM_OFFGLASS:get()==0)
    assert(handles.HUD_FPM_X_RAD:get()>0)
    SetCommand(11840,1);update()
    assert(handles.HUD_FPM_CAGED:get()==1 and handles.HUD_FPM_X_RAD:get()==0)
    assert(handles.HUD_FPM_GHOST_VALID:get()==1 and handles.HUD_FPM_GHOST_X:get()>0)
    SetCommand(11840,1);handles.EFM_HUD_VE:set(50);update()
    assert(handles.HUD_FPM_COMPUTED_VALID:get()==1 and handles.HUD_FPM_VALID:get()==0)
    assert(handles.HUD_FPM_OFFGLASS:get()==1,'clipping became sensor failure')
    SetCommand(11840,1);update()
    assert(handles.HUD_FPM_VALID:get()==1 and handles.HUD_FPM_GHOST_VALID:get()==0)
    handles.EFM_HUD_VALID:set(0);update()
    assert(handles.HUD_FPM_COMPUTED_VALID:get()==0 and handles.HUD_FPM_OFFGLASS:get()==0)
    handles.EFM_HUD_VALID:set(1);handles.EFM_HUD_SOUND:set(340.293988)
    handles.EFM_HUD_TAS:set(200);get_param_handle('F22_ALT_BARO_FT'):set(12000);update()
    get_param_handle('F22_ALT_BARO_FT'):set(9000);handles.EFM_HUD_TAS:set(100);update()
    assert(get_param_handle('HUD_QNH_VISIBLE'):get()==1,'high/fast-to-low/slow pressure redisplay missing')
    handles.EFM_HUD_SOUND:set(0);update()
    assert(get_param_handle('HUD_QNH_VISIBLE'):get()==0,'unavailable airspeed preserved approach redisplay')
''')
print('NAV FPM: computed/visible/off-glass distinction, lateral cage and uncaged ghost PASS')
