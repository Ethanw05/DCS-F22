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
 select_station=function(_,i)selected=i end,launch_station=function(_,i)assert(counts[i]>0);launches[#launches+1]={station=i,t=now};counts[i]=counts[i]-1 end,
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
lua.execute("""
function get_aircraft_property()return 1 end
function set_aircraft_draw_argument_value(n,v)draws[n]=v end
dofile(SCRIPT_ROOT..'Systems/MFD_System.lua');post_initialize();get_param_handle('MAIN_POWER'):set(1)
update()
-- MODE reveals compatible choices; mode alternatives are not permanent tabs.
actions={};SetCommand(10116,1);SetCommand(10116,0)
assert(get_param_handle('F22_SMS_UI_PAGE'):get()==4 and #actions==2 and actions[2][1]==10980)
get_param_handle('F22_SMS_MODE_AVAILABLE_2'):set(1)
actions={};SetCommand(10112,1);SetCommand(10112,0)
assert(#actions==3 and actions[1][1]==10742 and actions[1][2]==5 and actions[3][1]==10808)
assert(get_param_handle('F22_SMS_UI_PAGE'):get()==0)
get_param_handle('F22_SMS_LABEL'):set(1)
actions={};SetCommand(10118,1);SetCommand(10118,0)
assert(#actions==2 and actions[2][1]==10989,'Stores HUD must open the front keypad')
actions={};SetCommand(10119,1);SetCommand(10119,0)
assert(#actions==1 and actions[1][1]==10742,'blank former interval key must not edit a weapon')
SetCommand(10122,1);assert(get_param_handle('F22_SMS_UI_PAGE'):get()==1)
SetCommand(10123,1);assert(get_param_handle('F22_SMS_UI_PAGE'):get()==0)
SetCommand(10123,0);SetCommand(10123,1);update()
assert(get_param_handle('CMFD_MENU_PAGE'):get()==1 and get_param_handle('F22_SMS_PROGRAM_PAGE'):get()==0,'RTN/MENU hierarchy failed')
""")
for page in ['MFD_CENTER/stores_program.lua','MFD_CENTER/bay_page.lua','PMFD_CENTER/ag_radar_format.lua']:
    lua=runtime();lua.execute(f"dofile(SCRIPT_ROOT..'{page}')")
    names={e['name'] for _,e in lua.globals().elements.items()}
    for _,e in lua.globals().elements.items():
        parent=e['parent_element']
        assert parent is None or parent in names,(page,e['name'],'invalid native parent')
        for _,fmt in (e['formats'].items() if e['formats'] else []):
            if e['controllers'] and any(c[1]=='text_using_parameter' for _,c in e['controllers'].items()):
                assert '%s' not in fmt or e['element_params'][1]=='F22_WEAPON_NAME',(page,'numeric handle used as native string')
print('Actual formats and stores bezel: contextual MODE, selected-store HUD/keypad routing, RTN/MENU hierarchy and suppressed release edges PASS')


lua=runtime()
lua.execute("""
dofile(SCRIPT_ROOT..'Systems/ICP_System.lua');post_initialize()
local function put(n,v)get_param_handle(n):set(v)end
put('MAIN_POWER',1);put('HUD_MODE',7);put('CMFD_BAY_PAGE',1);put('F22_SMS_PROGRAM_PAGE',1);put('F22_SMS_ENTRY_FIELD',1)
for _,r in ipairs({{3027,10977,0},{3019,10977,3},{3026,10978,1},{3012,10979,1},{3028,10980,1}})do
 actions={};SetCommand(r[1],7.375);SetCommand(r[1],7.25)
 assert(#actions==1 and actions[1][1]==r[2] and actions[1][2]==r[3],'ICP stores routing or decoded release failed')
end
-- Choosing navigation cancels a stores edit and uses the original NAV transaction.
actions={};SetCommand(3004,7.375);assert(actions[1][1]==10980)
""")
print('ICP: zero/digits, CLR, OP5 store and UNDO scoped to bottom stores; navigation handoff cancels the edit PASS')
