"""Historical native results lack the paired v2 target-state packet.
The fixture remains original evidence; a new consumer must reject its missing
state rather than invent a matching target from the next radar report.
The .4m/s uncertainty is a declared harness value, not historical sensor data.
"""
import csv
from pathlib import Path
from lupa.lua51 import LuaRuntime
ROOT=Path(__file__).resolve().parents[1]
lua=LuaRuntime();lua.globals().ROOT=(ROOT/'Cockpit/Scripts').as_posix()+'/'
lua.execute('''
LockOn_Options={script_path=ROOT};values={F22_STT_VELOCITY_SIGMA_MPS=.4};now=0;pending=nil
function get_model_time()return now end
local function get(k)return values[k]or 0 end
local function put(k,v)values[k]=v end
local sensors={getSelfCoordinates=function()return values.north_m,values.altitude_m,values.east_m end,
 getHeading=function()return-values.heading_rad end,getPitch=function()return values.pitch_rad end,getRoll=function()return values.roll_rad end}
local function dispatch(_,command)
 assert(command==10851);assert(not pending,'request overwrite')
 pending={sequence=get('F22_GUN_REQUEST_SEQUENCE'),time=get('F22_GUN_REQUEST_TIME'),id=get('F22_GUN_TRACK_ID')}
end
local d=dofile(ROOT..'Systems/Gun_Director.lua').new(sensors,get,put,dispatch,dofile(ROOT..'Systems/Radar_Display.lua'),15)
function step()
 if pending then
  put('F22_GUN_RESPONSE_SEQUENCE',pending.sequence);put('F22_GUN_SOLUTION_SEQUENCE',pending.sequence)
  local valid=get('F22_GUN_RESULT_TIME')>=pending.time and get('F22_GUN_RESULT_TRACK_ID')==pending.id and get('F22_GUN_SOLVER_REASON')==0
  put('F22_GUN_SOLUTION_VALID',valid and 1 or 0);pending=nil
 end
 local a,e=d:update(values.HUD_MODE==5)
 return a~=nil,get('F22_GUN_DISPLAY_REASON')
end
''')
count=0;reasons={}
with (ROOT/'tests/fixtures/gun_deferred_pursuit.csv').open()as f:
 rows=list(csv.DictReader(f))
for row in rows:
 for key,value in row.items():lua.globals()["values"][key]=float(value)
 lua.globals().now=float(row['t_model_s'])
 valid,reason=lua.globals().step();count+=valid;reasons[reason]=reasons.get(reason,0)+1
assert count==0,(count,len(rows),reasons)
print(f'Historical pursuit: {len(rows)} schema1/unversioned native results cannot invent a schema2 target packet PASS')
