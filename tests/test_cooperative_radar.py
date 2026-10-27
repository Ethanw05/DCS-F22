from pathlib import Path
from lupa.lua51 import LuaRuntime

root=Path(__file__).resolve().parents[1]
lua=LuaRuntime()
lua.globals().MODULE=(root/'Cockpit/Scripts/Systems/Radar_Sensor_Tasking.lua').as_posix()
lua.globals().COMPUTER=(root/'Cockpit/Scripts/Systems/Radar_Computer.lua').as_posix()
lua.execute('''
local M=dofile(MODULE)
local function radar()
 return {power=true,mode='RWS',native_mode=1,acquire=false,
  source=function()end,age=function(_,t)return t.age or 0 end,range=function()return 80*1852 end}
end
local function cue(id,az,el,signal,age)
 return {source=id,az=math.rad(az),el=math.rad(el),signal=signal or 1,age=age or 0}
end
local function contains(p,c)
 return math.abs(p.az-c.az)<=p.half_az+1e-8 and math.abs(p.el-c.el)<=p.half_el+1e-8
end
local r=radar();local s=M.new();local c=cue(12,35,25)
local p=s:update(0,r,nil,{c},true)
assert(p.rf_cued and contains(p,c)and p.el>0 and p.az>0)
assert(p.range==r:range()and p.obligations==0,'RF bearing became a ranged track')
assert(s.status.task==2 and s.status.source==12)
local idle=M.new();idle:update(0,r,nil,{},true)
assert(idle:update(.05,r,nil,{c},true).rf_cued,'first fresh RF arrival waited an unnecessary extra background dwell')
local a,e=p.az,p.el
c.az=c.az+.0001;c.el=c.el+.0001
p=s:update(.05,r,nil,{c},true)
assert(p.az==a and p.el==e,'tiny bearing change churned native scan')
-- Bound cue dwell; keep background search alive and rotate to another cue.
local other=cue(22,-30,-20)
assert(s:update(2.01,r,nil,{c,other},true)==nil and s.status.task==1)
assert(s:update(3,r,nil,{c,other},true)==nil)
p=s:update(4.02,r,nil,{c,other},true)
assert(s.status.source==22 and contains(p,other),'RF revisit fairness starved a second source')
-- Gimbal containment applies to the whole actual scan, not just its centre.
s=M.new();c=cue(1,59,59);p=s:update(0,r,nil,{c},true)
assert(contains(p,c)and p.az+p.half_az<=M.limit+1e-8 and p.el+p.half_el<=M.limit+1e-8)
-- Explicit pilot scan edits win for their hold, without erasing the request.
s:command('elevation_down',.1);assert(s:update(.2,r,nil,{c},true)==nil)
assert(s.status.task==0);assert(s:update(7,r,nil,{c},true)==nil)
p=s:update(10,r,nil,{c},true);assert(p and p.rf_cued)
-- Hard track/support plans retain every original boundary and metric.
local base={az=0,el=0,half_az=math.rad(20),half_el=math.rad(10),range=50000,
 obligations=2,uncovered=0,support_count=1,support_overdue=0,revisit_remaining=5}
s=M.new();c=cue(5,22,3)
p=s:update(0,r,base,{c},true)
assert(s.status.task==3 and p.obligations==2 and p.support_count==1)
assert(p.az-p.half_az<=-base.half_az and p.az+p.half_az>=base.half_az)
assert(base.az==0 and base.half_az==math.rad(20),'soft cue mutated hard-plan hysteresis state')
base.revisit_remaining=1
assert(s:update(.1,r,base,{cue(6,40,30)},true)==base,'RF stole overdue support dwell')
base.revisit_remaining=5;s:command('vertical_span',.2)
assert(s:update(.3,r,base,{c},true)==base,'RF enlargement ignored pilot hold')
for _,state in ipairs({'acquire','stt','acm','off','disabled'})do
 s=M.new();r=radar()
 if state=='acquire'then r.acquire=true elseif state=='stt'then r.native_mode=3
 elseif state=='acm'then r.mode='VACQ'elseif state=='off'then r.power=false end
 assert(s:update(0,r,nil,{c},state~='disabled')==nil,state..' was overridden')
end
-- Confirmed fresh radar files do not waste an RF discovery dwell.
r=radar();r.source=function()return {hits=2,age=0}end
s=M.new();assert(s:update(0,r,nil,{c},true)==nil)
r.source=function()return {hits=2,age=3}end
assert(s:update(3,r,nil,{c},true).rf_cued,'coasting local track never regained discovery time')
-- Complete RF publication, age and class gates, with world/body reprojection.
local v={F22_TACTICAL_SEQUENCE=1,F22_TACTICAL_TIME=10}
local q='F22_TACTICAL_01_'
for k,x in pairs({VALID=1,SOURCE=7,RF_AGE=0,RF_SIGNAL=2,RF_GENERAL=1,
 AFFILIATION=-1,RF_DIRECTION_VALID=1,RF_WORLD_N=1,RF_WORLD_U=0,RF_WORLD_E=0})do v[q..k]=x end
local function get(k)return v[k]or 0 end
local pose={heading=0,pitch=math.rad(20),roll=0}
local cues=M.read(get,10,pose)
assert(#cues==1 and math.abs(cues[1].el+math.rad(20))<1e-8,'RF elevation not transformed into radar body frame')
pose={heading=math.rad(30),pitch=0,roll=math.rad(45)}
cues=M.read(get,10,pose)
assert(#cues==1 and cues[1].az<0 and cues[1].el<0,'ownship heading/roll sign mismatch')
for _,general in ipairs({0,2,3,4})do v[q..'RF_GENERAL']=general;assert(#M.read(get,10,pose)==0)end
v[q..'RF_GENERAL']=1
for _,id in ipairs({1,3})do v[q..'AFFILIATION']=id;assert(#M.read(get,10,pose)==0)end
v[q..'AFFILIATION']=-1;v[q..'RF_AGE']=3.5
assert(#M.read(get,10.1,pose)==0,'frozen publication renewed RF warning age')
v[q..'RF_AGE']=0;assert(#M.read(get,10.3,pose)==0,'stale producer used for search cue')
local reads=0;local function torn(k)
 if k=='F22_TACTICAL_SEQUENCE'then reads=reads+1;return reads end;return get(k)
end
assert(#M.read(torn,10,pose)==0,'torn sensor snapshot steered radar')
v[q..'RF_DIRECTION_VALID']=0;assert(#M.read(get,10,pose)==0,'uncompensated RF direction steered radar')
-- RWS selected files and missile support outrank soft discovery.
local C=dofile(COMPUTER);r=C.new();r:command('power')
assert(r:scan_plan({})==nil,'empty RWS replaced the pilot search volume')
r:update(.05,{{native_id=31,range=20000,az=.1,el=.1,age=0,iff=-1}},1)
r.selected=1
local mandatory=r:scan_plan({31})
assert(mandatory.obligations==1 and mandatory.support_count==1 and mandatory.uncovered==0)
s=M.new();p=s:update(r.clock,r,mandatory,{cue(66,-50,-30)},true)
assert(s.status.task==3 and p==mandatory,'unconfirmed support was displaced by RF cue')
-- Genuine observations may be delivered after their discovery dwell ended.
r=C.new();r:command('power');r.clock=1
local commanded={az=.4,el=.4,half_az=.1,half_el=.1,range=80000,rf_cued=true}
r:set_effective_scan(commanded,1);r:set_effective_scan(nil,3);r.clock=3.1
local late={native_id=99,north=10000,east=4000,altitude=4000,range=12000,
 az=.4,el=.4,age=.3,observed=2.8}
assert(r:inside(late),'late real radar observation lost after RF dwell')
late.observed=.5;assert(not r:inside(late),'observation predating RF dwell bypassed search gate')
r:reset();late.observed=2.8;assert(not r:inside(late),'power/reset retained RF observation permission')
print('Cooperative radar tasking: RF elevation/width, fairness, search budget, hard support, manual authority, frames and freshness PASS')
''')
