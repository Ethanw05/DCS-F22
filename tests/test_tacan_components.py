"""Actual guidance: receiver components, course-line indications and authority."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
fixture = ROOT / 'tests/test_display_startup.py'
scope = {'__file__': str(fixture)}
exec(compile(fixture.read_text().split('\nfor page in ', 1)[0], str(fixture), 'exec'), scope)
lua = scope['runtime']()
lua.execute(r'''
local function get(k)return get_param_handle(k):get()end
local function put(k,v)get_param_handle(k):set(v)end
local guide=dofile(SCRIPT_ROOT..'Systems/Nav_Guidance.lua')
local radio=dofile(SCRIPT_ROOT..'Systems/Radio_Navigation.lua')
local own={x=0,y=0,alt=1000,heading=0,gs=200}
put('MAIN_POWER',1);put('HUD_MODE',1);put('HUD_FPM_VALID',1)
put('F22_NAV_SOURCE',1);put('F22_NAV_OBS',1);put('F22_MAG_VALID',1)
put('F22_TCN_BRG_VALID',1);put('F22_TCN_RANGE_VALID',1)
put('F22_TCN_BRG_MAG',math.rad(4));put('F22_TCN_MODE',2)
for _,range in ipairs({1852,18520,185200})do
 put('F22_TCN_RANGE_M',range);guide(get,put,own,nil)
 assert(get('F22_NAV_CDI_VALID')==1 and math.abs(get('F22_NAV_CDI')-.5)<1e-10,
  'angular TACAN CDI changed with range')
 assert(get('F22_NAV_CDI_SCALE_TEXT')=='CDI 4/8D' and get('F22_NAV_STEER_VALID')==1)
end
put('F22_TCN_BRG_MAG',math.rad(184));guide(get,put,own,nil)
assert(math.abs(get('F22_NAV_CDI')+.5)<1e-10 and get('F22_NAV_TO_FROM')=='FROM')
put('F22_TCN_BRG_MAG',math.rad(-20));guide(get,put,own,nil)
assert(get('F22_NAV_CDI')==-1,'outer scale did not saturate')
-- Raw host flags cannot grant an impossible component for the selected mode.
put('F22_TCN_MODE',1);radio.publish_data(get,put);guide(get,put,own,nil)
assert(get('F22_NAV_TCN_RANGE_AVAILABLE')==0 and get('F22_NAV_TCN_BRG_AVAILABLE')==1)
assert(get('F22_NAV_CDI_VALID')==1 and get('F22_NAV_GUIDANCE_VALID')==1)
assert(get('F22_NAV_STEER_VALID')==0 and get('HUD_NAV_STEER_VALID')==0,
 'bearing-only course acquired a range-dependent intercept/direct-to solution')
put('F22_NAV_OBS',0);guide(get,put,own,nil)
assert(get('F22_NAV_STEER_VALID')==1,'REC lost valid direct bearing steering')
for _,mode in ipairs({3,4})do
 put('F22_TCN_MODE',mode);radio.publish_data(get,put);guide(get,put,own,nil)
 assert(get('F22_NAV_TCN_BRG_AVAILABLE')==0 and get('F22_NAV_TCN_RANGE_AVAILABLE')==1)
 assert(get('F22_NAV_GUIDANCE_VALID')==0 and get('F22_NAV_STEER_VALID')==0)
 assert(get('F22_NAV_DIST_TEXT')=='DME 100.0NM' and get('F22_NAV_STATUS_TEXT')=='TCN DME ONLY')
end
put('F22_TCN_MODE',2);put('F22_TCN_BRG_VALID',0);guide(get,put,own,nil)
assert(get('F22_NAV_DIST_TEXT')=='DME 100.0NM' and get('F22_NAV_GUIDANCE_VALID')==0)
put('F22_TCN_BRG_VALID',1);put('F22_MAG_VALID',0);put('F22_NAV_REFERENCE',1)
radio.publish_data(get,put);guide(get,put,own,nil)
assert(get('F22_NAV_TCN_BRG_AVAILABLE')==1 and get('F22_NAV_GUIDANCE_VALID')==0,
 'magnetic receiver readout incorrectly required ownship variation')
put('F22_NAV_REFERENCE',0);radio.publish_data(get,put)
assert(get('F22_NAV_TCN_BRG_AVAILABLE')==0,'unknown variation became a true bearing')
put('F22_MAG_VALID',1);put('F22_MAG_DECL',0/0);guide(get,put,own,nil)
assert(get('F22_NAV_GUIDANCE_VALID')==0,'nonfinite variation granted guidance')
put('F22_MAG_DECL',0);put('F22_TCN_RANGE_M',-1);radio.publish_data(get,put)
assert(get('F22_NAV_TCN_RANGE_AVAILABLE')==0)
put('F22_TCN_MODE',0);guide(get,put,own,nil)
assert(get('F22_NAV_GUIDANCE_VALID')==0 and get('F22_NAV_CDI_VALID')==0)
-- Waypoint CDI retains its own distance-based scale, not the radio angle.
put('F22_NAV_SOURCE',0);put('F22_NAV_OBS',0)
local route={bearing=0,course=0,cross=-1852,distance=18520,waypoint={id=2}}
guide(get,put,own,route)
assert(get('F22_NAV_CDI_SCALE_TEXT')=='CDI 2NM' and get('F22_NAV_CDI')==.5)
''')
print('TACAN: angular/range independence, TO/FROM, REC/TR/A-A, range-only data, reference loss, invalid inputs and separate waypoint scale PASS')
