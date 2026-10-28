"""Sensor-scoped track IDs correlate through data, not equal simulator labels."""
from test_display_startup import runtime
lua = runtime()
lua.execute(r'''
local Tracks=dofile(SCRIPT_ROOT..'Systems/Tactical_Tracks.lua')
local function batch(sequence,time,contacts)return {sequence=sequence,time=time,contacts=contacts}end
local store=Tracks.new()
store:update(10,{radar=batch(1,10,{{source=7,age=0,az=.2,el=0,range=20000}}),
 rf=batch(1,10,{{source=70001,age=0,az=.21,el=0,signal=2}})},true)
assert(#store.contacts==1 and store.contacts[1].mask==3)
local identity=store.contacts[1].source
store:update(10.1,{radar=batch(2,10.1,{{source=7,age=0,az=.2,el=0,range=20000}}),
 rf=batch(2,10.1,{{source=70001,age=0,az=-.6,el=0,signal=2}})},true)
assert(#store.contacts==2,'previous identity bypassed current geometry')
assert(store.contacts[2].source==identity)
-- Equal numeric IDs and incompatible geometry are separate observations.
store=Tracks.new()
store:update(20,{radar=batch(1,20,{{source=42,age=0,az=.2,el=0,range=20000}}),
 rf=batch(1,20,{{source=42,age=0,az=-.6,el=0,signal=2}})},true)
assert(#store.contacts==2 and store.contacts[1].source~=store.contacts[2].source)
-- A bearing cannot choose between two closely spaced radar targets.
store=Tracks.new()
store:update(20,{radar=batch(1,20,{{source=1,age=0,az=.2,el=0,range=20000},
 {source=2,age=0,az=.22,el=0,range=25000}}),
 rf=batch(1,20,{{source=1,age=0,az=.21,el=0,signal=2}})},true)
assert(#store.contacts==3)
for _,track in ipairs(store.contacts)do assert(track.mask==1 or track.mask==2)end
local function radar(source,n)return {source=source,age=0,az=0,el=0,range=n,n=n,u=3000,e=0,vn=100,vu=0,ve=0,friendly=true}end
local function donor(reporter,n,known)return {source=1,age=1,az=0,el=0,n=n,u=3000,e=0,vn=100,vu=0,ve=0,
 reporter=reporter,link=1,epoch=2,observation_known=known,received=30,time=29,hostile=true}end
store=Tracks.new()
store:update(30,{radar=batch(1,30,{radar(77,20000)}),datalink=batch(1,30,{donor(100,19900,true)})},true)
assert(#store.contacts==1 and store.contacts[1].mask==9)
assert(store.contacts[1].identity_conflict and store.contacts[1].friendly_protected)
assert(store.contacts[1].observations.radar.source==77 and store.contacts[1].datalink.source==1)
store=Tracks.new()
store:update(30,{radar=batch(1,30,{radar(77,20000)}),datalink=batch(1,30,{donor(100,19900,false)})},true)
assert(#store.contacts==2,'unknown sample epoch granted identity correlation')
store=Tracks.new()
store:update(30,{datalink=batch(1,30,{donor(100,20000,true),donor(101,40000,true)})},true)
assert(#store.contacts==2,'different reporters sharing track1 overwrote each other')
assert(store.contacts[1].datalink.reporter~=store.contacts[2].datalink.reporter)
''')
print('Tactical association: different/equal IDs, geometry divergence, ambiguous bearing, qualified/unknown donor and reporter namespaces PASS')
