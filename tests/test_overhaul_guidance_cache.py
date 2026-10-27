"""Actual weapon owner waits for native preparation; a late ack cannot fire it."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
fixture=ROOT/'tests/test_display_startup.py';ns={'__file__':str(fixture)}
exec(compile(fixture.read_text().split('\nfor page in ',1)[0],str(fixture),'exec'),ns)
lua=ns['runtime']()
lua.execute(r'''
local now=10;local count=4;local calls=0;local solver=1;local selected=-1
function get_model_time()return now end
function get_aircraft_property()return 1 end
function get_aircraft_draw_argument_value(n)return draws[n]or 0 end
function set_aircraft_draw_argument_value(n,v)draws[n]=v end
local function put(n,v)get_param_handle(n):set(v)end
local function val(n)return get_param_handle(n):get()end
native={get_station_info=function(_,i)return {count=i==4 and count or 0,CLSID='{GBU_32_V_2B}',weapon={level1=4,level2=5,level3=36,level4=85}}end,
 select_station=function(_,i)selected=i end,launch_station=function(_,i)
  assert(i==4 and val('F22_AG_GUIDANCE_CACHE_TARGET_N')==val('F22_AG_DELIVERY_TARGET_N'),'wrong prepared station/point launched')
  calls=calls+1;count=count-1
  for key,value in pairs({SEQUENCE=calls,ID=500+calls,STATION=i,MODE=7,TYPE=85,TIME=now})do
   put('F22_SHOT_01_'..key,value)
  end
  put('F22_LAUNCH_SEQUENCE',calls)
 end,get_chaff_count=function()return 120 end,get_flare_count=function()return 120 end}
function GetDevice()return native end
dofile(SCRIPT_ROOT..'Systems/Weapon_System.lua');post_initialize()
put('MAIN_POWER',1);put('WoW',0);put('HUD_AG_TARGET_VALID',1);put('HUD_AG_MARK_NORTH',10000);put('HUD_AG_MARK_ALT',300);put('HUD_AG_MARK_EAST',500)
SetCommand(10987,1);SetCommand(10800,7);SetCommand(10806,1);SetCommand(10006,1)
put('F22_AG_GUIDANCE_BACKEND_READY',1)
local function tick(n)
 for _=1,n do now=now+.02;put('F22_AG_SOLUTION_SCHEMA',2);put('F22_AG_SOLUTION_VALID',1);put('F22_AG_SOLUTION_TIME',now)
  put('F22_AG_SOLUTION_STATION',selected);put('F22_AG_SOLUTION_SEQUENCE',solver);put('F22_AG_AUTO_RELEASE',1);update()
 end
end
local function acknowledge()
 put('F22_AG_GUIDANCE_CACHE_VALID',1);put('F22_AG_GUIDANCE_CACHE_TIME',now);put('F22_AG_GUIDANCE_CACHE_STATION',4)
 put('F22_AG_GUIDANCE_CACHE_SOLUTION_SEQUENCE',solver)
 for _,key in ipairs({'SOURCE','SEQUENCE','N','U','E'})do put('F22_AG_GUIDANCE_CACHE_TARGET_'..key,val('F22_AG_DELIVERY_TARGET_'..key))end
end
tick(30);assert(selected==4 and val('BAY_C_ARG')>=.98)
SetCommand(10803,1);tick(5);assert(calls==0 and val('F22_SMS_RELEASE_PENDING')==0,'availability/fresh ballistics substituted for preparation ack')
SetCommand(10803,0);assert(val('F22_AG_RELEASE_CONSENT')==0,'pickle release left stale consent until update')
acknowledge();tick(3);assert(calls==0,'late preparation fired released consent')
put('F22_AG_GUIDANCE_CACHE_VALID',0);SetCommand(10803,1);tick(2)
put('HUD_AG_MARK_NORTH',12000);SetCommand(10987,1);solver=2
assert(val('F22_AG_RELEASE_CONSENT')==0,'target edit left stale consent until update')
tick(2);assert(calls==0,'editing a waiting target launched an old program')
-- An old cache has correct station but the prior target identity and solve.
put('F22_AG_GUIDANCE_CACHE_VALID',1);put('F22_AG_GUIDANCE_CACHE_TIME',now)
SetCommand(10803,0);SetCommand(10803,1);tick(2);assert(calls==0,'same-station target edit reused old native cache')
acknowledge();tick(3);assert(calls==1 and val('F22_AG_RELEASE_SEQUENCE')==1,'matched preparation did not reach physical inventory acknowledgement')
tick(10);assert(calls==1,'held consent repeated a completed one-store program')
SetCommand(10803,0);put('HUD_AG_MARK_NORTH',14000);SetCommand(10987,1);solver=3
SetCommand(10803,1);tick(2);assert(calls==1)
acknowledge();put('F22_AG_GUIDANCE_CACHE_TARGET_N',15000);tick(2);assert(calls==1,'coordinate mismatch passed an equal target-sequence cache')
acknowledge();put('F22_AG_GUIDANCE_CACHE_SOLUTION_SEQUENCE',2);tick(2);assert(calls==1,'previous solver sequence cache released a new solution')
acknowledge();put('F22_AG_GUIDANCE_CACHE_STATION',6);tick(2);assert(calls==1,'wrong prepared station released')
-- Program/SAFE changes while waiting need a new consent even when cache later
-- matches. No native request/quarantine is created by preparation alone.
SetCommand(10974,1);assert(val('F22_AG_RELEASE_CONSENT')==0,'program edit left stale consent until update')
acknowledge();tick(2);assert(calls==1 and val('F22_SMS_RELEASE_PENDING')==0)
SetCommand(10803,0);put('F22_AG_GUIDANCE_CACHE_VALID',0);SetCommand(10803,1);tick(2)
SetCommand(10806,0);assert(val('MASTER_ARM')==0 and val('F22_AG_RELEASE_CONSENT')==0,'SAFE guard publication lagged input')
SetCommand(10806,1);assert(val('F22_AG_RELEASE_CONSENT')==0,'quick re-arm resurrected old consent before update')
acknowledge();tick(2);assert(calls==1,'SAFE while waiting allowed delayed launch')
''')
print('Guidance preparation: unavailable/old/wrong-station/point/solver caches wait, cancellation/target edit/SAFE forbid late launch, physical ack remains separate PASS')
