"""DCS dispatch may finish after update returns: validate the real request handoff."""
from pathlib import Path
from lupa.lua51 import LuaRuntime
lua=LuaRuntime();lua.globals().ROOT=str(Path(__file__).resolve().parents[1]/'Cockpit/Scripts').replace('\\','/')+'/'
lua.execute('''
LockOn_Options={script_path=ROOT}
local M=dofile(ROOT..'Systems/Gun_Director.lua');local display=dofile(ROOT..'Systems/Radar_Display.lua')
local values={F22_AESA_GENERATION=7,F22_RADAR_STT_VALID=1,F22_STT_MOTION_VALID=1,F22_STT_VELOCITY_SIGMA_MPS=.4,EFM_HUD_VALID=1,F22_STT_ID=42,
 EFM_HUD_VN=220,F22_STT_VN=220,F22_STT_VU=0,F22_STT_VE=0}
local now=0;function get_model_time()return now end
local function get(k)return values[k]or 0 end
local function put(k,v)values[k]=v end
local position={1000,5000,0};local heading=0;local queue={}
local sensors={getSelfCoordinates=function()return unpack(position)end,getHeading=function()return-heading end,
 getPitch=function()return 0 end,getRoll=function()return 0 end}
local function dispatch(_,command)
 assert(command==10851)
 queue[#queue+1]={seq=get('F22_GUN_REQUEST_SEQUENCE'),id=get('F22_GUN_TRACK_ID'),time=get('F22_GUN_REQUEST_TIME')}
end
local d=M.new(sensors,get,put,dispatch,display,15)
local function sample(t)
 now=t;position={1000+220*t,5000,0}
 local pose={north=position[1],altitude=5000,east=0,heading=heading,pitch=0,roll=0}
 local target={north=position[1]+800,altitude=5000,east=0}
 local range,az,el=display.body_observation(target,pose,0)
 put('F22N_RADAR_STT_RANGE',range);put('F22N_RADAR_STT_AZIMUTH',az);put('F22N_RADAR_STT_ELEVATION',el)
 put('F22_STT_TIME',t);put('F22_STT_PN',target.north);put('F22_STT_PU',5000);put('F22_STT_PE',0)
 return d:update(true)
end
local function deliver(valid)
 local request=table.remove(queue,1);assert(request)
 put('F22_GUN_SOLUTION_SEQUENCE',request.seq);put('F22_GUN_RESPONSE_SEQUENCE',request.seq)
 put('F22_GUN_RESULT_TRACK_ID',request.id);put('F22_GUN_RESULT_TIME',now)
 put('F22_GUN_SOLUTION_VALID',valid and 1 or 0)
 put('F22_GUN_RESULT_SCHEMA',2);put('F22_GUN_RESULT_SOURCE',2);put('F22_GUN_RESULT_GENERATION',7)
 put('F22_GUN_CURRENT_N',1800+220*now);put('F22_GUN_CURRENT_U',5000);put('F22_GUN_CURRENT_E',0)
 put('F22_GUN_CURRENT_VN',220)
 for _,axis in ipairs({'N','U','E'})do put('F22_GUN_CURRENT_A'..axis,0)end
 put('F22_GUN_AIM_N',1);put('F22_GUN_AIM_U',0);put('F22_GUN_AIM_E',0)
 put('F22_GUN_BORE_N',1);put('F22_GUN_BORE_U',0);put('F22_GUN_BORE_E',0)
 put('F22_GUN_MNV_VALID',1);put('F22_GUN_MNV_ID',request.id);put('F22_GUN_MNV_TIME',now)
 local reference={BASE={1,0,0},LOW={1,0,0},HIGH={1,.04,0},LEFT={1,0,.03},RIGHT={1,0,-.03}}
 for name,v in pairs(reference)do for k,axis in ipairs({'N','U','E'})do put('F22_GUN_MNV_'..name..'_'..axis,v[k])end end

 return request
end
assert(not sample(0));assert(not sample(.05));assert(not sample(.1));assert(#queue==1)
-- Real native work completes between cockpit updates, rather than inside dispatch().
deliver(true)
assert(sample(.12),'completed previous-tick native result must be accepted')
assert(get('F22_GUN_DIRECTOR_VALID')==1)
assert(get('F22_GUN_MNV_SHOW')==1 and get('F22_GUN_MNV_LOW_MARK')==0 and get('F22_GUN_MNV_HIGH_MARK')==1)
assert(#queue==1,'only one outstanding native request')
local az=sample(.14);assert(az)
assert(#queue==1,'must not overwrite parameters or enqueue another request before acknowledgement')
-- The gun mount follows the current aircraft attitude while the confirmed aim is in world space.
heading=.05;local moved=sample(.16);assert(moved and math.abs(moved)<.001)
-- A newly completed rejected solve must hide the previous pipper.
deliver(false);assert(not sample(.18));assert(get('F22_GUN_DIRECTOR_VALID')==0)
assert(get('F22_GUN_MNV_SHOW')==0,'references cannot replace missing primary solution')
assert(#queue==1)
-- Old-target completion must not appear on a new lock.
put('F22_STT_ID',43);assert(not sample(.2));deliver(true)
assert(not sample(.25));assert(not sample(.3))
assert(get('F22_GUN_DIRECTOR_VALID')==0)
-- No late/missing native response can leave a pipper on screen.
assert(not sample(.5));assert(get('F22_GUN_DIRECTOR_VALID')==0)
put('F22_RADAR_STT_VALID',0);assert(not d:update(true));assert(get('F22_GUN_DIRECTOR_VALID')==0)
''')
print('Gun handoff: delayed completion, one pending request, current bore, failure, target change and expiry OK')
