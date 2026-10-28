"""Selected SRM prepares its actual bay before pickle or seeker-head uncage."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
fixture = ROOT / 'tests/test_display_startup.py'
ns = {'__file__': str(fixture)}
exec(compile(fixture.read_text().split('\nfor page in ', 1)[0], str(fixture), 'exec'), ns)

for station in (0, 10):
    lua = ns['runtime']()
    lua.globals().ir_station = station
    lua.execute(r'''
local now, clock, count, sequence = 4000, 10, 1, 0
local function p(n,v)get_param_handle(n):set(v)end
local function g(n)return get_param_handle(n):get()end
function get_model_time()return now end
function get_aircraft_property()return 1 end
function get_aircraft_draw_argument_value(n)return draws[n]or 0 end
function set_aircraft_draw_argument_value(n,v)draws[n]=v end
local native={get_station_info=function(_,i)
 return {count=i==ir_station and count or 0,CLSID='{AIM9X-BLKII}',
  weapon={level1=4,level2=4,level3=7,level4=474}}
end,select_station=function()end}
function GetDevice()return native end
local generic_releases=0
function dispatch_action(_,command)
 if command==350 then generic_releases=generic_releases+1 end
end
for name,value in pairs({MAIN_POWER=1,WoW=0,RADAR_PWR=0,
 EFM_POWER_OWNER=1,EFM_PHYSICAL_VALID=1,EFM_PHYSICAL_GENERATION=1,
 EFM_PHYSICAL_STAMP=clock,EFM_PHYSICAL_CLOCK_KIND=1,F22_AP_CLOCK=clock,
 F22_ELECTRICAL_VALID=1,EFM_MISSION_POWER_AVAILABLE=1,EFM_UTILITY_AVAILABLE=1})do p(name,value)end
dofile(SCRIPT_ROOT..'Systems/Weapon_System.lua');post_initialize()
local function feedback(locked)
 sequence=sequence+2
 for name,value in pairs({OWNER=1,SCHEMA=1,VALID=1,SEQUENCE=sequence,TIME=now,
  STATION=g('F22_IR_STATION'),GENERATION=g('F22_IR_STORE_GENERATION')})do p('F22_IR_SAMPLE_'..name,value)end
 for name,value in pairs({AVAILABLE=1,LOCK=locked and 1 or 0,STRENGTH=locked and 2 or 0,
  WORLD_VALID=1,WORLD_FWD_N=1,WORLD_FWD_U=0,WORLD_FWD_E=0})do p('F22_IR_'..name,value)end
end
local function tick(n, native_feedback)
 for _=1,n do
  now=now+.02;clock=clock+.02;p('F22_AP_CLOCK',clock);p('EFM_PHYSICAL_STAMP',clock)
  if native_feedback~=nil then feedback(native_feedback)end
  update()
 end
end
local door=ir_station==0 and 601 or 602
local other=ir_station==0 and 602 or 601
SetCommand(10800,3);tick(25)
assert(draws[door]==0 and g('F22_IR_EXPOSED')==0,'SAFE prepared a physical weapon')
SetCommand(10806,1);tick(1)
assert(g('F22_IR_CAGED')==1 and g('F22_IR_EXPOSED')==0 and draws[door]<.98,
 'commanded preparation bypassed achieved clearance')
tick(25)
assert(g('F22_IR_STATION')==ir_station and draws[door]>=.98 and draws[other]==0,
 'selected caged SRM did not achieve preparation in its own side bay')
assert(g('F22_IR_EXPOSED')==1 and g('F22_IR_RELEASE_REQUEST')==0 and g('PICKLE')==0,
 'selected caged SRM required a release press to prepare its seeker')
assert(g('HUD_IR_SEEKER_AVAILABLE')==0,'bay position fabricated native seeker feedback')
tick(1,false)
assert(g('F22_IR_CAGED')==1 and g('HUD_IR_SEEKER_AVAILABLE')==1
 and g('HUD_IR_SEEKER_VALID')==0,'current caged native search did not reach HUD before pickle')
SetCommand(10805,1);tick(1,true)
assert(g('F22_IR_CAGED')==0 and g('HUD_IR_SEEKER_VALID')==1)
SetCommand(10803,1);tick(1,true)
assert(g('F22_IR_RELEASE_REQUEST')==1 and g('F22_IR_EXPOSED')==1,
 'first consent after preparation never reached the typed native seeker')
assert(generic_releases==0,'SRM release used the generic empty seeker')
SetCommand(10803,0);tick(25,true)
assert(g('F22_IR_RELEASE_REQUEST')==0 and g('F22_IR_EXPOSED')==1
 and g('HUD_IR_SEEKER_VALID')==1,'pickle UP stowed an otherwise prepared seeker')
SetCommand(10805,1);tick(25,false)
assert(g('F22_IR_CAGED')==1 and draws[door]>=.98 and g('HUD_IR_SEEKER_AVAILABLE')==1,
 'head recage stowed the selected missile or erased current search feedback')
SetCommand(10806,0);tick(25)
assert(draws[door]==0 and g('F22_IR_EXPOSED')==0 and g('HUD_IR_SEEKER_AVAILABLE')==0,
 'SAFE retained physical preparation/current feedback')
SetCommand(10806,1);tick(25)
assert(g('F22_IR_EXPOSED')==1 and g('HUD_IR_SEEKER_AVAILABLE')==0,
 're-preparation revived stale native feedback')
tick(1,false);assert(g('HUD_IR_SEEKER_AVAILABLE')==1)
p('EFM_PHYSICAL_VALID',0);tick(1,true)
assert(g('F22_IR_EXPOSURE_VALID')==0 and g('F22_IR_EXPOSED')==0
 and g('HUD_IR_SEEKER_AVAILABLE')==0 and g('F22_IR_RELEASE_REQUEST')==0)
p('EFM_PHYSICAL_VALID',1);p('EFM_PHYSICAL_GENERATION',2);tick(25)
assert(g('F22_IR_EXPOSED')==1 and g('F22_IR_CAGED')==1
 and g('F22_IR_RELEASE_REQUEST')==0 and g('HUD_IR_SEEKER_VALID')==0,
 'supply recovery replayed old lock/consent instead of preparing a current instance')
count=0;tick(30)
assert(g('F22_WEAPON_COUNT')==0 and draws[door]==0 and g('F22_IR_EXPOSED')==0,
 'empty SRM station stayed exposed')
count=1;SetCommand(10800,3);tick(30,false)
SetCommand(10800,1);tick(30)
assert(draws[door]==0 and g('HUD_IR_SEEKER_AVAILABLE')==0 and g('F22_IR_EXPOSED')==0,
 'leaving SRM mode kept a seeker/current exposure indication')
''')
    print(f'Actual weapon owner: station{station} caged preparation, achieved exposure before consent, '
          'native feedback, pickle/head independence, supply/instance recovery and stow PASS')
