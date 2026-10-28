"""Actual completed-work consumer rejects replay, torn packets and epoch changes."""
from pathlib import Path
from lupa.lua51 import LuaRuntime
root=Path(__file__).resolve().parents[1]
lua=LuaRuntime()
lua.globals().ROOT=root.as_posix()
lua.execute('''
local values={F22_AESA_READY=1,F22_AESA_SEQUENCE=2,F22_AESA_GENERATION=1,F22_AESA_TIME=10,
 F22_AESA_SURFACE_DISCOVERY_SEQUENCE=0,F22_AESA_SURFACE_DISCOVERY_WORK=0}
local function get(n)return values[n]or 0 end
local source=dofile(ROOT..'/Cockpit/Scripts/Systems/AG_Radar_Collection.lua').new(get)
assert(source:sample(10)==0)
values.F22_AESA_SURFACE_SERVICE=0 -- Every short pulse has already ended.
values.F22_AESA_SURFACE_DISCOVERY_SEQUENCE=7;values.F22_AESA_SURFACE_DISCOVERY_WORK=7/308
assert(math.abs(source:sample(10)-7/308)<1e-12)
assert(source:sample(10)==0,'duplicate publication replayed RF work')
values.F22_AESA_SURFACE_SEQUENCE=40 -- Pointed/routine jobs do not change discovery work.
assert(source:sample(10)==0)
values.F22_AESA_SEQUENCE=3;values.F22_AESA_SURFACE_DISCOVERY_WORK=8/308
assert(source:sample(10)==0,'torn publication supplied RF work')
values.F22_AESA_SEQUENCE=4;assert(source:sample(10)==0,'recovery replayed unknown history')
values.F22_AESA_GENERATION=2;values.F22_AESA_SURFACE_DISCOVERY_WORK=0
values.F22_AESA_SURFACE_DISCOVERY_SEQUENCE=0;assert(source:sample(10)==0)
values.F22_AESA_SURFACE_DISCOVERY_WORK=1/308;values.F22_AESA_SURFACE_DISCOVERY_SEQUENCE=1
assert(math.abs(source:sample(10)-1/308)<1e-12)
values.F22_AESA_SURFACE_DISCOVERY_WORK=0/0;assert(source:sample(10)==0)
values.F22_AESA_SURFACE_DISCOVERY_WORK=100;assert(source:sample(11)==0,'stale source supplied work')
''')
print('Surface collection: missed pulses, fractional work, duplicate/pointed jobs, torn packets, generation, invalid and stale source PASS')
