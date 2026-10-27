"""Bearing-only ground estimates: observability, reception timing and lifecycle."""
from pathlib import Path
from lupa.lua51 import LuaRuntime

root = Path(__file__).resolve().parents[1]
lua = LuaRuntime()
lua.globals().MODULE = (root / 'Cockpit/Scripts/Systems/EW_Geolocation.lua').as_posix()
lua.execute(r'''
local M=dofile(MODULE)
local target={n=20000,u=50,e=3000}
local function position(t)return {n=250*t,u=3000,e=3*t*t}end
local function direction(p,t)
 local n,u,e=t.n-p.n,t.u-p.u,t.e-p.e
 local r=math.sqrt(n*n+u*u+e*e);return {n/r,u/r,e/r}
end
local function sample(t,p)
 local q=position(t);p=p or q
 return {n=p.n,u=p.u,e=p.e,time=t,direction=direction(p,target)}
end
local samples={}
for i=0,30 do samples[#samples+1]=sample(i*1.5)end
local fix=assert(M.solve(samples),'observable turning path did not yield a fix')
assert(math.abs(fix.n-target.n)<.001 and math.abs(fix.u-target.u)<.001 and math.abs(fix.e-target.e)<.001)
assert(fix.radius>0 and fix.radius<=M.max_radius and fix.samples==31)
assert(M.current(fix,45)and not M.current(fix,51.01)and not M.current(fix,44.9))
local relative=assert(M.relative(fix,45.1,position(45.1)))
assert(math.abs(relative.radius-fix.radius-3)<1e-6 and relative.range>500 and math.abs(relative.age-.1)<1e-6)
local malformed={};for k,v in pairs(fix)do malformed[k]=v end
malformed.radius=0/0;assert(not M.current(malformed,45))
malformed.radius=1;malformed.samples=0;assert(not M.current(malformed,45))
-- No position truth, terrain API or active range is supplied anywhere above.
-- Short, straight, repeated-position and near-parallel observations stay bearing-only.
local straight={};for i=0,20 do straight[#straight+1]=sample(i*1.5,{n=i*375,u=3000,e=0})end
local no,reason=M.solve(straight);assert(not no and reason=='maneuver')
local stationary={};for i=0,20 do stationary[#stationary+1]=sample(i*1.5,position(0))end
assert(not M.solve(stationary))
assert(not M.solve({samples[1],samples[2],samples[3],samples[4]}))
local far={};for i=0,30 do
 local s=sample(i*1.5);s.direction=direction(s,{n=280000,u=50,e=3000});far[#far+1]=s
end
assert(not M.solve(far),'poor parallax/uncertainty manufactured a distant fix')
local bad={};for i,s in ipairs(samples)do bad[i]=s end
bad[5]={n=0,u=3000,e=0,time=6,direction={0/0,0,0}}
assert(not M.solve(bad),'invalid ray reached the matrix solve')
bad[5]=samples[4];assert(not M.solve(bad),'replayed reception counted as an independent ray')
-- The old prototype retained only ~1.65 s of a continuous 20-Hz stream;
-- exercise the real owner at that rate, including a delayed RF reception.
for _,delay in ipairs({0,.2})do
 local owner=M.new();local count=0;local final
 for i=0,900 do
  local now=i*.05;local stamp=now-delay
  local c={source=7,general=2,bearing_compensated=true}
  owner:update(now,position(now),{c},{[7]={stamp=stamp,world=direction(position(stamp),target)}},true)
  if c.geolocation then count=count+1;final=c.geolocation end
 end
 assert(count>0 and final,'continuous input never accumulated the required time/baseline')
 assert(math.abs(final.n-target.n)<.02 and math.abs(final.e-target.e)<.02,'reception used current ownship position')
 assert(#owner.tracks[7].samples<=M.max_samples and #owner.history<=922)
 local last=owner.tracks[7].samples[#owner.tracks[7].samples]
 -- A new ray contradicts the fix before the next decimated fit is due.
 local c={source=7,general=2,bearing_compensated=true}
 owner:update(45.05,position(45.05),{c},{[7]={stamp=45.05,world={-1,0,0}}},true)
 assert(not c.geolocation and c.geolocation_status~=4,'contradicting evidence retained the fix')
 owner:update(45.10,position(45.10),{c},{},false)
 assert(next(owner.tracks)==nil and #owner.history==0 and c.geolocation_status==0)
end
-- Aircraft, ships, weapons and unqualified bearings must never enter this model.
for _,general in ipairs({0,1,3,4})do
 local s=M.new();local c={source=1,general=general,bearing_compensated=true}
 for i=0,900 do local t=i*.05;s:update(t,position(t),{c},{[1]={stamp=t,world=direction(position(t),target)}},true)end
 assert(not c.geolocation and not next(s.tracks))
end
local owner=M.new();local c={source=1,general=2,bearing_compensated=false}
owner:update(0,position(0),{c},{[1]={stamp=0,world={1,0,0}}},true);assert(not next(owner.tracks))
c.bearing_compensated=true
for i=0,900 do local t=i*.05;owner:update(t,position(t),{c},{[1]={stamp=t,world=direction(position(t),target)}},true)end
assert(c.geolocation)
-- A stopped emitter expires; frozen timestamps cannot create new geometry.
local old=owner.tracks[1].received
for i=1,125 do local t=45+i*.05;owner:update(t,position(t),{c},{[1]={stamp=old,world=direction(position(old),target)}},true)end
assert(not c.geolocation)
owner:update(1,position(1),{c},{[1]={stamp=1,world=direction(position(1),target)}},true)
assert(not c.geolocation and #owner.history==1,'rewind kept prior geometry')
owner:update(1.05,{n=1e6,u=3000,e=0},{c},{[1]={stamp=1.05,world={1,0,0}}},true)
assert(not c.geolocation and #owner.history==1,'teleport kept prior geometry')
owner:update(2,position(2),{c},{[1]={stamp=2,world={1,0,0}}},true)
assert(#owner.history==1,'activity gap kept geometry')
assert(not M.position({getSelfCoordinates=function()error('no sensor')end}))
assert(not M.position({getSelfCoordinates=function()return 0/0,1,2 end}))
''')
print('Passive geolocation: observable-only fit, continuous/delayed reception, bounds, freshness, contradiction, taxonomy and reset PASS')
