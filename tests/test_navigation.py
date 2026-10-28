"""Real Lua route computer/device contracts; synthetic ownship, no native claim."""
from pathlib import Path
import math,sys
from lupa.lua51 import LuaRuntime
from test_display_startup import runtime
ROOT=Path(__file__).resolve().parents[1]
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute((ROOT/'Cockpit/Scripts/Systems/Nav_Computer.lua').read_text().replace('return M','NAV=M;return M'))
lua.execute('''
local N=NAV
local route={{x=0,y=0,alt=3000},{x=18520,y=0,alt=3000,name='ALPHA'},
 {x=18520,y=18520,alt=100,alt_type='RADIO'}}
local c=N.new(route,function()return 500 end)
assert(#c.route==2 and c.route[1].id==2 and c.route[2].msl==600)
assert(#N.new({route[1]}).route==0,'spawn-only mission cannot create a target')
assert(#N.new(nil).route==0)
local own={x=0,y=1852,alt=3000,heading=0,gs=200}
local s=N.solution(c,own)
assert(math.abs(s.cross-1852)<1e-8 and s.course==0)
assert(math.abs(s.distance-math.sqrt(18520^2+1852^2))<1e-8 and s.ttg>90)
assert(s.points[1].x>0-0.1 and s.points[1].y>0)
c:direct(own);s=N.solution(c,own);assert(math.abs(s.cross)<1e-8 and s.direct)
c:step(1);assert(c.selected==2 and not c.direct_origin)
c:step(100);assert(c.selected==2);c:step(-100);assert(c.selected==1)
for i=1,30 do c:scale(-1) end;assert(c.range_index==1)
for i=1,30 do c:scale(1) end;assert(c.range_index==#N.ranges)
local clipped=N.clip(-2,0,2,0);assert(math.abs(clipped.x1+N.radius)<1e-10 and math.abs(clipped.x2-N.radius)<1e-10)
assert(not N.clip(-2,1,2,1) and not N.clip(0,0,0,0))
for _,h in ipairs({0,math.pi/2,math.pi,3*math.pi/2}) do
 local r={{x=0,y=0,alt=0},{x=18520*math.cos(h),y=18520*math.sin(h),alt=0}}
 local a=N.new(r);local v=N.solution(a,{x=0,y=0,alt=0,heading=h,gs=200})
 assert(math.abs(v.relative)<1e-8 and math.abs(v.points[1].x)<1e-8 and v.points[1].y>0)
end
c=N.new(route);c.automatic=true
N.solution(c,{x=18520,y=0,alt=3000,heading=0,gs=0});assert(c.selected==1)
N.solution(c,{x=18520,y=0,alt=3000,heading=0,gs=200});assert(c.selected==2)
N.solution(c,{x=18520,y=18520,alt=600,heading=0,gs=200});assert(c.selected==2 and c.arrived)
N.solution(c,{x=18520,y=18520,alt=600,heading=0,gs=200});assert(c.selected==2)
c=N.new(route);c.automatic=true
N.solution(c,{x=19000,y=200,alt=3000,heading=0,gs=200});assert(c.selected==2,'passed-waypoint gate')
c=N.new(route);c.automatic=true
N.solution(c,{x=19000,y=4000,alt=3000,heading=0,gs=200});assert(c.selected==1,'far abeam must not sequence')
c:step(1);assert(c.automatic,'manual NEXT silently disabled AUTO')
c:select_id(2);assert(c.automatic,'manual waypoint selection silently disabled AUTO')
c.designation={id=2}
N.solution(c,{x=18520,y=0,alt=3000,heading=0,gs=200});assert(c.selected==1 and c.automatic,'designation must suspend, not erase AUTO')
c.designation=nil;N.solution(c,{x=18520,y=0,alt=3000,heading=0,gs=200})
assert(c.selected==2 and c.sequence_count==1,'AUTO failed to resume after clearing designation')
assert(not N.solution(c,{x=0/0,y=0,alt=0,heading=0}))
local bad=N.new({route[1],{x=0/0,y=0},{x=100,y=0,alt=0}});assert(#bad.route==1 and bad.route[1].id==3)
local agl=N.new(route);assert(agl.route[2].reference=='AGL' and agl.route[2].msl==nil)
''')
print('Navigation computer: coordinates, route IDs, clipping, direct-to, sequencing and end-of-route PASS')

