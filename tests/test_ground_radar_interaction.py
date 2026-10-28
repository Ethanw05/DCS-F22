"""Actual ground-radar and HOTAS owners keep coordinate, track and image states separate."""
from pathlib import Path
import contextlib,io,runpy
ROOT=Path(__file__).resolve().parents[1]
with contextlib.redirect_stdout(io.StringIO()):
 runtime=runpy.run_path(str(ROOT/'tests/test_display_startup.py'))['runtime']
lua=runtime()
lua.execute('''
local v={F22_AG_RADAR_NATIVE_READY=1,F22_AG_VIDEO_SOURCE_PRESENT=1,F22_AG_VIDEO_READY=1,
 F22_AG_VIDEO_GEOMETRY_QUALIFIED=1,F22_AG_GMT_READY=1}
local function get(n)return v[n]or 0 end;local function put(n,x)v[n]=x end
package.preload.terrain=function()return {GetHeight=function()return 50 end}end
local s=dofile(SCRIPT_ROOT..'Systems/AG_Radar_System.lua').new(get,put,function()end)
dofile(SCRIPT_ROOT..'../../tests/surface_grant_fixture.lua')(s,put)
local pose={north=0,altitude=3000,east=0,heading=0,pitch=0,roll=0}
assert(s.model.mode==1,'A/G does not start in MAP')
s:update(pose,10,.05,true,true)
s:command('designate_begin',1,true,10)
assert(get('F22_AG_CURSOR_PREVIEW')==1 and get('F22_AG_VIDEO_HOLD')==1)
assert(get('F22_AG_VIDEO_FROZEN')==0 and get('F22_AG_DESIGNATION_VALID')==0,'TDC press committed early or selected FRZ')
local phase=get('F22_AG_VIDEO_SCAN_FRACTION');local sensor_angle=get('F22_AG_SENSOR_SCAN_AZ_DEG')
pose.north=1000;s:update(pose,10.1,.05,true,true)
assert(s.pose.north==30 and get('F22_AG_VIDEO_SCAN_FRACTION')==phase,'preview slid across the retained image')
assert(get('F22_AG_SENSOR_SCAN_AZ_DEG')~=sensor_angle,'image preview stopped live sensor sweep')
s:command('cursor_right',1,true,10.1)
local expected=s.model:point(s.pose,s.terrain)
s:command('designate_end',1,true,10.1)
assert(get('F22_AG_DESIGNATION_VALID')==1 and get('F22_AG_DESIGNATION_EAST')==expected.east)
assert(get('F22_AG_VIDEO_HOLD')==0 and get('F22_AG_VIDEO_FROZEN')==0,'release left video held')
s:update(pose,10.2,.05,true,true)
s:command('vertical_span',1,true,10.2);s:update(pose,10.25,.05,true,true)
local frozen_n,frozen_e=s.pose.north,s.pose.east
pose.north=2500;pose.heading=.3;s:update(pose,10.3,.05,true,true)
assert(s.pose.north==frozen_n and s.pose.east==frozen_e,'FRZ cursor adopted current aircraft frame')
expected=s.model:point(s.pose,s.terrain);s:command('designate',1,true,10.3)
assert(get('F22_AG_DESIGNATION_NORTH')==expected.north,'frozen pixel designated the wrong world coordinate')
s:command('vertical_span',1,true,10.3)
s:command('tws',1,true,10.3);s:update(pose,10.4,.05,true,true)
s:command('designate',1,true,10.4)
assert(get('F22_AG_DESIGNATION_VALID')==1 and get('F22_AG_TRACK_REQUEST_ACTIVE')==0,'GMT TDC coordinate started object acquisition')
s:command('acquire_begin',1,true,10.4)
assert(get('F22_AG_TRACK_REQUEST_ACTIVE')==0,'SCS press acquired before release')
s:command('acquire',1,true,10.4)
assert(get('F22_AG_TRACK_REQUEST_ACTIVE')==1)
local sequence=get('F22_AG_TRACK_REQUEST_SEQUENCE')
for k,x in pairs({VALID=1,ID=123,TYPE=2,N=18550,U=50,E=0,TIME=10.5,VN=8,VU=0,VE=0,VELOCITY_VALID=1})do put('F22_AG_NATIVE_TRACK_'..k,x)end
put('F22_AG_NATIVE_TRACK_REQUEST_SEQUENCE',sequence-1)
s:update(pose,10.5,.05,true,true);assert(get('F22_AG_TRACK_VALID')==0,'old request response became the new target')
put('F22_AG_NATIVE_TRACK_REQUEST_SEQUENCE',sequence)
s:update(pose,10.55,.05,true,true)
assert(get('F22_AG_TRACK_VALID')==1 and get('F22_AG_MODE')==3)
assert(get('F22_AG_TRACK_MOTION_VALID')==1)
assert(math.abs(s.last_track_point.north-18550)<1e-9,'predicted display became a fresh observation')
local original_sequence=get('F22_AG_DESIGNATION_SEQUENCE')
put('F22_AG_NATIVE_TRACK_MEMORY',1);s:update(pose,10.56,.01,true,true)
assert(get('F22_AG_DESIGNATION_SEQUENCE')==original_sequence,'coasting prediction renewed designation')
put('F22_AG_NATIVE_TRACK_VELOCITY_VALID',0);s:update(pose,10.57,.01,true,true)
assert(get('F22_AG_TRACK_MOTION_VALID')==0,'unknown ground motion remained a healthy vector')

s:command('undesignate',1,true,10.55);s:update(pose,10.6,.05,true,true)
assert(get('F22_AG_TRACK_VALID')==0 and get('F22_AG_MODE')==2,'cached native track survived reject')
s:command('rws',1,true,10.6);s:update(pose,10.65,.05,true,true)
s:command('acquire',1,true,10.65)
put('F22_AG_NATIVE_TRACK_REQUEST_SEQUENCE',get('F22_AG_TRACK_REQUEST_SEQUENCE'))
put('F22_AG_NATIVE_TRACK_ID',0);put('F22_AG_NATIVE_TRACK_TYPE',3)
s:update(pose,10.7,.05,true,true)
assert(get('F22_AG_FIXED_TRACK')==1 and get('F22_AG_TRACK_VALID')==1 and get('F22_AG_MODE')==1,'MAP FTT became GMTT or rejected a fixed-point track')
s:command('undesignate',1,true,10.7);s:update(pose,10.75,.05,true,true)
assert(get('F22_AG_FIXED_TRACK')==0 and get('F22_AG_MODE')==1)
s:command('designate_begin',1,true,10.75);s:command('preview_cancel',1,true,10.75)
local old=get('F22_AG_DESIGNATION_SEQUENCE');s:command('designate_end',1,true,10.75)
assert(get('F22_AG_DESIGNATION_SEQUENCE')==old,'cancelled TDC release committed an aimpoint')
''')
lua=runtime()
lua.execute('''
local events={};local s=dofile(SCRIPT_ROOT..'Systems/Combat_Logic.lua').new(function(n,v)events[#events+1]={n,v}end)
local c={primary_page=1};s:set_mode(7);events={}
s:input('tdc',1,c);s:input('tdc',1,c)
assert(#events==1 and events[1][1]=='ground_tdc' and events[1][2]==1)
s:input('tdc',0,c);assert(#events==2 and events[2][2]==0)
events={};s:input('scs_depress',1,c);s:input('scs_depress',0,c)
assert(#events==2 and events[1][1]=='ground_acquire' and events[2][2]==0)
events={};s:input('tdc',1,c);s:focus(3);s:input('tdc',0,c)
assert(#events==2 and events[2][1]=='ground_preview_cancel','focus change failed to cancel held preview')
s:focus(2);events={};s:input('tdc',1,c);c.primary_page=3;s:update(.02,c);s:input('tdc',0,c)
assert(#events==2 and events[2][1]=='ground_preview_cancel','page change committed a hidden aimpoint')
''')
lua=runtime()
lua.execute('''
local now=10;function get_model_time()return now end
function get_base_data()return setmetatable({getSelfCoordinates=function()return 0,3000,0 end},
 {__index=function()return function()return 0 end end})end
package.preload.terrain=function()return {GetHeight=function()return 50 end}end
native={set_power=function()end};function GetDevice()return native end
local function p(n,v)get_param_handle(n):set(v)end
local function g(n)return get_param_handle(n):get()end
dofile(SCRIPT_ROOT..'Systems/Radar_System.lua');post_initialize();local rc,ru=SetCommand,update
dofile(SCRIPT_ROOT..'Systems/Combat_System.lua');post_initialize();local cc,cu=SetCommand,update
function dispatch_action(device,command,value)
 if device==devices.RADAR_COMPUTER then rc(command,value)end
end
for n,v in pairs({MAIN_POWER=1,HUD_MODE=7,F22_SOI=2,F22_PMFD_PAGE=1,F22N_RADAR_MODE=1,
 F22_AG_RADAR_NATIVE_READY=1,F22_AG_VIDEO_SOURCE_PRESENT=1,F22_AG_VIDEO_READY=1,
 F22_AG_VIDEO_GEOMETRY_QUALIFIED=1,F22_AG_GMT_READY=1})do p(n,v)end
rc(10601,1);ru();cu()
cc(10733,16.375)
assert(g('F22_AG_CURSOR_PREVIEW')==1 and g('F22_AG_DESIGNATION_VALID')==0)
now=now+.05;ru();cc(10733,16.25)
assert(g('F22_AG_DESIGNATION_VALID')==1 and g('F22_AG_TRACK_REQUEST_ACTIVE')==0)
cc(10741,16.375);assert(g('F22_AG_TRACK_REQUEST_ACTIVE')==0)
cc(10741,16.25);assert(g('F22_AG_TRACK_REQUEST_ACTIVE')==1,'actual SCS release did not reach native acquisition request')
cc(10733,16.375);p('MAIN_POWER',0);cu()
assert(g('F22_AG_CURSOR_PREVIEW')==0,'power loss left an input preview held')
''')
print('Ground radar interaction: TDC preview/release, SCS acquisition, GMT coordinates, frozen-image registration, native request identity, MAP FTT/reject, actual HOTAS dispatch and focus/page/power cancellation PASS')
