"""Scan obligations and observation-quality tests against the real Lua owners."""
from pathlib import Path
import contextlib
import io
import runpy
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
lua = LuaRuntime()
lua.globals().MODULE = (ROOT / "Cockpit/Scripts/Systems/Radar_Computer.lua").as_posix()
lua.execute(r'''
local module=dofile(MODULE)
local function radar()
 local r=module.new();r:command('power');r:command('tws');return r
end
local function observation(id,az,el,range)
 return {native_id=id,range=range or 20000,az=math.rad(az),el=math.rad(el),age=0,iff=-1}
end
local function inside(p,t)
 return math.abs(t.current_az-p.az)<=p.half_az+1e-9 and
  math.abs(t.current_el-p.el)<=p.half_el+1e-9 and t.current_range<=p.range
end
local r=radar()
r:update(.1,{observation(101,-20,0),observation(202,40,0),observation(303,-55,-5)},1)
r.selected=1;r.secondary=2
local p=r:scan_plan({303,303})
assert(p.obligations==3 and p.uncovered==0,'designation/support obligations dropped or duplicated')
for _,t in pairs(r.tracks) do assert(inside(p,t),'primary-only scan starved another target') end
assert(p.half_az>math.rad(30),'widely separated targets need a wider native volume')
local a,e,az,el=p.az,p.el,p.half_az,p.half_el
r.clock=r.clock+.1;r.tracks[1].current_az=r.tracks[1].current_az+.0001
p=r:scan_plan({303})
assert(p.az==a and p.el==e and p.half_az==az and p.half_el==el,'scan churned on a tiny motion')
-- Missile target can move outside the original 10-degree elevation slice.
r.tracks[3].current_el=math.rad(35);r.tracks[3].current_range=100*1852
p=r:scan_plan({303})
assert(p.uncovered==0 and inside(p,r.tracks[3]) and p.range>=100*1852,'support elevation/range not included')
assert(p.half_el>=math.rad(20))
-- Unknown source and off-gimbal track remain explicit uncovered obligations.
r.tracks[3].current_az=math.rad(80)
p=r:scan_plan({303,404,404})
assert(p.obligations==4 and p.uncovered==2,'unsupported targets falsely advertised covered')
assert(p.az-p.half_az>=-math.rad(60)-1e-9 and p.az+p.half_az<=math.rad(60)+1e-9)
r.tracks[3].current_az=math.rad(-55)
r.secondary=nil;r.clock=r.clock+2.1
p=r:scan_plan({})
assert(p.half_az==math.rad(30) and p.half_el==math.rad(5),'scan did not shrink after obligations ended')
-- Secondary alone must be handled when primary is absent (sparse indices).
r.selected=nil;r.secondary=2;p=r:scan_plan({})
assert(p.obligations==1 and p.uncovered==0 and inside(p,r.tracks[2]))
-- Manual elevation establishes a bounded bias without losing the obligation.
r:command('elevation_up');p=r:scan_plan({})
assert(p.el>0 and inside(p,r.tracks[2]),'manual scan bias ignored or lost target')
r:command('recenter');p=r:scan_plan({});assert(math.abs(p.el)<1e-9)
r.acquire=true;assert(r:scan_plan({303})==nil,'automatic scan interfered with native acquisition')
r.acquire=false;r.native_mode=3;assert(r:scan_plan({303})==nil,'automatic scan fought STT')

r=radar()
local o={native_id=12,range=10000,az=0,el=0,age=0,north=10000,east=0,altitude=0,
 vn=100,ve=0,vu=0,velocity_valid=true}
r:update(.1,{o},1);local t=r.tracks[1]
assert(r:quality(t)==1 and not r:supportable(t))
o.north=10100;o.range=10100;r:update(1,{o},1)
assert(t.hits==2 and r:quality(t)==2 and r:supportable(t))
assert(math.abs(t.revisit_s-1)<1e-9 and t.prediction_error_m<1e-6)
local stamp=t.observed
for i=1,140 do
 o.age=i*.1;r:update(.1,{o},1)
end
assert(t.hits==2 and math.abs(t.observed-stamp)<1e-8,'cached observation became fresh')
assert(r:quality(t)==3 and not r:supportable(t),'coast acquired weapon quality')
r:command('next_track');assert(r.selected==1,'20-second retained file lost at old 10-second gate')
r:command('designate');assert(r.acquire and r.acquire_id==1)
-- Expiring a candidate must cancel acquisition before promoting the secondary.
r.acquire_time=r.clock;r.acquire_id=1;r.selected=1
r:update(6.1,{},2)
assert(not r.acquire and r.selected==nil,'expired candidate kept a native acquisition alive')
''')
print("Scan manager: primary/secondary/support enclosure, missing targets, limits, hysteresis and bias OK")
print("Track quality: distinct observations, residuals, coast, support freshness and acquisition expiry OK")

