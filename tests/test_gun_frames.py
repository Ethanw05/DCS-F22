from pathlib import Path
from lupa.lua51 import LuaRuntime
lua=LuaRuntime();lua.globals().ROOT=(Path(__file__).resolve().parents[1]/'Cockpit/Scripts/Systems').as_posix()+'/'
lua.execute('''
local f=dofile(ROOT..'Gun_Frames.lua');local display=dofile(ROOT..'Radar_Display.lua')
for _,heading in ipairs({0,.3,3.1,6.2})do for _,pitch in ipairs({-1.55,0,1.55})do for _,roll in ipairs({-3.1,-.7,0,.8,3.1})do
 local pose={heading=heading,pitch=pitch,roll=roll};local frame=f.from_pose(pose)
 local body={.7,.4,-.2};local world=f.world(frame,body);local recovered=f.body(frame,world)
 for k=1,3 do assert(math.abs(recovered[k]-body[k])<1e-10)end
 local range=math.sqrt(.7^2+.4^2+.2^2)
 local observation={range=range,az=math.atan2(-.2,.7),el=math.atan2(.4,math.sqrt(.7^2+.2^2))}
 pose.north=0;pose.east=0;pose.altitude=0;display.world_observation(observation,pose)
 assert(math.abs(world[1]-observation.north)<1e-10 and math.abs(world[2]-observation.altitude)<1e-10 and math.abs(world[3]-observation.east)<1e-10)
end end end
local a=f.from_pose({heading=6.28,pitch=.2,roll=3.13});local b=f.from_pose({heading=.003,pitch=.2,roll=-3.13})
local mid=f.at({{time=1,frame=a},{time=1.02,frame=b}},1.01);assert(mid)
local v={1,.2,-.4};local round=f.body(mid,f.world(mid,v));for k=1,3 do assert(math.abs(round[k]-v[k])<1e-10)end
assert(not f.at({{time=1,frame=a},{time=1.02,frame=b}},.9))
local history={{time=1,position={100,5000,20}},{time=1.02,position={104,5001,18}}}
local point=f.position_at(history,1.01)
assert(math.abs(point[1]-102)<1e-10 and math.abs(point[2]-5000.5)<1e-10)
point=f.position_at(history,1.025)
assert(math.abs(point[1]-105)<1e-10 and math.abs(point[3]-17.5)<1e-10)
assert(not f.position_at(history,.99) and not f.position_at(history,1.031))
assert(not f.position_at({{time=1},{time=1.02}},1.01),'missing position history fabricated a pose')

''')
print('Gun frames: radar-axis agreement, rigid transport, bank/heading wrap and interpolation OK')
