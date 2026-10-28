"""Explicit recovery intent, received guidance and terrain protection remain distinct."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
fixture = ROOT / 'tests/test_display_startup.py'
scope = {'__file__': str(fixture)}
exec(compile(fixture.read_text().split('\nfor page in ', 1)[0], str(fixture), 'exec'), scope)
lua = scope['runtime']()
lua.execute(r'''
local R=dofile(SCRIPT_ROOT..'Systems/Recovery_Context.lua')
local E=dofile(SCRIPT_ROOT..'Systems/Terrain_Escape.lua')
local function get(k)return get_param_handle(k):get()end
local function put(k,v)get_param_handle(k):set(v)end
local s={now=0,powered=true,valid=true,ground=false,gear=true,gear_down=true,gear_up=false,
 n=0,u=80,e=0,vn=140,vu=-8,ve=0,cas=140,nz=1,heading=0,roll=0}
local flat=function()return 0 end
put('HUD_ILS_LOC_VALID',1);put('HUD_ILS_GS_VALID',1)
put('HUD_ILS_LOC',.1);put('HUD_ILS_GS',.1)
assert(not R.update(s,get,put),'received needles created pilot recovery intent')
put('F22_RECOVERY_INTENT',1)
for source=0,2 do
 put('F22_NAV_SOURCE',source);s.approach=R.update(s,get,put)
 assert(s.approach and get('F22_RECOVERY_STATE_TEXT')=='ILS APPROACH')
 assert(E.solve(s,flat).landing,'steering selection changed identical received approach')
end
assert(E.solve(s,function(n)if n>500 then return 1500 end return 0 end).threat,
 'rising terrain retained a blanket landing exemption')
put('HUD_ILS_GS_VALID',0);assert(not R.update(s,get,put))
assert(get('F22_RECOVERY_STATE_TEXT')=='LOCALIZER / NO GS')
put('F22_RECOVERY_INTENT',2);put('HUD_ILS_LOC_VALID',0)
s.approach=R.update(s,get,put);assert(s.approach and E.solve(s,flat).landing)
s.vu=5;assert(not R.update(s,get,put)and get('F22_RECOVERY_STATE_TEXT')=='GO AROUND')
s.vu=-8;s.gear_down=false;assert(not R.update(s,get,put))
s.gear_down=true;s.ground=true;assert(not R.update(s,get,put)and get('F22_RECOVERY_STATE_TEXT')=='TOUCHDOWN')
s.ground=false;s.valid=false;assert(not R.update(s,get,put))
-- The active UFC page sends accepted intent changes to the actual ALT owner.
function get_model_time()return 0 end
function get_base_data()return {getRadarAltitude=function()return 100 end}end
put('MAIN_POWER',1);local altitude_physical=dofile(SCRIPT_ROOT..'../../tests/physical_frame_fixture.lua')({F22_ESSENTIAL_POWER=1});altitude_physical:publish(get_param_handle('F22_AP_CLOCK'):get());dofile(SCRIPT_ROOT..'Systems/Altitude_System.lua');post_initialize()
local owner=SetCommand
local ui=dofile(SCRIPT_ROOT..'Systems/UFC_Controller.lua').new(get,put,function(device,c,v)
 assert(device=='ALTITUDE_SYSTEM');owner(c,v)
end)
ui:open('ALT DISPLAY',true);ui:option(5);assert(ui.page=='RECOVERY')
ui:option(1);ui:update(0);assert(not ui.pending and get('F22_RECOVERY_INTENT')==1)
assert(ui:rows()[3].label=='MANUAL FLIGHT / NO AUTOLAND')
ui:option(5);assert(ui.page=='ALT DISPLAY')
''')
print('Manual recovery: explicit intent, retained TACAN/WPT steering, LOC-only/visual/go-around/touchdown, terrain protection and accepted UFC path PASS')
