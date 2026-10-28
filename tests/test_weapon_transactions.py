"""Exercise station generations, captured missions, cause-aware ACK and owner mailbox."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
f=ROOT/'tests/test_display_startup.py';ns={'__file__':str(f)}
exec(compile(f.read_text().split('\nfor page in ',1)[0],str(f),'exec'),ns)
lua=ns['runtime']()
lua.execute(r'''
local Model=dofile(SCRIPT_ROOT..'Systems/AG_Stores.lua')
local function load(count)return {count=count,CLSID='{GBU_32_V_2B}',
 weapon={level1=4,level2=5,level3=36,level4=85}}end
local m=Model.new();m:refresh({[4]=load(2)})
local early=Model.new();early:service(true);early:refresh({[4]=load(1)})
assert(early:generation(4)>1,'service before first sample reused an initial instance generation')
assert(m:capture_target(4,{n=10000,u=400,e=200,source=3,sequence=7,time=5}))
assert(m:start(10,99,{n=500,u=0,e=600,sequence=99}))
assert(m:consent_current(4,100),'unrelated live mark revoked captured mission')
assert(m.program.targets[4].source_sequence==7 and m.program.targets[4].time==5)
m:cancel();m:clear_target(4);assert(m:start(10,99,{n=500,u=0,e=600,sequence=99}))
assert(not m:consent_current(4,100),'live TOO changed without reconsent')
m:cancel();local generation=m:generation(4)
assert(m:select_mission(4,1)and m:target(4).n==10000)
assert(m:start(10,7)and m:request(4,load(2),10,nil,100))
m:service(false);m:refresh({[4]=load(2)})
assert(not m.program and not m.pending and not m:start(10.1),'service retained release consent')
m:service(true);assert(m:generation(4)>generation and not m:target(4))
assert(m:profile().quantity==1 and m:select_mission(4,1),'service erased retained mission/profile')
m:select_mission(4,2);assert(not m:target(4)and m:mission_mode(4)==2,'empty PP became live TOO')
assert(m:capture_target(4,{n=20000,u=700,e=100}))
m:select_mission(4,1);assert(m:target(4).n==10000)
m:select_mission(4,2);assert(m:target(4).n==20000)
-- Missing station inventory fails closed; a known refill creates another instance.
m:refresh({});assert(m:ready_count()==0)
m:refresh({[4]=load(3)});assert(m:generation(4)>generation+1)

local now,count,calls=20,3,0
function get_model_time()return now end
function get_aircraft_property()return 1 end
local native={get_station_info=function(_,s)return s==4 and load(count)or {count=0}end,
 select_station=function()end,launch_station=function()calls=calls+1 end,
 get_chaff_count=function()return 100 end,get_flare_count=function()return 100 end}
function GetDevice()return native end
local function p(k,v)get_param_handle(k):set(v)end
local function g(k)return get_param_handle(k):get()end
p('MAIN_POWER',1);p('WoW',0)
dofile(SCRIPT_ROOT..'Systems/Weapon_System.lua');post_initialize();update()
p('F22_SMS_PROGRAM_PAGE',1)
local function enter(value)
 SetCommand(10975,1);SetCommand(10977,value)
end
enter(2)
for key,value in pairs({REQUEST=1,ACTIVE=1,COMMAND=10979,VALUE=2})do p('F22_ENTRY_STORES_'..key,value)end
SetCommand(11800,1)
assert(g('F22_ENTRY_STORES_ACK_REQUEST')==1 and g('F22_ENTRY_STORES_RESULT')==1)
assert(g('F22_SMS_QUANTITY')==2 and g('F22_SMS_ENTRY_FIELD')==0)
enter(3);SetCommand(11800,1)
assert(g('F22_SMS_QUANTITY')==2 and g('F22_SMS_ENTRY_FIELD')==1,'duplicate token committed a later draft')
p('F22_ENTRY_STORES_REQUEST',2);p('F22_ENTRY_STORES_VALUE',3);p('F22_ENTRY_STORES_ACTIVE',0)
SetCommand(11800,2);assert(g('F22_SMS_QUANTITY')==2,'cancelled dispatch applied')
p('F22_ENTRY_STORES_ACTIVE',1);p('F22_ENTRY_STORES_VALUE',1);SetCommand(11800,2)
assert(g('F22_ENTRY_STORES_RESULT')==2 and g('F22_SMS_QUANTITY')==2,'mismatched buffer accepted')
-- Jettison interrupts all requests in the command call, before native effects.
SetCommand(10800,7);SetCommand(10806,1);update();SetCommand(10803,1)
assert(g('F22_AG_RELEASE_CONSENT')==1)
SetCommand(Keys.PiCommandSelecterUplaneJettisonWeapons,1)
assert(g('F22_AG_RELEASE_CONSENT')==0 and g('F22_SMS_RELEASE_PENDING')==0)
SetCommand(10803,0);SetCommand(10803,1);assert(g('F22_AG_RELEASE_CONSENT')==1)
CockpitEvent('WeaponRearmFirstStep',{})
assert(g('F22_AG_RELEASE_CONSENT')==0 and g('F22_SMS_SERVICE_ACTIVE')==1)
local old=g('F22_SMS_STATION_04_GENERATION')
CockpitEvent('WeaponRearmComplete',{});update()
assert(g('F22_SMS_SERVICE_ACTIVE')==0 and g('F22_SMS_STATION_04_GENERATION')>old)
SetCommand(10803,0);SetCommand(11120,1);SetCommand(11120,0);SetCommand(10803,1)
assert(handles['F22_SMS_SIM']==nil and g('F22_AG_RELEASE_CONSENT')==1,'retired SIM command still inhibits weapons')
SetCommand(10806,0);update()
for _=1,30 do now=now+.02;update()end
assert(calls==0 and g('F22_IR_RELEASE_REQUEST')==0 and g('HUD_GUN_TRIGGER')==0)
''')
print('Weapons transactions: PP/TOO, service, mailbox, jettison, removed SIM command and retained SAFE inhibition PASS')
