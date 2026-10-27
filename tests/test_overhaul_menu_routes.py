"""Menu press boundaries and retained ownership of forwarded button releases."""
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
fixture=ROOT/'tests/test_display_startup.py'
ns={'__file__':str(fixture)}
exec(compile(fixture.read_text().split('\nfor page in ',1)[0],str(fixture),'exec'),ns)
lua=ns['runtime']()
lua.execute(r'''
function get_aircraft_property()return 1 end
function get_aircraft_draw_argument_value(n)return draws[n]or 0 end
function set_aircraft_draw_argument_value(n,v)draws[n]=v end
dofile(SCRIPT_ROOT..'Systems/MFD_System.lua');post_initialize()
local mfd_command,mfd_update=SetCommand,update
dofile(SCRIPT_ROOT..'Systems/EW_System.lua');post_initialize()
local ew_command=SetCommand
local function p(k)return get_param_handle(k)end
local function value(k)return p(k):get()end
local events={}
function dispatch_action(device,command,v)
 events[#events+1]={device,command,v}
 if device==devices.EW_SYSTEM then ew_command(command,v)end
end
local function edge(command,down)mfd_command(command,devices.MFD_SYSTEM+(down and .375 or .25))end
local function button(command)edge(command,true);edge(command,false)end
p('MAIN_POWER'):set(1);p('F22_DEFENSIVE_DETAIL'):set(1);mfd_update()
-- Opening ENG on a press must not immediately hit ENG's MENU key on release.
button(10824);assert(value('F22_LMFD_MENU_GROUP')==0)
button(10064);mfd_update()
assert(value('LMFD_ENG_PAGE')==1 and value('LMFD_MENU_PAGE')==0,'ENG selection bounced back on release')
button(10073);mfd_update();assert(value('LMFD_MENU_PAGE')==1)

for _,route in ipairs({{10096,devices.RWR_SYSTEM,10906},{10110,devices.EW_SYSTEM,10910}})do
 for _,transition in ipairs({'page','power'})do
  p('MAIN_POWER'):set(1);mfd_command(10005,1);mfd_update();events={}
  edge(route[1],true)
  local found=0
  for _,e in ipairs(events)do if e[1]==route[2]and e[2]==route[3]and e[3]==1 then found=found+1 end end
  assert(found==1,'forwarded press missed its owner')
  if transition=='page'then button(10103);mfd_update()
  else p('MAIN_POWER'):set(0);mfd_update()end
  local before=#events;edge(route[1],false)
  assert(#events==before+1 and events[#events][1]==route[2]and events[#events][2]==route[3]and events[#events][3]==0,'page/power transition swallowed original release')
  before=#events;edge(route[1],false);assert(#events==before,'forwarded release delivered twice')
 end
end
-- Actual EW latching recovers after a release while its display lost power.
p('MAIN_POWER'):set(1);mfd_command(10005,1);mfd_update()
local selected=value('F22_CM_PROGRAM_SELECTED')
edge(10110,true);local next_selected=selected%3+1
assert(value('F22_CM_PROGRAM_SELECTED')==next_selected)
edge(10110,true);assert(value('F22_CM_PROGRAM_SELECTED')==next_selected,'repeat down bypassed EW latch')
p('MAIN_POWER'):set(0);mfd_update();edge(10110,false)
p('MAIN_POWER'):set(1);mfd_update();button(10110)
assert(value('F22_CM_PROGRAM_SELECTED')==next_selected%3+1,'owner remained latched after off-page/off-power release')
-- Stores in a DMS cycle is now the shared, owned format on that display.
for _,cycle in ipairs({{10820,'LMFD_PAGE','LMFD_BAY_PAGE'},{10821,'RMFD_PAGE','RMFD_BAY_PAGE'}})do
 for i=1,15 do
  mfd_command(cycle[1],1);mfd_update()
  assert((value(cycle[2])==5)==(value(cycle[3])==1),'DMS stores selection disagrees with the actual page')
 end
end
-- An ENG stores shortcut opens stores locally and preserves lower NAV.
for _,panel in ipairs({{10060,10820,'LMFD_PAGE'},{10090,10821,'RMFD_PAGE'}})do
 for i=1,8 do if value(panel[3])==1 then break end;mfd_command(panel[2],1);mfd_update()end
 assert(value(panel[3])==1)
 mfd_command(10823,1);mfd_update();assert(value('CMFD_HSI_PAGE')==1)
 button(panel[1]+3);mfd_update()
 assert(value(panel[3])==5 and value('CMFD_HSI_PAGE')==1,'ENG stores shortcut redirected to another display')
end
''')
print('Overhaul menu routes: ENG press/release navigation and RWR/EW release ownership across page/power transitions PASS')

lua=ns['runtime']()
lua.execute(r'''
function get_aircraft_property()return 1 end
function get_aircraft_draw_argument_value(n)return draws[n]or 0 end
function set_aircraft_draw_argument_value(n,v)draws[n]=v end
dofile(SCRIPT_ROOT..'Systems/RWR_System.lua');post_initialize()
local rwr_command,rwr_update=SetCommand,update
dofile(SCRIPT_ROOT..'Systems/PMFD_System.lua');post_initialize()
local command,tick=SetCommand,update
local function p(k)return get_param_handle(k)end
local function value(k)return p(k):get()end
local events={}
function dispatch_action(device,c,v)
 events[#events+1]={device,c,v}
 if device==devices.RWR_SYSTEM then rwr_command(c,v)end
end
local function edge(c,down)command(c,devices.PMFD_SYSTEM+(down and .375 or .25))end
local function button(c)edge(c,true);edge(c,false)end
p('MAIN_POWER'):set(1);tick();button(10143);tick()
assert(value('F22_PMFD_PAGE')==0)
-- Root RTN/Tactical PB13 must survive its release after entering the TSD.
button(10131);tick();assert(value('F22_PMFD_PAGE')==1,'PMFD TSD selection bounced to MENU on release')
button(10143);tick();assert(value('F22_PMFD_PAGE')==0)
for _,b in ipairs({5,6,7,8,9,10,11,12,14,15,16,17,18,19,20})do button(10130+b);tick();assert(value('F22_PMFD_PAGE')==0,'blank root key exposed a legacy MAP/SYS page')end
''')
print('Overhaul PMFD routes: direct TSD selection, decoded release suppression and no hidden layer/setup/diagnostic controls PASS')
