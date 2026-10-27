"""Settings units/STD and real native readback validity through the altitude owner."""
from test_display_startup import runtime
lua=runtime()
lua.execute('''
local S=dofile(SCRIPT_ROOT..'Systems/Altitude_Settings.lua')
local s=S.new();s.buffer='2992';assert(s:commit() and math.abs(s.qnh-759.968)<1e-6)
s.buffer='9999';assert(not s:commit()and math.abs(s.qnh-759.968)<1e-6)
s.buffer='';s:toggle_standard();assert(s:pressure()==760)
s:toggle_standard();assert(math.abs(s:pressure()-759.968)<1e-6)
s.units=1;s.buffer='1013';assert(s:commit() and math.abs(s.qnh-759.812484879)<1e-6)
s.field=2;s.buffer='25001';assert(not s:commit())
s.field=3;s.buffer='5001';assert(not s:commit())
''')
lua=runtime()
lua.execute('''
local time=10;function get_model_time()return time end
function get_base_data()return {getRadarAltitude=function()return 100 end}end
dofile(SCRIPT_ROOT..'Systems/Altitude_System.lua');post_initialize()
local function p(n,v)get_param_handle(n):set(v)end
local function g(n)return get_param_handle(n):get()end
p('MAIN_POWER',1);p('EFM_HUD_VALID',1);update()
assert(g('F22_ALT_BARO_VALID')==0 and g('F22_ALT_PRESSURE_REQUEST_VALID')==0,'no fake barometric solution')
p('F22_ALTIMETER_NATIVE_READY',1);p('F22_ALTIMETER_NATIVE_VALID',1);p('F22_ALTIMETER_RESULT_TIME',10)
p('F22_ALT_ACTUAL_PRESSURE_MMHG',745);p('F22_ALT_NATIVE_BARO_M',1000);update()
assert(g('F22_ALT_PRESSURE_MMHG')==745,'adopt actual mission pressure, do not overwrite it at startup')
assert(g('F22_ALT_DISPLAY_TEXT'):find('29.33')and g('F22_ALT_BARO_VALID')==1 and math.abs(g('F22_ALT_BARO_FT')-3280.839895)<1e-6)
SetCommand(11020,27.375);update();assert(g('F22_ALT_STD')==1 and g('F22_ALT_PRESSURE_MMHG')==760)
SetCommand(11020,1);update();assert(g('F22_ALT_PRESSURE_MMHG')==745)
SetCommand(11025,1500);SetCommand(11026,500);update();assert(g('F22_ALT_BARO_FLOOR')==1500 and g('F22_ALT_RADAR_FLOOR')==500)
time=11;update();assert(g('F22_ALT_BARO_VALID')==0,'stale native reading rejected')
p('MAIN_POWER',0);update();assert(g('F22_ALT_RADAR_VALID')==0)
''')
print('Altimetry: pressure conversion, STD restore, native mission-setting adoption, stale/power gates and independent floors PASS')
