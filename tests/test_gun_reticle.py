"""Gun mark angular size, inherited aim and measured-range arc invariants."""
from pathlib import Path
from lupa.lua51 import LuaRuntime
lua=LuaRuntime()
lua.globals().MODULE=str(Path(__file__).resolve().parents[1]/'Cockpit/Scripts/HUD/gun_reticle.lua')
lua.execute('''
local lines,groups={},{}
local scale=.22
local api={layout_scale=scale,
 line=function(x1,y1,x2,y2,w,parent) lines[#lines+1]={x1,y1,x2,y2,w,parent} end,
 group=function(name,x,y,p,c,parent) groups[#groups+1]={name=name,x=x,y=y,p=p,c=c,parent=parent} end}
dofile(MODULE)(api,'ACTUAL_SIGHT')
-- Fine cross stays exactly at the supplied ballistic solution; no new lead offset.
for i=1,2 do
 local l=lines[i]
 assert(l[6]=='ACTUAL_SIGHT')
 assert(math.abs(l[1]+l[3])<1e-12 and math.abs(l[2]+l[4])<1e-12)
 assert(math.abs(math.sqrt((l[3]-l[1])^2+(l[4]-l[2])^2)*scale-.003)<1e-12)
end
local function segments(range)
 local n=0
 for _,g in ipairs(groups) do
  if g.p[1]=='F22N_RADAR_STT_RANGE' then
   local c=g.c[1];if range>=c[3] and range<=c[4] then n=n+1 end
  end
 end
 return n
end
assert(segments(0)==0 and segments(-1)==0)
assert(segments(1000)==16 and segments(2000)==32 and segments(10000)==32)
local validity=false
for _,g in ipairs(groups) do
 if g.p[1]=='HUD_GUN_TARGET_VALID' then validity=true;assert(g.parent=='ACTUAL_SIGHT') end
end
assert(validity,'range arc requires a valid range')
''')
print('Gun reticle: angular size, zero aim offset, valid-range gate and bounded arc OK')
