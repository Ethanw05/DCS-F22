"""Independent sensor ages, deterministic direction and loss-aware declutter."""
from test_display_startup import runtime
lua=runtime()
lua.execute('''
local Tracks=dofile(SCRIPT_ROOT..'Systems/Tactical_Tracks.lua')
local Defensive=dofile(SCRIPT_ROOT..'Systems/EW_Defensive.lua')
local D=dofile(SCRIPT_ROOT..'Systems/Tactical_Declutter.lua')
local s=Tracks.new()
local function batch(sequence,time,contacts)return {sequence=sequence,time=time,contacts=contacts}end
s:update(8,{radar=batch(1,8,{{source=1,age=0,az=.1,el=0,range=1852}}),
 rf=batch(1,8,{{source=1,age=8,az=.2,el=0,signal=3}})},true)
local t=s.contacts[1]
assert(t.age==0 and t.radar_age==0 and t.rf_age==8 and t.rf_coast)
assert(t.threat_priority==1,'fresh radar renewed old launch-warning priority')
local v={};local d=Defensive.new(function(k,x)v[k]=x end,function()return 100 end)
d.now=8;d:update(s.contacts,false)
assert(v.F22_DEFENSIVE_AGE==8 and v.F22_DEFENSIVE_RF_AGE==8 and v.F22_DEFENSIVE_RANGE_AGE==0)
assert(v.F22_DEFENSIVE_COAST==1 and v.F22_DEFENSIVE_RANGE_VALID==1)
assert(v.F22_DEFENSIVE_DIRECTION_SOURCE==2)
-- A new optical sighting renews its own field, not the remembered RF signal.
s:update(8.1,{mws=batch(1,8.1,{{source=1,age=0,az=.3,el=.1}})},true)
t=s.contacts[1];assert(t.optical_age==0 and t.rf_age>8 and t.threat_priority==4)
d.now=8.1;d:update(s.contacts,false)
assert(v.F22_DEFENSIVE_AGE==0 and v.F22_DEFENSIVE_RF_AGE>8 and v.F22_DEFENSIVE_DIRECTION_SOURCE==4)
-- Coasting optical memory cannot starve a genuinely fresh RF launch warning.
s:update(9,{rf=batch(2,9,{{source=2,age=0,az=1,el=0,signal=3}})},true)
assert(s.contacts[1].source==2 and s.contacts[1].threat_priority==3)
-- New sequence with a regressed snapshot timestamp cannot replace fresh data.
s:update(9.1,{rf=batch(3,8.95,{{source=3,age=0,az=0,el=0,signal=1}})},true)
assert(s.contacts[1].source==2,'out-of-order publication replaced newer warning data')
-- Equal-time direction selection is explicit, independent of table iteration.
for i=1,10 do
 s=Tracks.new();s:update(5,{rf=batch(i,5,{{source=9,age=0,az=.1,el=0,signal=1}}),
 mws=batch(i,5,{{source=9,age=0,az=.2,el=0}})},true)
 assert(s.contacts[1].direction_sensor=='mws')
end
-- Clustering preserves each track elsewhere and never combines incompatible
-- identities, sensor glyphs, or fresh and coast state into a single cue.
local candidates={}
for i=1,12 do candidates[i]={source=i,angle=math.rad(i*.3),optical=false,affiliation=-1,coast=false}end
local clusters,omitted=D.group(candidates)
assert(#clusters==1 and clusters[1].count==12 and omitted==0 and #candidates==12)
candidates[#candidates+1]={source=20,angle=.01,optical=false,affiliation=1,coast=false}
candidates[#candidates+1]={source=21,angle=.01,optical=true,affiliation=-1,coast=false}
candidates[#candidates+1]={source=22,angle=.01,optical=false,affiliation=-1,coast=true}
clusters=D.group(candidates);assert(#clusters==4)
-- Angle wrap is geometric, not two independent edges of the bearing ring.
clusters=D.group({{angle=math.rad(179),optical=false,affiliation=-1,coast=false},
 {angle=math.rad(-179),optical=false,affiliation=-1,coast=false}})
assert(#clusters==1 and clusters[1].count==2)
local separated={}
for i=1,12 do separated[i]={angle=math.rad(i*30),optical=false,affiliation=-1,coast=false}end
clusters,omitted=D.group(separated);assert(#clusters==12 and omitted==4)
-- Actual TSD publication preserves the store's contacts while showing a
-- counted cluster. Fresh optical, friendly and coast evidence stay distinct.
local TSD=dofile(SCRIPT_ROOT..'Systems/Tactical_Situation.lua')
local values={F22_RADAR_RANGE_NM=20}
local view=TSD.new(function(k)return values[k]or 0 end,function(k,x)values[k]=x end,
 {getHeading=function()return 0 end,getPitch=function()return 0 end,getRoll=function()return 0 end})
local tracks={}
for i=1,12 do tracks[i]={source=i,signal=2,affiliation=-1,observations={rf={time=10,az=i*.003,el=0}}}end
view:update(10,tracks,true)
assert(values.F22_TSD_BEARING_TOTAL==12 and values.F22_TSD_BEARING_SHOWN==1)
assert(values.F22_TSD_BEARING_01_COUNT==12 and values.F22_TSD_BEARING_01_EXTRA_COUNT==11 and #tracks==12)
tracks[13]={source=100,signal=2,affiliation=1,observations={rf={time=10,az=.01,el=0}}}
tracks[14]={source=101,signal=0,optical=true,affiliation=-1,observations={mws={time=10,az=.01,el=0}}}
tracks[15]={source=102,signal=2,affiliation=-1,observations={rf={time=0,az=.01,el=0}}}
view:update(10,tracks,true)
assert(values.F22_TSD_BEARING_TOTAL==15 and values.F22_TSD_BEARING_SHOWN==4 and #tracks==15)
assert(values.F22_TSD_BEARING_01_SOURCE==101 and values.F22_TSD_BEARING_01_OPTICAL==1)
''')
print('Tactical provenance: independent RF/IR/range ages, evidence priority, chronology, deterministic direction and loss-aware clustering PASS')
