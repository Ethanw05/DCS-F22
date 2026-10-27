"""Kinematic boundaries and real-launch/multi-target engagement replay."""
from pathlib import Path
import contextlib, io, runpy

root = Path(__file__).resolve().parents[1]
with contextlib.redirect_stdout(io.StringIO()):
    runtime = runpy.run_path(str(root / 'tests/test_display_startup.py'))['runtime']

l = runtime()
l.execute('''
local m=dofile(SCRIPT_ROOT..'Systems/Weapon_Engagement.lua')
assert(math.abs(m.intercept({10000,0,0},{0,0,0},1000)-10)<1e-8)
assert(math.abs(m.intercept({10000,0,0},{-200,0,0},1000)-10000/1200)<1e-8)
assert(m.intercept({10000,0,0},{1100,0,0},1000)==nil,'faster escaping target became reachable')
assert(math.abs(m.time_to_active({5000,0,0},{-1000,0,0},2000)-3)<1e-8)
assert(m.time_to_active({5000,0,0},{1000,0,0},2000)==nil)
assert(m.time_to_active({1000,0,0},{1000,0,0},2000)==0)
assert(m.zone(700,700,20000,10000).inside)
assert(m.zone(699,700,20000,10000).too_close)
assert(not m.zone(21000,700,20000,10000).inside)
assert(m.zone(9000,700,20000,10000).turn)
assert(not m.zone(11000,700,20000,10000).turn)
assert(m.zone(1000,20000,700)==nil)
assert(m.countdown(12,100,105)==7 and m.countdown(0,100,100)==0)
assert(m.countdown(12,100,114)==nil and m.countdown(12,100,99)==nil)
assert(m.countdown(-1,100,100)==nil and m.countdown(nil,100,100)==nil)
''')

