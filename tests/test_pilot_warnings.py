"""Warning policy under real-valued flight/terrain inputs, not display snapshots."""
from test_display_startup import runtime
lua=runtime()
lua.execute('''
local W=dofile(SCRIPT_ROOT..'Systems/Pilot_Warnings.lua')
local function state()
 local conditions={};for i=1,8 do conditions[i]={valid=true,active=false}end
 return {now=10,powered=true,valid=true,ground=false,airborne=true,gear=false,n=0,u=1000,e=0,
  vn=200,vu=0,ve=0,roll=0,heading=0,cas=200,nz=1,baro=4000,radar=700,baro_floor=0,radar_floor=500,
  baro_valid=true,radar_valid=true,conditions=conditions,fcs_valid=true,fcs_fault=false}
end
local function confirmed(policy,s,height)
 local result=policy:update(s,height)
 if result.event then policy:played(result.event,s.now,result.altitude_ticket)end
 return result
end
local flat=function()return 0 end
local s=state();assert(not W.terrain(s,flat),'level over flat terrain is safe')
s.u=200;s.vu=-120;assert(W.terrain(s,flat)=='pull_up')
s.u=200;s.roll=math.rad(80);assert(W.terrain(s,flat)=='pull_up','snapshot equal-onset recovery uses oblique')
s.roll=-math.rad(80);assert(W.terrain(s,flat)=='pull_up')
s.vu=120;assert(not W.terrain(s,flat),'climb away must not call PULL UP')
s=state();s.u=400;assert(W.terrain(s,function(n)return n>500 and 600 or 0 end))
assert(not W.terrain(s,function()return 0/0 end),'invalid terrain fails closed')
s.n=0/0;assert(not W.terrain(s,flat))
local w=W.new();s=state();confirmed(w,s,nil)
s.now=10.1;s.radar=490
local r=confirmed(w,s,nil);assert(r.event=='altitude'and r.text=='ALTITUDE')
s.now=10.2;r=confirmed(w,s,nil);assert(not r.event and r.text=='ALTITUDE','single crossing, persistent visual')
local repeats=0
for i=1,30 do s.now=10.2+i*.1;if confirmed(w,s,nil).event then repeats=repeats+1 end end
assert(repeats==1,'persistent radar-low did not repeat at the bounded voice cadence')
s.radar=550;s.now=14;confirmed(w,s,nil);s.radar=490;s.now=14.1;assert(confirmed(w,s,nil).event=='altitude','height above low index did not reset warning')
s.radar=650;s.now=15;confirmed(w,s,nil);s.radar=450;s.now=15.1;assert(confirmed(w,s,nil).event=='altitude')
w=W.new();s=state();s.radar=400;assert(confirmed(w,s,nil).event=='altitude','valid first activation below radar-low was suppressed')
s.radar=700;confirmed(w,s,nil);s.gear=true;s.radar=400;s.now=11;assert(not confirmed(w,s,nil).event)
w=W.new();s=state();s.radar_floor=0;s.baro_floor=500;s.baro=700;confirmed(w,s,nil)
s.now=11;s.baro=490;assert(confirmed(w,s,nil).event=='altitude')
s.now=15;s.baro=550;confirmed(w,s,nil);s.now=15.1;s.baro=490;assert(not confirmed(w,s,nil).event,'baro floor lost100ft rearm band')
s.now=16;s.baro=650;confirmed(w,s,nil);s.now=16.1;s.baro=490;assert(confirmed(w,s,nil).event=='altitude')
w=W.new();s=state();confirmed(w,s,nil);s.radar=400;s.now=11;s.missile_warning=true
r=confirmed(w,s,nil);assert(r.text=='ALTITUDE'and not r.event,'missile audio gets precedence')
s.now=12;s.missile_warning=false;assert(confirmed(w,s,nil).event=='altitude')
w=W.new();s=state();s.u=250;s.vu=-120;s.missile_warning=true
assert(not confirmed(w,s,flat).event,'terrain debounce');s.now=10.25
r=confirmed(w,s,flat);assert(r.event=='pull_up'and r.priority==3,'urgent terrain overrides missile audio')
w:acknowledge();s.now=13;assert(confirmed(w,s,flat).event=='pull_up','urgent recovery is not acknowledgeable')
w=W.new();s=state();s.conditions[1].active=true;s.conditions[1].valid=false;confirmed(w,s,nil)
s.now=12;assert(not confirmed(w,s,nil).event,'unknown control health is not a failure')
s.conditions[1].valid=true;confirmed(w,s,nil);s.now=12.6;assert(confirmed(w,s,nil).event=='flight_controls')
w:acknowledge();s.now=40;assert(not confirmed(w,s,nil).event)
s.ground=true;s.airborne=false;assert(confirmed(w,s,flat).priority==0)
s.ground=false;s.powered=false;assert(confirmed(w,s,flat).priority==0)
''')
print('Pilot warnings: terrain/recovery handedness, debounce, real fault validity, floor crossing/rearm, gear/power gates and audio priorities PASS')
