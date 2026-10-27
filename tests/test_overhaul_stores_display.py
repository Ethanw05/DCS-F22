"""Actual stores controller ownership and scratchpad/navigation integration.

These checks exercise actions and cancellation, not visual text coordinates.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
fixture = ROOT / 'tests/test_display_startup.py'
ns = {'__file__': str(fixture)}
exec(compile(fixture.read_text().split('\nfor page in ', 1)[0], str(fixture), 'exec'), ns)
runtime = ns['runtime']
lua = runtime()
lua.execute(r'''
local Controller=dofile(SCRIPT_ROOT..'Systems/Stores_Display.lua')
local sent,pages,overrides,hud={},{},0,0
local function p(k)return get_param_handle(k)end
local function send(c,v)sent[#sent+1]={c,v}end
local display=Controller.new(p,send,function(page)pages[#pages+1]=page end,function()overrides=overrides+1 end,function()hud=hud+1 end)
assert(p('F22_SMS_PROGRAM_PAGE'):get()==0 and not display:handle(13))
display:update(true);assert(p('F22_SMS_PROGRAM_PAGE'):get()==1)
-- Unlabelled home keys are consumed, so old bay overrides cannot receive them.
for button=14,17 do
 local n=#sent;assert(display:handle(button));assert(#sent==n and overrides==0)
end
-- Labels may show a window into more than five types: select its backend index.
p('F22_SMS_STORE_1_INDEX'):set(7);assert(display:handle(1))
assert(sent[#sent][1]==10981 and sent[#sent][2]==7,'visible class row selected an absolute bezel number')
local empty_count=#sent;p('F22_SMS_STORE_2_INDEX'):set(0);assert(display:handle(2));assert(#sent==empty_count)
-- Only an explicitly available mode may leave the mode-selection popup.
assert(display:handle(6));assert(p('F22_SMS_UI_PAGE'):get()==4)
local n=#sent;assert(display:handle(2));assert(#sent==n and p('F22_SMS_UI_PAGE'):get()==4)
p('F22_SMS_MODE_AVAILABLE_3'):set(1);assert(display:handle(3))
assert(sent[#sent][1]==10809 and sent[#sent][2]==1 and p('F22_SMS_UI_PAGE'):get()==0)
-- Returning from programming cancels the edit before going back home.
assert(display:handle(12));assert(p('F22_SMS_UI_PAGE'):get()==1)
local previous_pages=#pages;assert(display:handle(18))
assert(sent[#sent][1]==10804 and p('F22_SMS_UI_PAGE'):get()==1 and #pages==previous_pages,'program station step navigated to FCS')
p('F22_SMS_LABEL'):set(1);assert(display:handle(8));assert(hud==1,'HUD did not open keypad programming')
n=#sent;assert(display:handle(9));assert(#sent==n,'blank former interval key dispatched an edit')
assert(display:handle(13));assert(sent[#sent][1]==10980 and p('F22_SMS_UI_PAGE'):get()==0)
assert(display:handle(13));assert(pages[#pages]==0,'home MENU did not return to parent menu')
-- Door overrides require the explicit doors subpage; blank popup keys consume.
assert(display:handle(11));assert(p('F22_SMS_UI_PAGE'):get()==2)
n=#sent;assert(display:handle(8));assert(#sent==n and overrides==0)
assert(display:handle(10));assert(overrides==1)
display:update(false)
assert(sent[#sent][1]==10980 and p('F22_SMS_UI_PAGE'):get()==0 and p('F22_SMS_PROGRAM_PAGE'):get()==0)
n=#sent;display:update(false);assert(#sent==n,'hidden display repeatedly sent cancellations')
for button=1,20 do assert(not display:handle(button))end
display:update(true);assert(p('F22_SMS_UI_PAGE'):get()==0,'old transient popup returned after reopening')
-- Cannon has its own employment context. Hidden bomb controls stay consumed.
p('HUD_AG_SUBMODE'):set(1)
for _,button in ipairs({7,8,9,10,12,14,15,16,17})do
 local previous=#sent;assert(display:handle(button));assert(#sent==previous,'hidden bomb control remained live in GUN')
end
display:set(1);display:update(true);assert(p('F22_SMS_UI_PAGE'):get()==0,'GUN retained a bomb-program subpage')
''')
print('Overhaul stores controller: blank keys, compatible modes, menu return, explicit door controls and visibility cancellation PASS')

lua=runtime()
lua.execute(r'''
local now=10;function get_model_time()return now end
local native={get_station_info=function(_,i)return {count=i==4 and 3 or 0,
 CLSID='{F22-MK83-TRAINING}',weapon={level1=4,level2=5,level3=9,level4=32}}end,
 select_station=function()end,get_chaff_count=function()return 120 end,get_flare_count=function()return 120 end}
function GetDevice()return native end
local function p(k,v)get_param_handle(k):set(v)end
local function g(k)return get_param_handle(k):get()end
dofile(SCRIPT_ROOT..'Systems/Weapon_System.lua');post_initialize();local wc,wu=SetCommand,update
dofile(SCRIPT_ROOT..'Systems/MFD_System.lua');post_initialize();local mc,mu=SetCommand,update
dofile(SCRIPT_ROOT..'Systems/ICP_System.lua');post_initialize();local ic,iu=SetCommand,update
function dispatch_action(d,c,v)if d==devices.WEAPON_SYSTEM then wc(c,v)elseif d==devices.ICP_SYSTEM then ic(c,v)end end
local function tick()now=now+.02;wu();mu();iu()end
local function bezel(base,b)mc(base+b,devices.MFD_SYSTEM+.375);mc(base+b,devices.MFD_SYSTEM+.25);tick()end
local function key(c)ic(c,devices.ICP_SYSTEM+.375);ic(c,devices.ICP_SYSTEM+.25);tick()end
p('MAIN_POWER',1);p('HUD_MODE',1);wc(10800,1);for i=1,20 do tick()end
bezel(10110,8);assert(g('F22_UFC_PAGE')=='STORES')
key(3008);key(3018);key(3008);assert(g('F22_SMS_QUANTITY')==2)
key(3010);key(3021);key(3027);key(3027);key(3010);assert(g('F22_SMS_SPACING_FT')==500)
key(3008);key(3017);assert(g('F22_SMS_ENTRY_FIELD')==1)
bezel(10110,13);assert(g('CMFD_MENU_PAGE')==1 and g('F22_SMS_ENTRY_FIELD')==0 and g('F22_UFC_PAGE')=='')
bezel(10110,3);assert(g('F22_CMFD_VIEW')==0)
mc(10823,1);tick();assert(g('CMFD_HSI_PAGE')==1)
bezel(10060,13);bezel(10060,3);bezel(10060,8)
assert(g('F22_UFC_PAGE')=='STORES'and g('CMFD_HSI_PAGE')==1,'left Stores redirected lower NAV')
key(3008);key(3017);key(3008);assert(g('F22_SMS_QUANTITY')==1)
key(3010);key(3018);key(3021);key(3027);key(3010);assert(g('F22_SMS_SPACING_FT')==250)
key(3008);key(3018);wc(10800,2);tick()
assert(g('F22_SMS_ENTRY_FIELD')==0 and g('F22_UFC_PAGE')=='','A/A retained a bomb numeric edit')
wc(10800,7);tick();bezel(10060,8);key(3008);key(3017)
p('MAIN_POWER',0);tick();assert(g('F22_SMS_ENTRY_FIELD')==0 and g('F22_UFC_SELECTED')==0)
''')
print('Actual Stores/MFD/UFC owners: same-option QTY/interval, local left display, MENU, power and mode cancellation PASS')

lua = runtime()
lua.execute(r'''
dofile(SCRIPT_ROOT..'MFD_CENTER/stores_program.lua')
local names={}
for _,element in ipairs(elements)do
 assert(not names[element.name],'duplicate native element name: '..element.name)
 names[element.name]=element
end
for _,element in ipairs(elements)do
 assert(not element.parent_element or names[element.parent_element],'unresolved native parent: '..element.name)
end
local function visible(element,seen)
 seen=seen or {};assert(not seen[element.name],'native parent cycle');seen[element.name]=true
 if element.parent_element and not visible(names[element.parent_element],seen)then return false end
 for _,controller in ipairs(element.controllers or {})do
  local parameter=element.element_params and element.element_params[controller[2]+1]
  local v=parameter and get_param_handle(parameter):get()
  if controller[1]=='parameter_in_range'and(v<controller[3]or v>controller[4])then return false end
  if controller[1]=='opacity_using_parameter'and v<=0 then return false end
 end
 return true
end
local function text_visible(label)
 for _,element in ipairs(elements)do if element.value==label and visible(element)then return true end end
 return false
end
get_param_handle('MFD_OPACITY'):set(1);get_param_handle('CMFD_BAY_PAGE'):set(1);get_param_handle('MASTER_ARM'):set(0)
get_param_handle('HUD_AG_SUBMODE'):set(2)
for _,page in ipairs({0,1,2,4})do
 get_param_handle('F22_SMS_UI_PAGE'):set(page)
 for _,label in ipairs({'STORES','MASTER SAFE'})do
  assert(text_visible(label),'persistent label hidden on stores subpage '..page..': '..label)
 end
 assert(not text_visible('ENG')and not text_visible('FUEL')and not text_visible('FCS')and not text_visible('FUZE'),'unrelated/unsupported controls clutter stores')
 assert(text_visible('BAY DOORS')==(page==2),'door detail disagrees with selected subpage')
end
get_param_handle('F22_SMS_UI_PAGE'):set(0);get_param_handle('HUD_AG_SUBMODE'):set(1)
assert(text_visible('CANNON 20 MM'))
assert(not text_visible('QTY')and not text_visible('PROG')and not text_visible('FUZE'),'hidden cannon-incompatible legends remain visible')
get_param_handle('HUD_AG_SUBMODE'):set(2);get_param_handle('F22_SMS_LABEL'):set(1)
assert(not text_visible('HUD'),'retired Stores HUD shortcut returned')
get_param_handle('CMFD_BAY_PAGE'):set(0)
assert(not text_visible('STORES'),'inactive stores format remained visible')
get_param_handle('CMFD_BAY_PAGE'):set(1);get_param_handle('MFD_OPACITY'):set(0)
assert(not text_visible('STORES'),'unpowered display retained visible stores labels')
''')
print('Overhaul native stores graph: unique names, resolved parents, persistent labels, current stroke glyphs and page/power visibility PASS')

lua = runtime()
lua.execute(r'''
dofile(SCRIPT_ROOT..'Systems/Weapon_System.lua')
dofile(SCRIPT_ROOT..'Systems/MFD_System.lua')
local declared={};for name in pairs(handles)do declared[name]=true end
dofile(SCRIPT_ROOT..'MFD_COMMON/stores_page.lua')('CMFD_BAY_PAGE','F22_BIND_STORES','F22_SMS_UI_PAGE_CMFD')
for _,element in ipairs(elements)do
 for _,parameter in ipairs(element.element_params or {})do
  if parameter:find('F22_SMS_',1,true)==1 then
   assert(declared[parameter],'stores parameter created after native binding: '..parameter)
  end
 end
end
''')
print('Overhaul native stores binding: display/weapon producers declare every bound SMS parameter during construction PASS')

