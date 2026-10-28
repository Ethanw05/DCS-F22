"""Owned sensor retirement reaches selection, tactical fusion and DEF together."""
from test_display_startup import runtime

lua = runtime()
lua.execute(r'''
local Computer=dofile(SCRIPT_ROOT..'Systems/Radar_Computer.lua')
local Tactical=dofile(SCRIPT_ROOT..'Systems/Radar_Tactical.lua')
local Picture=dofile(SCRIPT_ROOT..'Systems/Tactical_Picture.lua')
local r=Computer.new();r:command('power');r:command('tws')
local function observed(id,range,age)
 return {native_id=id,range=range,az=.1,el=0,age=age or 0,measurement_source=2,
  type_name='MiG-29A',association_valid=true,filter_valid=true,velocity_valid=true,
  north=range,altitude=3000,east=0,vn=-100,vu=0,ve=0,
  position_sigma_m=50,velocity_sigma_mps=10}
end
local function count(t)local n=0;for _ in pairs(t)do n=n+1 end;return n end
local a,b=observed(11,30000),observed(12,40000)
r:update(.05,{a,b},1,true)
assert(count(r.tracks)==2 and #r.plots==2)
r.selected=1;r.secondary=2;r.acquire=true;r.acquire_id=1
-- Cached native files remain present while coasting; a missing update is
-- different from a coherent producer snapshot explicitly retiring a file.
a.age=.05;b.age=.05
r:update(.05,{b,a},1,true)
assert(count(r.tracks)==2 and r.selected==1)
r:update(.05,{},1,false)
assert(count(r.tracks)==2,'a temporary unavailable provider destroyed coast')
-- Producer retires11 and re-acquires another return under a new track number.
local c=observed(13,30100)
r:update(.05,{b,c},1,true)
assert(count(r.tracks)==2 and not r:source(11) and r:source(12) and r:source(13))
assert(not r.acquire and not r.acquire_id and r.selected==2 and not r.secondary)
local values={}
local function put(k,v)values[k]=v end
local function get(k)return values[k] or 0 end
Tactical.publish(r,put,true)
assert(values.F22_RADAR_TACTICAL_01_TYPE_NAME=='MiG-29A','type lost in presentation track owner')
local sensors={getHeading=function()return 0 end,getPitch=function()return 0 end,
 getRoll=function()return 0 end,getSelfCoordinates=function()return 0,3000,0 end}
local picture=Picture.new(get,put,sensors)
picture:update(r.clock,{},true)
assert(#picture.store.contacts==2 and picture.store.contacts[1].label=='29')
r:update(.05,{},1,true);Tactical.publish(r,put,true);picture:update(r.clock,{},true)
assert(count(r.tracks)==0 and #r.plots==0 and not r.selected)
assert(#picture.store.contacts==0,'retired native file persisted on DEF')
''')
print('Owned radar retirement: coast, source retirement, designation, DCS type and fused DEF withdrawal PASS')
