"""DCS affiliation metadata through the actual receiver, fusion and DEF owner."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
fixture=ROOT/'tests/test_display_startup.py'
ns={'__file__':str(fixture)}
exec(compile(fixture.read_text().split('\nfor page in ',1)[0],str(fixture),'exec'),ns)
lua=ns['runtime']()
lua.execute('''
local now=10
function get_model_time()return now end
function GetDevice()return {set_power=function()end}end
local function put(k,v)get_param_handle(k):set(v)end
local function get(k)return get_param_handle(k):get()end
dofile(SCRIPT_ROOT..'Systems/RWR_System.lua');post_initialize()
put('MAIN_POWER',1);put('RADAR_PWR',0)
for k,v in pairs({SOURCE=42,TIME=.2,AZIMUTH=.3,ELEVATION=0,SIGNAL=1,
    PRIORITY=100,POWER=.4,GENERAL_TYPE=1,UNIT_TYPE='F-16C'})do put('RWR_CONTACT_01_'..k,v)end
local function metadata(side)
    put('F22_RWR_META_READY',1);put('F22_RWR_META_SEQUENCE',4);put('F22_RWR_META_TIME',now)
    put('F22_RWR_META_01_SOURCE',42);put('F22_RWR_META_01_SAMPLE_TIME',now-.2)
    put('F22_RWR_META_01_AFFILIATION',side)
end
metadata(1);update()
assert(get('F22_EW_01_AFFILIATION')==1 and get('F22_DEF_OV_01_AFFILIATION')==1)
assert(get('F22_EW_01_SOURCE')==42 and get('F22_TACTICAL_01_RANGE_VALID')==0)
assert(get('F22_TACTICAL_01_FRIENDLY_PROTECTED')==1,'friendly emitter lost protection')
now=10.1;metadata(0);update()
assert(get('F22_EW_01_AFFILIATION')==0 and get('F22_DEF_OV_01_AFFILIATION')==0)
-- Type/airframe and an absent reply never independently assign allegiance.
now=10.2;metadata(-1);update();assert(get('F22_EW_01_AFFILIATION')==-1)
metadata(1);put('F22_RWR_META_01_SOURCE',43);update();assert(get('F22_EW_01_AFFILIATION')==-1)
metadata(1);put('F22_RWR_META_SEQUENCE',5);update();assert(get('F22_EW_01_AFFILIATION')==-1)
metadata(1);put('F22_RWR_META_TIME',now+1);update();assert(get('F22_EW_01_AFFILIATION')==-1)
metadata(1);put('F22_RWR_META_TIME',now-.3);update();assert(get('F22_EW_01_AFFILIATION')==-1)
metadata(1);put('F22_RWR_META_01_SAMPLE_TIME',now-13);update();assert(get('F22_EW_01_AFFILIATION')==-1)
metadata(1);put('F22_RWR_META_READY',0);update();assert(get('F22_EW_01_AFFILIATION')==-1)
put('MAIN_POWER',0);update();assert(get('F22_EW_01_VALID')==0)
''')
print('Received DCS affiliation: actual RWR/DEF friendly and hostile, no invented range, stale/torn/foreign/neutral unknown and power withdrawal PASS')
