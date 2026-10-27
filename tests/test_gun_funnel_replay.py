"""Replay asynchronous native world samples through the actual Lua presentation.

Synthetic geometry tests timing and display continuity, not DCS ballistics.
"""
from pathlib import Path
from lupa.lua51 import LuaRuntime

root = Path(__file__).resolve().parents[1]
lua = LuaRuntime()
lua.globals().ROOT = (root / 'Cockpit/Scripts').as_posix() + '/'
lua.execute('''
LockOn_Options={script_path=ROOT}
local Frames=dofile(ROOT..'Systems/Gun_Frames.lua')
local Funnel=dofile(ROOT..'Systems/Gun_Funnel.lua')
local Presentation=dofile(ROOT..'Systems/Gun_Funnel_Presentation.lua')

-- Constant angular stream during a fast turn. World coordinates rotate and
-- translate, while native packets arrive one 50 Hz Lua tick late at 25 Hz.
local now=10
function get_model_time()return now end
local v={EFM_HUD_VALID=1}
local writes={}
local function pose(t)return {heading=.6*t,pitch=.08*math.sin(t),roll=.7*math.sin(.5*t)}end
local function position(t)return {200*t,5000+10*t,80*t}end
local sensors={
 getHeading=function()return -pose(now).heading end,
 getPitch=function()return pose(now).pitch end,
 getRoll=function()return pose(now).roll end,
 getSelfCoordinates=function()return unpack(position(now))end}
local f=Funnel.new(sensors,function(n)return v[n] or 0 end,
 function(n,x)v[n]=x;writes[#writes+1]={n,x}end,function()end,15)
local last_stamp
local function packet(t,az)
 local frame,own=Frames.from_pose(pose(t)),position(t)
 v.F22_FUNNEL_NATIVE_VALID=1;v.F22_FUNNEL_RESULT_TIME=t
 for i=1,7 do
  local range=150+175*(i-1)
  local p=Frames.world(frame,{range,-.01*range,math.tan(az or .02)*range})
  local key=string.format('F22_FUNNEL_%02d_',i)
  v[key..'VALID']=1
  for k,s in ipairs({'N','U','E'})do v[key..s]=own[k]+p[k]end
 end
end
local squared,new_squared,steps=0,0,0
local previous_old,previous_new
for tick=0,250 do
 now=10+tick*.02
 if tick>0 and tick%2==1 then
  last_stamp=now-.02;packet(last_stamp)
 end
 writes={};f:update(true)
 if tick>5 then
  assert(v.HUD_GUN_FUNNEL_VALID==1,'valid replay hidden')
  for _,write in ipairs(writes)do
   if write[1]=='HUD_GUN_FUNNEL_VALID' or write[1]:match('^HUD_FUNNEL_%d%d_VALID$')then
    assert(write[2]==1,'valid update transiently clears visibility')
   end
  end
  local center=(v.HUD_FUNNEL_04_L_X+v.HUD_FUNNEL_04_R_X)/2
  assert(math.abs(center-.02)<1e-9,'sample mixed with a different aircraft pose')
  local p=position(now)
  local body=Frames.body(Frames.from_pose(pose(now)),
   {v.F22_FUNNEL_04_N-p[1],v.F22_FUNNEL_04_U-p[2],v.F22_FUNNEL_04_E-p[3]})
  local old=math.atan2(body[3],body[1])
  if previous_old then
   squared=squared+(old-previous_old)^2
   new_squared=new_squared+(center-previous_new)^2
   steps=steps+1
  end
  previous_old,previous_new=old,center
 end
end
assert(math.sqrt(squared/steps)>.005,'replay did not exercise old jitter')
assert(math.sqrt(new_squared/steps)<1e-9,'steady-turn jitter remains')
print(string.format('Steady-turn replay: old %.3f mrad RMS/frame; corrected %.6f mrad',
 math.sqrt(squared/steps)*1000,math.sqrt(new_squared/steps)*1000))

-- Growing angular curve, including alternating 40/60 ms native intervals:
-- exact linear interpolation at a 40 ms delay, clamped only when no newer
-- sample has arrived. No overshoot or trajectory extrapolation.
local p=Presentation.new()
local stamp=0;local next_stamp=0;local interval=0
for tick=0,100 do
 local t=tick*.02
 if t+1e-9>=next_stamp then
  stamp=t;local points={}
  for i=1,7 do points[i]={.1*t,-.02*t,.01+.001*t}end
  p:push(t,points)
  interval=interval+1;next_stamp=t+(interval%2==0 and .06 or .04)
 end
 local point=p:at(t)[4]
 local sample_time=math.min(stamp,math.max(0,t-.04))
 assert(math.abs(point[1]-.1*sample_time)<1e-10)
 assert(math.abs(point[2]+.02*sample_time)<1e-10)
 assert(math.abs(point[3]-(.01+.001*sample_time))<1e-10)
end
p:reset();assert(next(p:at(2))==nil)
local function curve(x)return {{x,0,.01},{x,0,.01}}end
p:push(0,curve(0));p:push(.04,curve(.1))
assert(math.abs(p:at(.06)[1][1]-.05)<1e-10)
assert(math.abs(p:at(.08)[1][1]-.1)<1e-10,'step response exceeds 80 ms')
p:push(.08,{})
assert(next(p:at(.08))==nil,'missing native points bridged')

-- Real wrapper clears immediately and never carries old presentation into
-- native failure, stale results, lock changes, power loss or clock restart.
local function hidden()assert(v.HUD_GUN_FUNNEL_VALID==0)end
v.F22_FUNNEL_NATIVE_VALID=0;f:update(true);hidden()
now=now+.02;packet(now,-.03);f:update(true)
assert(math.abs((v.HUD_FUNNEL_04_L_X+v.HUD_FUNNEL_04_R_X)/2+.03)<1e-9)
v.F22_RADAR_STT_VALID=1;f:update(true);hidden()
v.F22_RADAR_STT_VALID=0;f:update(true);assert(v.HUD_GUN_FUNNEL_VALID==1)
now=now+.12;f:update(true);hidden()
packet(now);f:update(true);assert(v.HUD_GUN_FUNNEL_VALID==1)
f:update(false);hidden();assert(v.F22_FUNNEL_REQUEST_VALID==0)
now=1;packet(now);f:update(true);assert(v.HUD_GUN_FUNNEL_VALID==1)
now=.5;f:update(true);hidden() -- Old native packet is from the future.
packet(now,-.04);f:update(true)
assert(math.abs((v.HUD_FUNNEL_04_L_X+v.HUD_FUNNEL_04_R_X)/2+.04)<1e-9)
''')
print('Funnel replay: asynchronous poses, interpolation, response and invalidation OK')
