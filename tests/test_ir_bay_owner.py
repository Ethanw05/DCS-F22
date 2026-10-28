"""Exercise the actual display and weapon owners on their shared parameter bus.

The display's ground-service bay selection must never stow an airborne selected
missile. Native feedback here follows actual exposure; it does not acquire a
target on behalf of DCS.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
fixture = ROOT / 'tests/test_display_startup.py'
ns = {'__file__': str(fixture)}
exec(compile(fixture.read_text().split('\nfor page in ', 1)[0], str(fixture), 'exec'), ns)

for station in (0, 10):
    lua = ns['runtime']()
    lua.globals().ir_station = station
    lua.execute(r'''
local now, count, sequence = 4000, 1, 0
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
local sounds={}
function create_sound_host()return {create_sound=function(_,path)
 local s={starts=0,stops=0,playing=false};sounds[path]=s
 function s:update()end
 function s:play_continue()self.starts=self.starts+1;self.playing=true end
 function s:stop()self.stops=self.stops+1;self.playing=false end
 return s
end}end
local locked=false
local function native_feedback()
 sequence=sequence+2
 local exposed=g('F22_IR_EXPOSURE_VALID')==1 and g('F22_IR_EXPOSED')==1
 for name,value in pairs({OWNER=1,SCHEMA=1,VALID=exposed and 1 or 0,
  SEQUENCE=sequence,TIME=now,STATION=g('F22_IR_STATION'),
  GENERATION=g('F22_IR_STORE_GENERATION')})do p('F22_IR_SAMPLE_'..name,value)end
 for name,value in pairs({AVAILABLE=exposed and 1 or 0,LOCK=locked and 1 or 0,
  STRENGTH=locked and 2 or 0,WORLD_VALID=1,WORLD_FWD_N=1,
  WORLD_FWD_U=0,WORLD_FWD_E=0})do p('F22_IR_'..name,value)end
end
function dispatch_action(_,command)
 if command==10850 then native_feedback()end
end
for name,value in pairs({MAIN_POWER=1,WoW=0,RADAR_PWR=0,
 EFM_POWER_OWNER=1,EFM_PHYSICAL_VALID=1,EFM_PHYSICAL_GENERATION=1,
 EFM_PHYSICAL_STAMP=10,EFM_PHYSICAL_CLOCK_KIND=1,F22_AP_CLOCK=10,
 F22_ELECTRICAL_VALID=1,EFM_MISSION_POWER_AVAILABLE=1,EFM_UTILITY_AVAILABLE=1})do p(name,value)end
dofile(SCRIPT_ROOT..'Systems/Weapon_System.lua');post_initialize()
local weapon_update,weapon_command=update,SetCommand
weapon_command(10800,3);weapon_command(10806,1)
dofile(SCRIPT_ROOT..'Systems/MFD_System.lua')
local display_update,display_command=update,SetCommand
local function tick(n)
 for _=1,n do
  now=now+.02;p('F22_AP_CLOCK',now-3990);p('EFM_PHYSICAL_STAMP',now-3990)
  -- The display runs faster than Weapons in DCS and publishes its service
  -- selector continuously. Run it on both sides of each weapon callback.
  display_update();weapon_update();display_update()
 end
end
tick(40)
local door=ir_station==0 and 601 or 602
local other=ir_station==0 and 602 or 601
assert(draws[door]>=.98 and draws[other]==0 and draws[600]==0,
 'display service selector opened the wrong airborne missile bay')
assert(g('BAY_STATION')==2,'weapon owner overwrote the pilot service selector')
local generation=g('F22_IR_STORE_GENERATION')
local search=sounds['Aircrafts/F-22A/IR/search']
assert(search.playing and search.starts==1 and search.stops==0,
 'steady native search did not produce one continuous loop')
for _,selector in ipairs({1,3,4,2})do
 display_command(selector==1 and 10000 or selector==3 and 10001 or selector==4 and 10003 or 10002,1)
 for _=1,40 do
  tick(1)
  assert(g('F22_IR_EXPOSED')==1 and g('HUD_IR_SEEKER_AVAILABLE')==1,
   'display refresh interrupted prepared native seeker exposure')
  assert(g('F22_IR_STORE_GENERATION')==generation,'display refresh replaced the store instance')
 end
end
assert(search.starts==1 and search.stops==0,'service selection chopped the search loop')
locked=true;tick(2)
local track=sounds['Aircrafts/F-22A/IR/track']
for _=1,200 do tick(1);assert(g('HUD_IR_SEEKER_VALID')==1,'display refresh withdrew a current native lock')end
assert(track.playing and track.starts==1 and track.stops==0,'service selection chopped the track loop')
weapon_command(10806,0);tick(2)
assert(g('F22_IR_EXPOSED')==0 and g('HUD_IR_SEEKER_AVAILABLE')==0 and not track.playing,
 'SAFE retained native exposure/audio')
-- Ground service remains owned by the manual selector.
p('WoW',1);tick(2);display_command(10003,1);tick(500)
assert(g('BAY_STATION')==4 and draws[600]>=.98 and draws[601]>=.98 and draws[602]>=.98,
 'airborne selection removed the pilot ground-service bay controls')
''')
    print(f'IR station {station}: actual display/weapon interleaving, correct achieved bay, '
          'continuous search/track, SAFE and ground service PASS')
