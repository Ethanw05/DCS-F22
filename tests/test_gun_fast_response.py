"""Run the actual aiming device through deferred native results and a bank change."""
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
fixture = ROOT/'tests/test_display_startup.py'
scope = {'__file__': str(fixture)}
exec(compile(fixture.read_text().split('\nfor page in ', 1)[0], str(fixture), 'exec'), scope)
lua = scope['runtime']()
lua.execute(r'''
local now, bank, queued, period = 10, 0, nil, nil
local function p(n,v)get_param_handle(n):set(v)end
local function g(n)return get_param_handle(n):get()end
function get_model_time()return now end
function make_default_activity(value)period=value end
function get_base_data()return{
 getSelfCoordinates=function()return 220*now,5000,0 end,
 getHeading=function()return 0 end,getPitch=function()return 0 end,getRoll=function()return bank end}end
local lead=.02
local result_generation=7
function dispatch_action(_,command)
 assert(command==10851 and not queued,'multiple requests overwrote an outstanding solve')
 queued={time=now+.002,sequence=g('F22_GUN_REQUEST_SEQUENCE'),id=g('F22_GUN_TRACK_ID')}
end
local function deliver()
 if not queued or queued.time>now then return end
 p('F22_GUN_RESPONSE_SEQUENCE',queued.sequence);p('F22_GUN_SOLUTION_SEQUENCE',queued.sequence)
 p('F22_GUN_SOLUTION_VALID',1);p('F22_GUN_RESULT_TIME',queued.time);p('F22_GUN_RESULT_TRACK_ID',queued.id)
 p('F22_GUN_RESULT_SCHEMA',2);p('F22_GUN_RESULT_SOURCE',2);p('F22_GUN_RESULT_GENERATION',result_generation)
 p('F22_GUN_CURRENT_N',220*queued.time+800);p('F22_GUN_CURRENT_U',5000);p('F22_GUN_CURRENT_E',0)
 for _,axis in ipairs({'N','U','E'})do
  p('F22_GUN_CURRENT_V'..axis,axis=='N'and 220 or 0);p('F22_GUN_CURRENT_A'..axis,0)
 end
 p('F22_GUN_AIM_N',math.cos(lead));p('F22_GUN_AIM_U',0);p('F22_GUN_AIM_E',math.sin(lead))
 p('F22_GUN_BORE_N',1);p('F22_GUN_BORE_U',0);p('F22_GUN_BORE_E',0)
 queued=nil
end
for k,v in pairs({MAIN_POWER=1,HUD_MODE=5,F22_WEAPON_BACKEND_READY=1,EFM_HUD_VALID=1,
 EFM_HUD_VN=220,F22_AESA_GENERATION=7,F22_RADAR_STT_VALID=1,F22_STT_MOTION_VALID=1,F22_STT_ID=42,
 F22_STT_VN=220,F22_STT_VU=0,F22_STT_VE=0,F22_STT_VELOCITY_SIGMA_MPS=.4,
 F22N_RADAR_STT_RANGE=800,F22N_RADAR_STT_AZIMUTH=0,F22N_RADAR_STT_ELEVATION=0})do p(k,v)end
dofile(SCRIPT_ROOT..'Systems/Gun_System.lua');post_initialize()
assert(period==1/120)
local function step()
 now=now+period;deliver()
 local stamp=math.floor((now-.01)/.025)*.025
 p('F22_STT_TIME',stamp);p('F22_STT_PN',220*stamp+800);p('F22_STT_PU',5000);p('F22_STT_PE',0)
 update()
end
for _=1,60 do step()end
assert(g('HUD_GUN_NATIVE_VALID')==1 and math.abs(g('HUD_GUN_NATIVE_EL'))<1e-10)
-- A target estimator must not delay a new aircraft frame. A bank change
-- between control-system ticks must reach this next aiming callback exactly.
bank=.2;local changed=now;step()
local expected=math.atan2(-math.sin(lead)*math.sin(bank),math.cos(lead))
assert(now-changed<=1/120+1e-9 and math.abs(g('HUD_GUN_NATIVE_EL')-expected)<1e-9,
 'target-noise correction delayed or filtered current aircraft motion')
local previous=g('HUD_GUN_NATIVE_EL')
bank=-.2;step()
assert(g('HUD_GUN_NATIVE_EL')>0 and previous<0,'rapid bank reversal retained the old frame')
-- Sensor velocity uncertainty no longer feeds the native weapon P/V/load input.
for _,bad in ipairs({0,-1,101,0/0,math.huge})do
 p('F22_STT_VELOCITY_SIGMA_MPS',bad);step()
 assert(g('HUD_GUN_NATIVE_VALID')==1,'unused radar derivative noise suppressed clean native weapon state')
end
-- Results must belong to the generation of the association that requested them.
for _,bad in ipairs({0,8,0/0,math.huge})do
 result_generation=bad;for _=1,4 do step()end
 assert(g('HUD_GUN_NATIVE_VALID')==0,'wrong native generation retained a pipper')
end
result_generation=7;for _=1,4 do step()end
assert(g('HUD_GUN_NATIVE_VALID')==1)
p('MAIN_POWER',0);step()
assert(g('HUD_GUN_NATIVE_VALID')==0,'late native completion revived a power-off cue')
for _=1,50 do step()end
collectgarbage('collect');collectgarbage('stop')
local before=collectgarbage('count')
for _=1,10000 do step()end
local growth=collectgarbage('count')-before;collectgarbage('restart')
assert(growth<1,'disabled high-rate owner allocated replacement histories')
print(string.format('Disabled aiming owner:10000callbacks,%.3fKiB growth',growth))
''')
print('Actual aiming owner: 120Hz, deferred single request, immediate current-bank/reversal, '
      'native generation qualification and power withdrawal PASS')