from radar_test_runtime import owned_runtime
lua=owned_runtime()
lua.execute("""
f.command(10602,1)
local function returns()
 for _,t in ipairs({{101,-20},{202,20},{303,-50}})do
  f.measure(t[1],20000*math.cos(math.rad(t[2])),3000,20000*math.sin(math.rad(t[2])))
 end
end
returns();f.tick();returns();f.tick()
f.command(10618,1);f.tick()
for i=1,20 do f.command(10613,1)end
f.command(10628,1);f.put('F22_MSL_01_TARGET',303);f.put('F22_MSL_01_SUPPORT_REQUIRED',1);f.tick()
assert(f.get('F22_RADAR_SELECTED_HITS')==2 and f.get('F22_RADAR_SELECTED_MEASUREMENT_SOURCE')==2)
assert(f.get('F22_AESA_PRIORITY_01')==101 and f.get('F22_AESA_PRIORITY_02')==202)
assert(f.get('F22_AESA_PRIORITY_03')==303 and f.get('F22_RADAR_SECONDARY_VALID')==1)
f.tick(7)
assert(f.get('F22_RADAR_SELECTED_HITS')==2 and f.get('F22_RADAR_SELECTED_QUALITY')==3)
assert(f.get('F22_RADAR_SELECTED_SUPPORT_ELIGIBLE')==0 and f.get('F22_RADAR_DESIGNATION_VALID')==1)
local age=f.get('F22_RADAR_SELECTED_AGE');f.tick(0)
assert(f.get('F22_RADAR_SELECTED_AGE')==age)
f.pose.heading=math.rad(90);f.tick()
assert(f.get('F22_SCOPE_01_VALID')==0)
""")
print('Owned radar quality: distinct reports, two designations plus missile priority, source2, real age, pause and current geometry PASS')
lua=owned_runtime()
lua.execute("""
f.command(10602,1)
for frame=1,2 do
 for i=1,32 do f.measure(1000+i,20000,3000,i*20)end
 f.tick()
end
f.put('F22_MSL_08_TARGET',1032);f.put('F22_MSL_08_SUPPORT_REQUIRED',1);f.tick()
assert(f.get('F22_SUPPORT_01_ID')==1032 and f.get('F22_AESA_PRIORITY_10')==1032)
f.now=0;f.alive=false;f.tick()
assert(f.get('F22_RADAR_TRACK_COUNT')==0 and f.get('F22_TWS_TARGET_ID')==0)
assert(f.get('F22_AESA_CONTROL_EMIT')==1,'model rewind left the owned emitter latched off')
""")
print('Owned dense scope: support priority beyond24 visible files and generation rewind PASS')
# A target not yet observed cannot steer a narrow AUTO pattern.
fresh=LuaRuntime()
fresh.globals().MODULE=(ROOT / "Cockpit/Scripts/Systems/Radar_Computer.lua").as_posix()
fresh.execute("""
local r=dofile(MODULE).new();r:command('power');r:command('tws');r.vertical_span=20
assert(r:scan_plan({}).half_el>=math.rad(10),'TWS initial search dropped pilot elevation volume')
""")
