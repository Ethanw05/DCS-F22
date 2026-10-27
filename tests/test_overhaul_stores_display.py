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

lua = runtime()
lua.execute(r'''
local now=10
function get_model_time()return now end
function get_aircraft_property()return 1 end
function get_aircraft_draw_argument_value(n)return draws[n]or 0 end
function set_aircraft_draw_argument_value(n,v)draws[n]=v end
local counts={[4]=3}
local native={get_station_info=function(_,i)
 return {count=counts[i]or 0,CLSID='{F22-MK83-TRAINING}',weapon={level1=4,level2=5,level3=9,level4=32}}
end,select_station=function()end,get_chaff_count=function()return 120 end,get_flare_count=function()return 120 end}
function GetDevice()return native end
local function p(k)return get_param_handle(k)end
local function value(k)return p(k):get()end
dofile(SCRIPT_ROOT..'Systems/Weapon_System.lua');post_initialize()
local weapon_command,weapon_update=SetCommand,update
dofile(SCRIPT_ROOT..'Systems/MFD_System.lua');post_initialize()
local mfd_command,mfd_update=SetCommand,update
dofile(SCRIPT_ROOT..'Systems/ICP_System.lua');post_initialize()
local icp_command,icp_update=SetCommand,update
local events={}
function dispatch_action(device,command,v)
 events[#events+1]={device,command,v}
 if device==devices.WEAPON_SYSTEM then weapon_command(command,v)elseif device==devices.ICP_SYSTEM then icp_command(command,v)end
end
local function tick()
 now=now+.02;weapon_update();mfd_update();icp_update()
end
local function bezel(button)
 mfd_command(10110+button,devices.MFD_SYSTEM+.375)
 mfd_command(10110+button,devices.MFD_SYSTEM+.25)
end
local function key(command)
 icp_command(command,devices.ICP_SYSTEM+.375)
 icp_command(command,devices.ICP_SYSTEM+.25)
end
p('MAIN_POWER'):set(1);p('WoW'):set(0);weapon_command(10800,1)
for i=1,20 do tick()end
assert(value('CMFD_BAY_PAGE')==1 and value('F22_SMS_PROGRAM_PAGE')==1)
-- Hornet-style Stores HUD -> front keypad page -> option -> digits -> ENTER.
events={};bezel(8);tick()
local opens=0;for _,e in ipairs(events)do if e[2]==10989 then opens=opens+1;assert(e[1]==devices.ICP_SYSTEM)end end
assert(opens==1 and value('ICP_STORES_MENU')==1 and value('F22_SMS_ENTRY_FIELD')==0,'HUD did not open selected-munition keypad page')
key(3008);key(3018);key(3012);tick()
assert(value('F22_SMS_QUANTITY')==2 and value('F22_SMS_ENTRY_FIELD')==0,'quantity did not commit through actual owners')
key(3010);key(3018);key(3027);key(3027);key(3012);tick()
assert(value('F22_SMS_INTERVAL_MS')==200 and value('F22_SMS_ENTRY_FIELD')==0,'interval zero digits did not commit')
assert(value('ICP_STORES_ROW_1')==':QTY 2' or value('ICP_STORES_ROW_1')==' QTY 2')
-- Former MFD interval key is blank and cannot open an entry.
bezel(9);assert(value('F22_SMS_ENTRY_FIELD')==0)
-- Leaving the stores page cannot leave an entry that captures later NAV input.
key(3008);key(3017);assert(value('F22_SMS_ENTRY_FIELD')==1)
bezel(13);tick()
assert(value('CMFD_MENU_PAGE')==1 and value('F22_SMS_PROGRAM_PAGE')==0 and value('F22_SMS_ENTRY_FIELD')==0)
-- Root MENU stores returns to the existing lower display, with a fresh home.
bezel(3);tick();assert(value('CMFD_BAY_PAGE')==1 and value('F22_SMS_UI_PAGE')==0)
bezel(12);bezel(8);tick();assert(value('F22_SMS_UI_PAGE')==1 and value('ICP_STORES_MENU')==1);key(3008);assert(value('F22_SMS_ENTRY_FIELD')==1)
bezel(13);assert(value('F22_SMS_UI_PAGE')==0 and value('F22_SMS_ENTRY_FIELD')==0)
-- Power loss removes both visible page authority and its uncommitted entry.
bezel(8);tick();key(3008);p('MAIN_POWER'):set(0);tick()
assert(value('F22_SMS_PROGRAM_PAGE')==0 and value('F22_SMS_ENTRY_FIELD')==0)
p('MAIN_POWER'):set(1);tick();assert(value('F22_SMS_UI_PAGE')==0)
-- An incompatible master mode cannot retain the stores numeric scratchpad.
bezel(8);tick();key(3008);weapon_command(10800,2);tick()
assert(value('F22_SMS_ENTRY_FIELD')==0)
-- GUN neither changes a bomb profile nor opens its hidden program controls.
weapon_command(10800,7);for i=1,20 do tick()end
bezel(6);bezel(1);tick();assert(value('HUD_AG_SUBMODE')==1)
for _,button in ipairs({7,8,9,10,12,14,15,16,17})do bezel(button)end
assert(value('F22_SMS_ENTRY_FIELD')==0 and value('F22_SMS_QUANTITY')==2 and value('F22_SMS_UI_PAGE')==0)
weapon_command(10008,1);weapon_command(10803,1);tick()
assert(value('F22_SMS_REMAINING')==0 and value('F22_AG_RELEASE_CONSENT')==0,'GUN pickle created bomb consent')
weapon_command(10803,0);bezel(1);tick()
assert(value('HUD_AG_SUBMODE')==2 and value('F22_SMS_QUANTITY')==2 and value('F22_SMS_INTERVAL_MS')==200,'class selection failed to restore its retained bomb profile')
-- The reported left-MFD STORES bug: do not silently redirect to lower Stores.
mfd_command(10823,1);tick();assert(value('CMFD_HSI_PAGE')==1)
local function left(n)
 mfd_command(10060+n,devices.MFD_SYSTEM+.375);mfd_command(10060+n,devices.MFD_SYSTEM+.25)
end
left(13);left(3);tick()
assert(value('LMFD_BAY_PAGE')==1 and value('LMFD_SMS_PAGE')==0 and value('CMFD_HSI_PAGE')==1,'left STORES left the Attack status page visible')
left(8);tick();assert(value('ICP_STORES_MENU')==1)
key(3008);key(3017);key(3012);tick();assert(value('F22_SMS_QUANTITY')==1,'left-only stores could not commit UFC quantity')
key(3010);key(3021);key(3027);key(3027);key(3012);tick()
assert(value('F22_SMS_SPACING_FT')==500 and value('CMFD_HSI_PAGE')==1,'left UFC interval borrowed lower-display authority')
key(3011);key(3010);key(3018);key(3021);key(3027);key(3012);tick()
assert(value('F22_SMS_INTERVAL_MODE')==0 and value('F22_SMS_INTERVAL_MS')==250,'UFC time interval did not commit independently of impact spacing')
left(13);tick();assert(value('LMFD_MENU_PAGE')==1 and value('ICP_STORES_MENU')==0)
left(3);tick();assert(value('LMFD_BAY_PAGE')==1 and value('CMFD_HSI_PAGE')==1,'direct page picker still redirected stores')
''')
print('Overhaul stores integration: actual MFD/ICP/weapon routing, SAFE NAV entry, zero digits, MENU/RTN, power and master-mode cancellation PASS')

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
 assert(text_visible('STN STEP')==(page==1),'station-step legend disagrees with program subpage')
