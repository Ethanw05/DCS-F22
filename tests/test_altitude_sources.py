"""Actual ALT/UFC/HUD owners: explicit source choice, fallback and surviving standby."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
fixture = ROOT / 'tests/test_display_startup.py'
scope = {'__file__': str(fixture)}
exec(compile(fixture.read_text().split('\nfor page in ', 1)[0], str(fixture), 'exec'), scope)
lua = scope['runtime']()
lua.execute(r'''
local function get(key)return get_param_handle(key):get()end
local function put(key,value)get_param_handle(key):set(value)end
local now,radar=100,100
function get_model_time()return now end
function get_base_data()return setmetatable({getRadarAltitude=function()return radar end},
 {__index=function()return function()return 0 end end})end
function get_aircraft_draw_argument_value()return 0 end
put('MAIN_POWER',1);put('EFM_HUD_VALID',1)
put('F22_ALTIMETER_NATIVE_READY',1);put('F22_ALTIMETER_NATIVE_VALID',1)
put('F22_ALTIMETER_RESULT_TIME',now);put('F22_ALT_NATIVE_BARO_M',1000)
put('F22_ALT_STANDBY_NATIVE_VALID',1);put('F22_ALT_STANDBY_NATIVE_STAMP',now)
put('F22_ALT_STANDBY_NATIVE_M',1100)
dofile(SCRIPT_ROOT..'Systems/Altitude_System.lua');post_initialize()
local altitude_update,altitude_command=update,SetCommand
altitude_update()
local ui=dofile(SCRIPT_ROOT..'Systems/UFC_Controller.lua').new(get,put,function(owner,c,v)
 assert(owner=='ALTITUDE_SYSTEM');altitude_command(c,v)
end)
ui:open('ALT',true);ui:page_step(1);assert(ui.page=='ALT DISPLAY')
ui:option(1);ui:update(0);assert(not ui.pending and get('F22_ALT_SELECTION')==1)
dofile(SCRIPT_ROOT..'Systems/HUD_Flight_Data.lua');post_initialize()
local hud_update=update
hud_update();assert(get('HUD_ALT_SOURCE_TEXT')=='RDR' and math.abs(get('HUD_ALT_FT')-328.0839895)<.01)
radar=0/0;altitude_update();hud_update()
assert(get('HUD_ALT_SOURCE_TEXT')=='BARO FB' and get('HUD_ALT_VALID')==1)
ui:option(1);ui:update(0);assert(get('F22_ALT_SELECTION')==2)
put('F22_ALTIMETER_NATIVE_VALID',0);altitude_update();hud_update()
assert(get('F22_ALT_BARO_VALID')==0 and get('F22_ALT_STANDBY_VALID')==1)
assert(get('HUD_ALT_SOURCE_TEXT')=='STBY' and math.abs(get('HUD_ALT_FT')-1100*3.280839895)<.01)
put('F22_ALT_STANDBY_NATIVE_VALID',0);altitude_update();hud_update()
assert(get('HUD_ALT_VALID')==0,'standby failure silently switched to another source')
put('F22_ALT_STANDBY_NATIVE_VALID',1)
put('EFM_POWER_OWNER',1);put('EFM_PHYSICAL_VALID',1);put('EFM_PHYSICAL_GENERATION',1)
put('EFM_PHYSICAL_STAMP',10);put('F22_AP_CLOCK',10);put('EFM_PHYSICAL_CLOCK_KIND',1)
put('MAIN_POWER',0);put('F22_ESSENTIAL_POWER',1);altitude_update();hud_update()
assert(get('F22_ALT_STANDBY_VALID')==1 and get('HUD_ALT_VALID')==1,'usable DC lost standby display')
put('EFM_PHYSICAL_VALID',0);altitude_update();hud_update()
assert(get('F22_ALT_STANDBY_VALID')==0 and get('HUD_ALT_VALID')==0)
put('EFM_POWER_OWNER',0);put('MAIN_POWER',1);altitude_update();hud_update()
assert(get('HUD_ALT_VALID')==0,'invalid physical owner revived legacy power')
put('EFM_POWER_OWNER',1);put('EFM_PHYSICAL_VALID',1);altitude_update();hud_update()
assert(get('HUD_ALT_VALID')==1)
now=101;altitude_update();hud_update();assert(get('HUD_ALT_VALID')==0,'stale standby accepted')
''')
print('Altitude owners: correlated source selection, RDR/barometric fallback, independent standby, essential DC, stale/invalid power and recovery PASS')
