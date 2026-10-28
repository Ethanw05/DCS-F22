"""No noisy radar velocity or derivative may enter the native weapon request."""
from pathlib import Path
import argparse
import subprocess
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--baseline')
args = parser.parse_args()
lua = LuaRuntime()
lua.globals().ROOT = (ROOT/'Cockpit/Scripts').as_posix()+'/'
if args.baseline:
    sources = lua.table()
    for name in ('Gun_Director.lua', 'Gun_Motion.lua'):
        sources[name] = subprocess.check_output(
            ['git', 'show', args.baseline+':Cockpit/Scripts/Systems/'+name], cwd=ROOT).decode()
    lua.globals().sources = sources
    lua.execute('''
    local original = dofile
    function dofile(path)
        local name = string.match(path, '([^/]+)$')
        return sources[name] and assert(loadstring(sources[name]))() or original(path)
    end
    ''')
lua.execute('''
LockOn_Options={script_path=ROOT}
local values={F22_AESA_GENERATION=7,F22_RADAR_STT_VALID=1,F22_STT_MOTION_VALID=1,F22_STT_ID=42,
 F22_STT_VELOCITY_SIGMA_MPS=2.34,EFM_HUD_VALID=1,EFM_HUD_VN=220,
 F22N_RADAR_STT_RANGE=800,F22N_RADAR_STT_AZIMUTH=0,F22N_RADAR_STT_ELEVATION=0}
local function get(k)return values[k]or 0 end
local function put(k,v)values[k]=v end
local now, previous, maximum_step, requests = 0,nil,0,0
function get_model_time()return now end
local sensors={getSelfCoordinates=function()return 220*now,5000,0 end,
 getHeading=function()return 0 end,getPitch=function()return 0 end,getRoll=function()return 0 end}
local function dispatch(_,command)
 assert(command==10851)
 if now>1 then
  local velocity=get('F22_GUN_VE')
  assert(get('F22_GUN_INPUT_SOURCE')==2 and get('F22_GUN_REQUEST_GENERATION')==7)
  assert(values.F22_GUN_AE==nil and values.F22_GUN_VE==nil,'radar derivatives leaked into native weapon input')
  if previous then maximum_step=math.max(maximum_step,math.abs(velocity-previous))end
  previous=velocity;requests=requests+1
 end
 put('F22_GUN_RESPONSE_SEQUENCE',get('F22_GUN_REQUEST_SEQUENCE'))
 put('F22_GUN_SOLUTION_VALID',0)
end
local director=dofile(ROOT..'Systems/Gun_Director.lua').new(
 sensors,get,put,dispatch,dofile(ROOT..'Systems/Radar_Display.lua'),15)
for sample=0,160 do
 now=sample*.025
 put('F22_STT_TIME',now);put('F22_STT_PN',220*now+800);put('F22_STT_PU',5000)
 put('F22_STT_VN',220)
 put('F22_STT_VE',sample<40 and 0 or (sample%2==0 and 2.34 or -2.34))
 director:update(true)
end
assert(requests>100,'motion estimate stopped valid native requests')
assert(maximum_step<.75,'raw radar velocity bypassed the motion estimate: '..maximum_step)
print(string.format('Actual director: %.3f m/s radar velocity injected into source-2 requests despite alternating reports',maximum_step))
''')
print('Coherent gun velocity handoff PASS')
