"""A new radar report must not be combined with the previous shot solution.

Use a known constant ballistic offset and delayed native completion to isolate
packet timing. This does not model DCS acquisition or projectile accuracy.
"""
from pathlib import Path
from lupa.lua51 import LuaRuntime
ROOT=Path(__file__).resolve().parents[1]
lua=LuaRuntime(unpack_returned_tuples=True)
lua.globals().ROOT=(ROOT/'Cockpit/Scripts').as_posix()+'/'
lua.execute(r'''
LockOn_Options={script_path=ROOT}
local Director=dofile(ROOT..'Systems/Gun_Director.lua')
local Display=dofile(ROOT..'Systems/Radar_Display.lua')
local values={EFM_HUD_VALID=1,EFM_HUD_VN=220,F22_RADAR_STT_VALID=1,
 F22_STT_MOTION_VALID=1,F22_STT_ID=42,F22_STT_VN=220,F22_STT_VU=0,F22_STT_VE=0,
 F22_STT_VELOCITY_SIGMA_MPS=.4}
local now,queue=10,nil
local schema, corrupt = 2, false
function get_model_time()return now end
local function get(k)return values[k]or 0 end
local function put(k,v)values[k]=v end
local sensors={getSelfCoordinates=function()return 220*now,5000,0 end,
 getHeading=function()return 0 end,getPitch=function()return 0 end,getRoll=function()return 0 end}
local lead=.02
local function dispatch(_,command)
 assert(command==10851 and not queue)
 queue={time=now+.002,sequence=get('F22_GUN_REQUEST_SEQUENCE'),id=get('F22_GUN_TRACK_ID'),
  east=get('F22_GUN_TARGET_E')}
end
local function deliver()
 if not queue or queue.time>now then return end
 local los=math.atan2(queue.east,400)
 put('F22_GUN_RESPONSE_SEQUENCE',queue.sequence);put('F22_GUN_SOLUTION_SEQUENCE',queue.sequence)
 put('F22_GUN_SOLUTION_VALID',1);put('F22_GUN_RESULT_SCHEMA',schema)
 put('F22_GUN_RESULT_TIME',queue.time);put('F22_GUN_RESULT_TRACK_ID',queue.id)
 put('F22_GUN_AIM_N',math.cos(los+lead));put('F22_GUN_AIM_U',0);put('F22_GUN_AIM_E',math.sin(los+lead))
 put('F22_GUN_BORE_N',1);put('F22_GUN_BORE_U',0);put('F22_GUN_BORE_E',0)
 put('F22_GUN_CURRENT_N',corrupt and 0/0 or 220*queue.time+400);put('F22_GUN_CURRENT_U',5000)
 put('F22_GUN_CURRENT_E',queue.east)
 for _,axis in ipairs({'N','U','E'})do
  put('F22_GUN_CURRENT_V'..axis,axis=='N'and 220 or 0)
  put('F22_GUN_CURRENT_A'..axis,0)
 end
 queue=nil
end
local d=Director.new(sensors,get,put,dispatch,Display,15)
local worst,accepted=0,0
for tick=0,480 do
 now=10+tick/120;deliver()
 local report=math.floor((now-.001)*40)
 local stamp=report/40
 local east=report%2==0 and 2 or -2
 put('F22_STT_TIME',stamp);put('F22_STT_PN',220*stamp+400)
 put('F22_STT_PU',5000);put('F22_STT_PE',east)
 put('F22N_RADAR_STT_RANGE',math.sqrt(400^2+east^2))
 put('F22N_RADAR_STT_AZIMUTH',math.atan2(east,400));put('F22N_RADAR_STT_ELEVATION',0)
 local az=d:update(true)
 if tick>40 and az then
  worst=math.max(worst,math.abs(az+lead));accepted=accepted+1
 end
end
assert(accepted==440,'paired display lost otherwise current solutions')
assert(worst<1e-9,string.format('mixed radar/solution epochs caused %.3fmrad false pipper motion',worst*1000))
for _,bad in ipairs({0,1})do
 schema=bad
 for _=1,4 do now=now+1/120;deliver();d:update(true)end
 assert(get('F22_GUN_DIRECTOR_VALID')==0,'missing/old packet schema retained a current cue')
end
schema=2;corrupt=true
for _=1,4 do now=now+1/120;deliver();d:update(true)end
assert(get('F22_GUN_DIRECTOR_VALID')==0,'nonfinite packet target state retained a current cue')
corrupt=false
for _=1,4 do now=now+1/120;deliver();d:update(true)end
assert(get('F22_GUN_DIRECTOR_VALID')==1,'coherent native packet failed to recover')
put('F22_RADAR_STT_VALID',0)
assert(not d:update(true) and get('F22_GUN_DIRECTOR_VALID')==0,'paired packet outlived lock authority')
''')
print('Actual director: delayed native solve plus alternating radar-position corrections '
      'produce zero artificial pipper movement; lock withdrawal PASS')
