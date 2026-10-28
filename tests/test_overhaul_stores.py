"""Ground employment contracts against the real Lua stores/controller/geometry."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
fixture=ROOT/'tests/test_display_startup.py';ns={'__file__':str(fixture)}
exec(compile(fixture.read_text().split('\nfor page in ',1)[0],str(fixture),'exec'),ns)
runtime=ns['runtime']

lua=runtime()
lua.execute(r'''
local c=dofile(SCRIPT_ROOT..'Systems/Store_Capabilities.lua')
local function info(id,count,type3)return {CLSID=id,count=count,weapon={level1=4,level2=5,level3=type3 or 9,level4=32}}end
for _,r in ipairs({{'{AIM-260A}',2,9},{'{LAU_115_2xAIM-260A}',2,9},{'{MAKO_A2A_C}',2,10},{'{MAKO_A2G_C}',7,11},{'{F22_IRST}',false,13},{'CATM-9M',false,15}})do
 local cap=c.describe(info(r[1],1));assert(cap and cap.label==r[3] and (cap.kind or false)==r[2])
end
assert(c.mode_available(c.describe(info('{GBU_32_V_2B}',1)),2))
assert(not c.mode_available(c.describe(info('{GBU_32_V_2B}',1)),1))
assert(c.mode_available(c.describe(info('{GBU_32_V_2B}',1)),3))
assert(not c.mode_available(c.describe(info('{MAKO_A2G_C}',1)),3))
assert(not c.describe(info('{AIM-260A}',0)))
local m=dofile(SCRIPT_ROOT..'Systems/AG_Stores.lua').new()
local a,b=info('{F22-MK83-TRAINING}',4),info('{GBU_32_V_2B}',1,36)
m:refresh({[4]=a,[6]=b});assert(m:profile().interval_mode==1)
m:profile().quantity=4;m:edit('pair');assert(m:profile().pair==2)
m:begin_entry(4);m:digit(2);assert(m:commit()and m:profile().quantity==4)
m:begin_entry(3);for _,n in ipairs({2,0,0})do m:digit(n)end;assert(m:commit())
assert(m:start(10));assert(m:due(10));assert(not m:released(10,{n=1000,e=0,vn=200,ve=0}))
assert(m:due(10.02));assert(not m:released(10.02,{n=1000,e=0,vn=200,ve=0}))
assert(not m:due(11,{n=1060,e=0}),'spacing feet treated as elapsed time')
assert(not m:due(11,{n=1061,e=100}),'cross-track turn faked along-track spacing')
assert(m:due(11,{n=1061,e=0}),'predicted impact spacing did not release next pulse')
m:cancel();m:edit('profile');assert(m:profile_index()==2 and m:profile().quantity==1)
m:profile().quantity=2;m:step(1);assert(m:profile().quantity==1 and m:profile().mode==3)
m:step(-1);assert(m:profile_index()==2 and m:profile().quantity==2)
m:edit('profile');assert(m:profile().quantity==4 and m:profile().spacing_ft==200 and m:profile().pair==2)
m:step(1);assert(m:capture_target(6,{n=10000,u=500,e=300}))
assert(m:target(6).n==10000);assert(m:start(12));assert(m.program.targets[6].e==300)
m:cancel();m:refresh({[4]=a,[6]=info('{F22-MK83-TRAINING}',1)})
assert(not m:target(6),'target assignment leaked to a different station store')
''')

lua=runtime()
lua.execute(r'''
local d=dofile(SCRIPT_ROOT..'Systems/AG_Delivery.lua')
local p=d.ground({{n=0,u=100,e=0,t=0},{n=1000,u=80,e=0,t=5},{n=2000,u=0,e=0,t=10}},function(n)return n>=450 and n<=550 and 200 or 0 end)
assert(p and math.abs(p.n-450)<.01 and p.t>2 and p.t<3,'intervening ridge was skipped')
local own,impact,target={n=0,u=2000,e=0},{n=5000,e=0},{n=5500,u=0,e=500}
assert(not d.release(impact,target,200,0,20).ready)
local lar=d.guided(own,impact,target,200,0,0,20)
assert(lar and lar.ready and lar.estimated and lar.maximum<=24140,'JDAM still uses narrow unguided release window')
assert(not d.guided(own,impact,{n=-5000,u=0,e=0},200,0,0,20).ready)
assert(not d.guided({n=0,u=100,e=0},impact,target,200,0,0,20).ready)
assert(not d.guided(own,impact,target,40,0,0,20).ready)
''')

lua=runtime()
lua.execute(r'''
local now=20;function get_model_time()return now end
function get_aircraft_property()return 1 end
function get_aircraft_draw_argument_value(n)return draws[n]or 0 end
function set_aircraft_draw_argument_value(n,v)draws[n]=v end
local calls=0;local station=-1
local payload={
 [0]={count=1,CLSID='{5CE2FF2A-645A-4197-B48D-8720AC69394F}',weapon={level1=4,level2=4,level3=7,level4=136}},
 [4]={count=2,CLSID='{GBU_32_V_2B}',weapon={level1=4,level2=5,level3=36,level4=85}},
 [6]={count=1,CLSID='{MAKO_A2G_C}',weapon={level1=4,level2=4,level3=7,level4=190}},
 [7]={count=1,CLSID='{GBU_32_V_2B}',weapon={level1=4,level2=5,level3=36,level4=85}},
}
native={get_station_info=function(_,i)return payload[i]or {count=0}end,select_station=function(_,s)station=s end,
 launch_station=function()calls=calls+1;return 123 end,get_chaff_count=function()return 120 end,get_flare_count=function()return 120 end}
function GetDevice()return native end
local function put(n,v)get_param_handle(n):set(v)end
local function val(n)return get_param_handle(n):get()end
dofile(SCRIPT_ROOT..'Systems/Weapon_System.lua');post_initialize();put('MAIN_POWER',1);put('WoW',0)
update();assert(val('F22_SMS_STATION_00_LABEL')==6 and val('F22_SMS_STATION_00_PRESENT')==1)
assert(val('F22_SMS_AVAILABLE')==3 and station==-1,'NAV erased loaded class inventory')
put('CMFD_BAY_PAGE',1);put('F22_SMS_PROGRAM_PAGE',1)
SetCommand(10975,1);SetCommand(10977,2);SetCommand(10979,1);assert(val('F22_SMS_QUANTITY')==2,'SAFE NAV entry failed')
put('HUD_AG_TARGET_VALID',1);put('HUD_AG_MARK_NORTH',10000);put('HUD_AG_MARK_ALT',500);put('HUD_AG_MARK_EAST',300)
SetCommand(10987,1);assert(val('F22_SMS_TARGET_VALID')==1 and val('F22_SMS_TARGET_SOURCE')==2)
put('HUD_AG_MARK_NORTH',90000);update();assert(val('F22_SMS_TARGET_N')==10000,'stored station target followed live designation')
SetCommand(10804,1);assert(val('F22_SMS_TARGET_STATION_DISPLAY')==8 and station==-1,'NAV program station step selected a live weapon')
put('HUD_AG_MARK_NORTH',12000);SetCommand(10987,1);assert(val('F22_SMS_STATION_07_TARGET_VALID')==1 and val('F22_SMS_TARGET_N')==12000)
SetCommand(10804,1);assert(val('F22_SMS_TARGET_STATION_DISPLAY')==5 and val('F22_SMS_TARGET_N')==10000,'two station target assignments collapsed to one point')
SetCommand(10981,2);assert(val('F22_SMS_LABEL')==11 and val('F22_SMS_STATUS')==8)
assert(val('F22_SMS_MODE_AVAILABLE_2')==0 and val('F22_SMS_MODE_AVAILABLE_3')==0)
SetCommand(10981,1);SetCommand(10807,1);update()
assert(val('HUD_AG_SUBMODE')==1 and val('F22_SMS_MODE_TEXT')=='GUN')
SetCommand(10981,1);update();assert(val('HUD_AG_SUBMODE')==3,'global GUN overwrote retained JDAM AUTO profile')
SetCommand(10800,7);SetCommand(10806,1)
local function cache_ack()
 put('F22_AG_SOLUTION_SEQUENCE',1);put('F22_AG_GUIDANCE_CACHE_VALID',1);put('F22_AG_GUIDANCE_CACHE_TIME',now)
 put('F22_AG_GUIDANCE_CACHE_STATION',4);put('F22_AG_GUIDANCE_CACHE_SOLUTION_SEQUENCE',1)
 for _,key in ipairs({'SOURCE','SEQUENCE','N','U','E'})do put('F22_AG_GUIDANCE_CACHE_TARGET_'..key,val('F22_AG_DELIVERY_TARGET_'..key))end
end
for i=1,100 do
 now=now+.02;put('F22_AG_SOLUTION_SCHEMA',2);put('F22_AG_SOLUTION_VALID',1);put('F22_AG_SOLUTION_TIME',now);put('F22_AG_SOLUTION_STATION',4)
 put('F22_AG_AUTO_RELEASE',1);put('F22_AG_GUIDANCE_BACKEND_READY',1);cache_ack();update()
end
SetCommand(10803,1)
for i=1,100 do
 now=now+.02;put('F22_AG_SOLUTION_SCHEMA',2);put('F22_AG_SOLUTION_VALID',1);put('F22_AG_SOLUTION_TIME',now);put('F22_AG_SOLUTION_STATION',4)
 put('F22_AG_AUTO_RELEASE',1);cache_ack();update()
end
assert(calls==1 and val('F22_AG_RELEASE_SEQUENCE')==0 and val('F22_SMS_RELEASE_FAILED')==1,'successful function return advanced or retried failed physical release')
local active=val('F22_SMS_TARGET_STATION');SetCommand(10988,1);assert(val('F22_SMS_TARGET_SOURCE')==1 and val(string.format('F22_SMS_STATION_%02d_TARGET_VALID',active))==0)
''')
print('Overhaul stores: explicit capability masks, retained profiles, real impact spacing/pulses, terrain ridge, estimated guided LAR, SAFE NAV keypad, station targets and failed native request PASS')
