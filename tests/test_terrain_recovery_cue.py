"""Recovery direction follows current attitude and withdraws stale/invalid guidance."""
from test_display_startup import runtime
lua=runtime()
lua.execute('''
local C=dofile(SCRIPT_ROOT..'Systems/Terrain_Recovery_Cue.lua')
local function rad(x)return math.rad(x)end
local s={powered=true,valid=true,ground=false,now=10,roll=rad(60)}
local r={valid=true,threat=true,time=10,mode=0,escape_valid=false,best={safe=false,name='level',bank=0}}
local function check(angle,mode)
 local cue=C.evaluate(s,r)
 assert(cue.valid and math.abs(cue.rotation-rad(angle))<1e-8 and cue.mode==mode)
end
check(60,1);s.roll=rad(-60);check(-60,1)
s.now=10.1;s.roll=rad(-40);check(-40,1)
r.mode=1;r.best={safe=false,name='oblique',bank=rad(-40)};check(0,2)
s.roll=rad(50);check(0,2)
r.mode=0;s.roll=rad(140);check(140,1)
r.best.bank=0;r.best.name='level'
s.roll=rad(179);check(179,1);s.roll=rad(-179);check(-179,1)
for _,failure in ipairs({'power','ground','state','prediction','threat','stale','future','mode','nan'})do
 local a={powered=true,valid=true,ground=false,now=10.1,roll=0}
 local b={valid=true,threat=true,time=10,mode=0,escape_valid=false,best={safe=false,name='level',bank=0}}
 if failure=='power'then a.powered=false elseif failure=='ground'then a.ground=true
 elseif failure=='state'then a.valid=false elseif failure=='prediction'then b.valid=false
 elseif failure=='threat'then b.threat=false elseif failure=='stale'then a.now=10.251
 elseif failure=='future'then a.now=9.99 elseif failure=='mode'then b.mode=3
 else a.roll=0/0 end
 local cue=C.evaluate(a,b);assert(not cue.valid and cue.rotation==0 and cue.mode==0,failure)
end
''')
print('Terrain recovery cue: unsafe selected vertical/oblique paths, live attitude, inversion and validity withdrawal PASS')
