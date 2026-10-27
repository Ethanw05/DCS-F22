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
 now=now+.05;p('F22_AP_CLOCK',now)
 owners[8].update();drain();owners[9].update();drain()
 owners[8].update();owners[5].update();owners[16].update();owners[7].update();drain()
end
local function bezel(button)
 owners[5].command(10110+button,5.375)
 owners[5].command(10110+button,5.25);drain()
end
p('MAIN_POWER',1);p('MASTER_ARM',0);p('HUD_MODE',1)
p('HUD_GS_VALID',1);p('HUD_GS_MPS',200)
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
for button,source in pairs({[6]=0,[7]=1,[8]=2})do
 bezel(button);tick();assert(g('F22_NAV_SOURCE')==source,'visible navigation source routed elsewhere')
 assert(g('HUD_AG_TARGET_VALID')==1,'source selection silently cleared the weapon target')
end
bezel(6);tick();assert(g('F22_AG_TARGET_SEQUENCE')==sequence)
local before=g('F22_NAV_SCALE_NM');bezel(17);tick()
assert(g('F22_NAV_SCALE_NM')<before,'RNG- did not reduce numerical range')
bezel(18);tick();assert(g('F22_NAV_SCALE_NM')==before)
-- Unlabelled keys cannot fall through to old HSI/ICP/master-mode actions.
for _,button in ipairs({1,2,3,4,11,12,15})do
 sent={};bezel(button);tick()
 for _,row in ipairs(sent)do assert(row[2]==10742,'blank NAV key reached a hidden action')end
 assert(g('HUD_MODE')==7 and g('CMFD_PAGE')==8 and g('HUD_AG_TARGET_VALID')==1)
end
bezel(10);tick()
assert(g('HUD_AG_TARGET_VALID')==0 and g('F22_NAV_DESIGNATE_STATUS')==6)
assert(g('MASTER_ARM')==0 and g('CMFD_PAGE')==8)
bezel(5);tick();assert(g('CMFD_HSI_PAGE_DATA')==1,'DATA did not open waypoint inspection')
bezel(6);tick()
assert(g('ICP_NAV_MENU')==1,'DATA UFC did not open the selected-waypoint editor')
assert(g('CMFD_PAGE')==8 and g('HUD_MODE')==7,'UFC displaced NAV or changed master mode')
owners[7].command(3028,7.375);tick();assert(g('ICP_NAV_MENU')==0,'UNDO did not close the idle editor')
bezel(5);tick();assert(g('CMFD_PAGE')==8 and g('CMFD_HSI_PAGE_DATA')==0,'NAV did not return to steering')
''')
print('Actual NAV workflow: next/designate, queued selected point, SAFE planning, A/G page/focus/target persistence, sources, zoom, clear and blank-key ownership PASS')

for panel in ('LEFT','RIGHT','CENTER'):
    ui=runtime()
    ui.globals().NAV_PAGE={'LEFT':'LMFD','RIGHT':'RMFD','CENTER':'CMFD'}[panel]+'_HSI_PAGE'
    ui.execute(f"dofile(SCRIPT_ROOT..'MFD_{panel}/hsi_page.lua')")
    ui.execute(r'''
get_param_handle('MFD_OPACITY'):set(1);get_param_handle(NAV_PAGE):set(1);get_param_handle('F22_NAV_DESIGNATED'):set(1)
local named={};for _,e in ipairs(elements)do named[e.name]=e end
local function visible(e)
 if e.parent_element and not visible(named[e.parent_element])then return false end
 for _,c in ipairs(e.controllers or {})do
  local p=e.element_params and e.element_params[c[2]+1];local v=p and get_param_handle(p):get()
  if c[1]=='parameter_in_range'and(v<c[3]or v>c[4])then return false end
  if c[1]=='opacity_using_parameter'and v<=0 then return false end
 end
 return true
end
local expected={WPDSG={.86,-.42},UNDESG={.86,-.70},WYPT={.86,.42},TCN={.86,.14},ILS={.86,-.14},
 ['RNG+']={-.88,-.14},['RNG-']={-.88,-.42},DATA={.565,.92},['D-TO']={-.2825,-.92}}
for label,position in pairs(expected)do
 local found=false
 for _,element in ipairs(elements)do
  if element.value==label and visible(element)then
   assert(math.abs(element.init_pos[1]-position[1]*.95)<1e-8 and
    math.abs(element.init_pos[2]-position[2]*.95)<1e-8,'NAV label is not at its physical bezel')
   found=true
  end
 end
 assert(found,'missing visible NAV action: '..label)
end
for _,element in ipairs(elements)do
 assert(element.value~='EDIT'and element.value~='DESIG'and element.value~='CLEAR',
  'superseded NAV shortcut remained visible')
end
''')
print('All three native NAV formats: physical source/designate/clear/zoom/edit positions match the actual route contract PASS')
