"""Actual UFC/NAV/guidance owners: dropped, stale, duplicate and cancelled edits.

The native target callback is exercised separately by test_vehicle_efm.cpp.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
fixture = ROOT / 'tests/test_display_startup.py'
scope = {'__file__': str(fixture)}
exec(compile(fixture.read_text().split('\nfor page in ', 1)[0], str(fixture), 'exec'), scope)
lua = scope['runtime']()
lua.execute(r'''
local now=10
function get_model_time()return now end
function get_mission_route()return {{x=0,y=0,alt=3000},{x=10000,y=10000,alt=3000}}end
package.preload.terrain=function()return {
 GetHeight=function()return 0 end,
 convertMetersToLatLon=function(n,e)return 41+n/100000,42+e/100000 end,
 convertLatLonToMeters=function(lat,lon)return (lat-41)*100000,(lon-42)*100000 end}end
local function get(k)return get_param_handle(k):get()end
local function put(k,v)get_param_handle(k):set(v)end
put('MAIN_POWER',1);put('F22_AP_CLOCK',now);put('EFM_HUD_VALID',1)
dofile(SCRIPT_ROOT..'Systems/Navigation_System.lua');post_initialize();local nc,nu,np=SetCommand,update,post_initialize
local guidance_physical=dofile(SCRIPT_ROOT..'../../tests/physical_frame_fixture.lua')({F22_ESSENTIAL_POWER=1})
guidance_physical:publish(get_param_handle('F22_AP_CLOCK'):get())
dofile(SCRIPT_ROOT..'Systems/Flight_Guidance.lua');post_initialize();local gc,gu,gp=SetCommand,update,post_initialize
dofile(SCRIPT_ROOT..'Systems/Altitude_System.lua');post_initialize();local ac,ap=SetCommand,post_initialize
put('MAIN_POWER',1);put('F22_AP_CLOCK',now);put('EFM_HUD_VALID',1)
gu();nu()
local queued={};local hold_nav=false
function dispatch_action(device,command,value)
 if device==nil and command==11800 then queued[#queued+1]={kind='native',sequence=value}end
end
local function send(owner,command,value)
 if owner=='FLIGHT_GUIDANCE'then gc(command,value)
 elseif owner=='ALTITUDE_SYSTEM'then ac(command,value)
 elseif owner=='NAV_SYSTEM'then
  if hold_nav then queued[#queued+1]={kind='nav',sequence=value}else nc(command,value)end
 end
end
local function flush()
 local requests=queued;queued={}
 for _,request in ipairs(requests)do
  local sequence=request.sequence
  if request.kind=='nav'then nc(11800,sequence)
  elseif get('F22_ENTRY_GUIDANCE_ACTIVE')==1 and get('F22_ENTRY_GUIDANCE_REQUEST')==sequence
   and get('F22_ENTRY_GUIDANCE_ACK_REQUEST')<sequence then
   local value=get('F22_ENTRY_GUIDANCE_VALUE')
   put('F22_AP_HEADING',value);put('F22_ENTRY_GUIDANCE_ACK_VALUE',value)
   put('F22_ENTRY_GUIDANCE_RESULT',1);put('F22_ENTRY_GUIDANCE_ACK_REQUEST',sequence)
  end
 end
end
local ui=dofile(SCRIPT_ROOT..'Systems/UFC_Controller.lua').new(get,put,send,get_base_data())
local function digits(text)for digit in text:gmatch('.')do ui:digit(tonumber(digit))end end
for _,heading in ipairs({0,1,90,123,359})do
 ui:open('HEADING',true);ui:option(1);digits(tostring(heading));ui:option(1)
 assert(ui.pending and ui.entry,'same/equal value falsely acknowledged before request delivery')
 flush();ui:update(.02)
 assert(not ui.pending and not ui.entry and get('F22_UFC_SCRATCH')=='ENTERED')
end
put('F22_NAV_REFERENCE',1);put('F22_MAG_VALID',1);put('F22_MAG_DECL',math.rad(10))
ui:open('HEADING',true);ui:option(1);digits('359');ui:option(1);flush();ui:update(.02)
assert(math.abs(get('F22_AP_HEADING')-9)<1e-8,'magnetic/true conversion lost north crossing')
put('F22_NAV_REFERENCE',0)
ui:open('HEADING',true);ui:option(1);digits('90');ui:option(1);ui:update(1.1)
assert(ui.entry.error=='NO RESPONSE' and not ui.pending)
local old=get('F22_AP_HEADING');flush();assert(get('F22_AP_HEADING')==old,'timed-out request applied late')
ui:open('HEADING',true);ui:option(1);digits('123');ui:option(1)
ui:open('NAV',true);flush();assert(get('F22_AP_HEADING')==old,'page cancellation applied late')
ui:option(1);digits('16');ui:option(1);assert(not ui.pending and get('F22_TCN_CHANNEL')==16)
ui:open('ALT',true);ui:option(1);digits('3000');ui:option(1)
assert(not ui.pending and math.abs(get('F22_ALT_PRESSURE_MMHG')-762)<.02)
-- The selected ID is unchanged throughout a dropped same-ID coordinate edit.
nu();local id=get('HUD_WP_INDEX');local lat=get('F22_NAV_FIX_LAT')
hold_nav=true;ui:open('STPT',true);ui:option(2);digits('4130000');ui:option(2)
assert(get('HUD_WP_INDEX')==id and ui.pending and ui.entry,'ID alone acknowledged a coordinate edit')
ui:update(1.1);assert(ui.entry.error=='NO RESPONSE');flush();nu()
assert(get('F22_NAV_FIX_LAT')==lat,'cancelled same-ID edit mutated the route')
hold_nav=false;ui:open('STPT',true);ui:option(2);digits('4130000');ui:option(2);nu();ui:update(.02)
assert(not ui.pending and get('HUD_WP_INDEX')==id and math.abs(get('F22_NAV_FIX_LAT')-41.5)<1e-8)
-- Reordered ACKs cannot acknowledge a newer request for an equal setting.
ui:open('HEADING',true);ui:option(1);digits(tostring(old));ui:option(1)
local request=get('F22_ENTRY_GUIDANCE_REQUEST')
put('F22_ENTRY_GUIDANCE_ACK_REQUEST',request-1);ui:update(.02);assert(ui.pending)
put('MAIN_POWER',0);ui:update(.02);flush();assert(not ui.pending and ui.page=='')
put('F22_ENTRY_GUIDANCE_ACTIVE',1);put('F22_ENTRY_ALT_ACTIVE',1);put('F22_ENTRY_NAV_ACTIVE',1)
gp();ap();function get_mission_route()error('new mission unavailable')end;np()
assert(get('F22_ENTRY_GUIDANCE_ACTIVE')==0 and get('F22_ENTRY_ALT_ACTIVE')==0 and get('F22_ENTRY_NAV_ACTIVE')==0)
assert(get('F22_MISSION_ROUTE_GENERATION')==0 and get('F22_NAV_OWN_VALID')==0)
assert(get('F22_NAV_SNAPSHOT_SEQUENCE')==0,'mission restart retained old steering publication')
put('MAIN_POWER',1);gu();nu()
assert(get('F22_NAV_ROUTE_COUNT')==0,'failed new-mission import inherited previous route')
''')
print('Correlated UFC edits: degree headings, magnetic reference, same-ID NAV, drop/cancel/reorder and real local owners PASS')
