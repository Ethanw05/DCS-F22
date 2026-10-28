"""Actual NAV labels/owners: select, designate, A/G, preserve page and target."""
from test_display_startup import runtime

sim=runtime()
sim.execute(r'''
local now=1
function get_model_time()return now end
function get_aircraft_property()return 0 end
local base=get_base_data()
base.getSelfCoordinates=function()return 0,3000,0 end
base.getHeading=function()return 0 end
base.getPitch=function()return 0 end
base.getRoll=function()return 0 end
function get_base_data()return base end
function get_mission_route()return {{x=0,y=0,alt=3000},
 {x=20000,y=0,alt=3000,name='ALPHA'},{x=30000,y=5000,alt=3000,name='BRAVO'}}end
package.preload.terrain=function()return{GetHeight=function()return 20 end,
 convertMetersToLatLon=function(n,e)return n/100000,e/100000 end,
 convertLatLonToMeters=function(lat,lon)return lat*100000,lon*100000 end}end
local owners,queue,sent,subscribed={},{},{},{}
local original_get_self=GetSelf
function dispatch_action(device,command,value)
 local row={device,command,value};queue[#queue+1]=row;sent[#sent+1]=row
end
local function load_owner(name,id)
 SetCommand=nil;update=nil;post_initialize=nil
 subscribed[id]={}
 local proxy=setmetatable({listen_command=function(_,command)
  -- The common test runtime omits unrelated stock key constants.
  if type(command)=='number'then subscribed[id][command]=true end
 end},{__index=original_get_self()})
 GetSelf=function()return proxy end
 dofile(SCRIPT_ROOT..'Systems/'..name..'.lua')
 owners[id]={command=SetCommand,update=update}
 if post_initialize then post_initialize()end
 GetSelf=original_get_self
end
local guidance_physical=dofile(SCRIPT_ROOT..'../../tests/physical_frame_fixture.lua')({F22_ESSENTIAL_POWER=1})
guidance_physical:publish(get_param_handle('F22_AP_CLOCK'):get())
load_owner('Navigation_System',8);load_owner('AG_Mark_System',9)
load_owner('MFD_System',5);load_owner('Flight_Guidance',25)
load_owner('Weapon_System',4);load_owner('Combat_System',16)
load_owner('ICP_System',7)
queue={};sent={}
local function p(k,v)get_param_handle(k):set(v)end
local function g(k)return get_param_handle(k):get()end
local function drain()
 local count=0
 while #queue>0 do
  count=count+1;assert(count<200,'recursive owner routing')
  local row=table.remove(queue,1);local owner=owners[row[1]]
  if owner and owner.command and subscribed[row[1]][row[2]]then owner.command(row[2],row[3])end
 end
end
local function tick()
 now=now+.05;guidance_physical:publish(now)
 owners[25].update();drain()
 owners[8].update();drain();owners[9].update();drain()
 owners[8].update();owners[5].update();owners[16].update();owners[7].update();drain()
end
local function bezel(button)
 owners[5].command(10110+button,5.375)
 owners[5].command(10110+button,5.25);drain()
end
p('MAIN_POWER',1);p('MASTER_ARM',0);p('HUD_MODE',1)
p('HUD_GS_VALID',1);p('HUD_GS_MPS',200)
p('EFM_HUD_VALID',1);p('EFM_HUD_VN',200)
owners[5].command(10823,1);tick()
assert(g('CMFD_PAGE')==8 and g('HUD_WP_INDEX')==2)
-- Physical NEXT, then DESIG, before the next Navigation activity. The marker
-- must receive the new selection, rather than the old displayed coordinates.
bezel(20);bezel(9);tick()
assert(g('HUD_WP_INDEX')==3 and g('F22_NAV_DESIGNATE_STATUS')==2,'DESIG bezel did not acknowledge the selected waypoint')
assert(g('HUD_AG_TARGET_VALID')==1 and g('HUD_AG_MARK_NORTH')==30000 and g('HUD_AG_MARK_EAST')==5000,'DESIG used the wrong waypoint coordinates')
assert(g('F22_NAV_DESIGNATE_STATUS_TEXT')=='TARGET DESIGNATED')
local sequence=g('F22_AG_TARGET_SEQUENCE')
assert(g('MASTER_ARM')==0 and g('F22_SOI')==5)
-- Selecting A/G changes employment context, not the selected NAV display.
sent={};owners[16].command(10732,1);owners[16].command(10732,0);drain();tick()
assert(g('HUD_MODE')==7 and g('CMFD_PAGE')==8 and g('F22_SOI')==5)
assert(g('HUD_AG_TARGET_VALID')==1 and g('F22_AG_TARGET_SEQUENCE')==sequence)
for _,row in ipairs(sent)do assert(row[2]~=10005,'A/G selection requested a radar page takeover')end
-- A PMFD-targeted packet must not trigger the MFD's old global page override.
owners[5].command(10005,devices.PMFD_SYSTEM+.375);tick()
assert(g('CMFD_PAGE')==8,'foreign page request displaced NAV')
-- A second press removes steering without clearing the selected point or target.
bezel(6);tick();assert(g('F22_NAV_SOURCE')==3 and g('F22_NAV_STEER_VALID')==0)
assert(g('HUD_WP_VALID')==0 and g('HUD_WP_INDEX')==3 and g('HUD_AG_TARGET_VALID')==1)
bezel(6);tick();assert(g('F22_NAV_SOURCE')==0 and g('HUD_WP_INDEX')==3)
-- Route-line visibility is independent from the active steering source.
bezel(1);tick();assert(g('F22_NAV_SEQUENCE_VISIBLE')==0 and g('F22_NAV_LEG_01_VALID')==0)
assert(g('F22_NAV_SOURCE')==0 and g('HUD_WP_INDEX')==3)
bezel(1);tick();assert(g('F22_NAV_SEQUENCE_VISIBLE')==1)
local nav=dofile(SCRIPT_ROOT..'Systems/Nav_Computer.lua')
local route=nav.new({{x=0,y=0,alt=3000},{x=1000,y=0,alt=3000},{x=2000,y=0,alt=3000}})
route.automatic=true
local at_waypoint={x=1000,y=0,alt=3000,heading=0,gs=200}
nav.solution(route,at_waypoint,false);assert(route.selected==1,'unselected waypoint steering advanced AUTO')
nav.solution(route,at_waypoint,true);assert(route.selected==2,'selected waypoint steering failed to advance AUTO')
for _,pair in ipairs({{7,1},{8,2},{6,0}})do
 local button,source=pair[1],pair[2]
 bezel(button);tick();assert(g('F22_NAV_SOURCE')==source,'visible navigation source routed elsewhere')
 assert(g('HUD_AG_TARGET_VALID')==1,'source selection silently cleared the weapon target')
end
assert(g('F22_AG_TARGET_SEQUENCE')==sequence)
local before=g('F22_NAV_SCALE_NM');bezel(15);tick()
assert(g('F22_NAV_SCALE_NM')<before,'RNG- did not reduce numerical range')
bezel(14);tick();assert(g('F22_NAV_SCALE_NM')==before)
-- Unlabelled keys cannot fall through to old HSI/ICP/master-mode actions.
for _,button in ipairs({2,3,4,12})do
 sent={};bezel(button);tick()
 for _,row in ipairs(sent)do assert(row[2]==10742,'blank NAV key reached a hidden action')end
 assert(g('HUD_MODE')==7 and g('CMFD_PAGE')==8 and g('HUD_AG_TARGET_VALID')==1)
end
bezel(10);tick()
assert(g('HUD_AG_TARGET_VALID')==0 and g('F22_NAV_DESIGNATE_STATUS')==6)
assert(g('MASTER_ARM')==0 and g('CMFD_PAGE')==8)
bezel(11);tick();assert(g('CMFD_HSI_PAGE_DATA')==1,'DATA did not open waypoint inspection')
bezel(6);tick()
assert(g('ICP_NAV_MENU')==1,'DATA UFC did not open the selected-waypoint editor')
assert(g('CMFD_PAGE')==8 and g('HUD_MODE')==7,'UFC displaced NAV or changed master mode')
owners[7].command(11030,7.375);owners[7].command(11030,7.25);tick();assert(g('ICP_NAV_MENU')==1,'forced STPT reopen lost its context')
bezel(12);tick();assert(g('CMFD_PAGE')==8 and g('CMFD_HSI_PAGE_DATA')==0,'NAV did not return to steering')
-- HUD focus and TDC depress create a terrain mark in NAV, including repeat presses.
base.getPitch=function()return -.2 end
owners[16].command(10721,1);owners[16].command(10721,0)
owners[16].command(10704,1);owners[16].command(10704,0);drain();tick()
assert(g('F22_SOI')==1 and g('HUD_MODE')==1)
owners[16].command(10733,1);owners[16].command(10733,0);drain();tick()
assert(g('HUD_AG_TARGET_VALID')==1 and g('F22_AG_TARGET_SOURCE')==1,'HUD TDC did not designate terrain')
local first=g('F22_AG_TARGET_SEQUENCE')
owners[16].command(10733,1);owners[16].command(10733,0);drain();tick()
assert(g('F22_AG_TARGET_SEQUENCE')>first,'second TDC press did not create a fresh mark')
base.getHeading=function()return math.pi end;tick()
assert(g('HUD_AG_TARGET_VALID')==1 and g('HUD_AG_EDGE_VALID')==1,'rearward designation lost its edge cue')
local flash=g('HUD_AG_EDGE_FLASH');now=now+.25;owners[9].update()
assert(g('HUD_AG_EDGE_FLASH')~=flash,'off-screen marker does not flash')
base.getHeading=function()return 0 end;tick()
assert(g('HUD_AG_EDGE_VALID')==0 and g('HUD_AG_CUE_VALID')==1,'on-screen designation retained the edge box')
''')
print('Actual NAV workflow: next/designate, queued selected point, SAFE planning, A/G page/focus/target persistence, sources, zoom, clear and blank-key ownership PASS')

