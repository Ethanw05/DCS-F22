"""Exercise production ground controls, patch registration and physical input routing."""
from pathlib import Path
import contextlib, io, runpy
ROOT=Path(__file__).resolve().parents[1]
with contextlib.redirect_stdout(io.StringIO()):
    runtime=runpy.run_path(str(ROOT/'tests/test_display_startup.py'))['runtime']

lua=runtime()
lua.execute('''
local function close(a,b,t)assert(math.abs(a-b)<(t or 1e-6),tostring(a)..' != '..tostring(b))end
local modes=dofile(SCRIPT_ROOT..'Systems/AG_Radar_Modes.lua')
local function fixture()
 local v={F22_AG_RADAR_NATIVE_READY=1,F22_AG_VIDEO_SOURCE_PRESENT=1,F22_AG_VIDEO_READY=1,
  F22_AG_VIDEO_GEOMETRY_QUALIFIED=1,F22_AG_GMT_READY=1}
 local get=function(n)return v[n]or 0 end
 local put=function(n,x)v[n]=x end
 package.preload.terrain=function()return {GetHeight=function(n,e)return 50+n*.001+e*.002 end}end
 local s=dofile(SCRIPT_ROOT..'Systems/AG_Radar_System.lua').new(get,put,function()end)
dofile(SCRIPT_ROOT..'../../tests/surface_grant_fixture.lua')(s,put)
 return s,get,put
end
local pose={north=2000,altitude=4000,east=-3000,heading=.3,pitch=0,roll=0}
-- SIL preserves the picture, FRZ alone preserves emission, and ACTIVE ends
-- at the SAME phase/direction for different widths, starts and frame rates.
for _,width in ipairs({20,45,90,120})do for _,units in ipairs({.23,1.61})do
 local s,g=fixture();s.model.width=width;s.controls.units=units;s.controls.sweep=units%1
 s.controls.direction=math.floor(units)%2==0 and 1 or -1
 local t=10;s:update(pose,t,.017,true,true)
 s:command('vertical_span',1,true,t);s:update(pose,t+.02,.02,true,true)
 assert(g('F22_AG_RADAR_EMITTING')==1,'FRZ silenced the transmitter')
 s:command('vertical_span',1,true,t+.02)
 s:command('silent',1,true,t+.02);s:update(pose,t+.04,.02,true,true)
 assert(g('F22_AG_RADAR_EMITTING')==0 and g('F22_AG_VIDEO_HOLD')==1)
 local saved=s.controls.units
 s:command('active',1,true,t+.04)
 local end_units=s.controls.active_end;close(end_units-saved,1)
 local i=0;t=t+.04
 repeat t=t+.037;s:update(pose,t,.037,true,true);i=i+1;assert(i<300)until not s.controls.active
 close(s.controls.units,end_units)
 assert(g('F22_AG_RADAR_EMITTING')==0 and g('F22_AG_VIDEO_HOLD')==1,'ACTIVE did not return to silent hold')
 s:command('silent',1,true,t);s:update(pose,t+.02,.02,true,true)
 assert(g('F22_AG_RADAR_EMITTING')==1 and g('F22_AG_VIDEO_HOLD')==0)
end end
local s,g,put=fixture();assert(s.controls.fan,'ground radar did not start in FAN');s:update(pose,10,.02,true,true)
for i=1,8 do s:command('range_up',1,true,10)end;assert(s.model.range_nm==160)
s:command('tws',1,true,10);assert(s.model.range_nm==40)
s:command('sea',1,true,10);for i=1,4 do s:command('range_up',1,true,10)end;assert(s.model.range_nm==80)
s:command('rws',1,true,10);s.model.range_nm=40;s.model.cursor_fraction=.35
s:update(pose,10.1,.02,true,true)
local before=s.model:point(s.pose,s.terrain)
s:command('designate',1,true,10.1)
close(g('F22_AG_DESIGNATION_NORTH'),before.north);close(g('F22_AG_DESIGNATION_EAST'),before.east)
assert(s.model.range_nm==20,'designation did not fit a mode-valid range')
-- Persistent RF work survives a missed pulse; pointed jobs add no work.
do
 local values={F22_AG_RADAR_NATIVE_READY=1,F22_AG_GMT_READY=1}
 local function read(n)return values[n]or 0 end
 local function write(n,v)values[n]=v end
 local radar=dofile(SCRIPT_ROOT..'Systems/AG_Radar_System.lua').new(read,write,function()end)
 local function sample(time,work,jobs)
  write('F22_AESA_READY',1);write('F22_AESA_SEQUENCE',2);write('F22_AESA_GENERATION',1);write('F22_AESA_TIME',time)
  write('F22_AESA_SURFACE_DISCOVERY_SEQUENCE',jobs);write('F22_AESA_SURFACE_DISCOVERY_WORK',work)
  radar:update(pose,time,.02,true,true)
 end
 sample(10,0,0)
 sample(10.02,0,0)
 assert(radar.controls.units==0,'a pointed ground job created discovery credit')
 write('F22_AESA_SURFACE_SERVICE',0)
 sample(10.04,3/308,3);close(radar.controls.units,3/308)
 assert(read('F22_AG_VIDEO_COLLECTION')>0 and read('F22_AG_VIDEO_COLLECTION')<1,'partial RF work was rounded away')
 sample(10.06,3/308,3);close(radar.controls.units,3/308)
end
-- Geometry readiness alone cannot authorize a pixel from the previous range.
put('F22_AG_VIDEO_REFERENCE_SCHEMA',2);put('F22_AG_VIDEO_REFERENCE_VALID',1)
put('F22_AG_VIDEO_REFERENCE_MODE',1);put('F22_AG_VIDEO_REFERENCE_RANGE_NM',40)
put('F22_AG_VIDEO_REFERENCE_EXPANSION',0);put('F22_AG_VIDEO_REFERENCE_EPOCH',s.controls.epoch)
local sequence=g('F22_AG_DESIGNATION_SEQUENCE')
s:command('designate',1,true,10.1);assert(g('F22_AG_DESIGNATION_SEQUENCE')==sequence,'old camera range authorized a target')
put('F22_AG_VIDEO_REFERENCE_RANGE_NM',s.model.range_nm)
s:command('designate',1,true,10.1);assert(g('F22_AG_DESIGNATION_SEQUENCE')==sequence+1)
put('F22_AG_VIDEO_REFERENCE_SCHEMA',0)
local gain=s.controls.gain;s:command('elevation_up',1,true,10.1)
assert(s.controls.antenna==1 and s.controls.gain==gain)
s:command('gain_up',1,true,10.1);assert(s.controls.gain==gain+1 and s.controls.antenna==1)
s:command('reset',1,true,10.1);assert(s.controls.gain==5 and s.controls.antenna==0 and s.model.range_nm==40)
-- EXP2 and EXP3 retain the selected geographic patch across motion and turns.
for _,level in ipairs({1,2,3})do
 local q,g=fixture();q.model.range_nm=40;q.model.cursor_fraction=.25;q.model.cursor_az=.1
 q:update(pose,20,.02,true,true)
 q:command('exp'..level,1,true,20);q:update(pose,20.02,.02,true,true)
 assert(g('F22_AG_CORRAL_SHOW')==1)
 q:command('designate_begin',1,true,20.02)
 local point=q.model:point(q.pose,q.terrain)
 q:command('designate_end',1,true,20.02)
 q:update(pose,20.04,.02,true,true)
 assert(q.controls.expansion==level and g('F22_AG_DESIGNATION_VALID')==0,'corral selection became a target')
 local newpose={north=pose.north+500,altitude=pose.altitude,east=pose.east+200,heading=pose.heading+.15,pitch=0,roll=0}
 q:update(newpose,20.06,.02,true,true)
 local image_center=q.model:point(q.pose,q.terrain)
 if level>1 then close(image_center.north,point.north,.01);close(image_center.east,point.east,.01)
 else assert(math.abs(image_center.north-point.north)>100,'undesignated EXP1 incorrectly ground stabilized')end
 q:command('vertical_span',1,true,20.06);q:update(newpose,20.08,.02,true,true)
 local frozen=q.model:point(q.pose,q.terrain)
 newpose.north=newpose.north+300;newpose.heading=newpose.heading+.1
 q:update(newpose,20.10,.02,true,true)
 q:command('designate',1,true,20.10)
 close(g('F22_AG_DESIGNATION_NORTH'),frozen.north);close(g('F22_AG_DESIGNATION_EAST'),frozen.east)
 q:command('vertical_span',1,true,20.10)
 q:command('undesignate',1,true,20.10);q:update(newpose,20.12,.02,true,true)
 assert(q.controls.expansion==0 and g('F22_AG_DESIGNATION_VALID')==0)
end
-- Silent freeze retains the last measured bricks without inventing a fresh
-- observation or continuing native search.
do
 local q,g,put=fixture();q:command('tws',1,true,30)
 put('F22_AG_GMT_COUNT',1)
 for k,v in pairs({ID=12,N=10000,U=50,E=1000,VN=10,VU=0,VE=0,TIME=30,AZ=.1,RANGE=10000})do put('F22_AG_GMT_1_'..k,v)end
 q:update(pose,30,.02,true,true);local x=g('F22_AG_GMT_DISPLAY_1_X')
 q.model.mode=3;q.selected_id=12;q.track_requested=true
 q:command('silent',1,true,30);assert(q.model.mode==2,'SIL retained a tracking-mode title after cancelling the track');put('F22_AG_GMT_COUNT',0)
 q:update(pose,30.1,.02,true,true)
 assert(g('F22_AG_GMT_DISPLAY_1_VALID')==1 and g('F22_AG_GMT_DISPLAY_1_X')==x)
 assert(q.model.movers[1].stamp==30 and g('F22_AG_RADAR_EMITTING')==0)
end
-- Every expanded cursor point is an inverse of its displayed world mapping,
-- including negative world coordinates and off-nose views.
for _,heading in ipairs({0,.7,2,4.5})do for level=1,3 do
 local origin={north=-23000,east=17500,altitude=7000,heading=heading}
 local point={north=origin.north+15000*math.cos(heading+.2),east=origin.east+15000*math.sin(heading+.2),altitude=50}
 local v=modes.exp_geometry(origin,point,level)
 for _,xy in ipairs({{0,0},{.3,-.2},{-.65,.61}})do
  local p=modes.point(v,xy[1],xy[2],{GetHeight=function()return 50 end})
  local x,y=modes.project(p,v);close(x,xy[1]);close(y,xy[2])
 end
end end
''')

