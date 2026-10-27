"""Measured-field provenance, source loss and defensive inspection contracts."""
from test_display_startup import runtime

lua=runtime()
lua.execute('''
local Tracks=dofile(SCRIPT_ROOT..'Systems/Tactical_Tracks.lua')
local s=Tracks.new()
local function batch(seq,time,contacts)return {sequence=seq,time=time,contacts=contacts}end
local radar={source=10,age=0,az=.3,el=.1,range=18520,selected=true,friendly=true}
local rf={source=10,age=0,az=.31,el=.11,signal=2,label='29'}
local ir={source=20,age=0,az=-.5,el=0}
s:update(10,{radar=batch(1,10,{radar}),rf=batch(1,10,{rf}),mws=batch(1,10,{ir})},true)
assert(#s.contacts==2 and s.contacts[1].source==10)
local t=s.contacts[1]
assert(t.mask==3 and t.range==18520 and t.affiliation==1 and t.signal==2)
assert(t.observations.radar.time==10 and t.uncertainty==nil)
assert(s.contacts[2].range==nil and s.contacts[2].mask==4)
-- Frozen producer snapshots never refresh measurements.
for tick=1,140 do
 local now=10+tick*.05
 s:update(now,{radar=batch(1,now,{radar}),rf=batch(tick+1,now,{{source=10,age=0,az=.4,el=0,signal=1}})},true)
end
assert(#s.contacts==1 and s.contacts[1].range==nil,'RF renewed old radar range')
assert(s.contacts[1].affiliation==1,'loss of fresh ranging erased retained positive ID')
assert(s.contacts[1].mask==3,'radar memory should survive range expiry')
s:update(31,{rf=batch(200,31,{{source=10,age=0,az=.4,el=0,signal=1}})},true)
assert(#s.contacts==1 and s.contacts[1].mask==2)
assert(s.contacts[1].affiliation==-1,'expired friendly evidence became hostile or permanent')
-- Similar bearing does not establish source identity or passive range.
s:update(31.05,{rf=batch(201,31.05,{{source=10,age=0,az=.4,el=0,signal=1},
 {source=11,age=0,az=.4,el=0,signal=1,range=9999}}),
 offboard=batch(1,31.05,{{source=12,age=0,az=0,el=0,range=1000}})},true)
assert(#s.contacts==2 and s.contacts[2].source==11 and s.contacts[2].range==nil)
-- Replacing a source snapshot with empty data clears only that source.
s:update(31.1,{rf=batch(202,31.1,{})},true);assert(#s.contacts==0)
s:update(1,{},true);assert(#s.contacts==0)
s:update(1,{rf=batch(1,1,{{source=1.5,age=0,az=0,el=0,signal=1},
 {source=2,age=0,az=0/0,el=0,signal=3}})},true);assert(#s.contacts==0)
s:update(2,{},false);assert(next(s.batches)==nil)

-- Range-independent radar producer exports even when a plot would be offscope.
local computer=dofile(SCRIPT_ROOT..'Systems/Radar_Computer.lua').new()
computer.clock=5;computer.power=true;computer.selected=7
computer.tracks={[7]={id=7,native_id=100,observed=5,hits=2,range=90000,az=1.2,el=.1,iff=1},
 [8]={id=8,native_id=101,observed=5,hits=2,range=80000,az=-1.3,el=0,iff=-1}}
local values={};local function put(k,v)assert(v~=nil);values[k]=v end
local Radar=dofile(SCRIPT_ROOT..'Systems/Radar_Tactical.lua')
Radar.publish(computer,put,true)
assert(values.F22_RADAR_TACTICAL_01_SELECTED==1 and values.F22_RADAR_TACTICAL_02_SOURCE==101)
assert(values.F22_RADAR_TACTICAL_02_VALID==1,'offscope target lost tactical identity')
Radar.publish(computer,put,false);assert(values.F22_RADAR_TACTICAL_01_VALID==0)
computer.mode='TWS';computer.native_mode=1;computer.clock=9
computer.tracks[7].current_az=0;computer.tracks[7].current_el=0;computer.tracks[7].current_range=90000
local plan=computer:scan_plan({100})
assert(plan.support_overdue==0 and plan.revisit_remaining==2,'support deadline ignores actual observation age')
computer.clock=12;plan=computer:scan_plan({100})
assert(plan.support_overdue==1 and plan.revisit_remaining==0,'overdue support falsely advertised fresh')

local picture=dofile(SCRIPT_ROOT..'Systems/Tactical_Picture.lua').new(function(k)return values[k]or 0 end,put)
picture:update(5,{{source=100,az=.4,el=0,age=0,signal=2,affiliation=-1}},true)
assert(values.F22_TACTICAL_COUNT==1 and values.F22_TACTICAL_01_RANGE_VALID==0)
-- Defensive selection persists by identity when priority changes/reorders.
local Defensive=dofile(SCRIPT_ROOT..'Systems/EW_Defensive.lua')
local d=Defensive.new(put,function()return 100 end);d.now=5
local a={source=1,age=0,az=.1,el=0,signal=1,mask=2,affiliation=-1,
 observations={rf={time=5,az=.1,el=0}}}
local b={source=2,age=0,az=.2,el=0,signal=3,mask=2,affiliation=-1,
 observations={rf={time=5,az=.2,el=0}}}
d:update({a,b},false);assert(values.F22_DEFENSIVE_SOURCE==2)
d:command(10906);d:update({a,b},false);assert(values.F22_DEFENSIVE_SOURCE==1)
d:update({b,a},false);assert(values.F22_DEFENSIVE_SOURCE==1)
assert(values.F22_DEFENSIVE_DETAIL==0,"photo overview must be the default")
d:command(10908);d:update({a,b},false);assert(values.F22_DEFENSIVE_DETAIL==1)
d:update({a,b},true);assert(values.F22_DEFENSIVE_SOURCE==2)
d:update({},false);assert(values.F22_DEFENSIVE_VALID==0)
''')
print('Tactical picture: source contracts, frozen snapshots, independent field loss, passive-only limits, offscope export and defensive inspection PASS')
lua=runtime()
lua.execute('''
function GetAspect()return .8 end
dofile(SCRIPT_ROOT..'MFD_RIGHT/rwr_page.lua')
dofile(SCRIPT_ROOT..'MFD_LEFT/attack_page.lua')
local names={}
for _,element in ipairs(elements)do assert(not names[element.name],'duplicate indicator element '..element.name);names[element.name]=true end
''')
print('Defensive/Attack formats: actual native-property proxy construction and unique element names PASS')
