"""Preplanned partitions replace atomically and never act on live systems."""
from pathlib import Path
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
lua = LuaRuntime(unpack_returned_tuples=True)
lua.globals().MODULE = (ROOT / 'Cockpit/Scripts/Systems/Mission_Data.lua').as_posix()
lua.execute(r'''
local M=dofile(MODULE);local state=M.new()
local route={{x=0,y=0,alt=100},{x=1000,y=2000,alt=-100,alt_type='BARO',name='BELOW SEA'}}
local envelope={schema=1,source='TEST MISSION',date='2026-10-27',items=route}
local accepted,partition=state:replace('route',envelope)
assert(accepted and #partition.items==2 and partition.items[2].alt==-100)
route[2].x=0/0
assert(not state:replace('route',envelope))
assert(state.partitions.route==partition and partition.items[2].x==1000,'invalid route replaced or aliased the accepted partition')
route[2].x=1e8;assert(not state:replace('route',envelope))
route[2].x=2000;assert(state:replace('route',envelope))
assert(state.partitions.route.generation==2)
envelope.items={{n=100,e=200,radius_m=300,label='PLANNED'}}
assert(state:replace('planned_zones',envelope))
assert(state.partitions.planned_zones.items[1].planned==true)
envelope.items[1].radius_m=-1
assert(not state:replace('planned_zones',envelope))
assert(state.partitions.planned_zones.items[1].radius_m==300)
envelope.items={{radio=1,hz=251000000,modulation='AM'}}
assert(state:replace('radio_presets',envelope))
envelope.items[1].hz=0;assert(not state:replace('radio_presets',envelope))
assert(state.partitions.radio_presets.items[1].hz==251000000)
assert(not state:replace('live_tracks',envelope),'mission data acquired live sensor authority')
envelope.schema=99;assert(not state:replace('radio_presets',envelope))
envelope.schema=1;envelope.items={[1000]={x=1,y=1}}
assert(not state:replace('route',envelope),'sparse input silently replaced the route with empty data')
assert(state.partitions.route.items[2].x==2000,'independent bad partition corrupted the route')
''')
print('Mission data: bounded schema, atomic validation, provenance, signed elevation and separate planned/live authority PASS')
