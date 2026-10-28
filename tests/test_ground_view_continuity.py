"""Actual ground owner: retained designation and GMT authority across image views."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
fixture=ROOT/'tests/test_display_startup.py'
ns={'__file__':str(fixture)}
exec(compile(fixture.read_text().split('\nfor page in ',1)[0],str(fixture),'exec'),ns)
lua=ns['runtime']()
lua.execute('''
local values={F22_AG_RADAR_NATIVE_READY=1,F22_AG_GMT_READY=1,F22_AG_VIDEO_READY=1,
 F22_AG_VIDEO_SOURCE_PRESENT=1,F22_AG_VIDEO_GEOMETRY_QUALIFIED=1}
local function get(n)return values[n]or 0 end
local function put(n,v)values[n]=v end
package.preload.terrain=function()return {GetHeight=function()return 50 end}end
local s=dofile(SCRIPT_ROOT..'Systems/AG_Radar_System.lua').new(get,put,function()end)
dofile(SCRIPT_ROOT..'../../tests/surface_grant_fixture.lua')(s,put)
local pose={north=0,altitude=3000,east=0,heading=0,pitch=0,roll=0}
s:update(pose,10,.02,true,true)
s:command('designate',1,true,10)
local n,u,e=get('F22_AG_DESIGNATION_NORTH'),get('F22_AG_DESIGNATION_ALTITUDE'),get('F22_AG_DESIGNATION_EAST')
local sequence=get('F22_AG_DESIGNATION_SEQUENCE')
local now=10
for _,level in ipairs({1,2,1,3,0,2,3,1,0})do
 now=now+.02
 s:command(level==0 and 'rws'or'exp'..level,1,true,now)
 s:update(pose,now,.02,true,true)
 assert(s.controls.expansion==level and s.controls.pending==0,'view required a second designation')
 assert(get('F22_AG_DESIGNATION_VALID')==1 and get('F22_AG_DESIGNATION_SEQUENCE')==sequence)
 assert(get('F22_AG_DESIGNATION_NORTH')==n and get('F22_AG_DESIGNATION_ALTITUDE')==u
  and get('F22_AG_DESIGNATION_EAST')==e,'image magnification moved the target')
end
s:command('undesignate',1,true,now)
assert(not s.controls.patch and get('F22_AG_DESIGNATION_VALID')==0)
s:command('exp1',1,true,now)
assert(s.controls.pending==1,'cleared target resurrected when recalling EXP')
s:command('rws',1,true,now)
-- Acquire one genuine native GMT track; mode/view changes retain the request.
s:command('tws',1,true,20);s:update(pose,20,.02,true,true)
s:command('acquire',1,true,20)
local request=s.track_sequence
local function track(t,valid)
 for k,v in pairs({VALID=valid and 1 or 0,ID=42,TYPE=2,N=6000+10*(t-20),U=50,E=100,
  VN=10,VU=0,VE=0,VELOCITY_VALID=1,TIME=t,MEMORY=0,REQUEST_SEQUENCE=request})do
  put('F22_AG_NATIVE_TRACK_'..k,v)
 end
end
track(20.1,true);s:update(pose,20.1,.02,true,true)
assert(get('F22_AG_TRACK_VALID')==1 and s.model.mode==3)
now=20.1
for _,name in ipairs({'rws','exp1','exp2','exp1','exp3','rws','tws','rws'})do
 now=now+.1;track(now,true)
 s:command(name,1,true,now);s:update(pose,now,.1,true,true)
 assert(s.track_requested and s.track_sequence==request,'view change canceled the GMT measurement owner')
 assert(get('F22_AG_TRACK_ID')==42 and get('F22_AG_TRACK_VALID')==1)
 assert(get('F22_AG_DESIGNATION_VALID')==1 and get('F22_AG_DESIGNATION_NORTH')>6000)
end
track(now+.1,false);s:update(pose,now+.1,.1,true,true)
assert(get('F22_AG_TRACK_VALID')==0 and get('F22_AG_DESIGNATION_VALID')==0,'lost native track gained authority from imagery')
-- Real bezel action contract supplies the existing selected-box renderer.
put('HUD_MODE',7);put('F22_AG_EXPANSION',2);put('F22_AG_FAST_AVAILABLE',1);put('F22_AG_FAST',1)
put('F22_AG_OPTIONS_AVAILABLE',1);put('F22_AG_EXP1_AVAILABLE',1)
local C=dofile(SCRIPT_ROOT..'Systems/MFD_Controls.lua')
local P=dofile(SCRIPT_ROOT..'Systems/Display_Routing.lua').pages
local keys=C.for_page(P.tsd,0,get)
assert(keys[19].label=='FAST'and keys[19].selected)
assert(keys[4].label=='EXP2'and keys[4].selected)
assert(keys[1].label=='MAP'and keys[1].command==10601)
put('F22_AG_FAST',0);assert(not C.for_page(P.tsd,0,get)[19].selected)
put('F22_AG_EXPANSION',0);put('F22_AG_FAST_AVAILABLE',0);put('F22_AG_INTL_AVAILABLE',1)
keys=C.for_page(P.tsd,0,get)
assert(keys[2].label=='GMT'and keys[19].label=='INTL')
for _,view in ipairs({0,2,3})do
 for i,spec in ipairs({{'MAP',10601},{'GMT',10602},{'EXP1',10646},{'EXP2',10647},{'EXP3',10648}})do
  local key=C.for_page(P.tsd,view,get)[i]
  assert(key.label==spec[1]and key.command==spec[2],'top row changed or required a submenu')
 end
end
''')
print('Ground owner: EXP1/2/1/3/MAP retains designation, GMT/MAP retains native target authority, clear/loss withdraw, FAST/EXP selected boxes and direct MAP key PASS')