sim=runtime()
sim.execute('''
own={n=0,e=0,alt=3000,h=0,p=0,r=0}
route={{x=0,y=0,alt=3000},{x=37040,y=0,alt=3000,name='ALPHA'},
 {x=0,y=18520,alt=3000,name='BRAVO'}}
function get_mission_route()return route end
function get_base_data()return {
 getSelfCoordinates=function()return own.n,own.alt,own.e end,
 getHeading=function()return own.h end,getPitch=function()return own.p end,getRoll=function()return own.r end}end
dofile(SCRIPT_ROOT..'Systems/Navigation_System.lua');local reference_fixture=dofile(SCRIPT_ROOT..'../../tests/navigation_reference_fixture.lua')();update=reference_fixture:wrap(update)
declared={};for name in pairs(handles)do declared[name]=true end
post_initialize()
function p(n,v)get_param_handle(n):set(v)end
function g(n)return get_param_handle(n):get()end
p('MAIN_POWER',1);p('F22_GPS_AID',1);p('EFM_HUD_VALID',1);p('EFM_HUD_VN',200);p('HUD_GS_VALID',1);p('HUD_GS_MPS',200);update()
assert(g('HUD_WP_VALID')==1 and g('HUD_WP_INDEX')==2 and g('F22_NAV_ROUTE_COUNT')==2)
assert(g('HUD_WP_CUE_VALID')==0 and g('HUD_WP_OFFSCREEN')==0,'ordinary waypoint is steering-only')
assert(g('HUD_WP_RANGE_NM')==20 and g('HUD_WP_TTG_TEXT')=='00:03:05')
SetCommand(10830,8.375);SetCommand(10830,8.25);update()
assert(g('HUD_WP_INDEX')==3,'physical press/release only steps once')
assert(g('HUD_WP_CUE_VALID')==0 and g('HUD_WP_OFFSCREEN')==0,'offscreen ordinary waypoint does not get target cues')
SetCommand(10831,1);SetCommand(10831,0);update();assert(g('HUD_WP_INDEX')==2)
SetCommand(10832,1);SetCommand(10832,0);update();assert(g('F22_NAV_AUTO')==1)
SetCommand(10830,1);SetCommand(10831,1);update();assert(g('F22_NAV_AUTO')==1,'manual browse cancelled AUTO')
p('HUD_GS_VALID',0);p('EFM_HUD_VALID',1);p('EFM_HUD_VN',200);p('EFM_HUD_VE',0)
own.n=37040;update();assert(g('HUD_WP_INDEX')==3 and g('F22_NAV_SEQUENCE_COUNT')==1,'HUD invalidation stopped independent NAV sequencing')
SetCommand(10831,1);own.n=0;p('HUD_GS_VALID',1);p('HUD_GS_MPS',200);update()
p('MAIN_POWER',0);reference_fixture.physical.values.F22_ESSENTIAL_POWER=0;update();assert(g('HUD_WP_VALID')==0 and g('F22_NAV_PT_01_VALID')==0)
SetCommand(10830,1);p('MAIN_POWER',1);reference_fixture.physical.values.F22_ESSENTIAL_POWER=1;update();assert(g('HUD_WP_INDEX')==2)
own.n=0/0;p('EFM_HUD_VALID',0);update();assert(g('F22_NAV_VALID')==0 and g('HUD_WP_CUE_VALID')==0)
own.n=0;p('EFM_HUD_VALID',1);route={route[1]};SetCommand(10836,1);update()
assert(g('HUD_WP_VALID')==0 and g('F22_NAV_STATUS_TEXT')=='NO ROUTE')
function get_mission_route()error('no route')end;SetCommand(10836,1);update();assert(g('HUD_WP_VALID')==0)
''')
print('Navigation device: actual route owner, physical edges, HUD cues, invalid data and power PASS')

for panel in ('LEFT','RIGHT','CENTER'):
    ui=runtime();ui.execute(f"dofile(SCRIPT_ROOT..'MFD_{panel}/hsi_page.lua')")
    ui.execute('''
    local lines=0;local names={}
    for _,e in ipairs(elements)do assert(not names[e.name]);names[e.name]=true end
    for _,e in ipairs(elements) do
     if e.parent_element then assert(names[e.parent_element],'missing native element parent') end
     if e.controllers then for _,c in ipairs(e.controllers)do
      if c[1]=='line_object_set_point_using_parameters' then
       assert(e.kind=='ceSimpleLineObject','native point setter requires this concrete line class')
       assert(#e.vertices==2 and e.width>0 and c[5]>0 and c[6]>0);lines=lines+1
      end
     end end
    end
    assert(lines==128)
    ''')
    for _,element in ui.globals().elements.items():
        for _,param in (element.element_params or ui.table()).items():
            if str(param).startswith(('F22_NAV_','HUD_WP_')):
                assert sim.globals().declared[param],('display parameter first created after device construction',param)
print('All three native NAV subsets construct with explicit physical line-controller gains PASS')

controls=runtime();controls.execute('''
function get_aircraft_property()return 0 end
dofile(SCRIPT_ROOT..'Systems/MFD_System.lua');post_initialize()
get_param_handle('MAIN_POWER'):set(1)
local sends={}
function dispatch_action(device,command,value)
 if command==10742 then assert(device==devices.COMBAT_SYSTEM and value>=3 and value<=5);return end
 sends[#sends+1]={device,command,value}
end
for _,panel in ipairs({{10060,13},{10090,13},{10110,13}})do
 local b=panel[1]
 SetCommand(b+panel[2],1);SetCommand(b+panel[2],0)
 SetCommand(b+2,1);SetCommand(b+2,0) -- root MENU PB2 opens NAV
 local before=#sends
 SetCommand(b+20,5.375);SetCommand(b+20,5.25)
 assert(#sends==before+2 and sends[#sends][1]==8 and sends[#sends][2]==10830
  and sends[#sends-1][3]==1 and sends[#sends][3]==0)
 SetCommand(b+19,1);assert(sends[#sends][2]==10831)
 SetCommand(b+17,1);assert(sends[#sends][2]==10835)
 get_param_handle('F22_NAV_ROUTE_SELECTED'):set(1)
 SetCommand(b+18,1);assert(sends[#sends][2]==10832)
 SetCommand(b+15,1);assert(sends[#sends][2]==10833)
 SetCommand(b+14,1);assert(sends[#sends][2]==10834)
end
''')
print('All three MFD NAV softkey routes and decoded release suppression PASS')
