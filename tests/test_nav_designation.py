"""Hornet-inspired distinction: ordinary WYPT steering versus explicit target designation."""
from test_display_startup import runtime
sim=runtime()
sim.execute("""
package.preload['terrain']=function()return{GetHeight=function()return 20 end}end
own={n=0,e=0,alt=100}
function get_base_data()return {getSelfCoordinates=function()return own.n,own.alt,own.e end,
 getHeading=function()return 0 end,getPitch=function()return 0 end,getRoll=function()return 0 end}end
function get_mission_route()return {{x=0,y=0,alt=100},{x=20000,y=0,alt=100},{x=20000,y=5000,alt=100}}end
local function p(k,v)get_param_handle(k):set(v)end
local function g(k)return get_param_handle(k):get()end
dofile(SCRIPT_ROOT..'Systems/Navigation_System.lua');post_initialize();local nav_update,nav_set=update,SetCommand
dofile(SCRIPT_ROOT..'Systems/AG_Mark_System.lua');post_initialize();local ag_update,ag_set=update,SetCommand
function dispatch_action(device,command,value)if device==9 then ag_set(command,value)end end
p('MAIN_POWER',1);p('HUD_GS_VALID',1);p('HUD_GS_MPS',200);p('F22_AP_CLOCK',1)
nav_update();assert(g('HUD_WP_VALID')==1 and g('HUD_NAV_BUG_VALID')==1)
assert(g('HUD_WP_CUE_VALID')==0 and g('HUD_WP_OFFSCREEN')==0 and g('F22_NAV_DESIGNATED')==0)
assert(type(g('HUD_NAV_BUG_LABEL'))=='string' and tonumber(g('HUD_NAV_BUG_LABEL'))==nil,'numeric-only strings are coerced by native parameter API')
nav_set(10841,1);ag_update();nav_update()
assert(g('F22_NAV_DESIGNATED')==1 and g('HUD_AG_TARGET_VALID')==1 and g('F22_AG_TARGET_SOURCE')==3)
assert(g('HUD_AG_MARK_ALT')==20,'explicit WPDSG targets terrain, not mission flight-plan altitude')
assert(g('HUD_WP_CUE_VALID')==1 and g('HUD_WP_INFO'):find('TGT'))
nav_set(10842,1);ag_update();nav_update()
assert(g('F22_NAV_DESIGNATED')==0 and g('HUD_WP_CUE_VALID')==0 and g('HUD_AG_TARGET_VALID')==0)
""")
sim=runtime()
sim.execute("""
dofile(SCRIPT_ROOT..'Systems/Flight_Guidance.lua');post_initialize();local guidance=SetCommand
dofile(SCRIPT_ROOT..'Systems/ICP_System.lua');post_initialize()
get_param_handle('MAIN_POWER'):set(1)
function dispatch_action(d,c,v)
 actions[#actions+1]={d,c,v}
 if d==devices.FLIGHT_GUIDANCE then guidance(c,v)end
end
local function key(c)SetCommand(c,7.375);SetCommand(c,7.25);update()end
local function digits(s)for c in s:gmatch('.')do local n=tonumber(c);key(n==0 and 3027 or 3016+n)end end
key(3003);key(3008);digits('016');key(3008)
assert(actions[#actions][1]==25 and actions[#actions][2]==11800 and get_param_handle('F22_TCN_CHANNEL'):get()==16)
key(3009);digits('11030');key(3009)
assert(get_param_handle('F22_ENTRY_GUIDANCE_COMMAND'):get()==10947 and get_param_handle('F22_ILS_FREQ_KHZ'):get()==110300)
key(3010);digits('000');key(3010)
assert(get_param_handle('F22_ENTRY_GUIDANCE_COMMAND'):get()==10949 and get_param_handle('F22_NAV_COURSE'):get()==0,'north course entry accepted')
""")
print('Ordinary NAV has no target diamond; WPDSG/UNDES share ground designation; CNI keypad tuning PASS')

