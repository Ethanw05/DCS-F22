"""Actual NAV keeps received radio cues while unavailable GINS position stays invalid."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
fixture = ROOT / 'tests/test_display_startup.py'
scope = {'__file__': str(fixture)}
exec(compile(fixture.read_text().split('\nfor page in ', 1)[0], str(fixture), 'exec'), scope)
lua = scope['runtime']()
lua.execute(r'''
local route={{x=0,y=0,alt=1000},{x=10000,y=0,alt=1000}}
local coordinates=true;local heading=true;local attitude=true
function get_base_data()return {
 getSelfCoordinates=function()if not coordinates then error('GPS observation unavailable')end;return 0,1000,0 end,
 getHeading=function()return heading and 0 or 0/0 end,
 getPitch=function()return attitude and 0 or 0/0 end,getRoll=function()return 0 end}end
function get_mission_route()return route end
local function put(k,v)get_param_handle(k):set(v)end
local function get(k)return get_param_handle(k):get()end
dofile(SCRIPT_ROOT..'Systems/Navigation_System.lua');local reference_fixture=dofile(SCRIPT_ROOT..'../../tests/navigation_reference_fixture.lua')();update=reference_fixture:wrap(update);post_initialize()
put('MAIN_POWER',1);put('F22_GINS_1_POSITION_FAILURE',1);put('F22_GPS_AID',1)
put('F22_NAV_SOURCE',1);put('F22_TCN_MODE',2);put('F22_TCN_BRG_VALID',1);put('F22_TCN_BRG_MAG',.1);put('F22_MAG_VALID',1)
put('F22_TCN_RANGE_VALID',1);put('F22_TCN_RANGE_M',18520)
put('HUD_LANDING_CONFIG',1);put('F22_ILS_LOC_VALID',1);put('F22_ILS_GS_VALID',1)
update()
assert(get('F22_NAV_OWN_VALID')==0 and get('HUD_WP_VALID')==0,'failed position channel used hidden host truth')
assert(get('F22_NAV_GUIDANCE_VALID')==1 and get('F22_NAV_TCN_DIST_TEXT')=='DME 10.0NM')
assert(get('HUD_ILS_LOC_VALID')==1 and get('HUD_ILS_GS_VALID')==1)
local generation=get('F22_MISSION_ROUTE_GENERATION')
route={{x=0,y=0},{x=0/0,y=0}};SetCommand(10836,1)
assert(get('F22_MISSION_ROUTE_GENERATION')==generation and get('F22_MISSION_DATA_STATUS')=='ROUTE POSITION')
put('F22_GINS_1_POSITION_FAILURE',0);put('F22_NAV_SOURCE',0);update()
assert(get('HUD_WP_INDEX')==2 and get('F22_NAV_ROUTE_COUNT')==1,'bad reload discarded the prior valid route')
put('F22_GPS_AID',1)
put('EFM_HUD_VALID',1);put('EFM_HUD_VN',100);put('F22_AP_CLOCK',10);update()
coordinates=false;put('F22_GPS_FAILURE',1);put('F22_AP_CLOCK',11);update()
assert(get('F22_NAV_OWN_VALID')==1 and get('F22_INS_COASTING')==1)
assert(get('F22_GPS_OBSERVATION_VALID')==0 and get('F22_INS_LAST_FIX_AGE')==1)
assert(get('F22_NAV_HEADING_VALID')==1,'lost position observation hid an independent heading')
attitude=false;put('F22_AP_CLOCK',11.1);update()
assert(get('F22_NAV_ATTITUDE_VALID')==0 and get('F22_NAV_OWN_VALID')==1)
heading=false;put('F22_AP_CLOCK',11.2);update()
assert(get('F22_NAV_HEADING_VALID')==0 and get('F22_NAV_OWN_VALID')==1)
local Entry=dofile(SCRIPT_ROOT..'Systems/Nav_Entry.lua')
local entry=Entry.new(2,0,0,100,true);entry.field=4;entry.below_sea=true;entry.buffer='100'
assert(entry:accept() and entry.alt==-100)
entry.buffer='1641';assert(not entry:accept() and entry.alt==-100)
entry.buffer='bad';assert(not entry:accept() and entry.error=='ENTER DIGITS')
''')
print('GINS position loss: healthy TACAN/ILS retained, invalid position withdrawn, transactional reload and signed entry PASS')
