"""Current radar physical/array authority; no second sensing/processing owner."""
from radar_test_runtime import ns, owned_runtime

lua = ns['runtime']()
lua.execute(r'''
local Resource=dofile(SCRIPT_ROOT..'Systems/Radar_Resource.lua')
local function fixture()
 local v={EFM_POWER_OWNER=1,EFM_PHYSICAL_VALID=1,EFM_PHYSICAL_GENERATION=2,
  EFM_PHYSICAL_STAMP=5,EFM_PHYSICAL_CLOCK_KIND=1,F22_AP_CLOCK=5,
  EFM_MISSION_POWER_AVAILABLE=1,F22_ELECTRICAL_VALID=1,EFM_ENVIRONMENT_VALID=1,
  EFM_EQUIPMENT_TEMP_C=60,EFM_THERMAL_FAULT=0,F22_AESA_ARRAY_KNOWN=1,F22_AESA_ARRAY_HEALTH=1}
 local function get(n)return v[n]or 0 end
 return Resource.new(get),v,get
end
local r,v=fixture()
-- MAIN POWER and the removed optional resource publication confer no authority.
v.EFM_POWER_OWNER=0;v.MAIN_POWER=1;v.F22_RADAR_RESOURCE_SCHEMA=1
v.F22_RADAR_RESOURCE_VALID=1;v.F22_RADAR_RESOURCE_SUPPLY=1
assert(r:update(28805,true)==0 and not r.health_known)
v.EFM_POWER_OWNER=1
assert(r:update(28805,true)==1 and r.health_known)
v.EFM_MISSION_POWER_AVAILABLE=0
assert(r:update(28805,true)==0 and r.power_known,'APU-only power enabled radar')
v.EFM_MISSION_POWER_AVAILABLE=1;v.F22_ELECTRICAL_VALID=0
assert(r:update(28805,true)==0)
v.F22_ELECTRICAL_VALID=1;v.EFM_EQUIPMENT_TEMP_C=80
assert(r:update(28805,true)==.5)
v.F22_AESA_ARRAY_HEALTH=.3
assert(r:update(28805,true)==.3)
v.EFM_THERMAL_FAULT=1
assert(r:update(28805,true)==0)
v.EFM_THERMAL_FAULT=0
assert(r:update(28805,false)==0)
-- Invalid/missing current inputs cannot silently become a healthy resource.
for key,bad in pairs({EFM_POWER_OWNER=0,EFM_PHYSICAL_VALID=0,EFM_PHYSICAL_GENERATION=1.5,
 EFM_PHYSICAL_CLOCK_KIND=2,EFM_PHYSICAL_STAMP=4,F22_AP_CLOCK=6,
 EFM_MISSION_POWER_AVAILABLE=2,F22_ELECTRICAL_VALID=-1,EFM_ENVIRONMENT_VALID=0,
 EFM_EQUIPMENT_TEMP_C=0/0,EFM_THERMAL_FAULT=2,F22_AESA_ARRAY_KNOWN=0,
 F22_AESA_ARRAY_HEALTH=1.1})do
 local a,w=fixture();w[key]=bad
 assert(a:update(28805,true)==0 and not a.health_known,key)
end
for _,bad in ipairs({-1,0/0,math.huge})do
 local a,w=fixture();w.F22_AESA_ARRAY_HEALTH=bad
 assert(a:update(28805,true)==0 and not a.array_known)
end
local a,w,get=fixture();local reads=0
local torn=Resource.new(function(n)
 if n=='EFM_PHYSICAL_GENERATION'then reads=reads+1;if reads>1 then return 3 end end
 return get(n)
end)
reads=0
assert(torn:update(28805,true)==0,'torn physical envelope accepted')
-- Different World/spawn epochs are valid. A paused World does not age a sample;
-- both physical clock and stamp stopping while World advances withdraws it.
r,v=fixture();assert(r:update(28805,true)==1)
for _=1,30 do assert(r:update(28805,true)==1)end
assert(r:update(28805.26,true)==0 and not r.health_known)
v.F22_AP_CLOCK=5.3;v.EFM_PHYSICAL_STAMP=5.3
assert(r:update(28805.3,true)==1)
assert(r:update(1,true)==0 and r:update(1.1,true)==0,'rewind reused old physical evidence')
v.F22_AP_CLOCK=5.4;v.EFM_PHYSICAL_STAMP=5.4
assert(r:update(1.2,true)==1)
v.EFM_POWER_OWNER=0;v.MAIN_POWER=1
assert(r:update(1.2,true)==0)
local output={};r:publish(function(n,x)output[n]=x end)
assert(output.F22_RADAR_SERVICE_HEALTH_KNOWN==0 and output.F22_RADAR_SERVICE_RESOURCE==0)
assert(output.F22_RADAR_RESOURCE_POWER_KNOWN==0 and output.F22_RADAR_SERVICE_STATE==0)
''')
print('Radar resource: current physical/array owners, mission power, thermal/damage, torn/stale/stopped clocks and recovery PASS')

