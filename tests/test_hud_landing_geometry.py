"""Match installed Hornet proportions in native angular/controller units."""
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
lua=ns['runtime']()
lua.execute('''
sample={aoa=12,gear=1,wow=0}
function get_aircraft_draw_argument_value()return sample.gear end
function get_base_data()return setmetatable({getAngleOfAttack=function()return math.rad(sample.aoa)end,
getWOW_NoseLandingGear=function()return sample.wow end},{__index=function()return function()return 0 end end})end
local function p(n,v)get_param_handle(n):set(v)end
local function g(n)return get_param_handle(n):get()end
dofile(SCRIPT_ROOT..'Systems/HUD_Flight_Data.lua');post_initialize()
p('EFM_HUD_VALID',1);p('EFM_HUD_VN',100);p('EFM_HUD_TAS',100);p('EFM_HUD_SOUND',340);p('EFM_HUD_PRESSURE',101325)
update();assert(g('HUD_EBRACKET_VALID')==1 and g('HUD_EBRACKET_OFFSET')==0,'on-speed bracket disappeared')
sample.aoa=14;update();assert(math.abs(g('HUD_EBRACKET_OFFSET')-math.tan(math.rad(2)))<1e-9)
sample.aoa=10;update();assert(g('HUD_EBRACKET_OFFSET')<0)
sample.wow=1;update();assert(g('HUD_EBRACKET_VALID')==0)
sample.wow=0;sample.gear=0;update();assert(g('HUD_EBRACKET_VALID')==0)
sample.gear=1;sample.aoa=0/0;update();assert(g('HUD_EBRACKET_VALID')==0)
sample.aoa=12;sample.wow=1;p('EFM_GROUND_VALID',1);p('EFM_WEIGHT_ON_WHEELS',0);update()
assert(g('HUD_EBRACKET_VALID')==1,'generic base WOW overrode native airborne suspension contact')
p('EFM_WEIGHT_ON_WHEELS',1);sample.wow=0;update()
assert(g('HUD_EBRACKET_VALID')==0,'generic airborne sensor overrode native ground contact')
''')
print('Landing E-bracket: persistent on-speed cue, continuous AOA error, authoritative contact and gear/data gates PASS')
