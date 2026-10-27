"""Observed Hornet onset/45-degree truth table, including unsafe roll guidance."""
from pathlib import Path
from lupa.lua51 import LuaRuntime
lua=LuaRuntime()
root=Path(__file__).resolve().parents[1]
lua.globals().ROOT=(root/'Cockpit/Scripts').as_posix()+'/'
lua.execute('''
local D=dofile(ROOT..'Systems/Terrain_Director.lua')
local d=D.new()
assert(not d:update(10,false,true,math.rad(80)).threat)
local r=d:update(11,true,true,math.rad(80))
assert(r.mode==0 and r.call=='roll_left','vertical became unsafe last: roll must survive the unsafe boundary')
assert(d:update(11.1,true,true,math.rad(-80)).call=='roll_right')
for _,bank in ipairs({-45,0,45})do assert(d:update(11.2,true,true,math.rad(bank)).call=='pull_up')end
assert(d:update(11.3,true,true,math.rad(45.001)).call=='roll_left')
assert(d:update(11.4,true,true,math.rad(-45.001)).call=='roll_right')
d=D.new();d:update(20,true,false,math.rad(80));r=d:update(21,true,true,math.rad(80))
assert(r.mode==1 and r.call=='pull_up','oblique became unsafe last: retain bank and pull')
d=D.new();r=d:update(30,true,true,math.rad(80))
assert(r.mode==1 and r.call=='pull_up','native equal-onset tie selects oblique')
assert(not d:update(31,false,true,math.rad(80)).threat)
r=d:update(32,true,true,math.rad(80));assert(r.mode==0 and r.call=='roll_left','cleared path did not rearm its onset')
r=d:update(1,true,true,math.rad(80));assert(r.mode==1,'rewind retained a previous flight onset')
''')
print('Hornet director: later unsafe onset, equal-onset oblique tie, strict 45-degree threshold, mirrored bank, rearm and rewind PASS')