l.execute('''
now=100
function get_model_time()return now end
function get_base_data()return setmetatable({getSelfCoordinates=function()return 0,5000,0 end},
 {__index=function()return function()return 0 end end})end
local function p(n,v)get_param_handle(n):set(v)end
local function v(n)return get_param_handle(n):get()end
for n,x in pairs({MAIN_POWER=1,RADAR_PWR=1,F22_RADAR_BACKEND_READY=1,HUD_MODE=2,MASTER_ARM=1,F22_WEAPON_COUNT=6,
 F22_RADAR_WEAPON_TARGET_ID=101,F22_RADAR_OBSERVATIONS_READY=1,F22_RADAR_OBSERVATION_COUNT=2,
 F22_MISSILE_DATA_VALID=1,F22_MISSILE_NATIVE_MIN=700,F22_MISSILE_NATIVE_MAX=20000,
 F22_MISSILE_AVERAGE_SPEED=700,F22_MISSILE_LIFETIME=90,F22_DLZ_NATIVE_VALID=1,
 F22_DLZ_RMIN=700,F22_DLZ_RMAX=20000,F22_DLZ_RTR=10000,F22_DLZ_TARGET_ID=101,
 EFM_HUD_VN=220,F22_RADAR_RANGE_NM=40})do p(n,x)end
for i,id in ipairs({101,202})do
 local k=string.format('F22O_%02d_',i)
 p(k..'ID',id);p(k..'NORTH',10000);p(k..'ALTITUDE',5000);p(k..'EAST',(i-1)*1000);p(k..'VN',-200)
end
local original=dofile
function dofile(path)
 if path==SCRIPT_ROOT..'Systems/Equipment_Profile.lua'then
  return {supports=function(name)return name=='diagnostic_weapon_truth'end}
 end
 return original(path)
end
dofile(SCRIPT_ROOT..'Systems/Engagement_System.lua');post_initialize()
local engagement_update=update
function update()
 p('F22_RADAR_TACTICAL_TIME',now)
 p('F22_TWS_GUIDANCE_BACKEND_READY',1)
 p('F22_RADAR_SUPPORT_ENABLED',v('HUD_MODE')~=7 and 1 or 0)
 p('F22_SUPPORT_01_ID',101);p('F22_SUPPORT_02_ID',202)
 -- Native STT on another target cannot custom-support the first one.
 if v('F22N_RADAR_MODE')==3 then p('F22_RADAR_SUPPORT_ENABLED',0)end
 engagement_update()
end
update()
assert(v('F22_FC_SHOOT')==1 and v('F22_FC_DLZ_DYNAMIC')==1)
assert(math.abs(v('F22_FC_CLOSURE_KTS')-420*1.943844492)<1e-6)
assert(v('F22_FC_MISSILES')==0,'no launch event created a flyout')
p('F22_RADAR_SELECTED_FRIENDLY',1);update();assert(v('F22_FC_SHOOT')==0)
p('F22_RADAR_SELECTED_FRIENDLY',0);p('MASTER_ARM',0);update();assert(v('F22_FC_SHOOT')==0)
p('MASTER_ARM',1)
local function shot(slot,seq,id,target)
 local k=string.format('F22_SHOT_%02d_',slot)
 for name,x in pairs({SEQUENCE=seq,ID=id,TARGET=target,MODE=2,TIME=now,ALIVE=1,N=100,U=5000,E=0,VN=800,ACTIVE_RANGE=5000,ACTIVE=0,ACTIVE_VALID=1,SEEKER_VALID=1,SEEKER_TRACK=0,CURRENT_LOCK_VALID=1})do p(k..name,x)end
 p('F22_LAUNCH_SEQUENCE',seq)
end
shot(1,1,1001,101);update()
assert(v('F22_FC_MISSILES')==1 and v('F22_MSL_01_TARGET')==101)
assert(v('F22_MSL_01_TTG_VALID')==1 and v('F22_MSL_01_TTG_SOURCE')==2,'missing shared estimate suppressed real missile/radar fallback')
assert(v('F22_FC_TTA_VALID')==1 and v('F22_FC_TTA')>0)
assert(v('F22_MSL_01_SUPPORT_STATE')==1)
p('F22N_RADAR_MODE',3);p('F22_STT_ID',202);update()
assert(v('F22_MSL_01_SUPPORT_STATE')==2 and v('F22_FC_SUPPORT_DEGRADED')==1,'STT on another target hid support coast')
p('RADAR_PWR',0);update();assert(v('F22_MSL_01_SUPPORT_STATE')==3 and v('F22_FC_SUPPORT_LOST')==1)
p('RADAR_PWR',1);p('F22N_RADAR_MODE',1);update();assert(v('F22_MSL_01_SUPPORT_STATE')==1 and v('F22_FC_SUPPORT_DEGRADED')==0)
p('F22_RADAR_WEAPON_TARGET_ID',202);p('F22_DLZ_TARGET_ID',202);shot(2,2,1002,202);update()
assert(v('F22_FC_MISSILES')==2 and v('F22_MSL_01_TARGET')==101 and v('F22_MSL_02_TARGET')==202)
assert(v('F22_MSL_01_SUPPORT_REQUIRED')==1 and v('F22_MSL_02_SUPPORT_REQUIRED')==1)
p('HUD_MODE',7);update()
assert(v('F22_MSL_01_SUPPORT_STATE')==2,'A/G suppressed custom support but cockpit still claimed supported')
p('F22N_RADAR_MODE',3);p('F22_STT_ID',101);p('F22_STT_MOTION_VALID',1);p('F22_STT_TIME',now);update()
assert(v('F22_MSL_01_SUPPORT_STATE')==1 and v('F22_MSL_01_SUPPORT_SOURCE')==1,'qualified native STT fallback was hidden')
p('F22N_RADAR_MODE',1);p('F22_STT_MOTION_VALID',0)
p('HUD_MODE',5);update();assert(v('F22_MSL_01_TARGET')==101 and v('F22_FC_SHOOT')==0)
p('F22_SHOT_01_ACTIVE',1);update();assert(v('F22_MSL_01_SUPPORT_REQUIRED')==1,'emitting without acquisition dropped support')
p('F22_SHOT_01_SEEKER_ACQUIRED_EVER',1);p('F22_SHOT_01_CURRENT_LOCK_VALID',0);update()
assert(v('F22_MSL_01_SUPPORT_REQUIRED')==1 and v('F22_MSL_01_SELF_GUIDING')==0,'acquired-ever became continuous lock')
p('F22_SHOT_01_CURRENT_LOCK_VALID',1);p('F22_SHOT_01_SEEKER_TRACK',1);update();assert(v('F22_MSL_01_SUPPORT_REQUIRED')==0)
p('F22_SHOT_01_SEEKER_TRACK',0);update();assert(v('F22_MSL_01_SELF_GUIDING')==0,'lost current lock remained latched')
p('F22_SHOT_01_SEEKER_TRACK',1);update()
assert(v('F22_MSL_01_TTG_VALID')==1 and v('F22_MSL_01_ACTIVE')==1)
p('F22_SHOT_02_ACTIVE_RANGE',0);update();assert(v('F22_MSL_02_TTA_VALID')==0,'unknown activation distance invented a timer')
now=108;p('F22O_01_AGE',8);p('F22O_02_AGE',8);update()
assert(v('F22_FC_TARGET_VALID')==0 and v('F22_FC_SHOOT')==0)
assert(v('F22_MSL_02_TRACK_LOST')==1,'stale support remained fresh')
p('F22_SHOT_01_ALIVE',0);p('F22_SHOT_02_ALIVE',0);update()
assert(v('F22_FC_MISSILES')==0,'ended native missiles left permanent flyouts')
assert(v('F22_MSL_01_SUPPORT_REQUIRED')==0 and v('F22_MSL_02_SUPPORT_REQUIRED')==0)
-- An immediate selection of a short-life IR store cannot age an existing MRM.
now=200;p('F22_MISSILE_LIFETIME',1);p('HUD_MODE',3);p('F22O_01_AGE',0);p('F22O_02_AGE',0)
shot(3,3,1003,101);update()
now=245;update()
assert(v('F22_MSL_03_VALID')==1 and v('F22_MSL_03_SUPPORT_REQUIRED')==1,'selected IR lifetime terminated a still-live MRM')
p('F22_SHOT_03_ALIVE',0);update();assert(v('F22_MSL_03_VALID')==0)
-- New-scheme missiles do not expose an activation radius. A checked native
-- launch prediction supplies ACT without turning its expiry into acquisition.
now=300;shot(4,4,1004,101)
p('F22_SHOT_04_ACTIVE_RANGE',0);p('F22_SHOT_04_TOF_VALID',1);p('F22_SHOT_04_TOF',30)
p('F22_SHOT_04_ACT_VALID',1);p('F22_SHOT_04_ACT',10);p('F22_SHOT_04_ESTIMATE_TIME',300)
update();assert(v('F22_MSL_04_TTA_VALID')==1 and v('F22_MSL_04_TTA')==10 and v('F22_MSL_04_TTA_SOURCE')==1)
assert(v('F22_MSL_04_TTG')==30 and v('F22_MSL_04_TTG_SOURCE')==1,'initial missile speed displaced the validated trajectory estimate')
now=305;p('F22_RADAR_WEAPON_TARGET_ID',202);p('F22_SHOT_04_ACT',99);p('F22_SHOT_04_TOF',99);p('HUD_MODE',5);update()
assert(v('F22_MSL_04_TARGET')==101 and v('F22_MSL_04_TTA')==5,'launch estimate changed after target/weapon switch')
assert(v('F22_MSL_04_TTG')==25 and v('F22_MSL_04_TTG_SOURCE')==1,'airborne TOF changed after source/weapon switch')
now=312;update()
assert(v('F22_MSL_04_TTA_VALID')==0 and v('F22_MSL_04_SELF_GUIDING')==0 and v('F22_MSL_04_SUPPORT_REQUIRED')==1,'expired prediction declared active')
p('F22_SHOT_04_ACTIVE',1);update()
assert(v('F22_MSL_04_ACTIVE')==1 and v('F22_MSL_04_SELF_GUIDING')==0 and v('F22_MSL_04_SUPPORT_REQUIRED')==1)
p('F22_SHOT_04_SEEKER_TRACK',1);update()
assert(v('F22_MSL_04_SELF_GUIDING')==1 and v('F22_MSL_04_SUPPORT_REQUIRED')==0)
assert(v('F22_MSL_04_TTG')==18 and v('F22_MSL_04_TTG_SOURCE')==1,'actual activation discarded valid shared TOF')
now=332;update()
assert(v('F22_MSL_04_VALID')==1 and v('F22_FC_MISSILES')==1,'expired TOF manufactured a missile end')
assert(v('F22_MSL_04_TTG_VALID')==1 and v('F22_MSL_04_TTG_SOURCE')==2 and v('F22_MSL_04_TTG')>0,'expired shared prediction did not fall back to missile/radar geometry')
p('F22_SHOT_04_ALIVE',0);update();assert(v('F22_MSL_04_VALID')==0)
-- A native AIM-9X lock beyond 30 degrees is not vetoed by an MRM gate.
now=400;p('HUD_MODE',3);p('F22_RADAR_WEAPON_TARGET_ID',101);p('F22_DLZ_TARGET_ID',101)
p('F22O_01_NORTH',5000);p('F22O_01_EAST',6000);p('F22O_01_ALTITUDE',5000);p('F22O_01_AGE',0)
p('F22O_02_AGE',0);p('F22_IR_LOCK',1);p('F22_IR_CAGED',0);p('F22_WEAPON_COUNT',1)
update();assert(v('F22_FC_SHOOT')==1,'native HOBS lock truncated by radar-missile angle gate')
p('F22_IR_LOCK',0);update();assert(v('F22_FC_SHOOT')==0)
p('F22_IR_LOCK',1);p('F22_IR_CAGED',1);update();assert(v('F22_FC_SHOOT')==0)
-- The provider's AP clock is a different epoch from this World time. APU-only
-- main power cannot advertise SHOOT, and utility is distinct from FCS supply.
for name,value in pairs({EFM_POWER_OWNER=1,EFM_PHYSICAL_VALID=1,EFM_PHYSICAL_GENERATION=1,
 EFM_PHYSICAL_CLOCK_KIND=1,EFM_PHYSICAL_STAMP=10,F22_AP_CLOCK=10,F22_ELECTRICAL_VALID=1,
 EFM_MISSION_POWER_AVAILABLE=0,EFM_UTILITY_AVAILABLE=1,EFM_ACTUATOR_AVAILABLE=1})do p(name,value)end
p('F22_IR_CAGED',0);update()
assert(v('F22_FC_SHOOT')==0 and v('F22_FC_RELEASE_BLOCKER')==5,'APU-only power advertised release')
p('EFM_MISSION_POWER_AVAILABLE',1);p('EFM_UTILITY_AVAILABLE',0);update()
assert(v('F22_FC_SHOOT')==0 and v('F22_FC_RELEASE_BLOCKER')==3,'FCS supply bypassed failed utility')
p('EFM_ACTUATOR_AVAILABLE',0);p('EFM_UTILITY_AVAILABLE',1);update()
assert(v('F22_FC_SHOOT')==1,'FCS authority incorrectly blocked healthy utility/mission supply')
p('EFM_PHYSICAL_VALID',0);update();assert(v('F22_FC_SHOOT')==0,'invalid owned frame retained SHOOT')
p('EFM_PHYSICAL_VALID',1);update();assert(v('F22_FC_SHOOT')==1)
p('F22_IR_CAGED',1)
shot(5,5,1005,101);p('F22_SHOT_05_MODE',3);p('F22_SHOT_05_TOF_VALID',1)
p('F22_SHOT_05_TOF',25);p('F22_SHOT_05_TOF_SOURCE',2);p('F22_SHOT_05_ESTIMATE_TIME',now);p('F22_SHOT_05_LIFETIME',80)
update();assert(v('F22_FC_TIMER_MODE')==3 and v('F22_MSL_05_TTG')==25 and v('F22_MSL_05_TTG_SOURCE')==3)
assert(v('F22_MSL_05_SUPPORT_REQUIRED')==0,'IR flyout created a radar-support obligation')
now=410;p('F22_WEAPON_TYPE4',999);p('HUD_MODE',2);update()
assert(v('F22_MSL_05_TTG')==15 and v('F22_MSL_05_TTG_SOURCE')==3,'weapon switch replaced frozen descriptor prediction')
p('F22_SHOT_05_ALIVE',0);update()
''')
print('Engagement: kinematic limits, native DLZ identity, signed closure, consent, real launches, immutable targets/ACT prediction, actual seeker transition and stale/lost support PASS')

