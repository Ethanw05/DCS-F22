"""Check the native Hornet cue direction/scale with the F-22 normal reference."""
from pathlib import Path
import math
ROOT=Path(__file__).resolve().parents[1]
fixture=ROOT/'tests/test_display_startup.py';ns={'__file__':str(fixture)}
exec(compile(fixture.read_text().split('\nfor page in ',1)[0],str(fixture),'exec'),ns)
for scale in (.001,.00055):
 lua=ns['runtime']();lua.globals().unit_scale=scale
 lua.execute('function GetScale()return unit_scale end;dofile(SCRIPT_ROOT.."HUD/page.lua")')
 elements={e['name']:e for _,e in lua.globals().elements.items()}
 assert 'HUD_ILS_LOCALIZER'not in elements and 'HUD_ILS_GLIDESLOPE'not in elements,'unrequested ILS cross returned'
 assert elements['HUD_EBRACKET']['parent_element']=='HUD_FPM'
 bracket=elements['HUD_EBRACKET']
 assert math.isclose(bracket['init_pos'][1],-20.4,abs_tol=1e-9)
 # Positive owner output must move up, matching the native local-Y translation.
 assert math.isclose(bracket['controllers'][1][3],1000*scale,abs_tol=1e-9)
 assert 'HUD_APPROACH_LOW'not in elements and 'HUD_APPROACH_HIGH'not in elements
 spine=elements['HUD_EBRACKET_SPINE'];ys=[v[2]for _,v in spine['vertices'].items()]
 assert math.isclose(max(ys)-min(ys),100*1.2*.34,abs_tol=1e-9)
 assert 'HUD_HORIZON_LANDING'not in elements,'unrequested landing horizon expansion returned'
 assert elements['HUD_BANK_SCALE']['element_params'][1]=='HUD_LANDING_CONFIG'
 gain=elements['HUD_NAV_COURSE_ARROW']['controllers'][1][3]
 assert math.isclose(gain*math.radians(8),8*19*.34*scale,abs_tol=1e-9)
 assert elements['HUD_NAV_COURSE_ARROW']['init_pos'][2]==0,'invented steering-arrow vertical offset returned'
 assert elements['HUD_NAV_STEER_DOTS']['controllers'][1][3]==1.2499
 assert all('HUD_EW_CONTACT_'+str(i)in elements for i in range(1,7)),'HUD RWR repeater removed'
 print('E-bracket only, source-scaled Hornet NAV steering and intact HUD RWR at native scale',scale,'PASS')
math_lua=ns['runtime']().execute((ROOT/'Cockpit/Scripts/Systems/HUD_FlightMath.lua').read_text())
# Recovered native chain: producer 3E4D00 -> bus70 -> HUD35 -> 4E0220.
# Native 8.1-degree reference is used only as a comparison vector, never for F-22.
for aoa,reference,expected in ((6.1,8.1,.03490658503988659),
                              (8.1,8.1,0),(10.1,8.1,-.03490658503988659),
                              (10,12,.03490658503988659),(12,12,0),
                              (14,12,-.03490658503988659)):
 assert math.isclose(math_lua.approach_offset(aoa,reference),expected,abs_tol=1e-12)
for aoa,sign in ((-60,1),(90,-1)):
 offset=math_lua.approach_offset(aoa,12)
 assert offset*sign>0
 assert math.isclose(math.hypot(.0204,offset),math.radians(10),abs_tol=1e-12)
assert math_lua.approach_offset(float('nan'),12) is None
assert math_lua.approach_offset(12,float('inf')) is None
lua=ns['runtime']()
lua.execute('''
sample={aoa=12,gear=1,wow=0}
function get_aircraft_draw_argument_value()return sample.gear end
function get_base_data()return setmetatable({getAngleOfAttack=function()return math.rad(sample.aoa)end,
getWOW_NoseLandingGear=function()return sample.wow end},{__index=function()return function()return 0 end end})end
local function p(n,v)get_param_handle(n):set(v)end
local function g(n)return get_param_handle(n):get()end
dofile(SCRIPT_ROOT..'Systems/HUD_Flight_Data.lua');update=dofile(SCRIPT_ROOT..'../../tests/reference_frame_fixture.lua')():wrap(update);post_initialize()
p('EFM_HUD_VALID',1);p('EFM_HUD_VN',100);p('EFM_HUD_TAS',100);p('EFM_HUD_SOUND',340);p('EFM_HUD_PRESSURE',101325)
local physical=dofile(SCRIPT_ROOT..'../../tests/physical_frame_fixture.lua')({
 EFM_GROUND_VALID=1,EFM_WEIGHT_ON_WHEELS=0,EFM_GEAR_DOWN_LOCKED=1,EFM_GEAR_UP_LOCKED=0,EFM_GEAR_UNSAFE=0,
 EFM_AIRDATA_VALID=1,EFM_AIRDATA_HEALTH=0,EFM_AIRDATA_STAMP=0,EFM_AIRDATA_CAS_MPS=100,EFM_AIRDATA_TAS_MPS=100})
update=physical:wrap(update)

update();assert(g('HUD_EBRACKET_VALID')==1 and g('HUD_EBRACKET_OFFSET')==0,'on-speed bracket disappeared')
sample.aoa=14;update();assert(math.abs(g('HUD_EBRACKET_OFFSET')+.03490658503988659)<1e-9,
 'high AoA must place the bracket below the velocity vector')
sample.aoa=10;update();assert(math.abs(g('HUD_EBRACKET_OFFSET')-.03490658503988659)<1e-9,
 'low AoA must place the bracket above the velocity vector')
local before=g('HUD_EBRACKET_OFFSET');sample.aoa=10.1;update()
assert(g('HUD_EBRACKET_OFFSET')<before,'small continuous AoA changes did not move the bracket')
physical.values.EFM_GEAR_UNSAFE=1;update();assert(g('HUD_EBRACKET_VALID')==0)
physical.values.EFM_GEAR_UNSAFE=0;physical.values.EFM_AIRDATA_STAMP=-1;update()
assert(g('HUD_EBRACKET_VALID')==0 and g('HUD_EBRACKET_OFFSET')==0,'stale ADC retained approach guidance')
physical.values.EFM_AIRDATA_STAMP=0;update();assert(g('HUD_EBRACKET_VALID')==1)
sample.wow=1;physical.values.EFM_WEIGHT_ON_WHEELS=1;update();assert(g('HUD_EBRACKET_VALID')==0)
sample.wow=0;sample.gear=0;physical.values.EFM_WEIGHT_ON_WHEELS=0;physical.values.EFM_GEAR_DOWN_LOCKED=0;physical.values.EFM_GEAR_UP_LOCKED=1;update();assert(g('HUD_EBRACKET_VALID')==0)
sample.gear=1;sample.aoa=0/0;physical.values.EFM_GEAR_DOWN_LOCKED=1;physical.values.EFM_GEAR_UP_LOCKED=0;update();assert(g('HUD_EBRACKET_VALID')==0)
sample.aoa=12;sample.wow=1;p('EFM_GROUND_VALID',1);p('EFM_WEIGHT_ON_WHEELS',0);update()
assert(g('HUD_EBRACKET_VALID')==1,'generic base WOW overrode native airborne suspension contact')
physical.values.EFM_WEIGHT_ON_WHEELS=1;sample.wow=0;update()
assert(g('HUD_EBRACKET_VALID')==0,'generic airborne sensor overrode native ground contact')
''')
print('Landing E-bracket: native sign/linear gain/radial limit, F-22 center, continuous motion and gear/contact/data gates PASS')
