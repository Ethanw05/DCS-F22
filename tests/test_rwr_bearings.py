"""Passive bearing attitude compensation and actual HUD/EW owner integration.

Synthetic receiver observations exercise rotations, not native RF detection.
"""
from pathlib import Path
from lupa.lua51 import LuaRuntime
import contextlib
import io
import runpy

root=Path(__file__).resolve().parents[1]
lua=LuaRuntime()
lua.globals().ROOT=(root/'Cockpit/Scripts').as_posix()+'/'
lua.execute('''
LockOn_Options={script_path=ROOT}
local Frames=dofile(ROOT..'Systems/Gun_Frames.lua')
local Bearings=dofile(ROOT..'Systems/RWR_Bearings.lua')
local function frame(h,p,r)return Frames.from_pose({heading=-h,pitch=p or 0,roll=r or 0})end
local function error_angle(a,b)return math.abs(math.atan2(math.sin(a-b),math.cos(a-b)))end
local function observation(source,age,az,el)
 return {source=source,age=age,az=az,el=el or 0,signal=2}
end
local count=0
for az=-180,150,30 do for el=-60,60,30 do
 local b=Bearings.new();local start=frame(.4,.2,-.3)
 local a,e=math.rad(az),math.rad(el)
 local world=Frames.world(start,{math.cos(e)*math.cos(a),math.sin(e),-math.cos(e)*math.sin(a)})
 local c=observation(42,0,a,e);b:update(0,start,{c},true)
 for tick=1,40 do
  local now=tick*.05
  local current=frame(.4+now*.6,.2+now*.15,-.3+now*.8)
  -- Native export age has +/- 10 ms scheduling skew: this must not
  -- progressively re-anchor the stale raw angle to each newer aircraft pose.
  c=observation(42,now+(tick%2==0 and .01 or -.01),a,e)
  b:update(now,current,{c},true)
  local body=Frames.body(current,world)
  local expected=-math.atan2(body[3],body[1])
  local expected_el=math.atan2(body[2],math.sqrt(body[1]^2+body[3]^2))
  assert(c.bearing_compensated and error_angle(c.az,expected)<1e-10)
  assert(math.abs(c.el-expected_el)<1e-10)
  assert(c.age>0 and c.signal==2 and c.range==nil,'rotation changed receiver evidence')
  count=count+1
 end
end end
assert(count==2400)

-- An accepted reception is oriented at its measurement time, rather than
-- its later Lua read time. Roll/yaw interpolate across the angle wrap.
local b=Bearings.new()
for tick=0,40 do b:update(tick*.05,frame(math.rad(179)+tick*.005),{},true)end
local at=frame(math.rad(179)+.1)
local c=observation(1,1,.3,.1)
b:update(2,frame(math.rad(179)+.2),{c},true)
assert(c.bearing_compensated)
local w=Frames.world(at,{math.cos(.1)*math.cos(.3),math.sin(.1),-math.cos(.1)*math.sin(.3)})
local body=Frames.body(frame(math.rad(179)+.2),w)
assert(error_angle(c.az,-math.atan2(body[3],body[1]))<1e-10)
-- New RF reception immediately replaces the remembered world direction.
c=observation(1,0,-.7,.2);b:update(2.05,frame(1,.3,.4),{c},true)
assert(error_angle(c.az,-.7)<1e-10 and math.abs(c.el-.2)<1e-10)
-- Source identity, not receiver slot/order, owns the remembered direction.
local d=observation(2,0,1.2,-.1)
c=observation(1,.05,-.7,.2);b:update(2.1,frame(1,.3,.4),{d,c},true)
assert(error_angle(c.az,-.7)<1e-10 and error_angle(d.az,1.2)<1e-10)
b:update(2.15,frame(1),{},true);assert(next(b.tracks)==nil)
-- First seen aged contacts cannot be reconstructed without pose history.
c=observation(3,2,.5,.2);b:reset();b:update(4,frame(1),{c},true)
assert(not c.bearing_compensated and c.az==.5)
b:update(4.05,frame(1),{c},false);assert(next(b.tracks)==nil and #b.history==0)
c=observation(3,0,.5);b:update(5,frame(0),{c},true)
c=observation(3,1,.5);b:update(0,frame(1),{c},true)
assert(not c.bearing_compensated,'rewind retained a previous mission direction')
b:update(.05,nil,{c},true);assert(next(b.tracks)==nil)
assert(Bearings.frame({getHeading=function()return 0/0 end})==nil)
''')
print('RWR bearing compensation: 2,400 combined attitude cases, age skew, late receptions, wrap, identity and lifecycle PASS')

with contextlib.redirect_stdout(io.StringIO()):
    runtime=runpy.run_path(str(root/'tests/test_display_startup.py'))['runtime']
lua=runtime()
lua.execute('''
local now,heading=0,0
function get_model_time()return now end
function get_base_data()return {getHeading=function()return heading end,
 getPitch=function()return 0 end,getRoll=function()return 0 end}end
function GetDevice()return {set_power=function()end}end
local function put(n,v)get_param_handle(n):set(v)end
local function val(n)return get_param_handle(n):get()end
put('MAIN_POWER',1)
for key,value in pairs({SOURCE=123,TIME=0,AZIMUTH=0,ELEVATION=0,SIGNAL=2,POWER=1-.53/.84,GENERAL_TYPE=1,UNIT_TYPE='F-16'})do
 put('RWR_CONTACT_01_'..key,value)
end
dofile(SCRIPT_ROOT..'Systems/RWR_System.lua');post_initialize();update()
for i=1,20 do
 now=i*.05;heading=-now*math.pi/2;put('RWR_CONTACT_01_TIME',now);update()
 local az=val('F22_EW_01_AZ')
 -- Turn right 90 degrees: the remembered nose emitter moves to the left.
 assert(math.abs(az+heading)<1e-10)
 assert(math.abs(val('F22_EW_01_X')+math.sin(az)*.53)<1e-10)
 assert(math.abs(val('HUD_EW_01_X')+math.sin(az)*.32)<1e-10)
 assert(math.abs(val('HUD_EW_01_ROT')-az)<1e-10)
 assert(val('F22_RWR_ALERT')==2 and val('F22_EW_01_SOURCE')==123)
end
-- A new nose reception resets both outputs; no stale rotation survives.
now=1.05;put('RWR_CONTACT_01_TIME',0);update()
assert(math.abs(val('F22_EW_01_AZ'))<1e-10)
put('MAIN_POWER',0);update()
assert(val('F22_RWR_COUNT')==0 and val('HUD_EW_01_VALID')==0)
''')
print('Actual RWR owner: 90-degree turn, shared HUD/EW bearings, fresh reception and power loss PASS')
