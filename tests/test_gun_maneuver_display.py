"""Counterfactual reference projection, no invented minimum width and no primary substitute."""
from pathlib import Path
from lupa.lua51 import LuaRuntime
lua=LuaRuntime();lua.globals().ROOT=(Path(__file__).resolve().parents[1]/'Cockpit/Scripts').as_posix()+'/'
lua.execute('''
LockOn_Options={script_path=ROOT}
local director=dofile(ROOT..'Systems/Gun_Director.lua');local Frames=dofile(ROOT..'Systems/Gun_Frames.lua')
local f=Frames.from_pose({heading=0,pitch=0,roll=0})
local cues={base={1,0,0},LOW={1,0,0},HIGH={1,.04,0},LEFT={1,0,.03},RIGHT={1,0,-.03}}
local p=director.project_maneuver(cues,{1,0,0},{1,0,0},{1,0,0},f)
assert(p and math.abs(p.LOW[1])<1e-10 and math.abs(p.LOW[2])<1e-10)
assert(p.HIGH[2]<0 and p.LEFT[1]<0 and p.RIGHT[1]>0,'reference displacement sign')
local lines,groups={},{}
local api={layout_scale=.22,
 line=function(...)lines[#lines+1]={...}end,
 static=function(...)end,
 group=function(name,x,y,params,controllers,parent)groups[name]={p=params,c=controllers,parent=parent}end}
dofile(ROOT..'HUD/gun_maneuver.lua')(api,'GUN_MODE',.04/.22)
local g=groups.HUD_GUN_MANEUVER
assert(g.parent=='GUN_MODE' and g.p[1]=='F22_GUN_MNV_SHOW' and g.p[2]=='HUD_GUN_NATIVE_VALID')
local first=groups.HUD_GUN_MNV_ARM_LEFT_0
assert(math.abs(first.c[1][3]-.0115)<1e-10,'physical gap; do not fabricate a minimum wing')
for _,line in ipairs(lines)do
 if line[6]=='HUD_GUN_MNV_ARM_LEFT_0' then assert(math.abs(line[1]*.22-.010)<1e-10)end
end
''')
print('Maneuver display: hypothetical-solution signs, primary-valid gate and clear centre OK')
