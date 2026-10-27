"""Actual Lua funnel response handling and wingspan geometry, no invented lock."""
from pathlib import Path
from lupa.lua51 import LuaRuntime
r=Path(__file__).resolve().parents[1]
l=LuaRuntime()
l.globals().ROOT=(r/'Cockpit/Scripts').as_posix()+'/'
l.execute('''
LockOn_Options={script_path=ROOT}
local Frames=dofile(ROOT..'Systems/Gun_Frames.lua')
local m=dofile(ROOT..'Systems/Gun_Funnel.lua')
local v={EFM_HUD_VALID=1,F22_FUNNEL_NATIVE_VALID=1,F22_FUNNEL_RESULT_TIME=5}
local now=5;function get_model_time()return now end
local pose={heading=0,pitch=0,roll=0}
local sensors={getHeading=function()return -pose.heading end,getPitch=function()return pose.pitch end,
 getRoll=function()return pose.roll end,getSelfCoordinates=function()return 100,5000,300 end}
local calls=0
local f=m.new(sensors,function(n)return v[n] or 0 end,function(n,value)v[n]=value end,
 function(_,command)assert(command==10851);calls=calls+1 end,15)
local function populate()
 local frame=Frames.from_pose(pose)
 for i=1,7 do
  local age=.15+.175*(i-1)
  local p=Frames.world(frame,{1030*age,-4.9*age*age,0})
  local key=string.format('F22_FUNNEL_%02d_',i)
  v[key..'VALID']=1;v[key..'N']=100+p[1];v[key..'U']=5000+p[2];v[key..'E']=300+p[3]
 end
end
populate();f:update(true)
assert(calls==1 and v.HUD_GUN_FUNNEL_VALID==1)
local near=v.HUD_FUNNEL_01_R_X-v.HUD_FUNNEL_01_L_X
local far=v.HUD_FUNNEL_07_R_X-v.HUD_FUNNEL_07_L_X
assert(near>far and far>0)
-- Actual muzzle is laterally offset. Its range-dependent parallax must not
-- turn the stadiametric wingspan into a vertical height measurement.
v.F22_FUNNEL_01_E=v.F22_FUNNEL_01_E+1.57
v.F22_FUNNEL_02_E=v.F22_FUNNEL_02_E+1.57
now=now+.04;v.F22_FUNNEL_RESULT_TIME=now
f:update(true)
for i=1,7 do
 local p=string.format('HUD_FUNNEL_%02d_',i)
 assert(v[p..'L_Y']==v[p..'R_Y'],'wingspan rails rotated by parallax')
 assert(v[p..'L_X']<v[p..'R_X'])
end
now=now+.04;v.F22_FUNNEL_RESULT_TIME=now;populate();f:update(true)
local old=v.HUD_FUNNEL_04_L_X
f:update(false) -- Fresh mission/pose: do not interpolate across a teleport.
now=now+.04;v.F22_FUNNEL_RESULT_TIME=now
pose={heading=2.5,pitch=.7,roll=-1.2};populate();f:update(true)
assert(math.abs(v.HUD_FUNNEL_04_L_X-old)<1e-12,'projection must follow actual aircraft frame')
v.F22_RADAR_STT_VALID=1;f:update(true);assert(v.HUD_GUN_FUNNEL_VALID==0)
v.F22_RADAR_STT_VALID=0;f:update(true);assert(v.HUD_GUN_FUNNEL_VALID==1)
now=now+.11;f:update(true);assert(v.HUD_GUN_FUNNEL_VALID==0,'stale native result shown')
v.F22_FUNNEL_RESULT_TIME=now;f:update(true);assert(v.HUD_GUN_FUNNEL_VALID==1)
for i=2,7 do v[string.format('F22_FUNNEL_%02d_VALID',i)]=0 end
f:update(true);assert(v.HUD_GUN_FUNNEL_VALID==0,'isolated point cannot form rail')
f:update(false);assert(v.HUD_GUN_FUNNEL_VALID==0 and v.F22_FUNNEL_REQUEST_VALID==0)
''')
print('Gun funnel: native response geometry, wingspan taper, attitude, STT/loss, stale/power invalidation OK')