# Default profile must not promote diagnostic world state into cockpit telemetry.
other=runtime()
other.execute('''
function get_model_time()return 100 end
local function p(n,v)get_param_handle(n):set(v)end
local function g(n)return get_param_handle(n):get()end
for name,value in pairs({MAIN_POWER=1,RADAR_PWR=1,HUD_MODE=2,F22_RADAR_BACKEND_READY=1,
 F22_RADAR_OBSERVATIONS_READY=1,F22_RADAR_OBSERVATION_COUNT=1,F22_RADAR_WEAPON_TARGET_ID=101,
 F22_LAUNCH_SEQUENCE=1})do p(name,value)end
for name,value in pairs({ID=101,AGE=0,NORTH=10000,ALTITUDE=1000,EAST=0,VN=0,VU=0,VE=0})do
 p('F22O_01_'..name,value)
end
for name,value in pairs({SEQUENCE=1,ID=500,TARGET=101,MODE=2,TIME=100,ALIVE=1,
 N=1000,U=1000,E=0,VN=800,VU=0,VE=0,ACTIVE_RANGE=5000,ACTIVE=1,ACTIVE_VALID=1,
 SEEKER_VALID=1,SEEKER_TRACK=1,SEEKER_ACQUIRED_EVER=1,CURRENT_LOCK_VALID=0,STATE_SOURCE=2})do
 p('F22_SHOT_01_'..name,value)
end
dofile(SCRIPT_ROOT..'Systems/Engagement_System.lua');post_initialize();update()
assert(g('F22_FC_DIAGNOSTIC_TRUTH')==0)
assert(g('F22_MSL_01_TTG_VALID')==0 and g('F22_MSL_01_TTA_VALID')==0 and g('F22_MSL_01_PLOT_VALID')==0)
assert(g('F22_MSL_01_ACTIVE')==0 and g('F22_MSL_01_SELF_GUIDING')==0)
assert(g('F22_MSL_01_SEEKER_ACQUIRED_EVER')==1,'diagnostic evidence was erased instead of qualified')
''')
print('Engagement baseline: diagnostic world truth stays outside cockpit timers, positions and current-lock authority PASS')
