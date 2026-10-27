"""Ground target handoff, native trajectory geometry and actual release controller."""
from pathlib import Path
import contextlib,io,runpy
ROOT=Path(__file__).resolve().parents[1]
with contextlib.redirect_stdout(io.StringIO()):
 runtime=runpy.run_path(str(ROOT/'tests/test_display_startup.py'))['runtime']

lua=runtime()
lua.execute('''
local d=dofile(SCRIPT_ROOT..'Systems/AG_Delivery.lua')
local points={{n=0,u=10,e=0},{n=50,u=5,e=0},{n=100,u=-5,e=0}}
local p=d.ground(points,function()return 0 end)
assert(math.abs(p.n-75)<.01 and math.abs(p.u)<.01 and math.abs(p.t-.075)<.001)
assert(not d.ground(points,function()return nil end))
local r=d.release({n=3000,e=0},{n=5000,e=0},200,0,15)
assert(r.seconds==10 and r.cross==0 and not r.ready)
r=d.release({n=5000,e=0},{n=5000,e=0},200,0,15);assert(r.ready)
assert(not d.release({n=5000,e=0},{n=5000,e=100},200,0,15).ready)
assert(not d.release({n=5100,e=0},{n=5000,e=0},200,0,15).ready)
''')

lua=runtime()
lua.execute('''
package.preload.terrain=function()return {GetHeight=function()return 0 end}end
function get_base_data()return {getSelfCoordinates=function()return 0,1000,0 end,
 getHeading=function()return 0 end,getPitch=function()return -math.atan(.2)end,getRoll=function()return 0 end}end
dofile(SCRIPT_ROOT..'Systems/AG_Mark_System.lua');post_initialize()
local function put(n,v)get_param_handle(n):set(v)end
local function val(n)return get_param_handle(n):get()end
put('MAIN_POWER',1);put('HUD_MODE',7)
SetCommand(10810,9.375);SetCommand(10810,9.25);update()
assert(val('HUD_AG_TARGET_VALID')==1 and math.abs(val('HUD_AG_MARK_NORTH')-5000)<.1)
local seq=val('F22_AG_TARGET_SEQUENCE');update();assert(val('F22_AG_TARGET_SEQUENCE')==seq)
put('F22_AG_DESIGNATION_SEQUENCE',1);put('F22_AG_DESIGNATION_VALID',1)
put('F22_AG_DESIGNATION_NORTH',10000);put('F22_AG_DESIGNATION_ALTITUDE',0);put('F22_AG_DESIGNATION_EAST',2000);update()
assert(val('HUD_AG_MARK_NORTH')==10000 and val('HUD_AG_MARK_EAST')==2000)
put('F22_AG_DESIGNATION_NORTH',99999);update();assert(val('HUD_AG_MARK_NORTH')==10000,'designation moved without a new pilot event')
put('F22_NAV_VALID',1);put('F22_NAV_TARGET_N',12000);put('F22_NAV_TARGET_E',3000)
SetCommand(10812,1);SetCommand(10812,0);update();assert(val('HUD_AG_MARK_NORTH')==12000 and val('HUD_AG_MARK_ALT')==0)
SetCommand(10811,1);SetCommand(10811,0);update();assert(val('HUD_AG_TARGET_VALID')==0)
''')

lua=runtime()
lua.execute('''
function get_aircraft_property(_)return 1 end
function get_model_time()return 10 end
function get_aircraft_draw_argument_value(n)return draws[n]or 0 end
function set_aircraft_draw_argument_value(n,v)draws[n]=v end
local count=2;local guided=false;local launches=0;local selected=-1
native={get_station_info=function(self,i)return {count=i==4 and count or 0,CLSID=guided and '{GBU_32_V_2B}'or '{F22-MK83-TRAINING}',
 weapon={level1=4,level2=5,level3=guided and 36 or 9,level4=32}}end,
 select_station=function(self,i)selected=i end,launch_station=function(self,i)assert(i==4);launches=launches+1;count=count-1 end,
 get_chaff_count=function()return 120 end,get_flare_count=function()return 120 end}
function GetDevice(i)assert(i==15);return native end
dofile(SCRIPT_ROOT..'Systems/Weapon_System.lua');post_initialize()
local function put(n,v)get_param_handle(n):set(v)end
local function val(n)return get_param_handle(n):get()end
put('MAIN_POWER',1);put('WoW',0);SetCommand(10800,7);SetCommand(10808,1);SetCommand(10008,1)
for i=1,20 do update()end
assert(selected==4 and val('F22_AG_BOMB_SELECTED')==1 and val('HUD_AG_SUBMODE')==2)
SetCommand(10803,1);for i=1,40 do update()end;assert(launches==0,'CCIP released with no native solution')
put('F22_AG_SOLUTION_SCHEMA',2);put('F22_AG_SOLUTION_VALID',1);put('F22_AG_SOLUTION_TIME',9)
for i=1,40 do update()end;assert(launches==0,'CCIP used stale native solution')
put('F22_AG_SOLUTION_TIME',11)
for i=1,40 do update()end;assert(launches==0,'CCIP used future native solution')
put('F22_AG_SOLUTION_TIME',10);put('F22_AG_SOLUTION_STATION',4);for i=1,40 do update()end
assert(launches==1 and count==1,'CCIP did not release once when ready')
for i=1,50 do update()end;assert(launches==1,'held consent caused repeated releases')
SetCommand(10803,0);SetCommand(10809,1);SetCommand(10803,1)
for i=1,40 do update()end;assert(launches==1,'AUTO ignored release timing')
put('F22_AG_SOLUTION_VALID',1);put('F22_AG_AUTO_RELEASE',1);for i=1,20 do update()end;assert(launches==2)
-- An unarmed or weight-on-wheels request must never fire a bomb or gun.
count=2;guided=true;SetCommand(10803,0);SetCommand(10808,1)
SetCommand(10803,1);for i=1,40 do update()end;assert(launches==2,'guided bomb released in CCIP')
SetCommand(10803,0);SetCommand(10809,1);put('HUD_AG_TARGET_VALID',1);put('F22_AG_GUIDANCE_BACKEND_READY',1)
SetCommand(10803,1);update();put('F22_AG_SOLUTION_VALID',1);put('F22_AG_SOLUTION_SEQUENCE',1)
put('F22_AG_GUIDANCE_CACHE_VALID',1);put('F22_AG_GUIDANCE_CACHE_TIME',10);put('F22_AG_GUIDANCE_CACHE_STATION',4);put('F22_AG_GUIDANCE_CACHE_SOLUTION_SEQUENCE',1)
for _,key in ipairs({'SOURCE','SEQUENCE','N','U','E'})do put('F22_AG_GUIDANCE_CACHE_TARGET_'..key,val('F22_AG_DELIVERY_TARGET_'..key))end
for i=1,40 do update()end;assert(launches==3,'guided AUTO release missing')
SetCommand(10803,0);SetCommand(10807,1);SetCommand(10801,1);SetCommand(10802,1)
for i=1,30 do update()end;assert(val('HUD_GUN_TRIGGER')==1,'ground gun did not fire')
SetCommand(10802,0);update();assert(val('HUD_GUN_TRIGGER')==0)
put('WoW',1);SetCommand(10802,1);update();assert(val('HUD_GUN_TRIGGER')==0)
''')
print('A/G: terrain stream intersection, AUTO timing/cross-track, immutable radar/HUD/nav designation, selected native stores, consent/lockouts and ground gun PASS')
