"""Physical hydraulic supply owns achieved bay/gun door motion and release gates."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
fixture=ROOT/'tests/test_display_startup.py';ns={'__file__':str(fixture)}
exec(compile(fixture.read_text().split('\nfor page in ',1)[0],str(fixture),'exec'),ns)
lua=ns['runtime']()
lua.execute(r'''
local now=10;function get_model_time()return now end
function get_aircraft_property()return 1 end
function get_aircraft_draw_argument_value(n)return draws[n]or 0 end
function set_aircraft_draw_argument_value(n,v)draws[n]=v end
local count,launches,accept=1,0,true
native={get_station_info=function(_,i)return {count=i==4 and count or 0,CLSID='{F22-MK83-TRAINING}',weapon={level1=4,level2=5,level3=9,level4=32}}end,
 select_station=function()end,launch_station=function()launches=launches+1;if accept then count=count-1 end end,
 get_chaff_count=function()return 120 end,get_flare_count=function()return 120 end}
function GetDevice()return native end
local function put(n,v)get_param_handle(n):set(v)end
local function val(n)return get_param_handle(n):get()end
local release_logs,ack_logs=0,0
log={INFO=1,ERROR=2,write=function(topic,_,line)
 assert(type(line)=='string')
 if topic=='F22_AG_RELEASE'then release_logs=release_logs+1;assert(line:find('actual=',1,true)and line:find('target_source=',1,true))end
 if topic=='F22_AG_RELEASE_ACK'then ack_logs=ack_logs+1;assert(line:find('evidence=',1,true))end
end}
dofile(SCRIPT_ROOT..'Systems/Weapon_System.lua');post_initialize()
put('MAIN_POWER',1);put('WoW',0);put('EFM_VEHICLE_VALID',1);put('EFM_ACTUATOR_AVAILABLE',0)
SetCommand(10800,7);SetCommand(10806,1)
local function tick(n)for _=1,n do now=now+.02;put('F22_AG_SOLUTION_SCHEMA',2);put('F22_AG_SOLUTION_VALID',1);put('F22_AG_SOLUTION_TIME',now);put('F22_AG_SOLUTION_STATION',4);update()end end
tick(20);SetCommand(10803,1);tick(100)
assert(draws[600]==0 and launches==0 and val('F22_BAY_ACTUATOR_AUTHORITY')==0,'failed hydraulic supply opened bay or released a store')
put('EFM_ACTUATOR_AVAILABLE',.5);tick(1);assert(math.abs(draws[600]-.025)<1e-8,'partial pressure did not scale actuator rate')
tick(35);assert(launches==0,'release used commanded door state before achieved clearance')
tick(10);assert(launches==1,'restored physical supply never permitted achieved-clearance release')
assert(release_logs==1 and ack_logs==1,'normal-flight release/evidence telemetry omitted')
SetCommand(10803,0);SetCommand(10807,1);SetCommand(10801,1);SetCommand(10802,1)
put('EFM_ACTUATOR_AVAILABLE',0);tick(40);assert(draws[614]==0 and val('HUD_GUN_TRIGGER')==0,'gun door bypassed failed supply')
put('EFM_ACTUATOR_AVAILABLE',1);tick(8);assert(val('HUD_GUN_TRIGGER')==0,'gun fired before achieved door clearance')
tick(2);assert(val('HUD_GUN_TRIGGER')==1)
local open_gun=draws[614];put('EFM_ACTUATOR_AVAILABLE',0);tick(1)
assert(draws[614]==open_gun and val('HUD_GUN_TRIGGER')==0,'open gun door bypassed failed gun drive supply')
put('EFM_ACTUATOR_AVAILABLE',1);tick(1);assert(val('HUD_GUN_TRIGGER')==1)
-- Electrical ground power cannot supply failed hydraulic pressure.
put('WoW',1);put('MAIN_POWER',0);put('GROUND_POWER',1);put('GROUND_ORIDE',0);put('EFM_ACTUATOR_AVAILABLE',0);draws[601]=0
tick(30);assert(draws[601]==0,'GPU/ground-crew request bypassed hydraulic authority')
put('EFM_ACTUATOR_AVAILABLE',1);tick(1);assert(math.abs(draws[601]-.005)<1e-8)
-- A deliberately invalid EFM model uses the existing startup fallback.
put('EFM_VEHICLE_VALID',0);put('EFM_ACTUATOR_AVAILABLE',0);tick(1);assert(draws[601]>.005 and val('F22_BAY_ACTUATOR_VALID')==0)
-- Master SAFE cancels future consent without losing an already dispatched
-- request's unresolved inventory identity; immediate ARM/press cannot retry it.
put('MAIN_POWER',1);put('WoW',0);put('GROUND_POWER',0);count=1;accept=false
SetCommand(10802,0);SetCommand(10803,0);SetCommand(10800,7);tick(20);SetCommand(10808,1);tick(15)
draws[600]=1;SetCommand(10803,1);tick(1);assert(launches==2 and val('F22_SMS_RELEASE_PENDING')==1)
SetCommand(10806,0);tick(1);assert(val('F22_SMS_STATUS')==7 and val('F22_SMS_READY_COUNT')==0,'SAFE dropped dispatched-request reconciliation')
SetCommand(10803,0);SetCommand(10806,1);SetCommand(10803,1);tick(30);assert(launches==2,'immediate rearm reused an unconfirmed physical request')
''')
print('Stores actuators: no-pressure freeze, partial-pressure rate, achieved bay/gun clearance, restored supply, GPU guard and explicit legacy fallback PASS')
