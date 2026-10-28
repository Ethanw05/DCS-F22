"""Broadcast actual registered NAV/EW commands through both device owners."""
from test_display_startup import runtime

sim = runtime()
sim.execute(r'''
package.preload.terrain=function()return {GetHeight=function()return 20 end}end
function get_base_data()return {getSelfCoordinates=function()return 0,100,0 end,
 getHeading=function()return 0 end,getPitch=function()return 0 end,getRoll=function()return 0 end}end
function get_mission_route()return {{x=0,y=0,alt=100},{x=20000,y=0,alt=100}}end
local function p(k,v)get_param_handle(k):set(v)end
local function g(k)return get_param_handle(k):get()end
local registered={}
local function owner(id)
 registered[id]={listeners={}}
 function GetSelf()return {listen_command=function(_,c)registered[id].listeners[c]=true end}end
 return registered[id]
end
local nav=owner(8)
dofile(SCRIPT_ROOT..'Systems/Navigation_System.lua')
local references=dofile(SCRIPT_ROOT..'../../tests/navigation_reference_fixture.lua')()
references.physical.values.F22_ELECTRICAL_VALID=1
references.physical.values.EFM_MISSION_POWER_AVAILABLE=1
nav.update=references:wrap(update);nav.set=SetCommand;post_initialize()
local ag=owner(9)
dofile(SCRIPT_ROOT..'Systems/AG_Mark_System.lua');ag.update=update;ag.set=SetCommand;post_initialize()
local chaff,flare,ecm=120,120,false
local native={get_chaff_count=function()return chaff end,get_flare_count=function()return flare end,
 drop_chaff=function(_,n)chaff=chaff-n end,drop_flare=function(_,n)flare=flare-n end,
 get_ECM_status=function()return ecm end,set_ECM_status=function(_,on)ecm=on end}
function GetDevice(id)assert(id==15);return native end
local ew=owner(20)
dofile(SCRIPT_ROOT..'Systems/EW_System.lua');ew.update=update;ew.set=SetCommand;post_initialize()
function dispatch_action(_,command,value)
 for _,device in pairs(registered)do
  if device.listeners[command]then device.set(command,value)end
 end
end
p('MAIN_POWER',1);p('F22_GPS_AID',1);p('EFM_HUD_VALID',1);p('EFM_HUD_VN',200)
p('HUD_GS_VALID',1);p('HUD_GS_MPS',200);p('F22_AP_CLOCK',1)
nav.update();ew.update()
for _,encoded in ipairs({false,true})do
 local down,up=encoded and 8.375 or 1,encoded and 8.25 or 0
 dispatch_action(8,10841,down);dispatch_action(8,10841,up);ag.update();nav.update();ew.update()
 assert(g('F22_NAV_DESIGNATED')==1 and g('HUD_AG_TARGET_VALID')==1,'WPDSG lost target handoff')
 assert(chaff==120 and flare==120 and not ecm,'waypoint designation caused an EW action')
 dispatch_action(8,10842,down);dispatch_action(8,10842,up);ag.update();nav.update();ew.update()
 assert(g('F22_NAV_DESIGNATED')==0 and not ecm,'undesignation toggled ECM')
 dispatch_action(8,10840,down);dispatch_action(8,10840,up);ew.update()
 assert(chaff==120 and flare==120 and not ecm,'navigation undo dispensed a cartridge')
end
for command in pairs(nav.listeners)do assert(not ew.listeners[command],'NAV/EW listener ID collision')end
dispatch_action(20,11114,20.375);dispatch_action(20,11114,20.25)
dispatch_action(20,11115,20.375);dispatch_action(20,11115,20.25)
dispatch_action(20,11116,20.375);dispatch_action(20,11116,20.25);ew.update()
assert(flare==119 and chaff==119 and ecm,'isolated EW controls lost their intended native effect')
assert(g('F22_NAV_DESIGNATED')==0,'EW controls changed waypoint designation')
''')
print('Actual NAV/AG/EW owners: raw/encoded broadcast designation, undo, undesignation and isolated CM/ECM PASS')
