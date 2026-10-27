"""Read the real physical adapter and weapon owner across supply/epoch failures."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
fixture = ROOT / 'tests/test_display_startup.py'
ns = {'__file__': str(fixture)}
exec(compile(fixture.read_text().split('\nfor page in ', 1)[0], str(fixture), 'exec'), ns)

lua = ns['runtime']()
lua.execute(r'''
local Model=dofile(SCRIPT_ROOT..'Systems/Weapon_Physical_State.lua')
local function put(n,v)get_param_handle(n):set(v)end
local function frame()
 for name,value in pairs({EFM_POWER_OWNER=1,EFM_PHYSICAL_VALID=1,
  EFM_PHYSICAL_GENERATION=1,EFM_PHYSICAL_STAMP=10,EFM_PHYSICAL_CLOCK_KIND=1,
  F22_AP_CLOCK=10,EFM_UTILITY_AVAILABLE=.6,EFM_MISSION_POWER_AVAILABLE=1,
  F22_ELECTRICAL_VALID=1,MAIN_POWER=1,EFM_VEHICLE_VALID=1,EFM_ACTUATOR_AVAILABLE=1})do put(name,value)end
end
function get_model_time()error('physical consumer used World epoch')end
put('MAIN_POWER',1);put('EFM_VEHICLE_VALID',1);put('EFM_ACTUATOR_AVAILABLE',.4)
local state=Model.new();state:update()
assert(not state.owned and state.utility==.4 and state.mission,'older DLL compatibility changed')
frame();state:update();assert(state.valid and state.utility==.6 and state.mission)
for _,case in ipairs({
 {'EFM_POWER_OWNER',0},{'EFM_PHYSICAL_VALID',0},{'EFM_PHYSICAL_GENERATION',0},
 {'EFM_PHYSICAL_GENERATION',1.5},{'EFM_PHYSICAL_GENERATION',4294967296},
 {'EFM_PHYSICAL_STAMP',-1},{'EFM_PHYSICAL_STAMP',9.74},{'EFM_PHYSICAL_STAMP',10.06},
 {'EFM_PHYSICAL_CLOCK_KIND',0},{'EFM_PHYSICAL_CLOCK_KIND',2},
 {'F22_AP_CLOCK',0/0},{'F22_AP_CLOCK',-1},{'EFM_UTILITY_AVAILABLE',0/0},
 {'EFM_UTILITY_AVAILABLE',-1},{'EFM_UTILITY_AVAILABLE',1.01},
 {'EFM_MISSION_POWER_AVAILABLE',2},{'F22_ELECTRICAL_VALID',0},{'MAIN_POWER',.5},
})do
 frame();put(case[1],case[2]);state:update()
 assert(state.owned and not state.valid and state.utility==0 and not state.mission,
  'invalid owned frame revived legacy authority: '..case[1])
end
frame();put('EFM_UTILITY_AVAILABLE',nil);state:update();assert(not state.valid)
frame();put('EFM_MISSION_POWER_AVAILABLE',0);state:update()
assert(state.valid and state.electrical and not state.mission and state.utility==.6,'APU service became mission power')
frame();put('EFM_ACTUATOR_AVAILABLE',0);state:update()
assert(state.valid and state.utility==.6,'flight-control authority replaced utility authority')
frame();put('EFM_UTILITY_AVAILABLE',0);state:update()
assert(state.valid and state.utility==0 and state.mission)

-- Mutate each commit marker while the payload is being sampled. There are no
-- retries and no acceptance of a mixed generation, stamp, clock-kind or owner.
local utility=get_param_handle('EFM_UTILITY_AVAILABLE');local original_get=utility.get
for _,case in ipairs({{'EFM_PHYSICAL_VALID',0},{'EFM_PHYSICAL_GENERATION',2},
 {'EFM_PHYSICAL_STAMP',10.01},{'EFM_PHYSICAL_CLOCK_KIND',2},{'EFM_POWER_OWNER',0}})do
 frame()
 function utility:get()put(case[1],case[2]);return self.value end
 state:update();assert(not state.valid and state.utility==0,'torn frame accepted: '..case[1])
 utility.get=original_get
end
frame();put('EFM_PHYSICAL_GENERATION',2);put('EFM_PHYSICAL_STAMP',0);put('F22_AP_CLOCK',0)
state:update();assert(state.valid and state.generation==2 and state.stamp==0,'new spawn epoch refused')
-- A new owner appearing during the legacy sample must withdraw that fallback.
frame();put('EFM_POWER_OWNER',0);put('EFM_PHYSICAL_VALID',0)
local older=get_param_handle('EFM_ACTUATOR_AVAILABLE');local old_get=older.get
function older:get()put('EFM_POWER_OWNER',1);return 1 end
local race=Model.new();race:update()
assert(race.owned and not race.valid and race.utility==0 and not race.mission)
older.get=old_get
''')
print('Weapons physical adapter: owner latch, coherent frames, finite/range/age checks, '
      'AP clock epoch, source separation and recovery PASS')

lua = ns['runtime']()
lua.execute(r'''
local now,clock=4000,10
function get_model_time()return now end
function get_aircraft_property()return 1 end
function get_aircraft_draw_argument_value(n)return draws[n]or 0 end
function set_aircraft_draw_argument_value(n,v)draws[n]=v end
local function put(n,v)get_param_handle(n):set(v)end
local function val(n)return get_param_handle(n):get()end
local count,launches,armed,gun=1,0,true,false -- native constructor starts armed
local bomb={level1=4,level2=5,level3=9,level4=32}
local ir={level1=4,level2=4,level3=7,level4=136}
local native={get_station_info=function(_,i)
 if i==4 then return {count=count,CLSID='{F22-MK83-TRAINING}',weapon=bomb}end
 if i==0 then return {count=1,CLSID='{5CE2FF2A-645A-4197-B48D-8720AC69394F}',weapon=ir}end
 return {count=0}
 end,select_station=function()end,launch_station=function(_,station)
  launches=launches+1;count=count-1
  local sequence=val('F22_LAUNCH_SEQUENCE')+1
  for key,value in pairs({SEQUENCE=sequence,ID=100+sequence,STATION=station,MODE=7,TYPE=32,TIME=now})do
   put('F22_SHOT_01_'..key,value)
  end
  put('F22_LAUNCH_SEQUENCE',sequence)
 end}
function GetDevice()return native end
function dispatch_action(_,command,_value)
 if command==283 then armed=not armed
 elseif command==84 then gun=true elseif command==85 then gun=false end
end
for name,value in pairs({MAIN_POWER=1,WoW=1,EFM_POWER_OWNER=1,EFM_PHYSICAL_VALID=1,
 EFM_PHYSICAL_GENERATION=1,EFM_PHYSICAL_STAMP=clock,EFM_PHYSICAL_CLOCK_KIND=1,
 F22_AP_CLOCK=clock,EFM_UTILITY_AVAILABLE=1,EFM_MISSION_POWER_AVAILABLE=0,
 F22_ELECTRICAL_VALID=1,EFM_VEHICLE_VALID=1,EFM_ACTUATOR_AVAILABLE=1})do put(name,value)end
dofile(SCRIPT_ROOT..'Systems/Weapon_System.lua');post_initialize();update()
local follow_stamp=true
local function tick(n,solution)
 for _=1,n do
  now=now+.02;clock=clock+.02;put('F22_AP_CLOCK',clock)
  if follow_stamp then put('EFM_PHYSICAL_STAMP',clock)end
  put('F22_AG_SOLUTION_SCHEMA',2);put('F22_AG_SOLUTION_VALID',solution==false and 0 or 1)
  put('F22_AG_SOLUTION_TIME',now);put('F22_AG_SOLUTION_STATION',4);update()
 end
end
put('F22_SMS_PROGRAM_PAGE',1);SetCommand(10975,1);SetCommand(10977,1)
assert(val('F22_SMS_ENTRY_FIELD')==1 and val('F22_SMS_ENTRY_LENGTH')==1,'APU-only power disabled low-load Stores entry')
SetCommand(10980,1);put('WoW',0);SetCommand(10800,7);SetCommand(10806,1);SetCommand(10803,1);tick(20)
assert(not armed and launches==0 and draws[600]==0 and val('F22_AG_RELEASE_CONSENT')==0,
 'MAIN_POWER bypassed unavailable mission power')

put('EFM_MISSION_POWER_AVAILABLE',1);put('EFM_UTILITY_AVAILABLE',0)
SetCommand(10803,0);SetCommand(10803,1);tick(20)
assert(armed and draws[600]==0 and launches==0,'flight-control supply opened failed utility bay')
put('EFM_ACTUATOR_AVAILABLE',0);put('EFM_UTILITY_AVAILABLE',.5);tick(1)
assert(math.abs(draws[600]-.025)<1e-8,'utility pressure did not set partial door rate')
tick(35);assert(launches==0,'commanded bay state bypassed achieved clearance')
tick(10);assert(launches==1 and val('F22_AG_RELEASE_SEQUENCE')==1,'utility recovery never delivered a confirmed native launch')

-- Prepare another request, then invalidate a new-owner frame. A healthy legacy
-- actuator value cannot move the door or keep arm/consent alive after the latch.
SetCommand(10803,0);count=1;CockpitEvent('UnlimitedWeaponStationRestore',{});tick(20,false)
SetCommand(10803,1);tick(1,false)
assert(val('F22_AG_RELEASE_CONSENT')==1)
local door=draws[600];put('EFM_PHYSICAL_VALID',0);put('EFM_ACTUATOR_AVAILABLE',1);tick(1)
assert(not armed and draws[600]==door and val('F22_BAY_ACTUATOR_AUTHORITY')==0
 and val('F22_SMS_PHYSICAL_VALID')==0 and val('F22_AG_RELEASE_CONSENT')==0
 and val('F22_IR_EXPOSURE_VALID')==0,'invalid frame retained owned authority')
put('EFM_POWER_OWNER',0);tick(1);assert(val('F22_BAY_ACTUATOR_AUTHORITY')==0,'owner loss revived legacy fallback')
put('EFM_POWER_OWNER',1);put('EFM_PHYSICAL_VALID',1);tick(30)
assert(launches==1 and val('F22_AG_RELEASE_CONSENT')==0,'valid recovery replayed cancelled release')
follow_stamp=false;tick(14);assert(val('F22_SMS_PHYSICAL_VALID')==0,'AP-clock stale frame stayed authoritative')
follow_stamp=true;tick(1);assert(val('F22_SMS_PHYSICAL_VALID')==1)

-- Same station/type in a new physical generation is a new seeker instance.
SetCommand(10803,0);SetCommand(10800,3);put('EFM_UTILITY_AVAILABLE',1);tick(20)
draws[601]=1;SetCommand(10805,1);SetCommand(10803,1);tick(1)
assert(val('F22_IR_RELEASE_REQUEST')==1 and val('F22_IR_EXPOSED')==1)
local instance=val('F22_IR_STORE_GENERATION')
put('EFM_PHYSICAL_GENERATION',2);tick(1)
assert(val('F22_IR_STORE_GENERATION')>instance and val('F22_IR_RELEASE_REQUEST')==0
 and val('F22_IR_CAGED')==1,'new physical generation retained seeker/release instance')

-- Gun door and drive use utility authority; mission loss also stops an
-- already-open gun immediately during an input call, before the next update.
SetCommand(10803,0);SetCommand(10800,5);put('EFM_UTILITY_AVAILABLE',0)
SetCommand(10801,1);SetCommand(10802,1);tick(20)
assert(draws[614]==0 and not gun)
put('EFM_UTILITY_AVAILABLE',1);tick(10);assert(gun and val('HUD_GUN_TRIGGER')==1)
local gun_door=draws[614];put('EFM_PHYSICAL_VALID',0);tick(1)
assert(draws[614]==gun_door and not gun and not armed)
put('EFM_PHYSICAL_VALID',1);tick(1);assert(not gun,'physical recovery replayed cancelled trigger')
SetCommand(10802,0);SetCommand(10802,1);tick(1);assert(gun)
put('EFM_MISSION_POWER_AVAILABLE',0);SetCommand(10801,0)
assert(not gun and not armed and val('F22_SMS_MISSION_POWER')==0,'APU-only transition waited for another update to stop native effects')
SetCommand(10802,1);put('EFM_MISSION_POWER_AVAILABLE',1);tick(1)
assert(not gun,'unpowered trigger press survived recovery before the next update')
SetCommand(10800,7);tick(1,false);put('EFM_MISSION_POWER_AVAILABLE',0)
SetCommand(10803,1);put('EFM_MISSION_POWER_AVAILABLE',1);draws[600]=1;tick(1)
assert(launches==1 and val('F22_AG_RELEASE_CONSENT')==0,
 'unpowered release press survived recovery before the next update')
''')
print('Actual weapon owner: APU entry/release split, utility drive/clearance, native launch ACK, '
      'invalid/stale frames, no fallback/replay, spawn/seeker generation and gun interlocks PASS')
