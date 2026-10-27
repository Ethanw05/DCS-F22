"""Primary Stores/NAV/Systems stay local through actual display, weapon and UFC owners."""
from test_display_startup import runtime
lua=runtime()
lua.execute('''
local now=10
function get_model_time()return now end
function get_aircraft_property()return 1 end
function get_aircraft_draw_argument_value(n)return draws[n]or 0 end
function set_aircraft_draw_argument_value(n,v)draws[n]=v end
local native={get_station_info=function(_,i)return {count=i==4 and 3 or 0,
 CLSID='{F22-MK83-TRAINING}',weapon={level1=4,level2=5,level3=9,level4=32}}end,
 select_station=function()end,get_chaff_count=function()return 120 end,get_flare_count=function()return 120 end}
function GetDevice()return native end
dofile(SCRIPT_ROOT..'Systems/Weapon_System.lua');post_initialize();local wc,wu=SetCommand,update
dofile(SCRIPT_ROOT..'Systems/ICP_System.lua');post_initialize();local ic,iu=SetCommand,update
dofile(SCRIPT_ROOT..'Systems/MFD_System.lua');post_initialize();local mc,mu=SetCommand,update
dofile(SCRIPT_ROOT..'Systems/PMFD_System.lua');post_initialize();local pc,pu=SetCommand,update
local R=dofile(SCRIPT_ROOT..'Systems/Display_Routing.lua')
local events={}
function dispatch_action(d,c,v)
 events[#events+1]={d,c,v}
 if d==devices.WEAPON_SYSTEM then wc(c,v)elseif d==devices.ICP_SYSTEM then ic(c,v)
 elseif d==devices.MFD_SYSTEM then mc(c,v)elseif d==devices.PMFD_SYSTEM then pc(c,v)end
end
local function p(k,v)get_param_handle(k):set(v)end
local function g(k)return get_param_handle(k):get()end
local function tick()now=now+.02;wu();pu();mu();iu()end
local function key(owner,device,base,b)
 owner(base+b,device+.375);owner(base+b,device+.25);tick()
end
local function main(b)key(pc,devices.PMFD_SYSTEM,10130,b)end
local function left(b)key(mc,devices.MFD_SYSTEM,10060,b)end
local function right(b)key(mc,devices.MFD_SYSTEM,10090,b)end
local function bottom(b)key(mc,devices.MFD_SYSTEM,10110,b)end
local function ufc(c)ic(c,devices.ICP_SYSTEM+.375);ic(c,devices.ICP_SYSTEM+.25);tick()end
p('MAIN_POWER',1);p('MFD_OPACITY',1);wc(10800,7);for i=1,20 do tick()end
left(13);left(4);right(13);right(6);mc(10823,1);tick();bottom(5)
assert(g('LMFD_PAGE')==1 and g('RMFD_PAGE')==3 and g('CMFD_PAGE')==8 and g('CMFD_HSI_PAGE_DATA')==1)
local function unchanged()
 assert(g('LMFD_PAGE')==1 and g('RMFD_PAGE')==3 and g('CMFD_PAGE')==8,'primary selection changed another screen')
 assert(g('CMFD_HSI_PAGE_DATA')==1,'primary NAV changed lower NAV DATA')
end
local function selected(page)
 assert(g('F22_PMFD_PAGE')==page)
 for code,name in pairs(R.formats)do assert(g(name)==(code==page and 1 or 0),'primary format flags overlap: '..name)end
 unchanged()
end
main(13);main(3);selected(R.pages.stores)
main(8);assert(g('ICP_STORES_MENU')==1,'primary Stores UFC did not open')
ufc(3008);ufc(3018);ufc(3012);assert(g('F22_SMS_QUANTITY')==2)
ufc(3010);ufc(3021);ufc(3027);ufc(3027);ufc(3012);assert(g('F22_SMS_SPACING_FT')==500)
main(12);assert(g('F22_SMS_UI_PAGE')==1);main(13)
assert(g('F22_SMS_UI_PAGE')==0 and g('F22_PMFD_PAGE')==R.pages.stores,'Stores RTN closed the format')
main(13);selected(0);assert(g('ICP_STORES_MENU')==0,'leaving primary Stores retained UFC capture')
main(13);selected(R.pages.stores);main(13);main(2);selected(R.pages.nav)
main(5);assert(g('PMFD_HSI_PAGE_DATA')==1);main(3)
assert(g('PMFD_HSI_PAGE_DATA')==2);unchanged()
main(6);assert(g('ICP_CNI_MENU')==1,'primary NAV UFC did not reach radio entry')
main(13);selected(0);main(4);selected(R.pages.systems)
for b=6,20 do if b~=13 then main(b);selected(R.pages.systems)end end
for choice,page in pairs(R.system_choices)do
 main(choice);selected(page)
 main(13);selected(0);main(4);selected(R.pages.systems)
end
for source,shortcuts in pairs(R.system_shortcuts)do
 for button,destination in pairs(shortcuts)do
  main(13);main(4)
  for choice,page in pairs(R.system_choices)do if page==source then main(choice);break end end
  main(button);selected(destination)
  if destination==R.pages.stores or destination==R.pages.nav then main(13);main(4)end
 end
end
for _,e in ipairs(events)do
 assert(not(e[1]==devices.MFD_SYSTEM and e[2]>=10822 and e[2]<=10824),'primary menu still dispatched a cross-display shortcut')
end
-- Native hotkey/packed releases cannot bounce a retained page or operate hidden radar keys.
main(13);if g('F22_PMFD_PAGE')~=0 then main(13)end;main(3);selected(R.pages.stores)
p('MAIN_POWER',0);tick()
for _,name in pairs(R.formats)do assert(g(name)==0,'unpowered primary format remained active')end
assert(g('F22_SMS_PROGRAM_PAGE')==0)
p('MAIN_POWER',1);tick();assert(g('CMFD_HSI_PAGE_DATA')==0);bottom(5);selected(R.pages.stores)
local S=dofile(SCRIPT_ROOT..'Systems/Sensor_Control.lua')
assert(S.action(2,R.pages.nav,7,{})=='nav_zoom')
assert(S.action(2,R.pages.stores,7,{})==nil and S.action(2,R.pages.systems,2,{})==nil)
''')
print('Primary local formats: Stores/UFC programming, NAV/DATA/UFC, Systems/subpages/shortcuts, retained MENU, independent side/lower displays and power clearing PASS')

# Confirm each registered format can be constructed using the DCS write-only proxy.
for page in ['stores','nav','sys','eng','fcs','fuel','adi','checklist']:
    sim=runtime();sim.execute(f"dofile(SCRIPT_ROOT..'PMFD_CENTER/{page}_page.lua')")
    assert len(sim.globals().elements)>0,page
    for _,e in sim.globals().elements.items():
        assert e['value']!='SYS PLACEHOLDER'
        for _,value in (e['element_params'].items() if e['element_params'] else []):
            assert not str(value).startswith(('LMFD_','RMFD_','CMFD_')),(page,value,'another display owns this format')
print('All eight installed primary local format graphs construct and bind their own PMFD flags PASS')
