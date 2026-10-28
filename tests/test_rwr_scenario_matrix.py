"""Dense RWR direction/elevation/severity/freshness and owner lifecycle matrix."""
from pathlib import Path
from lupa.lua51 import LuaRuntime
import contextlib
import io
import runpy
ROOT=Path(__file__).resolve().parents[1]
lua=LuaRuntime()
lua.globals().ROOT=(ROOT/'Cockpit/Scripts/Systems').as_posix()+'/'
lua.execute(r'''
local m=dofile(ROOT..'RWR_Computer.lua');local r=m.new();local count=0
assert(m.label('J-11A',1)=='29' and m.label('Unknown aircraft',1)=='U','stock emitter alias must not classify unknown types')
for bearing=-180,175,5 do for elevation=-80,80,20 do
 for signal=1,3 do for _,age in ipairs({0,3,4,7,13}) do
  local o={source=123,age=age,az=math.rad(bearing),el=math.rad(elevation),signal=signal,
   priority=10,general=1,label='MiG-29S'}
  r:update({o},true);count=count+1
  if age>12 then assert(#r.contacts==0 and r.alert==0)
  else
   assert(#r.contacts==1 and r.contacts[1].source==123 and r.contacts[1].label=='29')
   local coast=age>(signal==1 and 6 or 3.5)
   assert(m.coasting(r.contacts[1])==coast)
   assert(r.alert==(coast and 0 or signal),'stale alarm or missed fresh warning')
   assert(r.contacts[1].range==nil and r.contacts[1].north==nil,'RWR invented range/position')
  end
 end end
end end
assert(count==9720)
-- Invalid IDs, ages and enum values must not reach ring geometry or formatting.
for _,signal in ipairs({0,1.5,2.5,4,0/0,math.huge}) do
 r:update({{source=1,age=0,az=0,signal=signal}},true);assert(#r.contacts==0)
end
for _,source in ipairs({0,-1,1.5,4294967296,0/0,math.huge}) do
 r:update({{source=source,age=0,az=0,signal=1}},true);assert(#r.contacts==0)
end
r:update({{source=20,age=0,az=0,signal=1,priority=900},
 {source=30,age=0,az=1,signal=3,priority=1},
 {source=10,age=0,az=-1,signal=2,priority=999},
 {source=30,age=1,az=1,signal=1,priority=1000}},true)
assert(#r.contacts==3 and r.contacts[1].source==30 and r.contacts[2].source==10)
r:update({},false);assert(#r.contacts==0 and r.alert==0)
''')
print('RWR receiver: 9,720 bearing/elevation/signal/age cases plus invalid data and severity ordering PASS')
with contextlib.redirect_stdout(io.StringIO()):
 runtime=runpy.run_path(str(ROOT/'tests/test_display_startup.py'))['runtime']
lua=runtime()
lua.execute(r'''
local now=100
function get_model_time()return now end
local available=true
native={set_power=function(self,v)self.power=v end}
function GetDevice()if not available then error('receiver unavailable') end;return native end
local playing={};local starts={}
function create_sound_host()return {create_sound=function(self,name)
 return {update=function()end,is_playing=function()return playing[name]end,
 play_continue=function()playing[name]=true end,stop=function()playing[name]=false end,
 play_once=function()starts[name]=(starts[name] or 0)+1 end}
end}end
local function put(n,v)get_param_handle(n):set(v)end
local function val(n)return get_param_handle(n):get()end
local function contact(az,el,signal,age)
 for k,v in pairs({SOURCE=123,TIME=age or 0,AZIMUTH=az,ELEVATION=el,SIGNAL=signal,
 UNIT_TYPE='MiG-29S',GENERAL_TYPE=1,PRIORITY=10,POWER=.25})do put('RWR_CONTACT_01_'..k,v)end
end
put('MAIN_POWER',1);put('RADAR_PWR',0)
dofile(SCRIPT_ROOT..'Systems/RWR_System.lua');post_initialize()
for bearing=-180,175,5 do for elevation=-80,80,20 do for signal=1,3 do
 now=now+.05;contact(math.rad(bearing),math.rad(elevation),signal);update()
 -- Native relative proximity is independent of the warning/launch state.
 local radius=.84*.75
 assert(val('F22_RWR_POWER')==1 and val('F22_RWR_COUNT')==1 and val('F22_RWR_ALERT')==signal)
 assert(math.abs(val('F22_EW_01_X')+math.sin(math.rad(bearing))*radius)<1e-10)
 assert(math.abs(val('F22_EW_01_Y')-math.cos(math.rad(bearing))*radius)<1e-10)
 assert(val('F22_EW_01_SOURCE')==123)
 assert(val('F22_EW_01_POWER')==.25 and val('F22_EW_01_PROXIMITY_VALID')==1)
end end end
-- A native service outage clears warning output and retries cleanly.
available=false;now=now+.1;update()
assert(val('F22_RWR_READY')==0 and val('F22_RWR_COUNT')==0 and val('F22_RWR_AUDIO_LOOP')==0)
available=true;now=now+.1;contact(0,0,3);update()
assert(val('F22_RWR_READY')==1 and val('F22_RWR_AUDIO_LOOP')==3)
SetCommand(10901,1);update();assert(val('F22_RWR_AUDIO_LOOP')==0 and val('F22_EW_01_VALID')==1)
SetCommand(10901,1);update();assert(val('F22_RWR_AUDIO_LOOP')==3)
put('MAIN_POWER',0);update()
assert(not native.power and val('F22_RWR_COUNT')==0 and val('F22_RWR_AUDIO_LOOP')==0)
put('MAIN_POWER',1);contact(0,0,1)
for k,v in pairs({VALID=1,SOURCE=123,CLASS=1,AGE=0})do put('F22_IDENT_01_'..k,v)end
put('F22_TWS_PUBLISH_SEQUENCE',10);update();assert(val('F22_EW_01_AFFILIATION')==0,'retired friend endpoint overrode recent hostile-act evidence')
-- Frozen radar identity parameters cannot renew their age indefinitely.
now=now+31;update();assert(val('F22_EW_01_AFFILIATION')==-1)
put('F22_TWS_PUBLISH_SEQUENCE',11);put('F22_IDENT_01_AGE',31);update()
assert(val('F22_EW_01_AFFILIATION')==-1)
put('F22_TWS_PUBLISH_SEQUENCE',12);put('F22_IDENT_01_AGE',0);update()
assert(val('F22_EW_01_AFFILIATION')==-1)
-- Model time pause cannot manufacture repeated RF pings.
local event_count=starts['Aircrafts/F-22A/RWR/ping'] or 0
for i=1,100 do update()end
assert((starts['Aircrafts/F-22A/RWR/ping'] or 0)==event_count)
-- Rewind discards cached identity even if the producer has not reset yet.
now=0;update();assert(val('F22_EW_01_AFFILIATION')==-1)
put('F22_TWS_PUBLISH_SEQUENCE',1);put('F22_IDENT_01_CLASS',0);update()
assert(val('F22_EW_01_AFFILIATION')==-1,'retired numeric identity endpoint classified an RF report')
''')
print('Actual RWR owner: 1,944 bearing/elevation/severity cases, radar-off, API outage, mute/power, identity freeze/expiry, pause and rewind PASS')
