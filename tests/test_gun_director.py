"""World motion association, actual pipper semantics and stale-response rejection."""
from pathlib import Path
from lupa.lua51 import LuaRuntime
lua=LuaRuntime();lua.globals().ROOT=str(Path(__file__).resolve().parents[1]/'Cockpit/Scripts/Systems').replace('\\','/')
lua.execute('''
LockOn_Options={script_path=ROOT..'/../'}
local M=dofile(ROOT..'/Gun_Director.lua');local display=dofile(ROOT..'/Radar_Display.lua')
local p=M.pipper({1,0,.1},{1,0,0},{1,0,0})
assert(p and p[3]<0,'a right-lead requirement moves the director pipper left')
local aligned=M.pipper({1,0,0},{1,0,0},{1,.1,.2})
assert(math.abs(aligned[2]/aligned[1]-.1)<1e-9 and math.abs(aligned[3]/aligned[1]-.2)<1e-9,
 'solved aim places pipper on current target')
local values={F22_RADAR_STT_VALID=1,F22_STT_MOTION_VALID=1,EFM_HUD_VALID=1,
 F22_STT_ID=42,F22_STT_ACCEL_VALID=1,EFM_HUD_VN=220,F22_STT_VN=220,F22_STT_VU=10,F22_STT_VE=80,
 F22_STT_AN=0,F22_STT_AU=0,F22_STT_AE=0}
local now=0;function get_model_time()return now end
local function get(k)return values[k]or 0 end
local function put(k,v)values[k]=v end
local position={1000,5000,0};local heading=0;local pitch=0;local roll=0;local calls=0
local sensors={getSelfCoordinates=function()return unpack(position)end,getHeading=function()return-heading end,
 getPitch=function()return pitch end,getRoll=function()return roll end}
local function dispatch(_,command)
 assert(command==10851);calls=calls+1
 assert(values.F22_GUN_VE==80 and values.F22_GUN_VU==10,'native world velocity retained')
 put('F22_GUN_AIM_N',1);put('F22_GUN_AIM_U',0);put('F22_GUN_AIM_E',.1)
 put('F22_GUN_BORE_N',1);put('F22_GUN_BORE_U',0);put('F22_GUN_BORE_E',0)
 for _,axis in ipairs({'N','U','E'})do put('F22_GUN_CURRENT_'..axis,get('F22_GUN_TARGET_'..axis))end
 put('F22_GUN_SOLUTION_VALID',1);put('F22_GUN_SOLUTION_SEQUENCE',get('F22_GUN_REQUEST_SEQUENCE'))
 put('F22_GUN_RESPONSE_SEQUENCE',get('F22_GUN_REQUEST_SEQUENCE'));put('F22_GUN_RESULT_TIME',now);put('F22_GUN_RESULT_TRACK_ID',get('F22_GUN_TRACK_ID'))
end
local d=M.new(sensors,get,put,dispatch,display,15)
local function sample(t)
 now=t;position={1000+220*t,5000,0}
 local target={north=position[1]+800,altitude=5000+10*t,east=80*t}
 local r,a,e=display.body_observation(target,{north=position[1],altitude=position[2],east=position[3],heading=heading,pitch=pitch,roll=roll},0)
 put('F22N_RADAR_STT_RANGE',r);put('F22N_RADAR_STT_AZIMUTH',a);put('F22N_RADAR_STT_ELEVATION',e)
 put('F22_STT_TIME',t);put('F22_STT_PN',target.north);put('F22_STT_PU',target.altitude);put('F22_STT_PE',target.east)
 return d:update(true)
end
assert(not sample(0));assert(not sample(.05));assert(sample(.1));assert(get('F22_GUN_DIRECTOR_VALID')==1)
local before=calls;assert(sample(.12));assert(calls==before+1,'current pose requires a fresh solve each cockpit tick')
heading=.1;pitch=.1;roll=.7
assert(sample(.15),'own heading/pitch/roll must not become target velocity')
assert(sample(.2));assert(calls>=2)
put('F22_STT_ID',43);assert(not sample(.25),'new identity requires fresh samples')
assert(not sample(.3));assert(sample(.4))
now=.7;assert(not d:update(true),'stale timestamp rejected');assert(get('F22_GUN_DIRECTOR_VALID')==0)
assert(not sample(.75));assert(not sample(.8));assert(sample(.9))
put('F22_RADAR_STT_VALID',0);assert(not d:update(true));assert(get('F22_GUN_REQUEST_VALID')==0)
put('F22_RADAR_STT_VALID',1)
assert(not sample(1));assert(not sample(1.05));assert(sample(1.15))
-- A missing/old EFM cannot reuse a prior successful response.
dispatch=function()end
local missing=M.new(sensors,get,put,dispatch,display,15)
d=missing
assert(not sample(2));assert(not sample(2.05));assert(not sample(2.15),'old response must not count as a new solution')
function get_model_time()return nil end
assert(not missing:update(true),'missing model clock must fail closed')
''')
print('Gun director: native motion, attitude compensation, current-target pipper, identity, stale lock and response checks OK')
