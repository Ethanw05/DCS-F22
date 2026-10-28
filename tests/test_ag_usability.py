"""Store programs, physical bezel ownership and acknowledged guidance routing."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
f=ROOT/'tests/test_display_startup.py';ns={'__file__':str(f)}
exec(compile(f.read_text().split('\nfor page in ',1)[0],str(f),'exec'),ns)
runtime=ns['runtime']

lua=runtime()
lua.execute("""
local m=dofile(SCRIPT_ROOT..'Systems/AG_Stores.lua').new()
local a={count=3,CLSID='MK',weapon={level1=4,level2=5,level3=9,level4=32}}
local b={count=2,CLSID='JDAM',weapon={level1=4,level2=5,level3=36,level4=85}}
m:refresh({[4]=a,[6]=b});assert(m:group().key=='MK')
m:edit('more');m:edit('more');assert(m:profile().quantity==3)
m:profile().interval_mode=0;assert(m:start(100,7));assert(m:due(100));assert(not m:released(100));assert(not m:due(100.19));assert(m:due(100.2))
m:cancel();assert(not m:due(101));m:step(1);assert(m:group().key=='JDAM' and m:profile().mode==3 and m:profile().quantity==1)
m:step(-1);assert(m:profile().quantity==3);assert(m:start(100));assert(not m:due(99),'rewind retained consent')
a.count=1;m:refresh({[4]=a,[6]=b});assert(not m:start(101),'quantity silently reduced to remaining load')
""")
print('Stores: actual inventory groups, per-weapon memory, immutable quantity/interval, cancellation and rewind PASS')

lua=runtime()
lua.execute("""
local now=10;function get_model_time()return now end
function get_aircraft_property()return 1 end
function get_aircraft_draw_argument_value(n)return draws[n]or 0 end
function set_aircraft_draw_argument_value(n,v)draws[n]=v end
local counts={[4]=3,[6]=1};local launches={};local selected
native={get_station_info=function(_,i)return {count=counts[i]or 0,CLSID=i==6 and '{GBU_32_V_2B}' or '{F22-MK83-TRAINING}',
 weapon={level1=4,level2=5,level3=i==6 and 36 or 9,level4=i==6 and 85 or 32}}end,
 select_station=function(_,i)selected=i end,launch_station=function(_,i)
  assert(counts[i]>0);launches[#launches+1]={station=i,t=now};counts[i]=counts[i]-1
  local sequence=#launches
  for key,value in pairs({SEQUENCE=sequence,ID=500+sequence,STATION=i,MODE=7,TYPE=i==6 and 85 or 32,TIME=now})do
   get_param_handle('F22_SHOT_01_'..key):set(value)
  end
  get_param_handle('F22_LAUNCH_SEQUENCE'):set(sequence)
 end,
 get_chaff_count=function()return 120 end,get_flare_count=function()return 120 end}
function GetDevice()return native end
local function put(n,v)get_param_handle(n):set(v)end
local function val(n)return get_param_handle(n):get()end
dofile(SCRIPT_ROOT..'Systems/Weapon_System.lua');post_initialize()
put('MAIN_POWER',1);put('WoW',0);SetCommand(10800,7)
local function tick(n)for i=1,n do
 now=now+.02;put('F22_AG_SOLUTION_SCHEMA',2);put('F22_AG_SOLUTION_VALID',1);put('F22_AG_SOLUTION_TIME',now);put('F22_AG_SOLUTION_SEQUENCE',1);put('F22_AG_SOLUTION_STATION',selected or -1)
 put('F22_AG_GUIDANCE_CACHE_VALID',1);put('F22_AG_GUIDANCE_CACHE_TIME',now);put('F22_AG_GUIDANCE_CACHE_STATION',selected or -1);put('F22_AG_GUIDANCE_CACHE_SOLUTION_SEQUENCE',1)
 for _,key in ipairs({'SOURCE','SEQUENCE','N','U','E'})do put('F22_AG_GUIDANCE_CACHE_TARGET_'..key,val('F22_AG_DELIVERY_TARGET_'..key))end
 update()
end end
tick(20);assert(selected==4 and val('F22_SMS_AVAILABLE')==3)
put('CMFD_BAY_PAGE',1);put('F22_SMS_PROGRAM_PAGE',1)
SetCommand(10975,1);SetCommand(10977,2);tick(3)
assert(val('F22_SMS_ENTRY_FIELD')==1,'master SAFE cancelled keypad programming')
assert(val('F22_SMS_QUANTITY')==1,'uncommitted quantity changed the program')
SetCommand(10979,1);assert(val('F22_SMS_QUANTITY')==2 and val('F22_SMS_ENTRY_FIELD')==0)
SetCommand(10976,1);SetCommand(10977,2);SetCommand(10979,1)
assert(val('F22_SMS_ENTRY_ERROR')==2 and val('F22_SMS_ENTRY_FIELD')==2,'invalid interval committed')
SetCommand(10977,0);SetCommand(10977,1);SetCommand(10978,1);SetCommand(10977,0);SetCommand(10979,1)
assert(val('F22_SMS_INTERVAL_MS')==200 and val('F22_SMS_ENTRY_FIELD')==0)
-- A new consent executes exactly two stores, separated by the captured interval.
SetCommand(10008,1);SetCommand(10803,1);tick(80)
assert(#launches==2 and counts[4]==1 and counts[6]==1,'ripple crossed to another weapon or wrong quantity')
assert(launches[2].t-launches[1].t>=.2-1e-9,'interval ignored');tick(80);assert(#launches==2)
SetCommand(10803,0);SetCommand(10971,1);tick(15)
assert(selected==6 and val('HUD_AG_SUBMODE')==3 and val('F22_SMS_QUANTITY')==1,'type selection failed to restore its own mode/program')
-- An in-flight program edit cancels the old hold and requires a new press.
put('HUD_AG_TARGET_VALID',1);put('F22_AG_GUIDANCE_BACKEND_READY',1);put('F22_AG_AUTO_RELEASE',1)
SetCommand(10803,1);SetCommand(10974,1);tick(40);assert(#launches==2,'edited program retained consent')
SetCommand(10803,0);SetCommand(10803,1);tick(40);assert(#launches==3 and counts[6]==0)
assert(val('F22_SMS_FUZE_TEXT')=='STORE DEFAULT','unsupported fuze programming advertised')
""")
print('Real release owner: selected type, two-store interval program, single hold limit, separate guided profile and edit cancellation PASS')

# The actual queued ballistic owner is exercised by test_overhaul_ballistics.py.
# The old inline-dispatch fixture contradicted measured DCS scheduling.

lua=runtime()
lua.execute(r'''
dofile(SCRIPT_ROOT..'Systems/MFD_System.lua');post_initialize()
local function p(k,v)get_param_handle(k):set(v)end
local function g(k)return get_param_handle(k):get()end
local function key(b)SetCommand(10110+b,devices.MFD_SYSTEM+.375);SetCommand(10110+b,devices.MFD_SYSTEM+.25)end
p('MAIN_POWER',1);p('HUD_MODE',7);update()
p('HUD_AG_SUBMODE',3);p('F22_SMS_MODE_AVAILABLE_3',1)
key(6);assert(g('F22_CMFD_VIEW')==4 and g('F22_MFD_CMFD_KEY_2')=='')
p('F22_SMS_MODE_AVAILABLE_2',1);actions={};key(2)
assert(g('F22_CMFD_VIEW')==0 and actions[2][1]==10808 and actions[2][2]==1 and actions[3][2]==0)
p('F22_SMS_LABEL',1);actions={};key(8)
assert(actions[2][1]==10989 and actions[2][2]==1 and actions[3][2]==0)
key(12);actions={};key(20);assert(actions[2][1]==10807,'A/G STORES cannon selection missing')
key(11);assert(g('F22_CMFD_VIEW')==3);key(12);assert(g('F22_CMFD_VIEW')==0)
key(13);assert(g('CMFD_MENU_PAGE')==1 and g('F22_SMS_PROGRAM_PAGE')==0)
''')
for page in ['MFD_CENTER/stores_program.lua','MFD_CENTER/bay_page.lua','PMFD_CENTER/ag_radar_format.lua']:
    lua=runtime();lua.execute(f"dofile(SCRIPT_ROOT..'{page}')")
    names={e['name'] for _,e in lua.globals().elements.items()}
    for _,e in lua.globals().elements.items():
        parent=e['parent_element']
        assert parent is None or parent in names,(page,e['name'],'invalid native parent')
        for _,fmt in (e['formats'].items() if e['formats'] else []):
            if e['controllers'] and any(c[1]=='text_using_parameter' for _,c in e['controllers'].items()):
                strings = {'F22_WEAPON_NAME', 'F22_ENGINE_L_RPM_TEXT', 'F22_ENGINE_R_RPM_TEXT'}
                assert '%s' not in fmt or e['element_params'][1] in strings,(page,'numeric handle used as native string')
print('Actual formats and stores bezel: contextual MODE, selected-store HUD/keypad routing, RTN/MENU hierarchy and suppressed release edges PASS')
