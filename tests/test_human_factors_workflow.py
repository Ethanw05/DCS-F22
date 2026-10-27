"""Actual-owner scenarios for unintended acceptance, mode changes and hidden coordinates."""
from pathlib import Path
root=Path(__file__).resolve().parents[1]
fixture=root/'tests/test_display_startup.py';ns={'__file__':str(fixture)}
exec(compile(fixture.read_text().split('\nfor page in ',1)[0],str(fixture),'exec'),ns)
lua=ns['runtime']()
lua.execute(r'''
function get_aircraft_property()return 1 end
function get_model_time()return 10 end
local function p(k,v)get_param_handle(k):set(v)end
local function g(k)return get_param_handle(k):get()end
local events={}
function dispatch_action(d,c,v)events[#events+1]={d,c,v}end
dofile(SCRIPT_ROOT..'Systems/ICP_System.lua');post_initialize()
local function key(c)SetCommand(c,devices.ICP_SYSTEM+.375);SetCommand(c,devices.ICP_SYSTEM+.25);update()end
local function digits(s)for d in s:gmatch('.')do key(d=='0'and 3027 or 3016+tonumber(d))end end
p('MAIN_POWER',1);p('HUD_MODE',1);p('F22_ALT_PRESSURE_MMHG',760)
key(10047);key(3013);key(3009);digits('7000');events={}
key(3008);key(3029);assert(#events==0,'field/readback or wheel accepted a typed AP draft')
assert(g('ICP_FLIGHT_ROW_1')==':ALT 7000 FT'and g('ICP_FLIGHT_ROW_5')=='ENTR')
key(3012);assert(#events==1 and events[1][2]==11011 and events[1][3]==7000)
key(3012);assert(#events==1 and g('ICP_FLIGHT_ROW_5')=='ENTR','repeat ENTER changed a mode')
key(3011);key(3012);digits('080');key(3012)
assert(events[#events][2]==11014 and events[#events][3]==.8,'separate Mach reference did not commit')
p('F22_AP_MACH',.8);p('F22_AP_SPEED',300);events={};key(3029)
assert(#events==1 and events[1][2]==11014 and math.abs(events[1][3]-.81)<1e-8,'Mach wheel changed the CAS reference')
key(3011);key(3011);events={};key(3029)
assert(#events==1 and events[1][2]==11013 and events[1][3]==305,'CAS wheel changed the Mach reference')
key(3011);key(3009);digits('8000');events={};key(3013)
assert(#events==0 and g('ICP_FLIGHT_MENU')==3,'page change submitted a pending reference')
key(3012);digits('100');key(3012)
assert(#events==0 and g('ICP_FLIGHT_ROW_3')=='RALT 200-5000 FT','RALT rejection lost corrective range')
key(3011);key(10045);key(3008);digits('299');events={};key(3012)
assert(#events==0 and g('ICP_FLIGHT_ROW_3')=='BARO 2560-3228','pressure format error is not useful')
key(3028);digits('2992');key(3012)
assert(events[#events][2]==11024 and math.abs(events[#events][3]-759.968)<.001)
key(3012);assert(#events==1,'repeat pressure ENTER changed STD or units')
key(11031);digits('016');events={};key(3012);key(3012)
assert(#events==1 and events[1][2]==10946 and events[1][3]==16,'repeat radio ENTER changed TACAN mode')
p('HUD_WP_INDEX',2);p('F22_NAV_FIX_LAT',41.5);p('F22_NAV_FIX_LON',42.5)
p('F22_NAV_FIX_ALT_FT',10000);p('F22_NAV_FIX_GEO_VALID',1)
key(11030);digits('4130123');assert(g('ICP_NAV_LAT_TEXT')==':LAT N41 30.123')
key(3014);assert(g('ICP_NAV_LAT_TEXT')==':LAT S41 30.123','hemisphere changed without visible feedback')
key(3012);assert(math.abs(g('F22_NAV_EDIT_LAT')+41.50205)<1e-8)
key(3009);digits('4130');key(3012)
assert(g('ICP_NAV_ENTER_TEXT')=='LAT DDMM.MMM'and g('ICP_NAV_LAT_TEXT')==':LAT S41 30.---')
key(3028);digits('4160000');key(3012);assert(g('ICP_NAV_ENTER_TEXT')=='MIN 00-59.999')
local E=dofile(SCRIPT_ROOT..'Systems/Nav_Entry.lua');local zero=E.new(2,0,0,0,true)
zero:choose(2);zero:hemisphere();assert(E.draft('0000000',true,zero.south)=='S00 00.000')
assert(E.coord(41.99999999,true)=='N42 00.000','rounding produced 60.000 minutes')
''')
print('Human factors: explicit/repeated ENTER, AP/ALT cancellation, independent Mach data, corrective errors and visible coordinate sign PASS')

lua=ns['runtime']()
lua.execute(r'''
local now=10
function get_model_time()return now end
function get_aircraft_property()return 1 end
local native={get_station_info=function(_,i)return {count=i==4 and 3 or 0,CLSID='{F22-MK83-TRAINING}',weapon={level1=4,level2=5,level3=9,level4=32}}end,
 select_station=function()end,get_chaff_count=function()return 120 end,get_flare_count=function()return 120 end}
function GetDevice()return native end
local function p(k,v)get_param_handle(k):set(v)end
local function g(k)return get_param_handle(k):get()end
dofile(SCRIPT_ROOT..'Systems/Weapon_System.lua');post_initialize();local wc,wu=SetCommand,update
dofile(SCRIPT_ROOT..'Systems/ICP_System.lua');post_initialize();local ic,iu=SetCommand,update
function dispatch_action(d,c,v)if d==devices.WEAPON_SYSTEM then wc(c,v)end end
local function tick()now=now+.02;wu();iu()end
local function key(c)ic(c,devices.ICP_SYSTEM+.375);ic(c,devices.ICP_SYSTEM+.25);tick()end
p('MAIN_POWER',1);p('F22_SMS_PROGRAM_PAGE',1);wc(10800,1);for i=1,20 do tick()end
key(10989);key(3008);key(3025);key(3012)
assert(g('ICP_STORES_ROW_5')==' QTY 1-3'and g('F22_SMS_QUANTITY')==1,'stores error is not based on actual loaded quantity')
key(3010);key(3021);key(3012)
assert(g('ICP_STORES_ROW_5')==' INT 10-9999 FT','spacing error does not match backend limits')
''')
print('Human factors: actual weapon owner publishes corrective errors without changing saved programs PASS')
