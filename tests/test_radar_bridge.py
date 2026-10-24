from lupa.lua51 import LuaRuntime
from pathlib import Path
import math
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute("""
handles={}
function get_param_handle(n)
 if not handles[n] then
  local p={v=0}
  function p:get() return self.v end
  function p:set(x) self.v=x end
  handles[n]=p
 end
 return handles[n]
end
function make_default_activity(dt) end
""")
lua.execute(Path("Cockpit/Scripts/Systems/Radar_Data_Bridge.lua").read_text())
h=lua.globals().handles
def put(k,v): h[k].v=v
def val(k): return h[k].v
lua.globals().post_initialize()
put("MAIN_POWER",1);put("RADAR_PWR",1);put("HUD_MODE",2)
put("RADAR_STT_RANGE",18520);put("RADAR_STT_AZIMUTH",0.03);put("RADAR_STT_ELEVATION",-0.04)
lua.globals().update()
assert val("HUD_AA_TARGET_VALID")==1 and abs(val("HUD_AA_TGT_RANGE_NM")-10)<1e-7
for _ in range(46): lua.globals().update()
assert val("HUD_AA_TARGET_VALID")==0
put("RADAR_STT_RANGE",18500);lua.globals().update()
assert val("HUD_AA_TARGET_VALID")==1
put("RADAR_STT_AZIMUTH",1);lua.globals().update()
assert val("HUD_AA_TARGET_VALID")==1 and val("HUD_AA_CUE_VALID")==0
put("MAIN_POWER",0);lua.globals().update()
assert val("HUD_AA_TARGET_VALID")==0
print("STT telemetry bridge: fresh/stale, range, FOV, power OK")

# The native RWS contact family (01..12) is display only and requires a
# changed, valid return; absence of those params cannot create fake targets.
put("MAIN_POWER",1)
put("RADAR_PWR",1)
put("HUD_MODE",2)
put("RADAR_STT_RANGE",0)
put("RADAR_CONTACT_01_RANGE",18520)
put("RADAR_CONTACT_01_AZIMUTH",0.1)
put("RADAR_CONTACT_01_TIME",1.0)
lua.globals().update()
assert val("HUD_RADAR_SEARCH_RETURNS")==1
assert val("HUD_RWS_01_VALID")==1
assert abs(val("HUD_RWS_01_X") - (0.1/(math.pi/3))*0.76)<1e-6
for _ in range(46): lua.globals().update()
assert val("HUD_RWS_01_VALID")==0, "stale B-scope echo retained"
put("RADAR_CONTACT_01_TIME",1.5)
lua.globals().update()
assert val("HUD_RWS_01_VALID")==1
put("RADAR_PWR",0)
lua.globals().update()
assert val("HUD_RADAR_SEARCH_RETURNS")==0
print("RWS real-contact scope: geometry, freshness, power OK")
