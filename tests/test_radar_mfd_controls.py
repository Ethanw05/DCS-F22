"""Exercise real bezel routing, native scan outputs and saved-input compatibility."""
from pathlib import Path
import contextlib
import io
import runpy

ROOT = Path(__file__).resolve().parents[1]
with contextlib.redirect_stdout(io.StringIO()):
    runtime = runpy.run_path(str(ROOT / 'tests/test_display_startup.py'))['runtime']

lua = runtime()
lua.execute('''
native={set_power=function() end};function GetDevice(_) return native end
dofile(SCRIPT_ROOT..'Systems/Radar_System.lua')
dofile(SCRIPT_ROOT..'../../tests/radar_body_fixture.lua');post_initialize()
radar_command=SetCommand;radar_update=update
local function put(n,v) get_param_handle(n):set(v) end
local function val(n) return get_param_handle(n):get() end
put('MAIN_POWER',1);put('F22N_RADAR_MODE',1)
radar_command(10601,1);radar_update()
dofile(SCRIPT_ROOT..'Systems/PMFD_System.lua');post_initialize()
local routed={}
function dispatch_action(device,command,value)
 if command==10742 then
  assert(device==devices.COMBAT_SYSTEM and value==2,'primary bezel notified wrong focus')
  return
 end
 routed[#routed+1]={device,command,value}
 if device==devices.RADAR_COMPUTER then radar_command(command,value) end
end
local function click(command)
 routed={};SetCommand(command,1);SetCommand(command,0);radar_update()
 assert(#routed==1,'bezel click/release dispatched more than one action')
 assert(routed[1][1]==devices.RADAR_COMPUTER,'scan bypassed radar owner')
end
-- The visible label, numbered physical OSB and bindable OSB have one meaning.
for _,commands in ipairs({
 {device_commands.Button_20,device_commands.Button_19,device_commands.Button_18,device_commands.Button_17,device_commands.Button_16},
 {10150,10149,10148,10147,10146},
}) do
 local width=val('F22_RADAR_SEARCH_WIDTH_DEG')
 click(commands[1]);assert(routed[1][2]==10616)
 local nextwidth=width==120 and 60 or width==60 and 30 or 120
 assert(val('F22_RADAR_SEARCH_WIDTH_DEG')==nextwidth)
 assert(math.abs(val('F22N_SCAN_ZONE_VOLUME_AZIMUTH')-math.rad(nextwidth))<1e-8)
 local height=val('F22_RADAR_SEARCH_HEIGHT_DEG')
 click(commands[2]);assert(routed[1][2]==10623)
 local nextheight=height==10 and 20 or height==20 and 40 or 10
 assert(val('F22_RADAR_SEARCH_HEIGHT_DEG')==nextheight)
 assert(math.abs(val('F22N_SCAN_ZONE_VOLUME_ELEVATION')-math.rad(nextheight))<1e-8)
 click(commands[3]);assert(routed[1][2]==10614 and math.abs(val('F22_RADAR_EL_DEG')-2)<1e-8)
 assert(math.abs(val('F22N_SCAN_ZONE_ORIGIN_ELEVATION')-math.rad(2))<1e-8)
 click(commands[4]);assert(routed[1][2]==10615 and math.abs(val('F22_RADAR_EL_DEG'))<1e-8)
 click(commands[3]);click(commands[5])
 assert(routed[1][2]==10617 and math.abs(val('F22_RADAR_EL_DEG'))<1e-8)
end
-- TWS shows its actual AUTO volume separately from the pilot's request.
radar_command(10602,1);radar_update()
assert(val('F22_RADAR_SCAN_AUTO')==1)
local previous=val('F22_RADAR_SEARCH_HEIGHT_DEG')
click(10149)
assert(val('F22_RADAR_SEARCH_HEIGHT_DEG')~=previous)
assert(val('F22_RADAR_SCAN_EL_DEG')==val('F22_RADAR_SEARCH_HEIGHT_DEG'),
 'TWS retained old scan height after pilot changed it')
-- Editing the next search pattern must never issue a native STT reject.
put('F22N_RADAR_MODE',3);put('F22N_RADAR_STT_RANGE',12964)
put('F22N_RADAR_STT_AZIMUTH',0);put('F22N_RADAR_STT_ELEVATION',0)
radar_update();assert(val('F22_RADAR_STT_VALID')==1)
for _,command in ipairs({10150,10149,10148,10147,10146}) do
 click(command);assert(val('F22_RADAR_STT_VALID')==1,'scan edit rejected STT')
end
-- Side buttons are inert on MENU and with the aircraft bus off.
SetCommand(10143,1);routed={};SetCommand(10150,1);SetCommand(10150,0)
assert(#routed==0,'MENU button changed radar settings')
SetCommand(10005,1);put('MAIN_POWER',0);routed={};SetCommand(10150,1)
assert(#routed==0,'unpowered MFD changed radar settings')
''')

