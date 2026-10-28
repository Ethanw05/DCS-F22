"""Actual AESA mailbox/controller, acquisition, display and engagement consumers."""
from pathlib import Path
import runpy
root=Path(__file__).resolve().parents[1]
lua=runpy.run_path(str(root/'tests/test_display_startup.py'))['runtime']()
lua.execute("""
now=10
function get_model_time() return now end
function p(n,v)get_param_handle(n):set(v)end
function g(n)return get_param_handle(n):get()end
function GetDevice() error('owned radar must never call a mechanical device') end
p('MAIN_POWER',1);p('HUD_MODE',2);p('F22_SOI',2);p('PMFD_FORMAT',2)
p('F22_AESA_DRIVER_READY',1)
dofile(SCRIPT_ROOT..'Systems/Radar_System.lua');post_initialize();update()
assert(g('F22_AESA_REQUEST')==1 and g('F22_AESA_CONTROL_EMIT')==1)
assert(#actions==0,'radar sent a native sensor command')
function report(stamp,hits)
 p('F22_AESA_READY',1);p('F22_AESA_SEQUENCE',4);p('F22_AESA_TIME',now)
 p('F22_AESA_GENERATION',1)
 for k,v in pairs({VALID=1,ID=42,TIME=stamp,N=10000,U=0,E=0,VN=-200,VU=0,VE=0,
 ASSOCIATION_VALID=1,VELOCITY_VALID=1,HITS=hits,RANGE_SIGMA_M=30,ANGLE_SIGMA_RAD=.001,
 FILTER_VALID=1,POSITION_SIGMA_M=20,VELOCITY_SIGMA_MPS=10})do p('F22A_01_'..k,v)end
end
now=10.1;report(now,1);update()
assert(g('F22_RADAR_TRACK_COUNT')==1)
assert(g('F22_SCOPE_01_HITS')==1)
now=10.2;p('F22_AESA_TIME',now);update()
assert(g('F22_SCOPE_01_HITS')==1,'reread of measured cache fabricated a second hit')
now=10.3;report(now,2);update()
assert(g('F22_SCOPE_01_HITS')==2)
-- ACM chooses the owned report; hard acquisition needs a later measurement.
SetCommand(10605,1);update()
assert(g('F22_AESA_PRIORITY_01')==42)
assert(g('F22_RADAR_STT_VALID')==0)
now=10.4;report(now,3);update()
assert(g('F22_RADAR_STT_VALID')==1 and g('F22_STT_ID')==42)
assert(g('F22_STT_MOTION_VALID')==1 and g('F22_RADAR_STT_MEASUREMENT_SOURCE')==2)
assert(g('F22_AESA_CONTROL_TARGET')==42)
assert(g('F22_STT_PN')==10000 and g('F22_STT_VN')==-200)
assert(#actions==0)
-- Other reports keep updating while the selected source has a priority lock.
for k,v in pairs({VALID=1,ID=84,TIME=now,N=12000,U=0,E=100,VN=-180,VU=0,VE=0,
 ASSOCIATION_VALID=1,VELOCITY_VALID=1,HITS=2,RANGE_SIGMA_M=30,ANGLE_SIGMA_RAD=.001,
 FILTER_VALID=1,POSITION_SIGMA_M=20,VELOCITY_SIGMA_MPS=10})do p('F22A_02_'..k,v)end
now=10.5;report(now,4);p('F22A_02_TIME',now);update()
now=10.6;report(now,5);p('F22A_02_TIME',now);update()
assert(g('F22_RADAR_STT_VALID')==1 and g('F22_RADAR_TRACK_COUNT')==2)
assert(g('F22_RADAR_BACKGROUND_AVAILABLE')==1 and g('F22_RADAR_TACTICAL_02_SOURCE')==84)
p('F22_MSL_01_TARGET',84);p('F22_MSL_01_SUPPORT_REQUIRED',1);update()
assert(g('F22_AESA_PRIORITY_03')==84,'priority lock excluded another missile target')
local radar_update=update
p('EFM_HUD_VALID',1);p('EFM_HUD_VN',220)
dofile(SCRIPT_ROOT..'Systems/Radar_Data_Bridge.lua');post_initialize();update()
assert(g('HUD_GUN_TARGET_VALID')==1 and g('HUD_AA_TARGET_VALID')==1)
p('HUD_MODE',7);p('F22_AG_RADAR_NATIVE_READY',1);radar_update()
assert(g('F22_AESA_CONTROL_SURFACE')==1 and g('F22_RADAR_AIR_SURFACE_CONCURRENT')==1)
assert(g('F22_RADAR_TACTICAL_02_SOURCE')==84 and g('F22_AESA_PRIORITY_03')==84)
p('HUD_MODE',2);radar_update()
-- Flight-control target advice uses the same measured producer, no F22O cache.
p('F22_RADAR_WEAPON_TARGET_ID',42)
dofile(SCRIPT_ROOT..'Systems/Engagement_System.lua');post_initialize();update()
assert(g('F22_FC_TARGET_VALID')==1 and g('F22_FC_TARGET_INPUT_ID')==42)
now=11.3;update();assert(g('F22_FC_TARGET_VALID')==1) -- measured coasting policy
-- A stopped producer cannot freshen the radar owner or create an acquisition.
dofile(SCRIPT_ROOT..'Systems/Radar_System.lua');post_initialize();update()
assert(g('F22_RADAR_STT_VALID')==0 and g('F22_RADAR_TRACK_COUNT')==0)
-- Torn snapshot and bad position reject instead of crossing into tracks.
assert(g("F22_AESA_CONTROL_EMIT")==1)
p("F22A_02_VALID",0)
now=11.4;report(now,3);p('F22_AESA_SEQUENCE',5);update()
assert(g('F22_RADAR_TRACK_COUNT')==0)
p('F22_AESA_SEQUENCE',6);p('F22A_01_N',0/0);update()
assert(g('F22_RADAR_TRACK_COUNT')==0)
p('MAIN_POWER',0);update();assert(g('F22_AESA_REQUEST')==0)
""")
lua.execute("""
local state={EFM_POWER_OWNER=1,EFM_PHYSICAL_VALID=1,EFM_PHYSICAL_GENERATION=2,
 EFM_PHYSICAL_STAMP=5,EFM_PHYSICAL_CLOCK_KIND=1,F22_AP_CLOCK=5,
 EFM_MISSION_POWER_AVAILABLE=1,F22_ELECTRICAL_VALID=1,EFM_ENVIRONMENT_VALID=1,
 EFM_EQUIPMENT_TEMP_C=60,EFM_THERMAL_FAULT=0,F22_AESA_ARRAY_KNOWN=1,F22_AESA_ARRAY_HEALTH=1}
local function get(n)return state[n]or 0 end
local r=dofile(SCRIPT_ROOT..'Systems/Radar_Resource.lua').new(get)
assert(r:update(28805,true)==1 and r.power_known and r.thermal_known)
state.EFM_MISSION_POWER_AVAILABLE=0
assert(r:update(28805,true)==0,'APU-only power enabled mission radar')
state.EFM_MISSION_POWER_AVAILABLE=1;state.EFM_EQUIPMENT_TEMP_C=80
assert(r:update(28805,true)==.5)
state.EFM_THERMAL_FAULT=1;assert(r:update(28805,true)==0)
state.EFM_THERMAL_FAULT=0;state.F22_AP_CLOCK=6;assert(r:update(28806,true)==0)
state.EFM_POWER_OWNER=0;state.MAIN_POWER=1
assert(r:update(28806,true)==0,'stopped physical owner restored legacy healthy power')
""")
print('Owned AESA Lua: measured tracks, cache deduplication, acquisition, source2 STT/gun aliases, engagement, stale/torn/invalid snapshots and power PASS')
from radar_test_runtime import owned_runtime
chain=owned_runtime()
chain.execute("""
f.measure(42);f.put('F22A_01_COV_00',111);f.put('F22A_01_MEASURED_RANGE',10023);f.tick()
assert(f.get('F22_RADAR_TACTICAL_01_MEASURED_RANGE')==10023,'filtered geometry overwrote raw radar range')
f.measure(84,12000);f.put('F22A_02_COV_00',222);f.tick()
assert(f.get('F22_RADAR_TACTICAL_01_COV_00')==111)
f.put('F22A_01_VALID',0);f.now=f.now+.1;f.measure(84,11990);f.tick()
assert(f.get('F22_RADAR_TACTICAL_01_COV_00')==111,'reused sample table changed a coasting track covariance')
assert(f.get('F22_RADAR_TACTICAL_01_MEASURED_RANGE')==10023)
f.generation=2;f.tick()
assert(f.get('F22_RADAR_TRACK_COUNT')==1 and f.get('F22_RADAR_TACTICAL_01_SOURCE')==84,
 'producer generation retained an old authoritative track')
""")