end
get_param_handle('F22_SMS_UI_PAGE'):set(0);get_param_handle('HUD_AG_SUBMODE'):set(1)
assert(text_visible('CANNON 20 MM') and text_visible('MODE') and text_visible('DOORS') and text_visible('MENU'))
assert(not text_visible('QTY')and not text_visible('PROG')and not text_visible('FUZE'),'hidden cannon-incompatible legends remain visible')
get_param_handle('HUD_AG_SUBMODE'):set(2);get_param_handle('F22_SMS_LABEL'):set(1)
assert(text_visible('UFC')and not text_visible('HUD'),'numeric programming has no correctly labelled MFD UFC entry')
get_param_handle('CMFD_BAY_PAGE'):set(0)
assert(not text_visible('STORES'),'inactive stores format remained visible')
get_param_handle('CMFD_BAY_PAGE'):set(1);get_param_handle('MFD_OPACITY'):set(0)
assert(not text_visible('STORES'),'unpowered display retained visible stores labels')
''')
print('Overhaul native stores graph: unique names, resolved parents, persistent labels on all subpages and page/power visibility PASS')

lua = runtime()
lua.execute(r'''
dofile(SCRIPT_ROOT..'Systems/Weapon_System.lua')
dofile(SCRIPT_ROOT..'Systems/MFD_System.lua')
local declared={};for name in pairs(handles)do declared[name]=true end
dofile(SCRIPT_ROOT..'MFD_CENTER/stores_program.lua')
for _,element in ipairs(elements)do
 for _,parameter in ipairs(element.element_params or {})do
  if parameter:find('F22_SMS_',1,true)==1 then
   assert(declared[parameter],'stores parameter created after native binding: '..parameter)
  end
 end
end
''')
print('Overhaul native stores binding: display/weapon producers declare every bound SMS parameter during construction PASS')

# A native capture exposed an invisible empty-entry marker. Validate literal
# strings against the shipped font descriptors, not a permissive font stub.
lua = runtime()
lua.execute(r'''
local fonts={}
function MakeFont(description,color,name)fonts[name]=description;return name end
local original_dofile=dofile
function dofile(path)
 if path==SCRIPT_ROOT..'fonts.lua'then return assert(loadfile(path))()end
 return original_dofile(path)
end
dofile(SCRIPT_ROOT..'MFD_CENTER/stores_program.lua')
for _,element in ipairs(elements)do
 if element.kind=='ceStringPoly'and element.value then
  local description=assert(fonts[element.material],'Stores text has no actual font description')
  local chars={};for _,glyph in pairs(description.chars)do chars[glyph[1]]=true end
  for i=1,#element.value do
   assert(chars[element.value:byte(i)],'Stores literal contains an unavailable native glyph: '..element.value)
  end
 end
end
''')
print('Overhaul stores native font: every literal, including empty keypad entry, has a shipped glyph PASS')
