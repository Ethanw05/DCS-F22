"""A valid native gyro output must never replace a missing computed solution."""
from pathlib import Path
from lupa.lua51 import LuaRuntime
root=Path(__file__).resolve().parents[1]
s=(root/'Cockpit/Scripts/Systems/Weapon_System.lua').read_text(encoding='utf8')
start=s.index("    local pa=get_param_handle('WS_GUN_PIPER_AZIMUTH')") if "    local pa=get_param_handle('WS_GUN_PIPER_AZIMUTH')" in s else s.index('    -- Computed director is the sole gun aiming source.')
end=s.index('    -- Interlock all locally dispatched',start)
lua=LuaRuntime();lua.globals().BLOCK=s[start:end]
lua.globals().PROJECTION=str(root/"Cockpit/Scripts/Systems/HUD_Projection.lua")
lua.execute('''
hud_projection=dofile(PROJECTION)
values={WS_GUN_PIPER_AVAILABLE=1,WS_GUN_PIPER_AZIMUTH=.1,WS_GUN_PIPER_ELEVATION=.1}
function get_param_handle(n)return{get=function()return values[n]or 0 end,set=function(_,v)values[n]=v end}end
native_ready=true;mode_state=5;parameters={MAIN_POWER={get=function()return 1 end}}
gun_director={update=function()return nil end}
local funnel_enabled
gun_funnel={update=function(_,enabled)funnel_enabled=enabled end}
assert(loadstring(BLOCK))()
assert(values.HUD_GUN_NATIVE_VALID==0,'native gyro substituted for missing director')
assert(values.HUD_GUN_NATIVE_AZ==0 and values.HUD_GUN_NATIVE_EL==0)
gun_director.update=function()return 0,.02 end
assert(loadstring(BLOCK))()
assert(values.HUD_GUN_NATIVE_VALID==1 and values.HUD_GUN_NATIVE_AZ==0 and values.HUD_GUN_NATIVE_EL==.02)
assert(values.HUD_GUN_NATIVE_X_SLOPE==0 and math.abs(values.HUD_GUN_NATIVE_Y_SLOPE-math.tan(.02))<1e-12)
native_ready=false;gun_director.update=function()return nil end
assert(loadstring(BLOCK))()
assert(not funnel_enabled and values.HUD_GUN_NATIVE_VALID==0,'unavailable backend supplied a gun cue')
''')
print('Gun aiming: computed director only; no gyro/manual substitute')
