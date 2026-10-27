"""MAP designate/reject resumes video and permits a new target through actual owners."""
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
fixture=ROOT/'tests/test_display_startup.py'
ns={'__file__':str(fixture)}
exec(compile(fixture.read_text().split('\nfor page in ',1)[0],str(fixture),'exec'),ns)

lua=ns['runtime']()
lua.execute(r'''
local now,north=10,0
function get_model_time()return now end
function get_base_data()return {
 getSelfCoordinates=function()return north,3000,0 end,
 getHeading=function()return 0 end,getPitch=function()return 0 end,getRoll=function()return 0 end
}end
package.preload.terrain=function()return {GetHeight=function()return 50 end}end
native={set_power=function()end};function GetDevice()return native end
local function put(n,v)get_param_handle(n):set(v)end
local function val(n)return get_param_handle(n):get()end
dofile(SCRIPT_ROOT..'Systems/Radar_System.lua');post_initialize()
local radar_command,radar_update=SetCommand,update
dofile(SCRIPT_ROOT..'Systems/AG_Mark_System.lua');post_initialize()
local mark_update=update
put('MAIN_POWER',1);put('HUD_MODE',7);put('F22_SOI',2);put('F22N_RADAR_MODE',1)
for _,n in ipairs({'RADAR_NATIVE_READY','VIDEO_SOURCE_PRESENT','VIDEO_READY','VIDEO_GEOMETRY_QUALIFIED'})do put('F22_AG_'..n,1)end
local grant=0
local function tick()
 grant=grant+1;put('F22_AESA_SURFACE_SERVICE',1);put('F22_AESA_SURFACE_SEQUENCE',grant)
 put('F22_AESA_SURFACE_AZ',math.sin(grant*.3)*.5)
 now=now+.05;radar_update();mark_update()
end
local function command(c)radar_command(c,1)end
command(10601);tick();assert(val('F22_AG_MODE')==1 and val('F22_AG_RADAR_CANDIDATE')==1)
for cycle=1,5 do
 command(10606);tick()
 assert(val('F22_AG_DESIGNATION_VALID')==1 and val('HUD_AG_TARGET_VALID')==1)
 assert(val('F22_AG_VIDEO_FROZEN')==0,'completed MAP designation latched FRZ')
 local phase=val('F22_AG_VIDEO_SCAN_FRACTION')
 local frame=val('F22_AG_VIDEO_NORTH');local erase=val('F22_AG_VIDEO_ERASE_SEQUENCE')
 local target_n,target_e=val('HUD_AG_MARK_NORTH'),val('HUD_AG_MARK_EAST')
 north=north+1000
 for i=1,5 do tick()end
 assert(val('F22_AG_VIDEO_SCAN_FRACTION')~=phase and val('F22_AG_VIDEO_NORTH')~=frame,'designation stopped live MAP')
 assert(val('HUD_AG_MARK_NORTH')==target_n and val('HUD_AG_MARK_EAST')==target_e,'live map moved the stabilized target')
 phase=val('F22_AG_VIDEO_SCAN_FRACTION')
 local sequence=val('F22_AG_DESIGNATION_SEQUENCE')
 command(cycle%2==1 and 10609 or 10630);mark_update()
 assert(val('HUD_AG_TARGET_VALID')==0 and val('F22_AG_DESIGNATION_VALID')==0)
 assert(val('F22_AG_DESIGNATION_SEQUENCE')==sequence+1)
 tick()
 assert(val('F22_AG_VIDEO_FROZEN')==0,'MAP undesignate left the video freeze latched')
 assert(val('F22_AG_VIDEO_SCAN_FRACTION')~=phase,'MAP sweep did not resume')
 assert(val('F22_AG_VIDEO_NORTH')~=frame,'MAP retained the captured frame after reject')
 assert(val('F22_AG_RADAR_CANDIDATE')==1,'reject blocked subsequent designation')
 assert(val('F22_AG_VIDEO_ERASE_SEQUENCE')==erase,'reject needlessly erased the map')
 assert(val('F22_AG_MODE')==1 and val('F22_AG_VIDEO_ENABLE')==1)
end
command(10607);tick();assert(val('F22_AG_RADAR_RANGE_NM')==40,'reject left range controls frozen')
command(10606);tick();assert(val('HUD_AG_TARGET_VALID')==1,'MAP could not designate again')
''')
print('MAP reject: five live designate/reject cycles, stabilized target, sweep/frame continuity and range controls PASS')

lua=ns['runtime']()
lua.execute(r'''
local v={F22_AG_RADAR_NATIVE_READY=1,F22_AG_VIDEO_SOURCE_PRESENT=1,F22_AG_VIDEO_READY=1,F22_AG_VIDEO_GEOMETRY_QUALIFIED=1}
local function get(n)return v[n]or 0 end;local function put(n,x)v[n]=x end
package.preload.terrain=function()return {GetHeight=function()return 50 end}end
local s=dofile(SCRIPT_ROOT..'Systems/AG_Radar_System.lua').new(get,put,function()end)
dofile(SCRIPT_ROOT..'../../tests/surface_grant_fixture.lua')(s,put)
local pose={north=0,altitude=3000,east=0,heading=0,pitch=0,roll=0}
s:command('rws',1,true,10);s:update(pose,10,.05,true,true)
s:command('designate',1,true,10);s:update(pose,10.05,.05,true,true)
assert(get('F22_AG_VIDEO_FROZEN')==0)
s:command('tws',1,true,10.05);s:update(pose,10.1,.05,true,true)
assert(get('F22_AG_MODE')==2 and get('F22_AG_VIDEO_FROZEN')==0,'MAP freeze leaked into GMT')
s:command('rws',1,true,10.1);s:update(pose,10.15,.05,true,true)
s:command('vertical_span',1,true,10.15);s:update(pose,10.2,.05,true,true)
assert(get('F22_AG_VIDEO_FROZEN')==1)
local phase=get('F22_AG_VIDEO_SCAN_FRACTION')
s:command('undesignate',1,true,10.2);s:update(pose,10.25,.05,true,true)
assert(get('F22_AG_VIDEO_FROZEN')==1 and get('F22_AG_VIDEO_SCAN_FRACTION')==phase,'reject changed an explicit FRZ selection')
s:command('vertical_span',1,true,10.25);s:update(pose,10.3,.05,true,true)
assert(get('F22_AG_VIDEO_FROZEN')==0 and get('F22_AG_VIDEO_SCAN_FRACTION')~=phase)
''')
print('MAP reject: live GMT handoff and independent explicit FRZ/resume PASS')
