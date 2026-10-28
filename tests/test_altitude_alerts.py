"""Distinct altitude occurrences survive deferred playback, inhibition and recovery."""
from pathlib import Path
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
lua = LuaRuntime(unpack_returned_tuples=True)
lua.globals().SOURCE = (ROOT / 'Cockpit/Scripts/Systems/Altitude_Alerts.lua').as_posix()
lua.execute(r'''
local A=dofile(SOURCE)
local s={now=0,radar=700,radar_floor=500,radar_valid=true,baro=4000,baro_floor=0,
 baro_valid=true,minima_floor=300,minima_source=0,gear_up=true,gear_down=false}
local a=A.new();assert(not a:update(s,true))
s.radar=400;s.now=1;assert(a:update(s,true)and a.label=='RADAR LOW')
local low=a.selected;a:played(low);assert(a:update(s,true),'clip completion disabled radar-low')
assert(a:disable_current());assert(not a:disable_current());assert(not a:update(s,true));a:power_lost()
assert(not a:update(s,true),'power recovery forgot the consumed disable/latch')
s.radar=510;s.now=2;a:update(s,true);s.radar=400;s.now=3
assert(a:update(s,true)and a.selected~=low,'measured climb did not reset disable')
assert(a:disable_current());a:update(s,true)
s.gear_up=false;s.gear_down=true;s.radar=500;s.now=4;a:update(s,true)
s.radar=250;s.now=5;assert(a:update(s,true)and a.label=='MINIMA')
local minima=a.selected
-- A late confirmation for an earlier low event cannot consume this minima event.
a:played(low);assert(a:update(s,true)and a.selected==minima)
a:played(minima);assert(not a:update(s,true),'minima repeated below its threshold')
s.radar=350;s.now=6;a:update(s,true);s.radar=250;s.now=7
assert(not a:update(s,true),'minima rearmed inside the100ft band')
s.radar=450;s.now=8;a:update(s,true);s.radar=250;s.now=9
assert(a:update(s,true),'minima failed to rearm above the band')
s.radar_valid=false;assert(not a:update(s,true),'invalid radar preserved pending minima')
s.minima_source=1;s.baro=1000;s.minima_floor=500;s.now=10;a:update(s,true)
s.baro=400;s.now=11;assert(a:update(s,true)and a.label=='MINIMA')
s.now=17;assert(not a:update(s,true),'stale unspoken crossing never expired')
s.gear_down=false;s.gear_up=false;s.radar_valid=true;s.radar=100;s.now=18
assert(not a:update(s,true),'gear transit gained low/minima authority')
s.gear_up=true;s.radar=600;a:update(s,true);s.radar=100
assert(a:update(s,true),'valid warning failed to recover')
a.occurrence=16777215;a.low.active=false;assert(not a:update(s,true),'exhausted event IDs were reused')
''')
print('Altitude events: persistent low, explicit disable/reset, separate minima/baro health, deferred-ticket identity, expiry, transit and capacity PASS')
fixture = ROOT / 'tests/test_display_startup.py'
scope = {'__file__': str(fixture)}
exec(compile(fixture.read_text().split('\nfor page in ', 1)[0], str(fixture), 'exec'), scope)
lua = scope['runtime']()
lua.execute(r'''
local now=10
function get_model_time()return now end
function get_base_data()return setmetatable({getSelfCoordinates=function()return 0,3000,0 end,
 getIndicatedAirSpeed=function()return 200 end,getVerticalAcceleration=function()return 1 end},
 {__index=function()return function()return 0 end end})end
function get_aircraft_draw_argument_value()return 0 end
local function get(k)return get_param_handle(k):get()end
local function put(k,v)get_param_handle(k):set(v)end
put('MAIN_POWER',1);put('EFM_HUD_VALID',1);put('EFM_GROUND_VALID',1);put('EFM_HUD_VN',200)
put('F22_ALT_RADAR_VALID',1);put('F22_ALT_RADAR_FT',100);put('F22_ALT_RADAR_FLOOR',500)
dofile(SCRIPT_ROOT..'Systems/Pilot_Warning_System.lua');local physical=dofile(SCRIPT_ROOT..'../../tests/warning_physical_fixture.lua')();update=physical:wrap(update);SetCommand=physical:wrap(SetCommand);post_initialize();update()
local owner,voice=SetCommand,update
assert(get('F22_ALT_ALERT_SOURCE')=='RADAR LOW')
owner(11000,1);voice();assert(get('F22_ALT_ALERT_SOURCE')=='RADAR LOW','master ACK disabled radar-low')
local ui=dofile(SCRIPT_ROOT..'Systems/UFC_Controller.lua').new(get,put,function(device,c,v)
 assert(device=='PILOT_WARNING_SYSTEM');owner(c,v)
end)
ui:open('ALT DISPLAY',true);ui:option(4);ui:update(0);voice()
assert(not ui.pending and get('F22_ENTRY_WARN_RESULT')==1 and get('F22_ALT_LOW_DISABLED')==1)
assert(get('F22_ALT_ALERT_SOURCE')=='')
ui:option(4);ui:update(0);assert(get('F22_ENTRY_WARN_RESULT')==2,'no current event falsely accepted')
put('MAIN_POWER',0);now=11;voice();put('MAIN_POWER',1);now=12;voice()
assert(get('F22_ALT_LOW_DISABLED')==1,'disable state was lost or replayed on recovery')
put('F22_ALT_RADAR_FT',700);voice();put('F22_ALT_RADAR_FT',100);now=13;voice()
assert(get('F22_ALT_LOW_DISABLED')==0 and get('F22_ALT_ALERT_SOURCE')=='RADAR LOW')
now=14;ui:option(4);ui:update(0)
assert(get('F22_ENTRY_WARN_RESULT')==2 and get('F22_ALT_LOW_DISABLED')==0,'stale owner event accepted disable')
voice();ui:option(4);ui:update(0);assert(get('F22_ENTRY_WARN_RESULT')==1)
''')
print('Actual UFC/warning owner: accepted disable, no-current/stale rejection, master ACK independence, power retention and deliberate recovery PASS')
