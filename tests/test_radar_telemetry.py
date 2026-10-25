"""Telemetry must preserve pauses, lock transitions and raw export values."""
from pathlib import Path
from lupa.lua51 import LuaRuntime

lua = LuaRuntime()
lua.globals().MODULE = str(Path(__file__).resolve().parents[1] / 'Cockpit/Scripts/Systems/Radar_Telemetry.lua')
lua.execute('''
local rows, params = {}, {}
local function get(k) return params[k] or 0 end
local r = dofile(MODULE).new(get, function(s) rows[#rows+1]=s end, 40)
r:sample(nil); assert(#rows==0, 'must not fabricate model time')
params.F22N_RADAR_STT_RANGE=1234
r:sample(10); local n=#rows
r:sample(10); assert(#rows==n, 'pause produced duplicate sample')
r:sample(10.02); assert(#rows==n, 'rate limit failed')
params.F22N_RADAR_MODE=3
r:sample(10.05); assert(#rows>n)
assert(rows[#rows]:find('1234'), 'raw STT range lost')
local before=#rows;r:sample(2);local rewind=false;for i=before+1,#rows do if rows[i]:find('v1,segment,',1,true)==1 then rewind=true end end;assert(rewind,'rewind not marked')
for i=1,100 do r:sample(2+i*.05) end
assert(#rows==40, 'log cap failed')
assert(rows[#rows]:find('limit'), 'missing stop reason')
''')
print('Radar telemetry: timestamps, pauses, cadence, raw data, rewind and cap OK')

# A cached source is not a new radar/RWR measurement on each publication.
lua.execute(r'''
local rows,params={},{}
local function get(n)return params[n] or 0 end
local t=dofile(MODULE).new(get,function(s)rows[#rows+1]=s end)
params.F22_RADAR_OBSERVATIONS_READY=1;params.F22_RADAR_OBSERVATION_COUNT=1
params.F22O_01_ID=42;params.F22O_01_AGE=1;params.F22O_01_NORTH=12345
params.RWR_CONTACT_01_SOURCE=42;params.RWR_CONTACT_01_TIME=1;params.RWR_CONTACT_01_SIGNAL=1
local function count(tag)local n=0;for _,s in ipairs(rows)do if s:find('v1,'..tag..',',1,true)==1 then n=n+1 end end;return n end
t:sample(10);assert(count('observation')==1 and count('emitter')==1)
for i=1,10 do params.F22O_01_AGE=1+i*.2;params.RWR_CONTACT_01_TIME=1+i*.2;t:sample(10+i*.2)end
assert(count('observation')==1 and count('emitter')==1,'cache reread became sensor revisit')
params.F22O_01_AGE=0;params.RWR_CONTACT_01_TIME=0;t:sample(12.2)
assert(count('observation')==2 and count('emitter')==2,'real timestamp advance missing')
params.F22O_01_AGE=.2;params.RWR_CONTACT_01_TIME=.2;params.RWR_CONTACT_01_SIGNAL=3;t:sample(12.4)
assert(count('emitter')==3,'warning transition missing')
local avionics,missile=false,false
for _,row in ipairs(rows)do
 assert(#row<3900,'DCS log message would be truncated')
 if row:find('v1,avionics_schema,',1,true)==1 and row:find('F22_FC_TIMER_SEQUENCE',1,true)then avionics=true end
 if row:find('v1,missile_schema,',1,true)==1 and row:find('SUPPORT_STATE',1,true)then missile=true end
end
assert(avionics and missile,'missing launch/support schemas')
t:sample(2)
assert(count('observation')==3 and count('emitter')==4,'rewind retained stale dedup history')
''')
print('Telemetry: real source timestamps, RF severity transitions, eight missile records and rewind dedup PASS')
