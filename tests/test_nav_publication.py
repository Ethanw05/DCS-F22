"""A page refresh cannot publish a half-written navigation frame to AFCS."""
from pathlib import Path
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
lua = LuaRuntime()
lua.globals().MODULE = (ROOT / 'Cockpit/Scripts/Systems/Nav_Publication.lua').as_posix()
lua.execute(r'''
local values={F22_NAV_STEER_VALID=1,F22_NAV_STEER_TRACK=0,F22_NAV_STEER_STAMP=10,
 F22_NAV_SOURCE=0,F22_NAV_ARRIVED=0,F22_NAV_OBS=0}
local watching=false
local function get(key)return values[key]or 0 end
local function put(key,value)
 if watching and key~='F22_NAV_SNAPSHOT_SEQUENCE'then
  assert(values.F22_NAV_SNAPSHOT_SEQUENCE==1)
  assert(values.F22_NAV_SNAPSHOT_1_TRACK==0 and values.F22_NAV_SNAPSHOT_1_TIME==10)
 end
 values[key]=value
end
local publisher=dofile(MODULE).new(get,put)
assert(publisher.publish() and values.F22_NAV_SNAPSHOT_SEQUENCE==1)
values.F22_NAV_STEER_TRACK=.5;values.F22_NAV_STEER_STAMP=11;values.F22_NAV_ARRIVED=1
watching=true;assert(publisher.publish());watching=false
assert(values.F22_NAV_SNAPSHOT_SEQUENCE==2 and values.F22_NAV_SNAPSHOT_0_TRACK==.5)
assert(values.F22_NAV_SNAPSHOT_0_TERMINAL==1)
values.F22_NAV_OBS=1;publisher.publish();assert(values.F22_NAV_SNAPSHOT_1_TERMINAL==0)
values.F22_NAV_STEER_VALID=0;publisher.publish();assert(values.F22_NAV_SNAPSHOT_0_VALID==0)
''')
print('Double-slot NAV publication: committed sequence last, zero track, arrival/course and invalid source PASS')
