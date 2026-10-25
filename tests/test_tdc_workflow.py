"""Actual TDC-over-plot flow, including attitude and retained multi-target scans."""
from pathlib import Path
from lupa.lua51 import LuaRuntime
ROOT=Path(__file__).resolve().parents[1]
lua=LuaRuntime()
lua.globals().ROOT=(ROOT/'Cockpit/Scripts/Systems').as_posix()+'/'
lua.execute('''
local C=dofile(ROOT..'Radar_Computer.lua')
local D=dofile(ROOT..'Radar_Display.lua')
for _,pitch in ipairs({-20,0,25})do for _,roll in ipairs({-60,0,60})do
 local pose={north=1000,east=2000,altitude=10000,heading=math.rad(35),pitch=math.rad(pitch),roll=math.rad(roll)}
 local r=C.new();r:command('power');r:command('tws')
 local obs={}
 for i,a in ipairs({-22,20,0})do
  local o={native_id=100+i,range=i*10000,az=math.rad(a),el=math.rad(4),age=0,iff=-1}
  D.world_observation(o,pose);obs[i]=o
 end
 r:update(.05,obs,1);r:update(.05,obs,1);r:geometry(D,pose)
 for i=1,3 do
  local t=r:source(100+i);r.cursor_follow=false
  r.cursor_range,r.cursor_az=D.scope_observation(t,pose,0)
  local x,y=D.point(r.cursor_range,r.cursor_az,r:range())
  local tx,ty=D.plot(t,pose,r:range(),0)
  assert(math.abs(x-tx)<1e-9 and math.abs(y-ty)<1e-9)
  r:command('designate')
  assert(r.selected==t.id and not r.acquire,'TDC over visible symbol failed or accidentally requested STT')
  for j=1,i do assert(r:source(100+j).designated,'earlier TDC designation lost')end
  if i>1 then assert(r.secondary==r:source(99+i).id)end
  local plan=r:scan_plan({});assert(plan.obligations==i and plan.uncovered==0,'AUTO dropped an earlier designation')
 end
 local intended=r.selected;r:command('designate')
 assert(r.acquire and r.acquire_id==intended,'repeat TDC on primary must request native STT')
 r:command('next_track');assert(r.acquire_id==intended,'focus change retargeted pending acquisition')
 r:command('undesignate');assert(not r.acquire and r.selected==nil)
 for _,t in pairs(r.tracks)do assert(not t.designated)end
end end
''')
print('TDC workflow: three actual plot designations retained across nine attitudes; repeat-primary STT and immutable acquisition intent PASS')
