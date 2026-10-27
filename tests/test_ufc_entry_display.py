"""Typed characters must reach a visible, full-size physical UFC option row."""
from pathlib import Path
root=Path(__file__).resolve().parents[1]
fixture=root/'tests/test_display_startup.py';ns={'__file__':str(fixture)}
exec(compile(fixture.read_text().split('\nfor page in ',1)[0],str(fixture),'exec'),ns)
lua=ns['runtime']()
lua.execute(r'''
local now=10
function get_model_time()return now end
function get_aircraft_property()return 1 end
local native={get_station_info=function(_,i)return {count=i==4 and 3 or 0,CLSID='{F22-MK83-TRAINING}',
 weapon={level1=4,level2=5,level3=9,level4=32}}end,select_station=function()end,
 get_chaff_count=function()return 120 end,get_flare_count=function()return 120 end}
function GetDevice()return native end
local function put(k,v)get_param_handle(k):set(v)end
local function get(k)return get_param_handle(k):get()end
dofile(SCRIPT_ROOT..'Systems/Weapon_System.lua');post_initialize();local weapon_command,weapon_update=SetCommand,update
dofile(SCRIPT_ROOT..'Systems/ICP_System.lua');post_initialize();local command,tick_icp=SetCommand,update
function dispatch_action(device,c,v)if device==devices.WEAPON_SYSTEM then weapon_command(c,v)end end
local function tick()now=now+.02;weapon_update();tick_icp()end
local function key(c)command(c,devices.ICP_SYSTEM+.375);command(c,devices.ICP_SYSTEM+.25)end
put('MAIN_POWER',1);put('F22_SMS_PROGRAM_PAGE',1);put('HUD_MODE',1)
weapon_command(10800,1);for i=1,20 do tick()end
key(10989);key(3008);key(3018);tick()
assert(get('ICP_STORES_ROW_1')==':QTY 2' and get('F22_SMS_QUANTITY')==1,'typed quantity is invisible or prematurely committed')
key(3026);tick();assert(get('ICP_STORES_ROW_1')==':QTY ----','empty entry has no visible cursor placeholder')
key(3027);key(3018);tick();assert(get('ICP_STORES_ROW_1')==':QTY 02','leading zero vanished from the draft')
key(3012);tick();assert(get('F22_SMS_QUANTITY')==2)
key(3010);key(3021);key(3027);key(3027);tick()
assert(get('ICP_STORES_ROW_3')==':INT 500 FT' and get('F22_SMS_SPACING_FT')==200,'interval draft is invisible or committed without ENTER')
-- Retain a genuine active row snapshot before opening another context.
stores_draft=get('ICP_STORES_ROW_3')
local declared={};for k in pairs(handles)do declared[k]=true end
dofile(SCRIPT_ROOT..'ICP/page_1.lua')
local function element_for(parameter)
 for _,e in ipairs(elements)do
  for _,p in ipairs(e.element_params or {})do
   if p==parameter and e.kind=='ceStringSLine'then return e end
  end
 end
 error('no native element for '..parameter)
end
local function visible_row(parameter,expected,y)
 local e=element_for(parameter)
 assert(declared[parameter],'entry parameter was not declared before native binding')
 assert(get(parameter)==expected,'visible row does not contain the entered characters: '..parameter)
 assert(math.abs(e.init_pos[2]-y)<.07 and e.stringdefs[1]>=.0043,'entry relegated to a tiny footer/outside its physical aperture')
 local echo=false
 for _,c in ipairs(e.controllers)do
  local p=e.element_params[c[2]+1];local v=get(p)
  if c[1]=='parameter_in_range'then assert(v>=c[3]and v<=c[4],'entry row is hidden')end
  if c[1]=='opacity_using_parameter'then assert(v>0,'entry row is transparent')end
  if c[1]=='text_using_parameter'and p==parameter then echo=true end
 end
 assert(echo,'native text controller does not bind the actual typed-value field')
end
visible_row('ICP_STORES_ROW_3',':INT 500 FT',0)
-- NAV and radios must echo into their active option rows as well.
put('HUD_WP_INDEX',2);put('F22_NAV_FIX_LAT',41.5);put('F22_NAV_FIX_LON',42.5)
put('F22_NAV_FIX_ALT_FT',10000);put('F22_NAV_FIX_GEO_VALID',1)
key(11030);key(3020);key(3017);key(3019);key(3027);tick()
visible_row('ICP_NAV_LAT_TEXT',':LAT N41 30.---',.6)
key(11031);key(3027);key(3017);key(3022);tick()
visible_row('ICP_CNI_1_TEXT',':TCN 016',1.2)
-- AP target data uses the same primary-row echo; no HUD changes are involved.
key(10047);key(3013);key(3009);key(3023);key(3027);key(3027);key(3027);tick()
visible_row('ICP_FLIGHT_ROW_1',':ALT 7000 FT',1.2)
for _,e in ipairs(elements)do
 for _,p in ipairs(e.element_params or {})do
  assert(p~='ICP_STORES_ENTRY'and p~='ICP_NAV_ENTRY_TEXT'and p~='ICP_CNI_ENTRY_TEXT'and p~='ICP_FLIGHT_ENTRY',
   'a detached tiny scratchpad footer remained in the native display')
 end
end
''')
print('Actual weapon/ICP/native elements: QTY/INT draft echo, leading zeros, no premature commit, NAV/radio/AP rows and physical-aperture visibility PASS')
