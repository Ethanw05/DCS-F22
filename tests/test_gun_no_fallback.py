"""The real high-rate owner must never replace the computed aim with native gyro."""
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
fixture = ROOT/'tests/test_display_startup.py'
ns = {'__file__': str(fixture)}
exec(compile(fixture.read_text().split('\nfor page in ', 1)[0], str(fixture), 'exec'), ns)
lua = ns['runtime']()
lua.execute(r'''
local original=dofile
local aim, elevation, funnel_enabled
function dofile(path)
 if path:find('Systems/Gun_Director.lua',1,true)then
  return{new=function()return{update=function(_,enabled)if enabled then return aim,elevation end end}end}
 elseif path:find('Systems/Gun_Funnel.lua',1,true)then
  return{new=function()return{update=function(_,enabled)funnel_enabled=enabled end}end}
 end
 return original(path)
end
local period
function make_default_activity(value)period=value end
local function p(n,v)get_param_handle(n):set(v)end
local function g(n)return get_param_handle(n):get()end
p('MAIN_POWER',1);p('HUD_MODE',5);p('F22_WEAPON_BACKEND_READY',1)
p('WS_GUN_PIPER_AVAILABLE',1);p('WS_GUN_PIPER_AZIMUTH',.1);p('WS_GUN_PIPER_ELEVATION',.1)
dofile(SCRIPT_ROOT..'Systems/Gun_System.lua');post_initialize();update()
assert(period<=1/120,'aiming retained the slower stores/control activity')
assert(g('HUD_GUN_NATIVE_VALID')==0,'native gyro substituted for missing computed aim')
assert(g('HUD_GUN_NATIVE_AZ')==0 and g('HUD_GUN_NATIVE_EL')==0)
aim,elevation=0,.02;update()
assert(g('HUD_GUN_NATIVE_VALID')==1 and g('HUD_GUN_NATIVE_AZ')==0 and g('HUD_GUN_NATIVE_EL')==.02)
assert(g('HUD_GUN_NATIVE_X_SLOPE')==0 and math.abs(g('HUD_GUN_NATIVE_Y_SLOPE')-math.tan(.02))<1e-12)
p('F22_WEAPON_BACKEND_READY',0);update()
assert(not funnel_enabled and g('HUD_GUN_NATIVE_VALID')==0,'missing backend retained a gun cue')
p('F22_WEAPON_BACKEND_READY',1);p('MAIN_POWER',0);update()
assert(not funnel_enabled and g('HUD_GUN_NATIVE_VALID')==0,'power loss retained a gun cue')
''')
print('Actual 120Hz aiming owner: computed solution only, projection, backend and power withdrawal PASS')
