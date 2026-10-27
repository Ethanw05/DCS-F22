"""Actual NAV/UFC owners: bounded marks, explicit steering and manual UTC arrival."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
fixture = ROOT / 'tests/test_display_startup.py'
scope = {'__file__': str(fixture)}
exec(compile(fixture.read_text().split('\nfor page in ', 1)[0], str(fixture), 'exec'), scope)
lua = scope['runtime']()
lua.execute(r'''
local M=dofile(SCRIPT_ROOT..'Systems/Nav_Marks_Time.lua');local bank=M.new()
bank:select(5)
for index=1,10 do assert(bank:capture({n=index,e=0,alt=-100},'OWN',index))end
assert(bank.sequence==10 and bank.next_slot==2 and bank.selected==5 and bank.marks[1].n==10)
assert(not bank:capture({n=0/0,e=0,alt=0},'OWN',11)and bank.sequence==10)
assert(not M.seconds(246000)and not M.seconds(126099))
local speed,status=bank:required_speed(12000,100);assert(not speed and status=='UTC UNAVAILABLE')
assert(bank:set_clock(235900,100));assert(bank:set_arrival(100,100))
speed,status=bank:required_speed(12000,100);assert(not speed and status=='ARRIVAL PAST')
assert(bank:set_day(1,100));speed=bank:required_speed(12000,100);assert(speed==100)
assert(M.clock_text(bank:utc(160))=='00:00:00')
speed,status=bank:required_speed(1e6,100);assert(not speed and status=='RGS LIMIT')
speed,status=bank:required_speed(12000,221);assert(not speed and status=='ARRIVAL PAST')
assert(not bank:utc(99)and not bank.arrival and not bank.arrival_input)

local now=100;local own={n=1000,e=0,alt=1000}
function get_model_time()return now end
function get_base_data()return {getSelfCoordinates=function()return own.n,own.alt,own.e end,
 getHeading=function()return 0 end,getPitch=function()return 0 end,getRoll=function()return 0 end}end
function get_mission_route()return {{x=0,y=0,alt=1000},{x=10000,y=0,alt=1000},{x=10000,y=10000,alt=1000}}end
package.preload.terrain=function()return {GetHeight=function()return 0 end,
 convertMetersToLatLon=function(n,e)return 41+n/100000,42+e/100000 end}end
local function get(k)return get_param_handle(k):get()end
local function put(k,v)get_param_handle(k):set(v)end
dofile(SCRIPT_ROOT..'Systems/Navigation_System.lua');post_initialize();local nc,nu=SetCommand,update
function dispatch_action(device,command)
 if device==devices.FLIGHT_GUIDANCE and command==11830 then put('F22_NAV_SOURCE',0)end
end
put('MAIN_POWER',1);put('F22_INS_MODEL_ENABLED',0);put('F22_AP_CLOCK',now)
put('EFM_HUD_VALID',1);put('EFM_HUD_VN',100);nu()
local waypoint=get('HUD_WP_INDEX')
nc(10838,1);nu()
assert(get('F22_NAV_MARK_SEQUENCE')==1 and get('HUD_WP_INDEX')==waypoint and get('F22_NAV_MARK_ACTIVE')==0)
nc(11818,1);assert(get('F22_NAV_MARK_SEQUENCE')==1,'invalid target created a mark')
put('HUD_AG_TARGET_VALID',1);put('HUD_AG_MARK_NORTH',20000);put('HUD_AG_MARK_EAST',0);put('HUD_AG_MARK_ALT',0)
nc(11818,1);assert(get('F22_NAV_MARK_SEQUENCE')==2 and get('HUD_WP_INDEX')==waypoint)
own.n=0;nc(11812,1);nu()
assert(get('F22_NAV_MARK_ACTIVE')==1 and get('HUD_WP_INDEX')==-1 and get('F22_NAV_POINT_LABEL')=='MARK 1')
assert(math.abs(get('HUD_WP_RANGE_NM')-1000/1852)<1e-8)
for index=1,8 do own.n=3000+index;nc(11810,1)end
own.n=0;nu()
assert(get('F22_NAV_MARK_SEQUENCE')==10 and get('HUD_WP_INDEX')==-1)
assert(math.abs(get('HUD_WP_RANGE_NM')-1000/1852)<1e-8,'overwritten mark silently retargeted active steering')
assert(get('F22_NAV_POINT_LABEL')=='MARK 1 HOLD','retained direct snapshot was not identified')
nc(11819,1);nu();assert(get('HUD_WP_INDEX')==waypoint and get('F22_NAV_MARK_ACTIVE')==0)
local function send(owner,command,value)if owner=='NAV_SYSTEM'then nc(command,value)end end
local ui=dofile(SCRIPT_ROOT..'Systems/UFC_Controller.lua').new(get,put,send,get_base_data())
local function digits(text)for digit in text:gmatch('.')do ui:digit(tonumber(digit))end end
ui:open('TIME',true);ui:option(1);digits('235900');ui:option(1)
assert(not ui.pending and get('F22_NAV_CLOCK_INPUT')==235900)
ui:option(2);digits('000100');ui:option(2)
assert(not ui.pending and get('F22_NAV_ARRIVAL_INPUT')==100)
ui:option(3);digits('3');ui:option(3);ui:option(4);nu()
assert(get('F22_NAV_TIMING_DESTINATION')==3 and get('HUD_WP_INDEX')==waypoint)
assert(get('F22_NAV_ARRIVAL_DAY')==1 and get('F22_NAV_TIMING_VALID')==1)
assert(math.abs(get('F22_NAV_TIMING_RGS_KTS')-20000/120*1.943844492)<1e-6,'required GS ignored remaining route legs')
now=160;put('F22_AP_CLOCK',now);nu();assert(get('F22_NAV_CLOCK_TEXT')=='UTC 00:00:00')
put('MAIN_POWER',0);nu();ui:update(.02)
put('MAIN_POWER',1);nu()
assert(get('F22_NAV_TIMING_VALID')==0 and get('F22_NAV_TIMING_TEXT')=='UTC UNAVAILABLE')
-- An owner power interruption cancels even a request whose UI producer stopped.
local channel=dofile(SCRIPT_ROOT..'Systems/Entry_Transaction.lua').channel('NAV',get,put)
local sequence
channel:submit(function(_,_,value)sequence=value end,'NAV_SYSTEM',11810,1,function()return true end)
local before=get('F22_NAV_MARK_SEQUENCE')
put('MAIN_POWER',0);nu();put('MAIN_POWER',1);nc(11800,sequence);nu()
assert(get('F22_NAV_MARK_SEQUENCE')==before,'a pre-outage mark request applied after restoration')
dofile(SCRIPT_ROOT..'MFD_COMMON/nav_page.lua')('LMFD_HSI_PAGE')
local names={}
for _,element in ipairs(elements)do assert(not names[element.name]);names[element.name]=true end
for _,element in ipairs(elements)do if element.parent_element then assert(names[element.parent_element])end end
''')
print('Marks/time: nine-slot wrap, independent capture, frozen direct snapshot, correlated UTC/arrival, midnight, RGS and power loss PASS')
