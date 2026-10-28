"""Actual four-panel Stores flow and guided CCIP consent/target handoff."""
from cockpit_fixture import runtime

lua = runtime()
lua.execute(r'''
local now=10
function get_model_time()return now end
function get_aircraft_property()return 1 end
function get_aircraft_draw_argument_value(index)return draws[index]or 0 end
function set_aircraft_draw_argument_value(index,value)draws[index]=value end
local count,launches=2,0
local native={get_station_info=function(_,station)
 return {count=station==4 and count or 0,CLSID='{GBU_32_V_2B}',
  weapon={level1=4,level2=5,level3=36,level4=85}}
end,select_station=function()end,launch_station=function(_,station)
 assert(station==4);launches=launches+1;count=count-1
 for key,value in pairs({SEQUENCE=launches,ID=800+launches,STATION=4,MODE=7,TYPE=85,TIME=now})do
  get_param_handle('F22_SHOT_01_'..key):set(value)
 end
 get_param_handle('F22_LAUNCH_SEQUENCE'):set(launches)
end,get_chaff_count=function()return 120 end,get_flare_count=function()return 120 end}
function GetDevice()return native end
local function put(key,value)get_param_handle(key):set(value)end
local function get(key)return get_param_handle(key):get()end
dofile(SCRIPT_ROOT..'Systems/Weapon_System.lua');post_initialize()
local wc,wu=SetCommand,update
dofile(SCRIPT_ROOT..'Systems/MFD_System.lua');post_initialize()
local mc,mu=SetCommand,update
dofile(SCRIPT_ROOT..'Systems/PMFD_System.lua');post_initialize()
local pc,pu=SetCommand,update
function dispatch_action(device,command,value)
 if device==devices.WEAPON_SYSTEM then wc(command,value)
 elseif device==devices.MFD_SYSTEM then mc(command,value)end
end
local function tick(n)for i=1,n do now=now+.02;wu();mu();pu()end end
local function key(panel,button)
 local owner=panel==4 and pc or mc
 local base=({10060,10090,10110,10130})[panel]
 local device=panel==4 and devices.PMFD_SYSTEM or devices.MFD_SYSTEM
 owner(base+button,device+.375);owner(base+button,device+.25);tick(1)
end
put('MAIN_POWER',1);put('MFD_OPACITY',1);put('WoW',0)
wc(10800,7);wc(10806,1);tick(30)
local panels={'LMFD','RMFD','CMFD','PMFD'}
for panel,name in ipairs(panels)do
 key(panel,13);key(panel,3)
 assert(get('F22_MFD_'..name..'_KEY_1')=='GB32')
 key(panel,1)
 assert(get('F22_MFD_'..name..'_KEY_6')=='MODES')
 assert(get('F22_MFD_'..name..'_KEY_9')=='GUN')
 key(panel,6)
 assert(get('F22_MFD_'..name..'_KEY_1')=='AUTO')
 assert(get('F22_MFD_'..name..'_KEY_2')=='CCIP')
 for b=1,20 do assert(get('F22_MFD_'..name..'_KEY_'..b)~='GUN','cannon in bomb delivery modes')end
 key(panel,2);assert(get('HUD_AG_SUBMODE')==2)
 key(panel,9);assert(get('HUD_AG_SUBMODE')==1)
 assert(get('F22_MFD_'..name..'_KEY_6')=='','cannon exposes bomb delivery modes')
 assert(get('F22_SMS_STORE_1_SELECTED')==0,'bomb and cannon both selected')
 wc(10813,1);tick(1);assert(get('HUD_AG_SUBMODE')==1,'mode-cycle changed selected cannon')
 key(panel,1);assert(get('HUD_AG_SUBMODE')==2,'store lost its retained delivery mode')
end
wc(10813,1);tick(1);assert(get('HUD_AG_SUBMODE')==3)
wc(10813,1);tick(1);assert(get('HUD_AG_SUBMODE')==2,'mode-cycle includes cannon')
wc(10800,1);tick(2)
assert(get('F22_MFD_CMFD_KEY_9')=='','NAV offers ground cannon selection')
wc(10800,7);tick(20)

local sequence=100
local function solution()
 sequence=sequence+1
 for name,value in pairs({F22_AG_SOLUTION_VALID=1,F22_AG_SOLUTION_SCHEMA=2,
  F22_AG_SOLUTION_TIME=now,F22_AG_SOLUTION_SEQUENCE=sequence,F22_AG_SOLUTION_STATION=4,
  F22_AG_TERRAIN_PATH_VALID=1,HUD_AG_CCIP_CUE_VALID=1,F22_AG_SOLUTION_IMPACT_N=5000,
  F22_AG_SOLUTION_IMPACT_U=120,F22_AG_SOLUTION_IMPACT_E=400})do put(name,value)end
end
-- A bad press is consumed; recovery cannot become a delayed release.
wc(10803,1);solution();tick(30)
assert(launches==0 and get('F22_AG_RELEASE_CONSENT')==0)
wc(10803,0)
for _,bad in ipairs({{'F22_AG_SOLUTION_TIME',now-1},{'F22_AG_SOLUTION_TIME',now+1},
 {'F22_AG_SOLUTION_STATION',6},{'F22_AG_TERRAIN_PATH_VALID',0},
 {'HUD_AG_CCIP_CUE_VALID',0},{'F22_AG_SOLUTION_IMPACT_N',0/0}})do
 solution();put(bad[1],bad[2]);wc(10803,1)
 assert(get('F22_AG_RELEASE_CONSENT')==0,'invalid pipper accepted: '..bad[1]);wc(10803,0)
end
-- An unrelated steerpoint must never replace the pipper's captured point.
put('HUD_AG_TARGET_VALID',1);put('HUD_AG_MARK_NORTH',90000);put('F22_AG_TARGET_SEQUENCE',7)
solution();wc(10803,1);tick(1)
assert(get('F22_AG_DELIVERY_TARGET_SOURCE')==3 and get('F22_AG_DELIVERY_TARGET_N')==5000)
put('HUD_AG_MARK_NORTH',95000);put('F22_AG_TARGET_SEQUENCE',8)
solution();put('F22_AG_SOLUTION_IMPACT_N',6000);tick(1)
assert(get('F22_AG_DELIVERY_TARGET_N')==5000 and launches==0,'target moved or native cache was bypassed')
local function cache()
 put('F22_AG_GUIDANCE_BACKEND_READY',1);put('F22_AG_GUIDANCE_CACHE_VALID',1)
 put('F22_AG_GUIDANCE_CACHE_TIME',now);put('F22_AG_GUIDANCE_CACHE_STATION',4)
 put('F22_AG_GUIDANCE_CACHE_SOLUTION_SEQUENCE',get('F22_AG_SOLUTION_SEQUENCE'))
 for _,axis in ipairs({'SOURCE','SEQUENCE','N','U','E'})do
  put('F22_AG_GUIDANCE_CACHE_TARGET_'..axis,get('F22_AG_DELIVERY_TARGET_'..axis))
 end
end
for i=1,40 do solution();cache();tick(1)end
assert(launches==1 and count==1,'qualified guided CCIP did not release exactly once')
for i=1,30 do solution();cache();tick(1)end
assert(launches==1,'held CCIP press released an extra bomb')
wc(10803,0);solution();wc(10803,1);wc(10807,1)
for i=1,30 do solution();cache();tick(1)end
assert(launches==1,'cannon selection retained bomb consent')
''')
print('Selected-store MODES on all four panels; cannon selection; guided CCIP capture, cache, release and cancellation PASS')
