"""Real reference/HUD callbacks must not alias a smooth constant-AoA maneuver."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
fixture = ROOT / 'tests/test_display_startup.py'
scope = {'__file__': str(fixture)}
exec(compile(fixture.read_text().split('\nfor page in ', 1)[0], str(fixture), 'exec'), scope)

for phase in (0, 3, 7):
    lua = scope['runtime']()
    lua.globals().PHASE_MS = phase
    lua.execute(r'''
local now=0
local function get(k)return get_param_handle(k):get()end
local function put(k,v)get_param_handle(k):set(v)end
function get_model_time()return now end
local function pitch()return math.rad(25)*now end
function get_base_data()return setmetatable({getPitch=pitch,getRoll=function()return 0 end,
 getHeading=function()return 0 end,getSelfCoordinates=function()return 0,3000,0 end,
 getAngleOfAttack=function()return math.rad(12)end,getVerticalAcceleration=function()return 1 end},
 {__index=function()return function()return 0 end end})end
LockOn_Options.init_conditions.birth_place='AIR_HOT'
put('MAIN_POWER',1)
local physical=dofile(SCRIPT_ROOT..'../../tests/physical_frame_fixture.lua')({F22_ESSENTIAL_POWER=1,
 EFM_HUD_VALID=1,EFM_GROUND_VALID=1,EFM_WEIGHT_ON_WHEELS=0,EFM_GEAR_DOWN_LOCKED=0,
 EFM_GEAR_UP_LOCKED=1,EFM_GEAR_UNSAFE=0,EFM_AIRDATA_VALID=1,EFM_AIRDATA_HEALTH=0,
 EFM_AIRDATA_CAS_MPS=200,EFM_AIRDATA_TAS_MPS=220})
physical:publish(now)
local guide_period
function make_default_activity(period)guide_period=period end
dofile(SCRIPT_ROOT..'Systems/Flight_Guidance.lua');post_initialize();local guidance=update
local hud_period
function make_default_activity(period)hud_period=period end
dofile(SCRIPT_ROOT..'Systems/HUD_Flight_Data.lua');post_initialize();local hud=update
local guide_step=math.floor(guide_period*1000+.5)
local hud_step=math.floor(hud_period*1000+.5)
assert(guide_step>=1 and hud_step>=1)
local next_guide,next_hud=PHASE_MS,7
local minimum,maximum,count=math.huge,-math.huge,0
for tick=0,1000 do
 now=tick/1000
 local gamma=pitch()-math.rad(12)
 put('EFM_HUD_VN',220*math.cos(gamma));put('EFM_HUD_VU',220*math.sin(gamma));put('EFM_HUD_VE',0)
 put('EFM_AIRDATA_STAMP',now);physical:publish(now)
 if tick>=next_guide then guidance();next_guide=next_guide+guide_step end
 if tick>=next_hud then
  hud();next_hud=next_hud+hud_step
  if tick>200 then
   assert(get('HUD_FPM_COMPUTED_VALID')==1)
   local value=get('HUD_FPM_Y_RAD')
   minimum,maximum=math.min(minimum,value),math.max(maximum,value);count=count+1
  end
 end
end
assert(count>=30)
local span=math.deg(maximum-minimum)
assert(span<.05,string.format('reference/HUD phase alias: %.3f deg at %.3f/%.3f s, phase%d',
 span,guide_period,hud_period,PHASE_MS))
-- Real reference failure still withdraws attitude/FPM authority immediately.
put('F22_GINS_1_ATTITUDE_FAILURE',1);now=now+.01;physical:publish(now);guidance();hud()
assert(get('HUD_REFERENCE_ATTITUDE_VALID')==0 and get('HUD_FPM_VALID')==0)
put('F22_GINS_1_ATTITUDE_FAILURE',0);now=now+.01;physical:publish(now);guidance();hud()
assert(get('HUD_REFERENCE_ATTITUDE_VALID')==1 and get('HUD_FPM_VALID')==1)
print(string.format('Actual GINS/HUD callbacks: phase%d smooth-maneuver FPM span %.6f deg, failure/recovery PASS',PHASE_MS,span))
''')
