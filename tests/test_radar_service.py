"""Native-constrained service policy and actual Lua owner, running Lua 5.1."""
from pathlib import Path
import contextlib
import io
import runpy

ROOT = Path(__file__).resolve().parents[1]
with contextlib.redirect_stdout(io.StringIO()):
    runtime = runpy.run_path(str(ROOT / "tests/test_display_startup.py"))["runtime"]

lua = runtime(service_enabled=True)
lua.execute(r'''
local Policy=dofile(SCRIPT_ROOT..'Systems/Radar_Service_State.lua')
local function sample(id,stamp,az)
 return {native_id=id,observed=stamp,north=10000,east=0,altitude=3000,
  range=10000,az=az or 0,el=0,iff=-1,vn=0,vu=0,ve=0,velocity_valid=true}
end
local s=Policy.new()
local o=sample(12,1)
local _,n=s:update(1,{o},1,{},1,1);assert(n==0 and s.busy)
local release=s.release
_,n=s:update(1,{o},1,{},1,1);assert(n==0,'frozen time completed service')
_,n=s:update(1.03,{o},1,{},1,1);assert(n==0,'processing delay omitted')
local out;out,n=s:update(1.1,{o},1,{},1,1)
assert(n==1 and out[1].observed==1 and out[1].measurement_source==1)
for i=1,20 do _,n=s:update(1.1+i*.1,{o},1,{},1,1);assert(n==0,'cached sample re-serviced')end
local wide=Policy.new();wide:update(1,{o},1,{},1,4)
assert(wide.release>release,'larger search had unlimited processing budget')
local edge=Policy.new();edge:update(1,{sample(13,1,math.rad(55))},1,{},1,1)
assert(edge.release>release,'declared off-axis service cost absent')
local degraded=Policy.new();degraded:update(1,{o},1,{},.5,1)
assert(degraded.release>release,'partial resource loss equals healthy service')
_,n=degraded:update(1.1,{o},1,{},0,1);assert(n==0 and not degraded.busy)
_,n=degraded:update(1.2,{o},1,{},1,1);assert(n==0 and not degraded.busy,'outage replayed old evidence')
-- Rewind and callback stalls discard backlog instead of a fictitious catch-up.
s:update(2,{sample(44,2)},1,{},1,1)
_,n=s:update(1,{},0,{},1,1);assert(n==0 and not s.busy)
s:update(1,{sample(44,1)},1,{},1,1)
_,n=s:update(5,{},0,{},1,1);assert(n==0 and not s.busy)
-- Full queue has a declared overflow; churn cannot displace retained jobs.
s=Policy.new();local batch={};for i=1,64 do batch[i]=sample(i,1)end
s:update(1,batch,64,{},1,1)
s:update(1.01,{sample(100,1.01)},1,{},1,1)
assert(s.dropped==1 and #s.slots==64)
-- Support has priority; one in four starts still services discovery.
s=Policy.new();batch={sample(1,1),sample(2,1)}
local priorities={[1]=3}
s:update(1,batch,2,priorities,1,1);assert(s.job.native_id==1)
local served_background=false
for i=1,8 do
 local t=1+i*.1
 local result,count=s:update(t,{sample(1,t),sample(2,t)},2,priorities,1,1)
 if count==1 and result[1].native_id==2 then served_background=true end
end
assert(served_background,'support churn starved all background service')
-- Bad provider input never yields a contact or a healthy zero measurement.
for _,bad in ipairs({0/0,math.huge,-1})do
 _,n=s:update(2,{},bad,{},1,1);assert(n==0 and not s.busy)
end
o=sample(9,3);o.north=0/0
_,n=s:update(3,{o},1,{},1,1);assert(n==0 and not s.busy)
-- Core recurring work reuses all buffers, even with a stopped test collector.
s=Policy.new();local empty,priority={},{}
collectgarbage('collect');collectgarbage('stop')
local before=collectgarbage('count');local started=os.clock()
for i=1,10000 do s:update(10+i*.01,empty,0,priority,1,1)end
local elapsed=os.clock()-started;local growth=collectgarbage('count')-before
collectgarbage('restart')
assert(growth<16,'service core allocated recurring buffers: '..growth)
print(string.format('Service core: 10000 updates %.4fs; stopped-GC heap growth %.3f KiB',elapsed,growth))
''')
print("Service: distinct timestamps, finite work/processing, load, off-axis cost, resource loss, fairness, overflow and resets PASS")

# Production sensing/processing now lives in C++ AesaRadar; owner acquisition,
# source2 and stale publication are covered by test_owned_aesa_lua.py.
lua = runtime(service_enabled=True)
lua.execute(r'''
local v={F22_RADAR_RESOURCE_SCHEMA=1,F22_RADAR_RESOURCE_SEQUENCE=2,F22_RADAR_RESOURCE_TIME=1,
 F22_RADAR_RESOURCE_VALID=1,F22_RADAR_RESOURCE_SUPPLY=1,F22_RADAR_RESOURCE_COOLING=.6,F22_RADAR_RESOURCE_ARRAY=.8}
local function get(n)return v[n]or 0 end
local a=dofile(SCRIPT_ROOT..'Systems/Radar_Service_Adapter.lua').new()
assert(a:health(get,1,true)==.6 and a.health_known)
for _,field in ipairs({'SUPPLY','COOLING','ARRAY'})do
 for _,bad in ipairs({-1,2,0/0,math.huge})do
  local key='F22_RADAR_RESOURCE_'..field;local old=v[key];v[key]=bad
  assert(a:health(get,1,true)==0 and not a.health_known);v[key]=old
 end
end
assert(a:health(get,2,true)==0 and a:health(get,.5,true)==0)
v.F22_RADAR_RESOURCE_VALID=0;assert(a:health(get,1,true)==0)
v.F22_RADAR_RESOURCE_VALID=1;v.F22_RADAR_RESOURCE_SCHEMA=2;assert(a:health(get,1,true)==0)
v.F22_RADAR_RESOURCE_SCHEMA=1
local calls=0
local function torn(n)
 if n=='F22_RADAR_RESOURCE_SEQUENCE'then calls=calls+1;return calls end
 return get(n)
end
assert(a:health(torn,1,true)==0,'torn physical-resource publication accepted')
assert(a:health(get,1,false)==0)
''')
print("Resource adapter: missing/invalid/stale/future/unknown-schema/torn supply, cooling and damage inputs fail closed PASS")

lua = runtime()
lua.execute(r'''
local module=dofile(SCRIPT_ROOT..'Systems/Radar_Computer.lua')
local r=module.new();r.power=true;r:command('tws')
local o={native_id=1,range=10000,az=0,el=0,age=0}
r:update(.1,{o},1);r:update(1,{o},1)
assert(r:supportable(r.tracks[1]))
r:update(7,{},1);r:update(.1,{o},1)
assert(r.tracks[1].hits==1 and not r:supportable(r.tracks[1]),'reacquisition retained mature weapon authority')
r:update(.1,{o},1);assert(r:supportable(r.tracks[1]))
for i=1,1000 do r:update(.02,{o},1)end
assert(r.tracks[1].hits==module.maximum_hits)
for i=2,100 do r:update(.02,{{native_id=i,range=10000,az=0,el=0,age=0}},1)end
local count=0;for _ in pairs(r.tracks)do count=count+1 end
assert(count==64,'retained file store exceeded its declared capacity')
''')
print("Track owner: freshness-gap reacquisition, bounded hit counter and 64-file retention PASS")