for panel, base in (('LMFD',10060),('RMFD',10090),('CMFD',10110)):
    ui=runtime();ui.globals().PANEL=panel;ui.globals().BASE=base
    ui.execute(r'''
dofile(SCRIPT_ROOT..'Systems/MFD_System.lua');post_initialize()
get_param_handle('MAIN_POWER'):set(1);update()
SetCommand(BASE+13,1);SetCommand(BASE+2,1);update()
assert(get_param_handle('F22_'..PANEL..'_FORMAT'):get()==7,
 PANEL..' format '..tostring(get_param_handle('F22_'..PANEL..'_FORMAT'):get())..' base '..tostring(BASE))
dofile(SCRIPT_ROOT..'MFD_COMMON/nav_page.lua')(PANEL..'_HSI_PAGE')
dofile(SCRIPT_ROOT..'MFD_COMMON/bezel.lua')(PANEL)
local named={};for _,e in ipairs(elements)do assert(not named[e.name]);named[e.name]=e end
for b,label in pairs({[9]='WPDSG',[10]='UNDESG',[6]='WYPT',[7]='TCN',[8]='ILS',
 [14]='RNG+',[15]='RNG-',[11]='DATA',[17]='D-TO'})do
 if b==10 then get_param_handle('F22_NAV_DESIGNATED'):set(1);update()end
 local key='F22_MFD_'..PANEL..'_KEY_'..b
 assert(get_param_handle(key):get()==label,'visible action missing: '..label)
 local e=assert(named['F22_BEZEL_'..PANEL..'_'..b])
 assert(e.element_params[1]==key and e.controllers[1][1]=='text_using_parameter')
 assert(math.abs(e.init_pos[1])<=1 and math.abs(e.init_pos[2])<=1,'bezel label outside aperture')
end
''')
print('All three native NAV formats bind the current physical source/designate/clear/range keys PASS')
