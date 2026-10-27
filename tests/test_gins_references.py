"""Independent simulated reference health, coherent selection and bounded alignment."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
fixture = ROOT / 'tests/test_display_startup.py'
scope = {'__file__': str(fixture)}
exec(compile(fixture.read_text().split('\nfor page in ', 1)[0], str(fixture), 'exec'), scope)
lua = scope['runtime']()
lua.execute(r'''
local R=dofile(SCRIPT_ROOT..'Systems/Gins_References.lua')
local A=dofile(SCRIPT_ROOT..'Systems/Gins_Alignment.lua')
local function get(k)return get_param_handle(k):get()end
local function put(k,v)get_param_handle(k):set(v)end
local n,e=0,0
local base={getPitch=function()return .1 end,getRoll=function()return -.2 end,getHeading=function()return -.3 end,
 getSelfCoordinates=function()return n,1000,e end}
put('MAIN_POWER',1);put('EFM_GROUND_VALID',1);put('EFM_WEIGHT_ON_WHEELS',1)
put('HUD_GS_VALID',1);put('HUD_GS_MPS',0);put('F22_AP_CLOCK',10)
local producer=R.new(get,put,base);producer:reset(true)
local hud,sfg,nav=R.reader(get,'HUD'),R.reader(get,'SFG'),R.reader(get,'NAV')
assert(hud:update().valid and hud.values.SOURCE==1 and hud.values.ATTITUDE_VALID==1)
assert(sfg:update().valid and sfg.values.SOURCE==2 and sfg.values.ATTITUDE_VALID==1)
put('F22_GINS_1_ATTITUDE_FAILURE',1);put('F22_GINS_1_POSITION_FAILURE',1);producer:update()
assert(hud:update().values.ATTITUDE_VALID==0 and sfg:update().values.ATTITUDE_VALID==1)
assert(nav:update().values.POSITION_READY==0 and get('F22_INS_READY')==0)
assert(producer:select('NAV',2));assert(nav:update().values.POSITION_READY==1 and get('F22_INS_READY')==1)
assert(not producer:select('HUD',3))
put('F22_GINS_2_HEADING_FAILURE',1);producer:update()
assert(sfg:update().values.ATTITUDE_VALID==1 and sfg.values.HEADING_VALID==0)
put('F22_GINS_2_HEADING_FAILURE',0);producer:update()
put('F22_AP_CLOCK',11);assert(not sfg:update().valid,'stale reference became current truth')
put('F22_GINS_SCHEMA',0);assert(not sfg:update().valid and sfg.present,'legacy fallback revived after ownership')
put('F22_GINS_SCHEMA',1);producer:update();assert(sfg:update().valid)
local mixed=false
local reader=R.reader(function(k)
 local value=get(k)
 if mixed and k=='F22_GINS_SFG_PITCH'then put('F22_GINS_SEQUENCE',get('F22_GINS_SEQUENCE')+1)end
 return value
end,'SFG')
mixed=true;assert(not reader:update().valid);mixed=false
local s={now=0,powered=true,stationary=true,n=0,e=0,heading=0}
local alignment=A.new(false);alignment:update(s)
for i=1,4799 do s.now=i*.1;alignment:update(s)end
assert(not alignment.ready and alignment.progress>479)
s.now=480.1;alignment:update(s);assert(alignment.ready)
s.powered=false;s.now=481;alignment:update(s)
s.powered=true;s.now=490;alignment:update(s);assert(not alignment.ready)
assert(alignment:request(1,s)and alignment.total==90)
for i=1,901 do s.now=490+i*.1;alignment:update(s)end
assert(alignment.ready)
s.powered=false;s.now=581;alignment:update(s);s.powered=true;s.now=590;s.n=10;alignment:update(s)
assert(not alignment:request(1,s),'retained heading accepted movement while unpowered')
assert(alignment:request(2,s)and alignment.total==30)
s.stationary=false;s.now=591;alignment:update(s);assert(alignment.progress==0 and not alignment.ready)
s.stationary=true;s.now=592;assert(alignment:request(2,s))
for i=1,301 do s.now=592+i*.1;alignment:update(s)end
assert(alignment.ready)
s.now=1;alignment:update(s);assert(not alignment.ready and not alignment.saved_time)
s.now=0/0;assert(not alignment:request(0,s),'invalid clock accepted alignment')
''')
print('GINS references: independent source/component failures, selections, coherent/stale frames, 480/90/30s estimates, movement rejection and mission rewind PASS')
lua = scope['runtime']()
lua.execute(r'''
local function get(k)return get_param_handle(k):get()end
local function put(k,v)get_param_handle(k):set(v)end
local north=0
local base=setmetatable({getSelfCoordinates=function()return north,3000,0 end,
 getPitch=function()return .1 end,getRoll=function()return -.2 end,getHeading=function()return 0 end,
 getVerticalAcceleration=function()return 1 end}, {__index=function()return function()return 0 end end})
function get_base_data()return base end
function get_aircraft_draw_argument_value()return 0 end
function get_mission_route()return{{x=0,y=0,alt=3000},{x=10000,y=0,alt=3000}}end
for k,v in pairs({MAIN_POWER=1,EFM_HUD_VALID=1,EFM_HUD_VN=100,EFM_HUD_VE=0,EFM_HUD_VU=0,
 EFM_HUD_TAS=100,EFM_HUD_SOUND=340,EFM_HUD_PRESSURE=101325,F22_ALT_BARO_VALID=1,
 F22_ALT_BARO_FT=10000,F22_AP_CLOCK=10})do put(k,v)end
dofile(SCRIPT_ROOT..'Systems/Flight_Guidance.lua');post_initialize()
local guidance,command=update,SetCommand
dofile(SCRIPT_ROOT..'Systems/Navigation_System.lua');post_initialize();local navigation=update
dofile(SCRIPT_ROOT..'Systems/HUD_Flight_Data.lua');post_initialize();local hud=update
local displays=dofile(SCRIPT_ROOT..'Systems/Attitude_References.lua').new(get,put)
local function tick()
 put('F22_AP_CLOCK',get('F22_AP_CLOCK')+.1);guidance();navigation();hud();displays.update(0/0,0/0)
end
tick();assert(get('F22_NAV_OWN_VALID')==1 and get('HUD_FPM_VALID')==1 and get('F22_SFG_ATTITUDE_VALID')==1)
put('F22_GINS_1_POSITION_FAILURE',1);tick()
assert(get('F22_NAV_OWN_VALID')==0 and get('F22_GINS_2_ESTIMATE_VALID')==1)
put('F22_GINS_1_ATTITUDE_FAILURE',1);tick()
assert(get('F22_PRIMARY_ATTITUDE_VALID')==0 and get('HUD_REFERENCE_ATTITUDE_VALID')==0)
assert(get('F22_SFG_ATTITUDE_VALID')==1 and get('F22_SFG_PITCH')==.1)
assert(get('HUD_FPM_VALID')==0 and get('HUD_AIRDATA_VALID')==1 and get('HUD_ALT_VALID')==1)
local ui=dofile(SCRIPT_ROOT..'Systems/UFC_Controller.lua').new(get,put,function(owner,c,v)
 assert(owner=='FLIGHT_GUIDANCE');command(c,v)
end)
ui:open('GINS REFERENCES',true);ui:option(1);ui:update(0);tick()
assert(not ui.pending and get('F22_GINS_NAV_SOURCE')==2 and get('F22_NAV_OWN_VALID')==1)
assert(get('F22_PRIMARY_ATTITUDE_VALID')==1 and get('HUD_REFERENCE_ATTITUDE_VALID')==0)
ui:option(2);ui:update(0);tick()
assert(get('F22_GINS_HUD_SOURCE')==2 and get('HUD_FPM_VALID')==1)
assert(get('F22_AP_ACTIVE')==0,'reference selection engaged flight control')
local before=get('F22_NAV_OWN_N');put('F22_GPS_FAILURE',1);north=1000;tick()
assert(get('F22_NAV_OWN_N')<before+20,'GPS loss used hidden position truth')
put('F22_GPS_FAILURE',0);tick()
put('F22_GINS_SCHEMA',0);hud();displays.update(.9,.9)
assert(get('HUD_REFERENCE_ATTITUDE_VALID')==0 and get('F22_SFG_ATTITUDE_VALID')==0)
guidance();tick();assert(get('HUD_REFERENCE_ATTITUDE_VALID')==1)
put('F22_GINS_HUD_PITCH',0/0);hud()
assert(get('HUD_REFERENCE_ATTITUDE_VALID')==0 and get('HUD_PITCH')==0,'invalid reference crossed render boundary')
guidance();tick()
ui:option(4);assert(ui.page=='GINS ALIGN');ui:option(2);ui:update(0)
assert(get('F22_ENTRY_GUIDANCE_RESULT')==2,'moving aircraft accepted retained alignment')
put('EFM_GROUND_VALID',1);put('EFM_WEIGHT_ON_WHEELS',1);put('HUD_GS_VALID',1);put('HUD_GS_MPS',0)
ui:option(3);ui:update(0)
assert(get('F22_ENTRY_GUIDANCE_RESULT')==1 and get('F22_GINS_2_ALIGN_TOTAL')==30)
assert(get('F22_INS_READY')==0,'accepted training request invented completed alignment')
''')
print('Actual guidance/NAV/HUD/display owners: independent estimates, standby survival, accepted source changes, GPS coast, no fallback and explicit alignment requests PASS')
lua = scope['runtime']()
lua.execute(r'''
local function get(k)return get_param_handle(k):get()end
local function put(k,v)get_param_handle(k):set(v)end
local north=0
local base={getSelfCoordinates=function()return north,3000,0 end,getPitch=function()return 0 end,
 getRoll=function()return 0 end,getHeading=function()return 0 end}
function get_base_data()return base end
function get_mission_route()return{{x=0,y=0,alt=3000},{x=10000,y=0,alt=3000}}end
put('MAIN_POWER',1);put('EFM_HUD_VALID',1);put('EFM_HUD_VN',100);put('F22_AP_CLOCK',10)
dofile(SCRIPT_ROOT..'Systems/Flight_Guidance.lua');post_initialize();local guidance=update
dofile(SCRIPT_ROOT..'Systems/Navigation_System.lua');post_initialize();local navigation=update
guidance();navigation();assert(get('F22_GINS_1_ESTIMATE_VALID')==1 and get('F22_GINS_2_ESTIMATE_VALID')==1)
put('EFM_POWER_OWNER',1);put('EFM_PHYSICAL_VALID',1);put('EFM_PHYSICAL_GENERATION',1)
put('EFM_PHYSICAL_CLOCK_KIND',1);put('F22_ESSENTIAL_POWER',1);put('MAIN_POWER',0)
put('F22_AP_CLOCK',10.1);put('EFM_PHYSICAL_STAMP',10.1);put('F22_GPS_FAILURE',1);north=5000
guidance();navigation()
assert(get('F22_GINS_1_ESTIMATE_VALID')==1 and get('F22_GINS_2_ESTIMATE_VALID')==1)
assert(get('F22_NAV_OWN_N')>9 and get('F22_NAV_OWN_N')<11,'display power stopped healthy reference coast')
put('MAIN_POWER',1);put('F22_GINS_1_POWER_FAILURE',1);put('F22_AP_CLOCK',10.2);put('EFM_PHYSICAL_STAMP',10.2)
guidance();navigation()
assert(get('F22_GINS_1_ESTIMATE_VALID')==0 and get('F22_GINS_2_ESTIMATE_VALID')==1,
 'one failed channel withdrew the independent healthy estimate')
''')
print('Reference memory: healthy DC-powered estimates continue without main display power; one channel loss leaves the other coasting PASS')
for page in ('UFD_LEFT/base_page.lua', 'UFD_RIGHT/base_page.lua', 'MFD_COMMON/adi_page.lua'):
    graph = scope['runtime']()
    graph.globals().PAGE = page
    graph.execute(r'''
if PAGE:find('MFD_COMMON',1,true)then dofile(SCRIPT_ROOT..PAGE)('TEST_ADI')else dofile(SCRIPT_ROOT..PAGE)end
local moving=0
local valid=PAGE:find('UFD_RIGHT',1,true)and'F22_SFG_ATTITUDE_VALID'or'F22_PRIMARY_ATTITUDE_VALID'
for _,element in ipairs(elements)do
 local pose=false;local index
 for i,key in ipairs(element.element_params or{})do
  if key=='ADIROLL'or key=='ADIPITCH'or key=='F22_SFG_ROLL'or key=='F22_SFG_PITCH'then pose=true end
  if key==valid then index=i-1 end
 end
 if pose then
  moving=moving+1;assert(index,'moving attitude graphic has no selected-source validity')
  local gated=false
  for _,controller in ipairs(element.controllers or{})do
   if controller[1]=='parameter_in_range'and controller[2]==index then gated=true end
  end
  assert(gated,'native controller missed its source-valid parameter')
 end
end
assert(moving>=5)
''')
print('Native write-only ADI graphs: primary/standby pose bindings and source-valid controller indices PASS')
