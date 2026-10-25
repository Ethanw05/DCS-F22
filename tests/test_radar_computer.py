"""Sensor-independent track/mode tests; no claim of DCS missile guidance."""
from pathlib import Path
from lupa.lua51 import LuaRuntime
lua=LuaRuntime(unpack_returned_tuples=True)
lua.globals().MODULE=str(Path(__file__).resolve().parents[1]/'Cockpit/Scripts/Systems/Radar_Computer.lua')
lua.execute('''
local module=dofile(MODULE)
local function obs(r,a,age) return {range=r,az=math.rad(a),el=0,age=age or 0,iff=-1} end
local function count(t) local n=0;for _ in pairs(t) do n=n+1 end;return n end
local r=module.new();r:command('power');r:command('tws')
r:update(.1,{obs(30000,-10),obs(40000,10)},1)
assert(count(r.tracks)==2)
local id1,id2=1,2
-- Export slots are reversed; target file IDs must not follow array index.
r:update(.1,{obs(39980,10),obs(29980,-10)},1)
assert(r.tracks[id1].az<0 and r.tracks[id2].az>0)
assert(r.tracks[id1].hits==2 and math.abs(r.tracks[id1].rate+200)<.001)
r.cursor_az=math.rad(-10);r.cursor_range=29980;r:command('designate')
assert(r.selected==id1 and not r.acquire,'first TWS press bugs a track')
r:command('designate');assert(r.acquire and not r.locked)
r:update(.1,{},2);assert(not r.locked,'acquisition must not claim STT')
r:update(.1,{},3);assert(r.locked and not r.acquire)
r:update(.1,{},1);assert(not r.locked and r.selected==id1,'loss retains a coasting designation without claiming lock')
-- Old native AGE increases each frame. It must not become fresh observations.
r=module.new();r:command('power');r:command('tws')
r:update(.1,{obs(30000,0,0)},1)
for i=1,8 do r:update(.1,{obs(30000,0,i*.1)},1) end
assert(r.tracks[1].hits==1,'aging echo promoted to track')
for i=1,210 do r:update(.1,{},1) end
assert(count(r.tracks)==0)
-- Duplicate sensor echoes cannot create two track files.
r:update(.1,{obs(30000,0),obs(30010,.05)},1);assert(count(r.tracks)==1)
r:command('undesignate');r:command('vertical')
r:update(.1,{{range=5000,az=0,el=math.rad(30),age=0}},1)
assert(r.acquire,'vertical acquisition omitted in-volume target')
r:command('undesignate');r:command('boresight')
r:update(.1,{{range=5000,az=0,el=math.rad(30),age=0}},1)
assert(not r.acquire and #r.plots==0,'boresight accepted high target')
r:update(.1,{obs(5000,0)},1);assert(r.acquire)
for i=1,45 do r:update(.1,{},2) end
assert(not r.acquire,'acquisition timeout missing')
r:command('range_down');r:command('range_down');r:command('range_down');assert(r:range()==18520)
r:command('power');r:update(.1,{obs(5000,0)},1)
assert(count(r.tracks)==0 and #r.plots==0)
''')
lua.execute("""
local module=dofile(MODULE)
for _,mode in ipairs({'vertical','boresight','wide'}) do
 for _,nm in ipairs({.1,.3,.7}) do
  local r=module.new();r:command('power');r:command(mode)
  r:update(.05,{{range=nm*1852,az=0,el=0,age=0}},1)
  assert(r.acquire,mode..' failed close-range acquisition at '..nm..' NM')
  r:update(.05,{},3);assert(r.locked)
  r:update(.05,{{range=nm*1852,az=0,el=0,age=0}},1)
  assert(r.acquire and not r.locked,mode..' failed automatic reacquisition')
 end
end
local d=dofile(MODULE:gsub('Radar_Computer','Radar_Display'))
for _,p in ipairs({{pitch=.4,roll=.7,heading=1,north=100,east=200,altitude=3000},{pitch=-.3,roll=-1.1,heading=3,north=-300,east=70,altitude=1200}}) do
 local o={range=2500,az=.12,el=.17}
 d.world_observation(o,p)
 local r,a,e=d.body_observation(o,p,0)
 assert(math.abs(r-2500)<1e-6 and math.abs(a-.12)<1e-6 and math.abs(e-.17)<1e-6,'body/world acquisition transform mismatch')
end
""")
print('Radar: slot reorder, TWS confirmation/bug, native STT/loss, age, duplicate echoes, VS/BORE, timeout, range and standby OK')

lua.execute("""
local module=dofile(MODULE)
local r=module.new();r:command('power');r:command('wide')
local function contact(id,range,age) return {native_id=id,range=range,az=0,el=0,age=age} end
r:update(.05,{contact(123,12964,0),contact(123,14000,.5)},1)
assert(#r.plots==1 and r.plots[1].range==12964,'history duplicated one native aircraft')
r:update(.05,{contact(123,12900,0),contact(456,12901,0)},2)
local n=0;for _ in pairs(r.tracks) do n=n+1 end
assert(n==2,'nearby distinct native aircraft merged')
assert(r.tracks[1].native_id==123 and r.tracks[1].range==12900,'native identity changed')
""")
print('Native contact identity: history deduplicated, nearby distinct aircraft preserved')

lua.execute("""
local r=dofile(MODULE).new();r:command('power');r:command('tws')
r:update(.05,{{native_id=123,range=12964,az=0,el=0,age=0}},1)
r:update(2,{},1);r:command('next_track')
assert(r.selected==1,'pilot could not select return between revisits')
r:command('designate');assert(r.acquire and not r.locked,'designation must request native confirmation')
""")
print('Manual selection between revisits requests acquisition without fabricating STT')
