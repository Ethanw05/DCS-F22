"""Combined A/G work and radar integrity policies preserve each other's routing."""
from pathlib import Path
root=Path(__file__).resolve().parents[1]
fixture=root/'tests/test_display_startup.py'
ns={'__file__':str(fixture)}
exec(compile(fixture.read_text().split('\nfor page in ',1)[0],str(fixture),'exec'),ns)
lua=ns['runtime']()
lua.execute(r'''
local now=10;function get_model_time()return now end
native={set_power=function()end};function GetDevice()return native end
package.preload.terrain=function()return {GetHeight=function()return 0 end}end
local function put(n,v)get_param_handle(n):set(v)end
local function val(n)return get_param_handle(n):get()end
dofile(SCRIPT_ROOT..'Systems/Radar_System.lua');post_initialize()
put('MAIN_POWER',1);put('HUD_MODE',2);put('F22N_RADAR_MODE',1)
SetCommand(10602,1);update();assert(val('RADAR_PWR')==1)
SetCommand(10600,1);update();assert(val('RADAR_PWR')==0)
put('HUD_MODE',7);update();assert(val('RADAR_PWR')==0,'A/G entry silently enabled emissions')
SetCommand(10626,1);update();assert(val('RADAR_PWR')==0,'A/G operate request erased inhibit')
SetCommand(10600,1);update();assert(val('RADAR_PWR')==1)
SetCommand(10600,1);update();assert(val('RADAR_PWR')==0)
put('HUD_MODE',2);update();assert(val('RADAR_PWR')==0,'A/A entry lost A/G radar-off preference')
local events={}
local s=dofile(SCRIPT_ROOT..'Systems/Combat_Logic.lua').new(function(n,v)events[#events+1]=n end)
local c={locked=false,ground=false};s:set_mode(7)
local function press(n)s:input(n,1,c);s:input(n,0,c)end
press('dms_up');events={};press('tdc');press('tms_up');press('tms_down')
assert(#events==3 and events[1]=='ag_mark' and events[2]=='ag_mark' and events[3]=='ag_clear',
 'focus guard blocked the A/G owner HUD mark/clear workflow')
press('dms_down');events={};press('tdc');assert(#events==2 and events[1]=='ground_tdc' and events[2]=='ground_tdc')
press('dms_right');events={};press('tdc');assert(#events==0)
''')
print('A/G handoff: explicit EMIT across A/A-A/G modes, preserved HUD mark/clear and radar focus PASS')
