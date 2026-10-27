"""Actual adapters release original held owners and preserve saved light inputs."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
fixture = ROOT / 'tests/test_display_startup.py'
scope = {'__file__': str(fixture)}
exec(compile(fixture.read_text().split('\nfor page in ', 1)[0], str(fixture), 'exec'), scope)
lua = scope['runtime']()
lua.execute(r'''
local args,actions={},{}
local lights=dofile(SCRIPT_ROOT..'Systems/External_Light_Control.lua').new(
 function(argument)return args[argument]or 0 end,
 function(owner,command,value)
  local argument=command==3004 and 709 or command==3007 and 714 or command==3003 and 715 or 713
  args[argument]=value;actions[#actions+1]={owner,command,value}
 end)
for command=10505,10512 do assert(lights:command(command))end
assert(not lights:command(11605),'AFCS command entered the light adapter')
for command=11905,11912 do assert(lights:command(command))end
for _,action in ipairs(actions)do assert(action[1]=='ELECTRICAL_SYSTEM'or action[1]=='AVIONICS')end
local events={}
local function get(key)return get_param_handle(key):get()end
local function put(key,value)get_param_handle(key):set(value)end
local routing=dofile(SCRIPT_ROOT..'Systems/Display_Routing.lua')
local controller=dofile(SCRIPT_ROOT..'Systems/MFD_Controller.lua').new(get_param_handle,
 function(owner,command,value)events[#events+1]={owner=owner,command=command,value=value}end,function()end)
put('HUD_MODE',7);put('F22_SOI',3);controller:update(true);controller:select(1,routing.pages.def)
controller:button(1,6,true)
local command=events[#events].command
assert(events[#events].owner=='RWR_SYSTEM'and events[#events].value==1)
controller:select(1,routing.pages.nav)
assert(events[#events].command==command and events[#events].value==0,'page loss did not release original owner')
local count=#events;controller:button(1,6,true);assert(#events==count,'held edge re-fired after page loss')
controller:button(1,6,false);controller:select(1,routing.pages.def);controller:button(1,6,true)
put('F22_SOI',4);controller:update(true)
assert(events[#events].command==command and events[#events].value==0,'focus loss did not release original owner')
controller:button(1,6,false);controller:button(1,6,true);controller:update(false)
assert(events[#events].command==command and events[#events].value==0,'power loss did not release original owner')
local actions={}
function dispatch_action(device,command,value)actions[#actions+1]={device,command,value}end
put('MAIN_POWER',1);put('HUD_MODE',1)
dofile(SCRIPT_ROOT..'Systems/Combat_System.lua');post_initialize()
local function cages()
 local count=0
 for _,event in ipairs(actions)do if event[2]==11840 or event[2]==10805 then count=count+1 end end
 return count
end
SetCommand(10723,1);assert(cages()==1)
put('MAIN_POWER',0);update();put('MAIN_POWER',1);update();SetCommand(10723,1)
assert(cages()==1,'held cage re-fired after power restoration')
SetCommand(10723,0);SetCommand(10723,1);assert(cages()==2);SetCommand(10723,0)
put('MAIN_POWER',0);SetCommand(10723,1);update();put('MAIN_POWER',1);update();SetCommand(10723,1)
assert(cages()==2,'unpowered press replayed on recovery')
SetCommand(10723,0);SetCommand(10723,1);assert(cages()==3)
''')
print('Saved light aliases, disjoint dispatch, held page/focus/power releases and repeat suppression PASS')

# Input profiles have a separate environment from cockpit registration.
lua = scope['runtime']()
lua.execute(r'''
function _(s)return s end
function external_profile()return {keyCommands={},axisCommands={}}end
function ignore_features()end
function join(destination,items)for i=1,#items do destination[#destination+1]=items[i]end end
local profiles={}
for _,kind in ipairs({'joystick','keyboard'})do
 profiles[#profiles+1]=dofile(SCRIPT_ROOT..'../../Input/F-22A/'..kind..'/default.lua')
end
dofile(SCRIPT_ROOT..'devices.lua')
for _,profile in ipairs(profiles)do
 local count=0
 for _,key in ipairs(profile.keyCommands)do
  if key.down and key.down>=11905 and key.down<=11912 then
   assert(key.cockpit_device_id==devices.FLIGHT_GUIDANCE,'light profile device differs from registration')
   count=count+1
  end
 end
 assert(count==8,'standalone profile lost a light binding')
end
''')
print('Standalone keyboard/joystick profiles construct without cockpit globals and match actual light registration PASS')
