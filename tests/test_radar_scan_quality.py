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

with contextlib.redirect_stdout(io.StringIO()):
    runtime = runpy.run_path(str(ROOT / "tests/test_display_startup.py"))["runtime"]
lua = runtime()
lua.execute(r'''
local now=0
local pose={north=0,east=0,altitude=0,heading=0,pitch=0,roll=0}
function get_model_time() return now end
function get_base_data() return {
 getSelfCoordinates=function() return pose.north,pose.altitude,pose.east end,
 getHeading=function() return (2*math.pi-pose.heading)%(2*math.pi) end,
 getPitch=function() return pose.pitch end,getRoll=function() return pose.roll end} end
native={set_power=function() end};function GetDevice() return native end
dofile(SCRIPT_ROOT..'Systems/Radar_System.lua');post_initialize()
local d=dofile(SCRIPT_ROOT..'Systems/Radar_Display.lua')
local function put(n,v) get_param_handle(n):set(v) end
local function val(n) return get_param_handle(n):get() end
local obs={}
local function contact(id,a,e,r)
 local o={range=r or 20000,az=math.rad(a),el=math.rad(e)}
 d.world_observation(o,pose);o.id=id;o.stamp=now;obs[#obs+1]=o
end
local function tick()
 now=now+.05
 put('F22_RADAR_OBSERVATIONS_READY',1);put('F22_RADAR_OBSERVATION_COUNT',#obs)
 for i,o in ipairs(obs) do
  local p=string.format('F22O_%02d_',i)
  for k,v in pairs({ID=o.id,AGE=now-o.stamp,NORTH=o.north,EAST=o.east,ALTITUDE=o.altitude,
   VN=0,VU=0,VE=0,IFF=o.friend or -1}) do put(p..k,v) end
 end
 update()
end
put('MAIN_POWER',1);put('F22N_RADAR_MODE',1);put('EFM_HUD_VALID',1);put('EFM_HUD_VN',200)
SetCommand(10602,1)
contact(101,-20,0);contact(202,20,0);contact(303,-50,5);obs[1].friend=1
put('F22_MSL_01_TARGET',303);put('F22_MSL_01_SUPPORT_REQUIRED',1)
tick();for _,o in ipairs(obs) do o.stamp=now end;tick()
SetCommand(10618,1)
for i=1,20 do SetCommand(10613,1) end
SetCommand(10628,1);tick()
assert(val('F22_RADAR_SCAN_OBLIGATIONS')==3 and val('F22_RADAR_SCAN_UNCOVERED')==0)
assert(val('F22_RADAR_SCAN_AUTO')==1 and val('F22_RADAR_SCAN_COVERAGE_COMPLETE')==1)
assert(val('F22_RADAR_SELECTED_QUALITY')==2 and val('F22_RADAR_SELECTED_HITS')==2)
assert(val('F22_RADAR_SELECTED_SUPPORT_ELIGIBLE')==1 and val('F22_RADAR_SECONDARY_VALID')==1)
assert(val('F22_TWS_TARGET_ID')==101 and val('F22_TWS_ACTIVE')==1,'native adapter contract changed')
-- Time advances but the measurement stamps do not. A normal three-second
-- revisit gap retains closure; a fourteen-second gap retains designation only.
for i=1,60 do tick() end
assert(val('F22_RADAR_SELECTED_CLOSURE_VALID')==1,'one-second closure cutoff survived')
for i=1,220 do tick() end
assert(val('F22_RADAR_SELECTED_HITS')==2 and val('F22_RADAR_SELECTED_QUALITY')==3)
assert(val('F22_RADAR_SELECTED_SUPPORT_ELIGIBLE')==0 and val('F22_RADAR_SELECTED_CLOSURE_VALID')==0)
assert(val('F22_RADAR_DESIGNATION_VALID')==1 and val('F22_RADAR_SECONDARY_VALID')==1,
 '10-second display gates contradicted the 20-second TWS memory')
assert(val('F22_TWS_TARGET_AGE')>14,'adapter age was reset by a cached echo')
-- A delayed Lua callback must use elapsed model time rather than one nominal tick.
now=now+3;tick()
assert(val('F22_RADAR_SELECTED_AGE')>17,'callback cadence hid a real measurement gap')
local paused_age=val('F22_RADAR_SELECTED_AGE')
for i=1,5 do update() end
assert(val('F22_RADAR_SELECTED_AGE')==paused_age,'paused model clock aged a track')
-- Current body geometry: turn away from an old in-volume bearing. Scope validity
-- must follow current LOS rather than the azimuth from the old observation.
pose.heading=math.rad(90);tick()
assert(val('F22_SCOPE_01_VALID')==0,'old body azimuth kept off-gimbal target visible')
put('F22_MSL_02_TARGET',999);put('F22_MSL_02_SUPPORT_REQUIRED',1);tick()
assert(val('F22_RADAR_SCAN_COVERAGE_COMPLETE')==0 and val('F22_RADAR_SCAN_UNCOVERED')>=1)
-- Reject and provide a real timestamped STT measurement in a new frame.
SetCommand(10609,1);pose.heading=0;tick()
obs={};put('F22N_RADAR_MODE',3);put('F22N_RADAR_STT_RANGE',8000)
put('F22N_RADAR_STT_AZIMUTH',0);put('F22N_RADAR_STT_ELEVATION',0)
put('F22N_RADAR_STT_FRIENDLY',0);put('F22_STT_MOTION_VALID',0);tick()
assert(val('F22_RADAR_SELECTED_QUALITY')==0 and val('F22_SCOPE_01_SOURCE')==0,
 'unknown STT inherited prior TWS source/quality: '..val('F22_RADAR_SELECTED_QUALITY')..' / '..val('F22_SCOPE_01_SOURCE'))
assert(val('F22_RADAR_SELECTED_FRIENDLY')==0,'new lock inherited previous friendly designation')
put('F22_STT_MOTION_VALID',1);put('F22_STT_ID',909);put('F22_STT_TIME',now)
put('F22_STT_PN',0);put('F22_STT_PU',800);put('F22_STT_PE',10000)
put('F22_STT_VN',0);put('F22_STT_VU',0);put('F22_STT_VE',0)
tick();local hits=val('F22_RADAR_SELECTED_HITS')
for i=1,5 do tick() end
assert(val('F22_RADAR_SELECTED_HITS')==hits,'STT cache reread counted as another hit')
assert(val('F22_RADAR_SELECTED_AGE')>.25 and val('F22_RADAR_SCAN_AUTO')==0)
assert(val('F22_SCOPE_01_VALID')==0,'STT polar cache overrode current world geometry')
put('MAIN_POWER',0);tick()
assert(val('F22_RADAR_SELECTED_VALID')==0 and val('F22_RADAR_SELECTED_SUPPORT_ELIGIBLE')==0)
assert(val('F22_RADAR_SCAN_AUTO')==0)
''')
print("Actual radar owner: missile inputs, native adapter contract, real age gates, current geometry, timestamped STT and power-off OK")

