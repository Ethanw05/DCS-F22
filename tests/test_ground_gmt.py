"""Exercise native contact transport through real Lua commands and symbology."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
fixture=ROOT/'tests/test_display_startup.py'
ns={'__file__':str(fixture)}
exec(compile(fixture.read_text().split('\nfor page in ',1)[0],str(fixture),'exec'),ns)
lua=ns['runtime']()
lua.execute('''
local v={F22_AG_RADAR_NATIVE_READY=1,F22_AG_GMT_READY=1,F22_AG_GMT_COUNT=1}
local function get(n)return v[n]or 0 end;local function put(n,x)v[n]=x end
package.preload.terrain=function()return {GetHeight=function()return 50 end}end
local s=dofile(SCRIPT_ROOT..'Systems/AG_Radar_System.lua').new(get,put,function()end)
s:command('tws',1,true,10)
assert(get('F22_AG_INTERLEAVE')==0,'GMT must open on a clean background')
s:command('interrogate',1,true,10)
local pose={north=0,altitude=3000,east=0,heading=0,pitch=0,roll=0}
for k,x in pairs({ID=123,N=18550,U=50,E=0,VN=8,VU=0,VE=0,TIME=10,AZ=0,RANGE=18520})do put('F22_AG_GMT_1_'..k,x)end
s:update(pose,10,1/60,true,true)
assert(get('F22_AG_MODE')==2 and get('F22_AG_GMT_DISPLAY_1_VALID')==1)
assert(get('F22_AG_RADAR_CANDIDATE')==1)
s:command('acquire',1,true,10)
assert(get('F22_AG_MODE')==2,'mode publishes on update only')
assert(s.model.mode==2 and get('F22_AG_TRACK_REQUEST_ACTIVE')==1)
assert(get('F22_AG_TRACK_REQUEST_NORTH')==18550 and get('F22_AG_TRACK_REQUEST_EAST')==0)
assert(get('F22_AG_TRACK_REQUEST_ID')==0,'TDC acquisition must not require a search ID')
for k,x in pairs({VALID=1,ID=123,TYPE=2,N=18550,U=50,E=0,VN=8,VU=0,VE=0,TIME=10.1})do put('F22_AG_NATIVE_TRACK_'..k,x)end
put('F22_AG_NATIVE_TRACK_REQUEST_SEQUENCE',get('F22_AG_TRACK_REQUEST_SEQUENCE'))
s:update(pose,10.1,1/60,true,true)
assert(get('F22_AG_TRACK_VALID')==1 and get('F22_AG_DESIGNATION_VALID')==1)
assert(math.abs(get('F22_AG_TRACK_SPEED')-8*1.94384449)<1e-6)
put('F22_AG_NATIVE_TRACK_MEMORY',1)
s:update(pose,12.1,1/60,true,true);assert(get('F22_AG_TRACK_COAST')==1)
put('F22_AG_NATIVE_TRACK_VALID',0)
s:update(pose,15.2,1/60,true,true);assert(get('F22_AG_TRACK_VALID')==0)
assert(get('F22_AG_TRACK_REQUEST_ID')==0 and get('F22_AG_DESIGNATION_VALID')==0)
s:command('rws',1,true,17)
put('F22_AG_VIDEO_SOURCE_PRESENT',1);put('F22_AG_VIDEO_READY',1)
s:update(pose,17,1/60,true,true);s:command('designate',1,true,17)
assert(get('F22_AG_DESIGNATION_VALID')==0,'unqualified MAP enabled designation')
put('F22_AG_VIDEO_GEOMETRY_QUALIFIED',1)
put('F22_AG_VIDEO_REFERENCE_VALID',1);put('F22_AG_VIDEO_REFERENCE_NORTH',200)
put('F22_AG_VIDEO_REFERENCE_EAST',300);put('F22_AG_VIDEO_REFERENCE_ALTITUDE',3000)
s:update(pose,17.1,1/60,true,true);s:command('designate',1,true,17.1)
assert(get('F22_AG_DESIGNATION_NORTH')==18720 and get('F22_AG_DESIGNATION_EAST')==300)
local erase=s.video_erase;local phase=s.sweep_phase
s:update(pose,17.2,1/60,true,true)
assert(s.video_erase==erase and s.sweep_phase>phase and not s.video_frozen)
phase=s.sweep_phase
local video_phase=get('F22_AG_VIDEO_SCAN_FRACTION')
s:command('vertical_span',1,true,17.3);s:update(pose,17.3,1/60,true,true)
assert(s.video_erase==erase and s.sweep_phase>phase and s.video_frozen)
assert(get('F22_AG_VIDEO_SCAN_FRACTION')==video_phase,'FRZ changed retained pixels while sensing')
s:command('vertical_span',1,true,17.35);s:update(pose,17.35,1/60,true,true)
assert(s.video_erase==erase and s.sweep_phase>phase)
s:command('tws',1,true,17.4);assert(not s.interleave,'mode entry did not clear interleave')
s:update(pose,17.4,1/60,true,true);assert(get('F22_AG_VIDEO_ENABLE')==1)
assert(s.pose.north==30 and s.pose.east==0,'GMT without imagery retained an old MAP reference')
s:update(pose,17.5,1/60,false,true);assert(get('F22_AG_GMT_DISPLAY_1_VALID')==0)
''')
ui=ns['runtime']();ui.execute((ROOT/'Cockpit/Scripts/PMFD_CENTER/ag_radar_format.lua').read_text())
els=ui.globals().elements
assert sum(e.kind=='ceTexPoly' for _,e in els.items())==1
assert sum(str(e.name).startswith('F22_AG_GMT_BRICK_') for _,e in els.items())==64
print('GMT transport/designation/coast/expiry, MAP reference/inhibit, freeze continuity, interleave and one texture plus 64 bricks PASS')
