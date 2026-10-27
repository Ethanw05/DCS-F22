"""Custom payload capability routing and native world-beam HUD projection."""
from pathlib import Path
from lupa.lua51 import LuaRuntime
r=Path(__file__).resolve().parents[1]
l=LuaRuntime()
l.globals().ROOT=(r/'Cockpit/Scripts').as_posix()+'/'
l.execute('''
LockOn_Options={script_path=ROOT}
local m=dofile(ROOT..'Systems/IR_Seeker.lua')
assert(m.profile({count=1,CLSID='{AIM9X-BLKII}',weapon={level4=10042}})==1)
assert(m.profile({count=1,clsid='{LAU_115_2xAIM9X-II}',weapon={level4=10043}})==1)
assert(m.profile({count=1,weapon={level4=136}})==1)
assert(m.profile({count=1,CLSID='{6CEB49FC-DED8-4DED-B053-E1F033FF72D3}',weapon={level4=22}})==0)
assert(m.profile({count=0,CLSID='{AIM9X-BLKII}'})==0)
local f=dofile(ROOT..'Systems/Gun_Frames.lua')
for _,h in ipairs({0,.4,2.8,5.9}) do for _,p in ipairs({-.4,0,.7}) do for _,r in ipairs({-1,0,1.2}) do
 local frame=f.from_pose({heading=h,pitch=p,roll=r})
 local az,el=.12,-.06
 local beam=f.world(frame,{math.cos(el)*math.cos(az),math.sin(el),math.cos(el)*math.sin(az)})
 local a,e=m.project(frame,beam)
 assert(math.abs(a-az)<1e-12 and math.abs(e-el)<1e-12)
end end end
assert(m.project(f.from_pose({heading=0,pitch=0,roll=0}),{0,0,0})==nil)
local v={F22_IR_AVAILABLE=1,F22_IR_LOCK=0,F22_IR_STRENGTH=0,F22_IR_WORLD_VALID=1,
 F22_IR_WORLD_FWD_N=1,F22_IR_WORLD_FWD_U=0,F22_IR_WORLD_FWD_E=0,F22_IR_STATION=0}
local s=m.new({getHeading=function()return 0 end,getPitch=function()return 0 end,getRoll=function()return 0 end},function(n)return v[n] or 0 end)
assert(s:update(true,.02)==0)
v.F22_IR_WORLD_FWD_N=math.cos(.1);v.F22_IR_WORLD_FWD_E=math.sin(.1)
local a=s:update(true,.02);assert(math.abs(a-.04)<1e-12)
v.F22_IR_WORLD_VALID=0;assert(s:update(true,.02)==nil)
v.F22_IR_WORLD_VALID=1;a=s:update(true,.02);assert(math.abs(a-.1)<1e-12)
assert(s:update(false,.02)==nil)
''')
print('IR profiles, world/body projection across attitude, smoothing, station/power validity OK')