lua = runtime()
lua.execute(r'''
local now=0
function get_model_time() return now end
native={set_power=function() end};function GetDevice() return native end
dofile(SCRIPT_ROOT..'Systems/Radar_System.lua');post_initialize()
local function put(n,v) get_param_handle(n):set(v) end
local function val(n) return get_param_handle(n):get() end
put('MAIN_POWER',1);put('F22N_RADAR_MODE',1)
put('F22_RADAR_OBSERVATIONS_READY',1);put('F22_RADAR_OBSERVATION_COUNT',32)
SetCommand(10602,1)
for frame=1,2 do
 now=now+.05
 for i=1,32 do
  local p=string.format('F22O_%02d_',i)
  for k,v in pairs({ID=1000+i,AGE=0,NORTH=20000,EAST=i*20,ALTITUDE=0,VN=0,VU=0,VE=0,IFF=-1}) do put(p..k,v) end
 end
 update()
end
put('F22_MSL_08_TARGET',1032);put('F22_MSL_08_SUPPORT_REQUIRED',1);now=now+.05;update()
assert(val('F22_SUPPORT_01_ID')==1032,'24-slot snapshot discarded an in-flight support obligation')
assert(val('F22_RADAR_SCAN_OBLIGATIONS')==1 and val('F22_RADAR_SCAN_UNCOVERED')==0)
-- An engine model-time rewind clears mission-local files and identity metadata.
now=0;put('F22_RADAR_OBSERVATION_COUNT',0);update()
assert(val('F22_RADAR_TRACK_COUNT')==0 and val('F22_RADAR_SELECTED_QUALITY')==0)
assert(val('F22_TWS_TARGET_ID')==0)
''')
print("Dense scope: in-flight source gets support-slot priority; model-time rewind clears old files OK")

for side in (-1, 1):
    lua = runtime()
    lua.globals().EAST_SIDE = side * 8000
    lua.execute(r'''
local now=0
function get_model_time() return now end
function get_base_data() return {
 getSelfCoordinates=function() return 0,0,0 end,getHeading=function() return 0 end,
 getPitch=function() return 0 end,getRoll=function() return 0 end} end
native={set_power=function() end};function GetDevice() return native end
dofile(SCRIPT_ROOT..'Systems/Radar_System.lua');post_initialize()
local function put(n,v) get_param_handle(n):set(v) end
local function val(n) return get_param_handle(n):get() end
put('MAIN_POWER',1);put('F22N_RADAR_MODE',1);SetCommand(10602,1)
put('F22_RADAR_OBSERVATIONS_READY',1);put('F22_RADAR_OBSERVATION_COUNT',1)
for i=1,3 do
 now=now+.05
 for k,v in pairs({ID=321,AGE=0,NORTH=20000,EAST=EAST_SIDE,ALTITUDE=0,VN=0,VU=0,VE=0,IFF=-1}) do
  put('F22O_01_'..k,v)
 end
 put('F22_MSL_01_TARGET',321);put('F22_MSL_01_SUPPORT_REQUIRED',1);update()
end
local rotation=val('F22N_SCAN_ZONE_ORIGIN_AZIMUTH')
assert(rotation*EAST_SIDE<0,'AUTO scan beam steered away from its support target')
assert(math.abs(-rotation-math.atan2(EAST_SIDE,20000))<1e-6,'physical AUTO beam center differs from target LOS')
''')
print("Native AUTO beam rotation: asymmetric support targets on both sides steer toward their actual LOS OK")

# A target not yet observed cannot steer a narrow AUTO pattern.
fresh=LuaRuntime()
fresh.globals().MODULE=(ROOT / "Cockpit/Scripts/Systems/Radar_Computer.lua").as_posix()
fresh.execute("""
local r=dofile(MODULE).new();r:command('power');r:command('tws');r.vertical_span=20
assert(r:scan_plan({}).half_el>=math.rad(10),'TWS initial search dropped pilot elevation volume')
""")
