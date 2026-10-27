from pathlib import Path
import contextlib,io

repo=Path(__file__).resolve().parents[1]
fixture=repo/'tests/test_display_startup.py'
namespace={'__file__':str(fixture)}
exec(compile(fixture.read_text().split('\nfor page in ',1)[0],str(fixture),'exec'),namespace)
lua=namespace['runtime']()
lua.execute('''
local now=0;local heading,pitch,bank=0,0,0
function get_model_time()return now end
function get_base_data()return {
 getSelfCoordinates=function()return 0,3000,0 end,getHeading=function()return -heading end,
 getPitch=function()return pitch end,getRoll=function()return bank end}end
local radar={set_power=function()end};local passive={set_power=function()end}
function GetDevice(id)if id==13 then return radar elseif id==17 then return passive end end
local function p(n,v)get_param_handle(n):set(v)end
local function v(n)return get_param_handle(n):get()end
dofile(SCRIPT_ROOT..'Systems/RWR_System.lua');post_initialize()
local rf_update=update
dofile(SCRIPT_ROOT..'Systems/Radar_System.lua');post_initialize();dofile(SCRIPT_ROOT..'../../tests/legacy_measurement_fixture.lua')
local radar_update=update;local radar_command=SetCommand
assert(v('F22_TACTICAL_01_RF_DIRECTION_VALID')==0)
assert(v('F22_RADAR_RF_CUE_ACTIVE')==0,'construction invented a task')
p('MAIN_POWER',1);p('F22_RADAR_ACQ_COORDINATES_READY',1)
p('F22_RADAR_OBSERVATIONS_READY',1);p('F22N_RADAR_MODE',1)
local q='RWR_CONTACT_01_'
for k,x in pairs({SOURCE=71,TIME=0,AZIMUTH=-math.rad(35),ELEVATION=math.rad(25),
 SIGNAL=2,GENERAL_TYPE=1,UNIT_TYPE='SU-27'})do p(q..k,x)end
local function tick()
 now=now+.05;p(q..'TIME',now-.05);rf_update();radar_update()
end
tick()
assert(v('F22_TACTICAL_01_RF_DIRECTION_VALID')==1)
assert(v('F22_TACTICAL_01_RF_GENERAL')==1 and v('F22_TACTICAL_01_RANGE_VALID')==0)
assert(v('F22_RADAR_RF_CUE_ACTIVE')==1 and v('F22_RADAR_RF_CUE_SOURCE')==71)
assert(math.abs(-v('F22_AESA_CONTROL_CUE_AZ')+math.rad(35))<1e-8,'native scanner azimuth reflection missing')
assert(math.abs(v('F22_AESA_CONTROL_CUE_EL')-math.rad(25))<1e-8)
assert(v('F22_RADAR_DRAWN_COUNT')==0 and v('F22_RADAR_STT_VALID')==0,'passive cue fabricated detection/lock')
-- Same measured RF reception, but ownship turns. Search follows the fixed
-- world direction instead of freezing the old body bearing.
heading=math.rad(30)
-- A newer optical direction for the same source must not replace RF task LOS.
p('F22_MWS_PUBLISH_SEQUENCE',1);p('F22_MWS_PUBLISH_TIME',now+.05)
for k,x in pairs({VALID=1,SOURCE=71,AGE=0,AZ=-.5,EL=-.2})do p('F22_MWS_01_'..k,x)end
tick()
assert(v('F22_TACTICAL_01_DIRECTION_SOURCE')==4)
assert(math.abs(-v('F22_AESA_CONTROL_CUE_AZ')+math.rad(5))<1e-8)
-- A genuine new radar observation in the cued volume must not be rejected
-- merely because it is above the pilot's former +/-10-degree search slice.
local d=dofile(SCRIPT_ROOT..'Systems/Radar_Display.lua')
local observed={range=20000,az=math.rad(5),el=math.rad(25)}
d.world_observation(observed,{north=0,east=0,altitude=3000,heading=heading,pitch=0,roll=0})
p('F22_RADAR_OBSERVATION_COUNT',1)
for k,x in pairs({ID=71,AGE=0,NORTH=observed.north,EAST=observed.east,ALTITUDE=observed.altitude,
 VN=0,VU=0,VE=0,IFF=-1})do p('F22O_01_'..k,x)end
tick();assert(v('F22_RADAR_DRAWN_COUNT')==1,'real RF-cued radar detection discarded by old search elevation')
-- Manual scan elevation suspends RF steering without changing pilot intent.
radar_command(10614,1);tick()
assert(v('F22_RADAR_RF_CUE_ACTIVE')==0 and v('F22_RADAR_RF_MANUAL_HOLD')>7)
assert(math.abs(v('F22_AESA_CONTROL_EL')-math.rad(2))<1e-8)
-- ACM and A/G own their patterns; RF policy cannot leave a latched cue active.
radar_command(10604,1);tick();assert(v('F22_RADAR_RF_CUE_ACTIVE')==0)
p('HUD_MODE',7);tick();assert(v('F22_RADAR_RF_CUE_ACTIVE')==0 and v('F22_RADAR_SENSOR_TASK')==0)
p('HUD_MODE',2)
-- RF receiver lost/powered down: complete publication withdraws its cues.
p(q..'SOURCE',0);tick();assert(v('F22_RADAR_RF_CUE_ACTIVE')==0)
p('MAIN_POWER',0);tick();assert(v('RADAR_PWR')==0 and v('F22_RADAR_RF_CUE_ACTIVE')==0)
for _,action in ipairs(actions)do
 assert(action[1]~=509 and action[1]~=84 and action[1]~=350,'RF tasking issued lock/fire command')
end
print('Actual RF receiver -> common picture -> radar: aircraft-only bearing cue, world-frame turn, native angles, manual/power and no fabricated track PASS')
''')