for kind in ('joystick', 'keyboard'):
    lua = runtime()
    lua.globals().INPUT_PROFILE = (ROOT / f'Input/F-22A/{kind}/default.lua').as_posix()
    lua.execute('''
    function _(s) return s end
    iCommandPlaneTrimUp=95;iCommandPlaneTrimDown=96;iCommandPlaneTrimLeft=93;iCommandPlaneTrimRight=94
    iCommandPlaneAirBrake=73;iCommandPlaneAirBrakeOn=147;iCommandPlaneAirBrakeOff=148
    iCommandPlanePitch=2001;iCommandPlaneRoll=2002
    iCommandPlaneThrustCommon=2004;iCommandPlaneThrustLeft=2005;iCommandPlaneThrustRight=2006
    local original_combo={key='JOY_X'}
    function external_profile(_) return {
     keyCommands={{pressed=95,up=215},{down=147},{down=148}},
     axisCommands={{action=2001,combos={original_combo}},{action=2005}},
    } end
    function ignore_features(...) end
    function join(target,extra) for _,b in ipairs(extra) do target[#target+1]=b end end
    local profile=dofile(INPUT_PROFILE)
    local commands={}
    for _,b in ipairs(profile.keyCommands) do if b.down then commands[b.down]=b end end
    for command=10700,10733 do
     local b=assert(commands[command],'missing saved HOTAS command '..command)
     assert(b.up==command and b.value_down==1 and b.value_up==0 and b.cockpit_device_id==16,
      'HOTAS command identity/release changed')
     local category=command<=10718 and 'F-22 HOTAS - Stick' or 'F-22 HOTAS - Throttle'
     assert(b.category==category,'HOTAS assigned to wrong physical group')
    end
    assert(commands[10729].name=='Weapon Select - AIM-9 Sidewinder')
    assert(commands[10730].name=='Weapon Select - AIM-120 AMRAAM')
    for _,command in ipairs({10614,10615}) do
     assert(commands[command].category=='F-22 HOTAS - Throttle')
    end
    assert(commands[10623] and commands[10623].cockpit_device_id==14)
    assert(commands[147].name=='Speedbrake - Extend' and commands[148].name=='Speedbrake - Retract')
    assert(profile.keyCommands[1].pressed==95 and profile.keyCommands[1].up==215)
    assert(profile.keyCommands[1].category=='F-22 HOTAS - Stick')
    assert(profile.axisCommands[1].action==2001 and profile.axisCommands[1].combos[1]==original_combo)
    assert(profile.axisCommands[1].category=='F-22 HOTAS - Stick')
    assert(profile.axisCommands[2].category=='F-22 HOTAS - Throttle')
    for _,b in ipairs(profile.axisCommands) do
     if b.action==10620 or b.action==10621 then assert(b.category=='F-22 HOTAS - Throttle') end
    end
    ''')

print('MFD scan controls: physical/bindable OSBs, native search geometry, TWS AUTO, STT retention, power/page gates and HOTAS identity PASS')