lua=runtime()
lua.execute('''
local events={};local s=dofile(SCRIPT_ROOT..'Systems/Combat_Logic.lua').new(function(n,v)events[#events+1]={n,v}end)
local c={primary_page=1};s:set_mode(7);s:focus(3);events={}
s:input('dms_down',1,c);s:input('dms_down',0,c)
assert(s.soi==2 and #events==0,'first directional SCS must assign focus')
s:input('dms_down',1,c);s:input('dms_down',1,c);s:input('dms_down',0,c)
assert(#events==2 and events[1][1]=='ground_acquire'and events[1][2]==1 and events[2][2]==0)
events={};s:input('dms_down',1,c);c.primary_page=3;s:update(.02,c);s:input('dms_down',0,c)
assert(#events==2 and events[2][1]=='ground_preview_cancel','hidden-page directional release acquired')
''')

lua=runtime()
lua.execute('''
local events={}
function get_aircraft_property()return 0 end
dofile(SCRIPT_ROOT..'Systems/MFD_System.lua');post_initialize();local mc=SetCommand
function dispatch_action(d,c,v)if d==devices.MFD_SYSTEM then mc(c,v)else events[#events+1]={d,c,v}end end
dofile(SCRIPT_ROOT..'Systems/PMFD_System.lua');post_initialize()
local function p(n,v)get_param_handle(n):set(v)end
p('MAIN_POWER',1);p('HUD_MODE',7);p('F22_AG_GAIN_INDEX',1);p('F22_AG_OPTIONS_AVAILABLE',1);p('F22_AG_EXP1_AVAILABLE',1);p('F22_AG_RANGE_AVAILABLE',1)
local function key(c)SetCommand(c,1);SetCommand(c,0)end
key(10132);assert(events[#events][2]==10646,'EXP1 key did not reach the radar owner')
key(10141);key(10148);assert(events[#events][2]==10641,'DATA GN+ drove antenna input')
key(10142);key(10148);assert(events[#events][2]==10614,'main EL+ drove gain')
p('F22_AG_OPTIONS_AVAILABLE',0);p('F22_AG_EXP1_AVAILABLE',0);local n=#events;SetCommand(10133,1)
for i=n+1,#events do assert(events[i][1]~=devices.RADAR_COMPUTER,'unavailable expansion command executed')end
''')
lua=runtime()
lua.execute('''
local now=10;function get_model_time()return now end
function get_base_data()return setmetatable({getSelfCoordinates=function()return 0,3000,0 end},
 {__index=function()return function()return 0 end end})end
package.preload.terrain=function()return {GetHeight=function()return 50 end}end
function GetDevice()error('surface controls called a mechanical radar')end
local function p(n,v)get_param_handle(n):set(v)end
local function g(n)return get_param_handle(n):get()end
dofile(SCRIPT_ROOT..'Systems/Radar_System.lua');post_initialize()
for n,v in pairs({MAIN_POWER=1,HUD_MODE=7,F22_SOI=2,F22_PMFD_PAGE=1,F22N_RADAR_MODE=1,
 F22_AG_RADAR_NATIVE_READY=1,F22_AG_VIDEO_SOURCE_PRESENT=1,F22_AG_VIDEO_READY=1,
 F22_AG_VIDEO_GEOMETRY_QUALIFIED=1,F22_AG_GMT_READY=1})do p(n,v)end
local sequence=0
local function tick(time)
 now=time;sequence=sequence+1
 p('F22_AESA_DRIVER_READY',1);p('F22_AESA_READY',1);p('F22_AESA_GENERATION',1)
 p('F22_AESA_TIME',now);p('F22_AESA_SEQUENCE',sequence*2)
 p('F22_AESA_SURFACE_SERVICE',1);p('F22_AESA_SURFACE_SEARCH',1);p('F22_AESA_SURFACE_CELLS',16);p('F22_AESA_SURFACE_SEQUENCE',sequence)
 p('F22_AESA_SURFACE_DISCOVERY_SEQUENCE',sequence);p('F22_AESA_SURFACE_DISCOVERY_WORK',sequence/16)
 update()
end
SetCommand(10601,1);tick(10);assert(g('F22_AESA_CONTROL_EMIT')==1)
SetCommand(10638,1);tick(10.1)
assert(g('F22_AESA_CONTROL_EMIT')==0 and g('RADAR_PWR')==1 and g('F22_AG_RADAR_OPERATING')==1 and g('F22_RADAR_EMISSION_INHIBIT')==1)
SetCommand(10639,1);tick(10.2);assert(g('F22_AESA_CONTROL_EMIT')==1 and g('F22_RADAR_EMISSION_INHIBIT')==0)
for i=1,250 do tick(10.2+i/60)end
assert(g('F22_AESA_CONTROL_EMIT')==0 and g('F22_AG_SILENT')==1 and g('F22_AG_VIDEO_FROZEN')==1)
''')

print('Ground modes: SIL/ACTIVE cycle matrix, mode ranges/autorange, antenna/gain isolation, EXP corral/stabilization/FRZ, projection inverse, directional SCS and actual bezel dispatch PASS')
