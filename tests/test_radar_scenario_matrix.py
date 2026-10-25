"""Synthetic geometry/control matrix; native flight acceptance is separate."""
from pathlib import Path
from lupa.lua51 import LuaRuntime
lua=LuaRuntime()
lua.globals().ROOT=(Path(__file__).resolve().parents[1]/'Cockpit/Scripts/Systems').as_posix()+'/'
lua.execute(r'''
local module=dofile(ROOT..'Radar_Computer.lua');local d=dofile(ROOT..'Radar_Display.lua')
local tested,accepted=0,0;local totals={}
for _,mode in ipairs({'rws','tws','boresight','vertical','wide'})do
 totals[mode]={tested=0,accepted=0}
 for _,h in ipairs({0,90,180,359})do for _,pitch in ipairs({-15,0,20})do for _,roll in ipairs({-60,0,60})do
 local pose={north=10000,east=20000,altitude=10000,heading=math.rad(h),pitch=math.rad(pitch),roll=math.rad(roll)}
 for _,nm in ipairs({.1,3,10,40})do for _,az in ipairs({-61,-15,-1.6,0,1.6,15,61})do for _,el in ipairs({-14,-9,-1.6,0,1.6,25,47})do
 local o={range=nm*1852,az=math.rad(az),el=math.rad(el),age=0,native_id=123,iff=-1}
 d.world_observation(o,pose)
 if o.altitude>=200 then
 local rr,aa,ee=d.body_observation(o,pose,0)
 assert(math.abs(rr-o.range)<1e-6 and math.abs(aa-o.az)<1e-9 and math.abs(ee-o.el)<1e-9)
 local r=module.new();r:command('power');r:command(mode)
 if mode=='tws'then r:scan_plan({})end
 local p=r:profile();local allowed=nm<=r:range()/1852+1e-9
 if p then allowed=allowed and math.abs(az)<=p.az and el>=p.lo and el<=p.hi
 elseif mode=='tws'then local s=r.scan;allowed=allowed and math.abs(o.az-s.az)<=s.half_az and math.abs(o.el-s.el)<=s.half_el
 else allowed=allowed and math.abs(az)<=r.azimuth and math.abs(el)<=r.vertical_span/2 end
 r:update(.05,{o},1)
 assert((#r.plots==1)==allowed,mode..' volume failure')
 tested=tested+1;totals[mode].tested=totals[mode].tested+1
 if allowed then
 accepted=accepted+1;totals[mode].accepted=totals[mode].accepted+1
 r:geometry(d,pose);local t=r.tracks[1]
 assert(t and t.native_id==123 and math.abs(t.current_range-o.range)<1e-6)
 r.cursor_range=o.range;r.cursor_az=o.az
 if mode=='tws'then r:command('designate');assert(r.selected==1 and not r.acquire);r:command('designate');assert(r.acquire)
 elseif not p then r:command('designate');assert(r.acquire)
 else assert(r.acquire,'ACM acquisition omitted')end
 r:update(.05,{o},2);assert(not r.locked)
 r:update(.05,{o},3);assert(r.locked and not r.acquire)
 local stamp=t.observed;r:update(.5,{},1);assert(not r.locked and t.observed==stamp and r.selected==1)
 local turned={north=pose.north+50,east=pose.east-20,altitude=pose.altitude+10,heading=pose.heading+.2,pitch=pose.pitch+.1,roll=pose.roll-.2}
 r:geometry(d,turned);local pr,pa,pe=d.body_observation(t,turned,.5)
 assert(math.abs(t.current_range-pr)<1e-6 and math.abs(t.current_az-pa)<1e-9 and math.abs(t.current_el-pe)<1e-9)
 r:command('power');r:update(.05,{o},1);assert(next(r.tracks)==nil and not r.locked)
 end
 end
 end end end
 end end end
end
assert(tested>30000 and accepted>1000)
for _,mode in ipairs({'rws','tws','boresight','vertical','wide'})do print(string.format('Radar %s: %d geometry cases, %d accepted control/ACQ/STT chains PASS',mode,totals[mode].tested,totals[mode].accepted))end
print(string.format('Synthetic radar total: %d cases, %d accepted chains; native performance acceptance remains separate',tested,accepted))
''')
