"""Hornet-inspired recovery-boundary checks, not certified flight performance."""
from pathlib import Path
from lupa.lua51 import LuaRuntime

root = Path(__file__).resolve().parents[1]
lua = LuaRuntime()
lua.globals().ROOT = (root / 'Cockpit/Scripts').as_posix() + '/'
lua.execute('''
LockOn_Options={script_path=ROOT}
local E=dofile(ROOT..'Systems/Terrain_Escape.lua')
local flat=function()return 0 end
local function state()
 return {now=0,n=0,u=2000,e=0,vn=200,vu=0,ve=0,cas=200,nz=1,heading=0,roll=0}
end
-- A high-altitude tactical maneuver is not a reason to command recovery.
-- Exercise transient roll direction, inverted banks and actual pulling loads.
local checked=0
for _,cas in ipairs({140,200,300})do
 for _,bank in ipairs({-160,-100,-75,0,75,100,160})do
  for _,rate in ipairs({-120,0,120})do
   for _,nz in ipairs({0,1,3,6})do
    local s=state();s.cas=cas;s.vn=cas;s.roll=math.rad(bank)
    s.roll_rate=math.rad(rate);s.nz=nz
    local r=E.solve(s,flat)
    assert(r.valid and not r.threat,'recoverable high-altitude maneuver generated warning')
    assert(r.queries<=E.max_queries);checked=checked+1
   end
  end
 end
end
assert(checked==252)
-- Current-path intersection alone is insufficient when recovery is clear.
local s=state();s.u=1200;s.vu=-120;s.roll=math.rad(80)
local early=E.solve(s,flat)
assert(early.current.impact and early.recovery_margin and not early.call)
-- The exact current-bank ORT avoids a nuisance wings-level escape in a turn.
s=state();s.u=500;s.roll=math.rad(40)
local valley=function(n,e)if n>1000 and e<100 then return 2400 end return 0 end
local turn=E.solve(s,valley)
assert(turn.valid and not turn.threat and turn.paths[2].safe)
assert(turn.paths[2].direction==0,'holding bank must never command a roll')
local level
for _,p in ipairs(turn.paths)do if p.name=='level'then level=p end end
assert(level and not level.safe,'fixture must challenge wings-level recovery')
-- No broad altitude/combat-mode inhibit: a severe high-altitude dive warns.
s=state();s.u=1000;s.vn=150;s.vu=-250;s.cas=180
local dive=E.solve(s,flat)
assert(dive.valid and dive.threat and dive.call=='pull_up' and dive.no_escape)
print('Terrain nuisance: 252 maneuver snapshots, current-bank ORT, quiet spare recovery and severe dive PASS')
''')
