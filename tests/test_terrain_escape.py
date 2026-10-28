"""Two-path analytic terrain checks; these do not qualify aircraft performance."""
from pathlib import Path
from lupa.lua51 import LuaRuntime
import time
lua=LuaRuntime()
root=Path(__file__).resolve().parents[1]
lua.globals().ROOT=(root/'Cockpit/Scripts').as_posix()+'/'
started=time.perf_counter()
lua.execute('''
LockOn_Options={script_path=ROOT}
local E=dofile(ROOT..'Systems/Terrain_Escape.lua')
local function state()
 return {now=0,n=0,u=1200,e=0,vn=200,vu=-120,ve=0,cas=200,nz=1,heading=0,roll=math.rad(80),fcs_valid=true,fcs_fault=false}
end
local flat=function()return 0 end
for _,side in ipairs({-1,1})do
 local engine=E.new();local spoken=false;local s=state();s.roll=s.roll*side
 for altitude=1800,40,-20 do
  s.u=altitude;s.now=(1800-altitude)/120
  local r=engine:update(s,flat)
  assert(r.valid and #r.paths==2 and r.paths[1].name=='level'and r.paths[2].name=='oblique')
  if r.threat then
   assert(r.paths[1].impact and r.paths[2].impact and r.no_escape)
   assert(r.mode==0 and r.call==(side==1 and 'roll_left'or'roll_right'),'unsafe boundary replaced required roll with PULL UP')
   spoken=true
  end
  assert(r.queries<=E.max_queries)
 end
 assert(spoken,'continuous descent never reached directional recovery')
end
local s=state();s.u=200;local snap=E.solve(s,flat)
assert(snap.threat and snap.mode==1 and snap.call=='pull_up','equal snapshot onsets choose oblique')
s=state();s.u=2000;assert(not E.solve(s,flat).threat)
s.u=400;s.vu=120;assert(not E.solve(s,flat).threat)
for _,bank in ipairs({-30,0,30})do
 s=state();s.u=80;s.vu=0;s.roll=math.rad(bank);s.nz=1/math.cos(s.roll)
 assert(not E.solve(s,flat).threat,'stable low flight generated nuisance warning')
end
s=state();s.vn=0;s.vu=-250;s.u=400;s.roll=0
assert(E.solve(s,flat).threat,'vertical dive lost terrain protection')
s=state();s.u=80;s.vn=140;s.cas=140;s.vu=-8;s.roll=0;s.gear=true;s.approach=true
assert(E.solve(s,flat).landing and not E.solve(s,flat).threat)
s.approach=false;assert(not E.solve(s,flat).landing,'gear alone inhibited terrain protection')
s.approach=true;assert(E.solve(s,function(n)if n>500 then return 1500 end return 0 end).threat)
s=state();assert(not E.solve(s,function()return 0/0 end).valid)
s.cas=0;assert(not E.solve(s,flat).valid)
s=state();s.nz=0/0;assert(not E.solve(s,flat).valid)
local engine=E.new();s=state();local calls=0
local height=function()calls=calls+1;return 0 end
local r=engine:update(s,height);local count=calls
s.now=.05;assert(engine:update(s,height)==r and calls==count)
s.now=.21;engine:update(s,height);assert(calls>count)
s.now=.22;s.cas=0;assert(not engine:update(s,height).valid)
s.cas=200;s.now=.23;assert(engine:update(s,height).valid)
assert(not engine:update(s,nil).valid)
s.now=0;assert(engine:update(s,height).valid)
-- Six-scalar native terrain visibility catches obstacles between samples.
local ridge=801.123
local thin=function(n)if n>=ridge and n<=ridge+.001 then return 3000 end return 0 end
local function visible(n1,u1,e1,n2,u2,e2)
 if (n1-ridge)*(n2-ridge)<=0 and n1~=n2 then
  local f=(ridge-n1)/(n2-n1);return u1+(u2-u1)*f>3000
 end
 return true
end
s=state();s.vu=0;s.roll=0;s.u=500
assert(not E.solve(s,thin).threat)
assert(E.solve(s,thin,nil,visible).threat,'segment obstacle was missed')
assert(not E.solve(s,flat,nil,function()return 'unknown'end).valid)
''')
print(f'Terrain: continuous mirrored descents retain roll through unsafe paths, two-path gate, approach, vertical dive, cache and rays PASS ({time.perf_counter()-started:.2f}s)')
