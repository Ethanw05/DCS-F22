"""Gun consumes real measurement epochs at the owned radar's interleaved cadence."""
from pathlib import Path
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
lua = LuaRuntime()
lua.globals().ROOT = (ROOT/'Cockpit/Scripts').as_posix()+'/'
lua.execute(r'''
LockOn_Options={script_path=ROOT}
local Director=dofile(ROOT..'Systems/Gun_Director.lua')
local display=dofile(ROOT..'Systems/Radar_Display.lua')
local values={F22_RADAR_STT_VALID=1,F22_STT_MOTION_VALID=1,F22_STT_VELOCITY_SIGMA_MPS=.4,EFM_HUD_VALID=1,
 F22_STT_ID=42,EFM_HUD_VN=220,F22_STT_VN=220,F22_STT_VU=10,F22_STT_VE=80}
local now, stamp, calls, solutions = 10.1, 10, 0, 0
local function get(k)return values[k]or 0 end
local function put(k,v)values[k]=v end
function get_model_time()return now end
local own={1000,5000,0}
local sensors={getSelfCoordinates=function()return unpack(own)end,getHeading=function()return 0 end,
 getPitch=function()return 0 end,getRoll=function()return 0 end}
local function dispatch(_,command)
 assert(command==10851);calls=calls+1
 assert(get('F22_GUN_MEASUREMENT_AGE')>=.08 and get('F22_GUN_MEASUREMENT_AGE')<=.5,
  'actual observation age was relabelled as a current measurement')
 for prefix,vector in pairs({AIM={1,0,.1},BORE={1,0,0}})do
  for k,axis in ipairs({'N','U','E'})do put('F22_GUN_'..prefix..'_'..axis,vector[k])end
 end
 put('F22_GUN_SOLUTION_VALID',1);put('F22_GUN_SOLUTION_SEQUENCE',get('F22_GUN_REQUEST_SEQUENCE'))
 put('F22_GUN_RESPONSE_SEQUENCE',get('F22_GUN_REQUEST_SEQUENCE'))
 put('F22_GUN_RESULT_TRACK_ID',get('F22_STT_ID'));put('F22_GUN_RESULT_TIME',now)
end
local d=Director.new(sensors,get,put,dispatch,display,15)
local function sample()
 own={1000+220*(now-10),5000,0}
 local measured={1000+800+220*(stamp-10),5000+10*(stamp-10),80*(stamp-10)}
 local age=now-stamp
 local current={north=measured[1]+220*age,altitude=measured[2]+10*age,east=measured[3]+80*age}
 local range,az,el=display.body_observation(current,
  {north=own[1],altitude=own[2],east=own[3],heading=0,pitch=0,roll=0},0)
 put('F22_STT_TIME',stamp);put('F22_STT_PN',measured[1]);put('F22_STT_PU',measured[2]);put('F22_STT_PE',measured[3])
 put('F22N_RADAR_STT_RANGE',range);put('F22N_RADAR_STT_AZIMUTH',az);put('F22N_RADAR_STT_ELEVATION',el)
 local azimuth=d:update(true)
 if azimuth then solutions=solutions+1 end
 return azimuth
end
-- Player-log normal median .306s measurement interval and at least .085s
-- report age. Cockpit updates between reports must not reset motion history.
for i=0,80 do
 now=10.1+i*.02
 stamp=10+math.floor((now-10-.085)/.306)*.306
 sample()
end
assert(calls>0 and solutions>0,'qualified .306s radar reports never reached the native gun solver')
local successful=calls
now=stamp+.501;assert(not sample() and get('F22_GUN_REQUEST_VALID')==0,
 'frozen radar state remained authoritative beyond the bounded observation age')
assert(calls==successful)
-- A new identity still needs two actual reports. Repeating a timestamp cannot
-- warm the new track, and loss of lock cancels an outstanding/old solution.
put('F22_STT_ID',43);now=12;stamp=11.9
assert(not sample());now=12.02;assert(not sample())
now=12.306;stamp=12.206;assert(sample())
put('F22_RADAR_STT_VALID',0)
assert(not d:update(true) and get('F22_GUN_REQUEST_VALID')==0 and get('F22_GUN_DIRECTOR_VALID')==0)
''')
print('Gun actual director: .306s measured cadence/.085s report latency, native requests/pipper, '
      'original observation age, bounded stale cutoff, identity warmup and lock loss PASS')
