"""HUD consumer contract: live stationary STT, geometry, ID and availability."""
from lupa.lua51 import LuaRuntime
from pathlib import Path
lua=LuaRuntime(unpack_returned_tuples=True)
root=Path(__file__).resolve().parents[1]
lua.globals().LockOn_Options=lua.table_from({'script_path':(root/'Cockpit/Scripts').as_posix()+'/'})
lua.execute('''
handles={}
function get_param_handle(n)
 if not handles[n]then
  local p={v=0};function p:get()return self.v end;function p:set(v)self.v=v end
  handles[n]=p
 end
 return handles[n]
end
function make_default_activity()end
''')
lua.execute("dofile(LockOn_Options.script_path..'Systems/Radar_Data_Bridge.lua');post_initialize()")
lua.execute("dofile(LockOn_Options.script_path..'../../tests/stt_snapshot_fixture.lua')")
def put(k,v): lua.globals().get_param_handle(k).set(lua.globals().get_param_handle(k),v)
def val(k): return lua.globals().get_param_handle(k).v
def sample(r=18520,a=.03,e=-.04,iff=-1):
 lua.globals().publish_test_stt(r,a,e,iff)
 lua.globals().update()
for key in ('MAIN_POWER','RADAR_PWR','F22_RADAR_BACKEND_READY'):put(key,1)
put('HUD_MODE',2)
sample()
assert val('HUD_AA_TARGET_VALID')==1 and abs(val('HUD_AA_TGT_RANGE_NM')-10)<1e-7
for _ in range(46): sample()
assert val('HUD_AA_TARGET_VALID')==1,'fresh stationary measurements were dropped'
sample(18500)
assert val('HUD_AA_TARGET_VALID')==1
sample(a=1)
assert val('HUD_AA_TARGET_VALID')==1 and val('HUD_AA_CUE_VALID')==0
put('MAIN_POWER',0);lua.globals().update();assert val('HUD_AA_TARGET_VALID')==0
put('MAIN_POWER',1);put('F22N_RADAR_MODE',1);lua.globals().update()
assert val('HUD_AA_TARGET_VALID')==0,'old STT survived unlock'
sample(iff=2);assert val('HUD_AA_TGT_IFF')==-1,'native neutral coalition leaked into pilot ID'
sample(iff=1);assert val('HUD_AA_TGT_IFF')==1
put('F22_RADAR_BACKEND_READY',0);lua.globals().update();assert val('HUD_AA_TARGET_VALID')==0
print('Shared STT snapshot: stationary fresh data, range/FOV, friendly/unknown ID, unlock and backend/power loss OK')