lua = owned_runtime()
lua.execute(r'''
f.measure(42);f.tick();f.now=f.now+.1;f.measure(42);f.tick()
SetCommand(10605,1);f.tick();f.now=f.now+.1;f.measure(42);f.tick()
assert(f.get('F22_RADAR_STT_VALID')==1 and f.get('F22_RADAR_SUPPORT_ENABLED')==1)
local clock=get_model_time
for _,bad in ipairs({'missing','throws','nan','negative'})do
 if bad=='missing'then get_model_time=nil
 elseif bad=='throws'then get_model_time=function()error('unavailable')end
 elseif bad=='nan'then get_model_time=function()return 0/0 end
 else get_model_time=function()return -1 end end
 f.update()
 for _,key in ipairs({'F22_AESA_REQUEST','F22_AESA_CONTROL_EMIT','F22_RADAR_BACKEND_READY',
  'F22_RADAR_STT_VALID','F22_RADAR_SUPPORT_ENABLED','F22_RADAR_DESIGNATION_VALID',
  'F22_RADAR_SELECTED_VALID','F22_RADAR_TRACK_COUNT','F22_SCOPE_01_VALID'})do
  assert(f.get(key)==0,bad..' clock retained '..key)
 end
end
get_model_time=clock;f.now=f.now+.1;f.generation=(f.generation or 1)+1;f.measure(42);f.tick()
assert(f.get('F22_AESA_REQUEST')==1 and f.get('F22_RADAR_STT_VALID')==0)
-- The current owner is mandatory even before its first publication.
test_radar_physical.enabled=false;f.put('EFM_POWER_OWNER',0);f.tick()
assert(f.get('F22_AESA_REQUEST')==0 and f.get('F22_RADAR_SUPPORT_ENABLED')==0)
''')
print('Radar owner: clock loss withdraws emission/track/weapon authority, fresh recovery and missing physical owner PASS')

lua = ns['runtime']()
lua.execute(r'''
local module=dofile(SCRIPT_ROOT..'Systems/Radar_Computer.lua')
local r=module.new();r.power=true;r:command('tws')
local o={native_id=1,range=10000,az=0,el=0,age=0}
r:update(.1,{o},1);r:update(1,{o},1)
assert(r:supportable(r.tracks[1]))
r:update(7,{},1);r:update(.1,{o},1)
assert(r.tracks[1].hits==1 and not r:supportable(r.tracks[1]),'reacquisition retained mature weapon authority')
r:update(.1,{o},1);assert(r:supportable(r.tracks[1]))
for _=1,1000 do r:update(.02,{o},1)end
assert(r.tracks[1].hits==module.maximum_hits)
for i=2,100 do r:update(.02,{{native_id=i,range=10000,az=0,el=0,age=0}},1)end
local count=0;for _ in pairs(r.tracks)do count=count+1 end
assert(count==64,'retained file store exceeded its declared capacity')
''')
print('Track owner: freshness-gap reacquisition, bounded hit counter and 64-file retention PASS')
