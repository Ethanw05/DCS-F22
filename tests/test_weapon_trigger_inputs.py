"""Actual saved detent bindings and Combat/Weapon owners cannot fire on release."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
fixture = ROOT / 'tests/test_display_startup.py'
ns = {'__file__': str(fixture)}
exec(compile(fixture.read_text().split('\nfor page in ', 1)[0], str(fixture), 'exec'), ns)
lua = ns['runtime']()
lua.execute(r'''
function _(s)return s end
function external_profile()return {keyCommands={},axisCommands={}}end
function ignore_features()end
function join(destination,items)for i=1,#items do destination[#destination+1]=items[i]end end
local function binding(profile,id)
 for i=1,#profile.keyCommands do if profile.keyCommands[i].down==id then return profile.keyCommands[i]end end
 error('missing binding '..id)
end
local profiles={}
for _,kind in ipairs({'joystick','keyboard'})do
 folder=SCRIPT_ROOT..'../../Input/F-22A/'..kind..'/'
 local profile=dofile(SCRIPT_ROOT..'../../Input/F-22A/'..kind..'/default.lua')
 for _,id in ipairs({10716,10717,10718})do
  local b=binding(profile,id)
  assert(b.up==id and b.value_down==1 and b.value_up==0,'ambiguous momentary descriptor '..id)
 end
 profiles[kind]=profile
end
-- Historical detent descriptors still exercise the internal owner below;
-- only the canonical HOTAS descriptors remain in the options catalog.
local detent={down=10022,up=10022,value_down=1,value_up=0}
local first={down=10021,up=10021,value_down=1,value_up=0}
local hotas=binding(profiles.joystick,10717)
local pickle=binding(profiles.joystick,10718)
function get_aircraft_property()return 1 end
function get_aircraft_draw_argument_value(n)return draws[n]or 0 end
function set_aircraft_draw_argument_value(n,v)draws[n]=v end
local native={get_station_info=function()return {count=0,weapon={}}end,select_station=function()end}
function GetDevice()return native end
local function p(n,v)get_param_handle(n):set(v)end
local function g(n)return get_param_handle(n):get()end
local weapon_set, starts, stops = nil, 0, 0
function dispatch_action(device,command,value)
 if device==devices.WEAPON_SYSTEM and weapon_set then weapon_set(command,value)
 elseif command==84 then starts=starts+1
 elseif command==85 then stops=stops+1 end
end
p('MAIN_POWER',1);p('WoW',0)
dofile(SCRIPT_ROOT..'Systems/Weapon_System.lua');post_initialize()
weapon_set=SetCommand
local weapon_update=update
local function tick(count)for i=1,count or 1 do weapon_update()end end
weapon_set(10800,5);weapon_set(10806,1);tick(30)
weapon_set(detent.up,detent.value_up);tick(30)
assert(g('HUD_GUN_TRIGGER')==0 and starts==0,'orphan release started cannon')
weapon_set(first.up,first.value_up);tick();assert(g('DETENT')==0)

-- One physical press stays held without repeat events. Repeats/releases are
-- idempotent, and each detent releases only its own current command source.
weapon_set(first.down,first.value_down);tick()
assert(g('DETENT')==.5 and g('HUD_GUN_TRIGGER')==0)
weapon_set(detent.down,detent.value_down);tick(60)
assert(g('HUD_GUN_TRIGGER')==1 and starts==1,'held press did not keep firing')
for i=1,20 do weapon_set(detent.down,detent.value_down);tick()end
assert(starts==1 and g('HUD_GUN_TRIGGER')==1,'repeated press toggled/restarted cannon')
weapon_set(first.up,first.value_up);tick()
assert(g('DETENT')==1 and g('HUD_GUN_TRIGGER')==1,'first detent release cancelled second detent')
weapon_set(detent.up,detent.value_up);local stopped=stops;tick()
assert(g('HUD_GUN_TRIGGER')==0)
weapon_set(detent.up,detent.value_up);tick()
assert(starts==1 and stops==stopped,'duplicate release changed native firing state')

-- Test the real dedicated HOTAS owner, including packed device values. Its
-- second-stage trigger is10717;10718 is pickle and cannot steal gun ownership.
dofile(SCRIPT_ROOT..'Systems/Combat_System.lua');post_initialize()
local combat_set=SetCommand
local combat_update=update
combat_set(hotas.down,devices.COMBAT_SYSTEM+.375);tick(30)
assert(g('HUD_GUN_TRIGGER')==1)
local held_starts=starts
weapon_set(detent.up,detent.value_up);tick()
assert(g('HUD_GUN_TRIGGER')==1 and starts==held_starts,'orphan other-source release stopped HOTAS trigger')
weapon_set(detent.down,detent.value_down);tick()
combat_set(hotas.up,devices.COMBAT_SYSTEM+.25);tick()
assert(g('HUD_GUN_TRIGGER')==1,'HOTAS release stopped separately held saved trigger')
combat_set(pickle.up,pickle.value_up);tick()
assert(g('HUD_GUN_TRIGGER')==1,'unrelated weapon-release event cancelled trigger')
combat_set(10742,3);p('LMFD_PAGE',3);p('F22_PMFD_PAGE',4);tick(30)
assert(g('HUD_GUN_TRIGGER')==1,'focus/page change stole a held trigger')
weapon_set(detent.up,detent.value_up);tick()
assert(g('HUD_GUN_TRIGGER')==0)

-- SAFE/mode/power cancellation consumes accepted consent, retaining the down
-- latch until its matching physical release. Neither restoration nor repeats
-- of the held input may act as a fresh press.
weapon_set(detent.down,1);tick();assert(g('HUD_GUN_TRIGGER')==1)
weapon_set(10806,0);tick();assert(g('HUD_GUN_TRIGGER')==0)
local safe_starts=starts
weapon_set(10806,1);weapon_set(detent.down,1);tick(30)
assert(g('HUD_GUN_TRIGGER')==0 and starts==safe_starts,'SAFE restoration replayed held trigger')
weapon_set(detent.up,0);weapon_set(detent.down,1);tick(30);assert(g('HUD_GUN_TRIGGER')==1)
weapon_set(10800,1);tick();weapon_set(10800,5);weapon_set(detent.down,1);tick(30)
assert(g('HUD_GUN_TRIGGER')==0,'mode restoration replayed held trigger')
weapon_set(detent.up,0);weapon_set(detent.down,1);tick(30);assert(g('HUD_GUN_TRIGGER')==1)
p('MAIN_POWER',0);tick();assert(g('HUD_GUN_TRIGGER')==0)
local outage_starts=starts
p('MAIN_POWER',1);weapon_set(detent.down,1);tick(30)
assert(g('HUD_GUN_TRIGGER')==0 and starts==outage_starts,'power restoration replayed held trigger')
weapon_set(detent.up,0);weapon_set(detent.down,1);tick(30);assert(g('HUD_GUN_TRIGGER')==1)
p('MAIN_POWER',0);weapon_set(detent.up,0);tick()
p('MAIN_POWER',1);tick(30);assert(g('HUD_GUN_TRIGGER')==0,'unpowered release was lost')
weapon_set(detent.down,devices.WEAPON_SYSTEM+.375);tick(30);assert(g('HUD_GUN_TRIGGER')==1)
weapon_set(detent.up,devices.WEAPON_SYSTEM+.25);tick();assert(g('HUD_GUN_TRIGGER')==0)
for _,bad in ipairs({0/0,math.huge,-math.huge,'bad',2,-1})do
 weapon_set(detent.down,bad);tick();assert(g('HUD_GUN_TRIGGER')==0,'malformed trigger value started cannon')
end
for _,bad in ipairs({0/0,math.huge,-math.huge,'bad',2,-1})do
 weapon_set(detent.up,0);weapon_set(detent.down,1);tick(30);assert(g('HUD_GUN_TRIGGER')==1)
 weapon_set(10806,0);weapon_set(detent.down,bad)
 weapon_set(10806,1);weapon_set(detent.down,1);tick(30)
 assert(g('HUD_GUN_TRIGGER')==0,'malformed value erased held trigger ownership before real UP')
end
weapon_set(detent.up,0)
combat_set(hotas.down,1);tick(30);assert(g('HUD_GUN_TRIGGER')==1)
p('MAIN_POWER',0);combat_update();tick();assert(g('HUD_GUN_TRIGGER')==0)
local routed_starts=starts
p('MAIN_POWER',1);combat_update();combat_set(hotas.down,1);tick(30)
assert(g('HUD_GUN_TRIGGER')==0 and starts==routed_starts,
 'HOTAS power owner fabricated a release and replayed physically held trigger')
combat_set(hotas.up,0);combat_set(hotas.down,1);tick(30)
assert(g('HUD_GUN_TRIGGER')==1,'real HOTAS release/press did not recover')
combat_set(hotas.up,0);tick();assert(g('HUD_GUN_TRIGGER')==0)
''')
print('Actual weapon/Combat owners: saved descriptors, orphan/duplicate release, held/repeated press, '
      'detent/source ownership, HOTAS10717/pickle10718, focus/mode/SAFE/power and packed values PASS')