# Device activities are asynchronous: step/select and designate can arrive
# before Navigation_System has published the next display snapshot.
sim=runtime()
sim.execute("""
local terrain_ok=true
package.preload.terrain=function()return{GetHeight=function()if terrain_ok then return 20 end end}end
function get_base_data()return {getSelfCoordinates=function()return 0,100,0 end,
 getHeading=function()return 0 end,getPitch=function()return 0 end,getRoll=function()return 0 end}end
function get_mission_route()return {{x=0,y=0,alt=100},{x=20000,y=0,alt=100},{x=30000,y=5000,alt=100}}end
local function p(k,v)get_param_handle(k):set(v)end
local function g(k)return get_param_handle(k):get()end
dofile(SCRIPT_ROOT..'Systems/Navigation_System.lua');post_initialize();local nav_update,nav_set=update,SetCommand
dofile(SCRIPT_ROOT..'Systems/AG_Mark_System.lua');post_initialize();local ag_update,ag_set=update,SetCommand
function dispatch_action(device,command,value)
 assert(device==9 and (command==10811 or command==10843),'planning dispatched an arm/fire action')
 ag_set(command,value)
end
p('MAIN_POWER',1);p('F22_AP_CLOCK',1);p('HUD_MODE',1);p('MASTER_ARM',0)
nav_update();assert(g('F22_NAV_TARGET_N')==20000)
nav_set(10830,1);nav_set(10841,1)
assert(g('F22_NAV_TARGET_N')==20000,'fixture must retain the previous display snapshot')
assert(g('F22_NAV_DESIGNATE_STATUS_TEXT')=='DESIGNATING')
ag_update();nav_update()
assert(g('F22_NAV_DESIGNATED')==1 and g('HUD_AG_MARK_NORTH')==30000 and g('HUD_AG_MARK_EAST')==5000,
 'rapid step/designate marked the previously displayed waypoint')
local marked=g('F22_AG_TARGET_SEQUENCE')
p('HUD_MODE',7);ag_update();nav_update()
assert(g('F22_AG_TARGET_SEQUENCE')==marked and g('HUD_AG_MARK_NORTH')==30000,'A/G entry moved/cleared NAV target')
assert(g('MASTER_ARM')==0 and g('F22_NAV_DESIGNATE_STATUS_TEXT')=='TARGET DESIGNATED')
-- An existing target at the same coordinates cannot acknowledge a new request.
p('HUD_MODE',1);nav_set(10841,1);nav_update()
assert(g('F22_NAV_DESIGNATED')==0 and g('F22_NAV_DESIGNATE_STATUS_TEXT')=='DESIGNATING')
terrain_ok=false;ag_update();nav_update()
assert(g('F22_NAV_DESIGNATE_STATUS_TEXT')=='TERRAIN UNAVAIL' and g('F22_NAV_DESIGNATED')==0)
assert(g('F22_AG_TARGET_SEQUENCE')==marked,'failed planning silently changed the previous target')
terrain_ok=true
-- A pending request cancelled by a new selection must not set an old target.
nav_set(10841,1);nav_set(10831,1);ag_update();nav_update()
assert(g('F22_AG_TARGET_SEQUENCE')==marked and g('F22_NAV_DESIGNATED')==0)
-- Missing device acknowledgement is reported instead of silently disappearing.
nav_set(10841,1);p('F22_AP_CLOCK',1.6);nav_update()
assert(g('F22_NAV_DESIGNATE_STATUS_TEXT')=='DESIGNATE FAILED')
ag_update();assert(g('F22_AG_TARGET_SEQUENCE')==marked,'timed-out request applied later')
-- The private request channel must not poison the old direct-mark command.
p('F22_NAV_VALID',1);p('F22_NAV_TARGET_N',12345);p('F22_NAV_TARGET_E',678)
ag_set(10812,1);ag_set(10812,0);ag_update()
assert(g('HUD_AG_MARK_NORTH')==12345 and g('HUD_AG_MARK_EAST')==678,'legacy waypoint mark reused an old sequenced request')
p('MAIN_POWER',0);nav_set(10841,1);nav_update()
assert(g('F22_NAV_DESIGNATE_STATUS_TEXT')=='POWER OFF' and g('F22_NAV_TARGET_REQUEST_VALID')==0)
ag_update();p('MAIN_POWER',1);nav_update();ag_update();nav_update()
assert(g('F22_NAV_DESIGNATE_STATUS')==0 and g('F22_NAV_DESIGNATE_STATUS_TEXT')=='',
 'restored power left stale POWER OFF action feedback')
assert(g('F22_NAV_STATUS_TEXT')=='MISSION ROUTE' and g('F22_NAV_DESIGNATED')==0 and g('HUD_AG_TARGET_VALID')==0,
 'power recovery fabricated a successful designation')
-- An actual in-flight request must be cancelled across the outage too.
nav_set(10841,1);assert(g('F22_NAV_DESIGNATE_STATUS')==1)
p('MAIN_POWER',0);nav_update();ag_update()
p('MAIN_POWER',1);nav_update();ag_update();nav_update()
assert(g('F22_NAV_TARGET_REQUEST_VALID')==0 and g('F22_NAV_DESIGNATE_STATUS')==0 and
 g('F22_NAV_DESIGNATED')==0 and g('HUD_AG_TARGET_VALID')==0,'pending pre-outage request survived power recovery')
nav_set(10841,1);ag_update();nav_update()
assert(g('F22_NAV_DESIGNATE_STATUS')==2 and g('F22_NAV_DESIGNATED')==1,'fresh designation failed after power recovery')
""")
print('Asynchronous NAV selection/designation: exact snapshot, fresh acknowledgement, SAFE planning, A/G persistence, terrain/timeout/cancel/power failures PASS')
