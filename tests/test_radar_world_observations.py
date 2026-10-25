"""Regression for stabilized VACQ scan-frame angles rejecting a level target."""
from pathlib import Path
import runpy, contextlib, io
root=Path(__file__).resolve().parents[1]
with contextlib.redirect_stdout(io.StringIO()):
 runtime=runpy.run_path(str(root/'tests/test_display_startup.py'))['runtime']
lua=runtime()
lua.execute("""
function get_base_data() return {
 getSelfCoordinates=function() return 1000,5000,2000 end,
 getHeading=function() return 0 end,getPitch=function() return 0 end,getRoll=function() return 0 end} end
native={set_power=function() end};function GetDevice(_) return native end
dofile(SCRIPT_ROOT..'Systems/Radar_System.lua');post_initialize()
local function put(n,v) get_param_handle(n):set(v) end
local function val(n) return get_param_handle(n):get() end
put('MAIN_POWER',1);put('F22N_RADAR_MODE',1);SetCommand(10604,1)
-- A level target has -16.5-degree scan-frame elevation in VACQ. These old
-- polar fields must have no effect on aircraft-body acquisition geometry.
put('F22N_RADAR_CONTACT_01_RANGE',12964)
put('F22N_RADAR_CONTACT_01_ELEVATION',math.rad(-16.5))
put('F22_RADAR_OBSERVATIONS_READY',1);put('F22_RADAR_OBSERVATION_COUNT',1)
for k,v in pairs({ID=123,AGE=0,NORTH=13964,ALTITUDE=5000,EAST=2000,VN=0,VU=0,VE=0,IFF=-1}) do put('F22O_01_'..k,v) end
update()
assert(val('F22_RADAR_MODE_TEXT')=='ACQ','level VACQ target rejected by scan-frame elevation')
assert(math.abs(val('F22N_RADAR_TDC_RANGE')-12964)<.001)
assert(math.abs(val('F22N_SCAN_ZONE_ORIGIN_ELEVATION'))<1e-9,'acquisition chased scan-origin offset')
assert(val('F22_RADAR_DRAWN_COUNT')==1)
put('F22_RADAR_OBSERVATIONS_READY',0);SetCommand(10622,1);update()
assert(val('F22_RADAR_MODE_TEXT')~='ACQ','unavailable bridge accepted old polar data')
""")
print('Checked world snapshot: level VACQ at 7 NM, correct acquisition cue, no polar fallback OK')
