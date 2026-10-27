"""Changing ACM patterns, moving native acquisitions, and visible scope contacts."""
from pathlib import Path
import runpy,contextlib,io
ROOT=Path(__file__).resolve().parents[1]
with contextlib.redirect_stdout(io.StringIO()):
    runtime=runpy.run_path(str(ROOT/'tests/test_display_startup.py'))['runtime']
lua=runtime()
lua.execute('''
native={set_power=function() end};function GetDevice(id) assert(id==13);return native end
dofile(SCRIPT_ROOT..'Systems/Radar_System.lua');dofile(SCRIPT_ROOT..'../../tests/radar_body_fixture.lua');post_initialize()
local function put(n,v) get_param_handle(n):set(v) end
local function val(n) return get_param_handle(n):get() end
local p='F22N_RADAR_CONTACT_01_'
put('MAIN_POWER',1);put('F22N_RADAR_MODE',1);
-- Native reports positive contact age, -1 when a slot is absent. No world
-- objects or fabricated STT are supplied to the controller in these trials.
for _,command in ipairs({10622,10604,10605,10622,10605,10604}) do
 SetCommand(command,1)
 put('F22N_RADAR_MODE',1)
 put(p..'RANGE',700);put(p..'AZIMUTH',0);put(p..'ELEVATION',0);put(p..'TIME',0)
 update();assert(val('F22_RADAR_MODE_TEXT')=='ACQ','mode switch failed to acquire candidate')
 put('F22N_RADAR_MODE',2)
 -- Target continues maneuvering after acquisition starts. Its new native
 -- measurements must replace the original cue, including beyond BST bounds.
 for i=1,5 do
  put(p..'RANGE',700-i*20);put(p..'ELEVATION',math.rad(i));update()
  assert(math.abs(val('F22N_RADAR_TDC_RANGE')-(700-i*20))<.001,'acquisition froze target range')
  assert(math.abs(val('F22N_SCAN_ZONE_ORIGIN_ELEVATION')-math.rad(i))<1e-6,'acquisition froze target elevation')
  assert(val('F22_SCOPE_01_VALID')==1 and val('F22_RADAR_DRAWN_COUNT')>=1,'contact vanished during acquisition')
  assert(val('F22_RADAR_STT_VALID')==0,'search contact fabricated an STT lock')
 end
end
-- Last-seen returns remain visible during a revisit gap but do not reacquire.
SetCommand(10622,1);put('F22N_RADAR_MODE',1)
put(p..'ELEVATION',0);put(p..'TIME',2);for i=1,41 do update() end
assert(val('F22_RADAR_MODE_TEXT')=='WIDE','old contact was auto-acquired')
assert(val('F22_SCOPE_01_VALID')==1 and val('F22_SCOPE_01_COAST')==1)
-- Target in a higher native export slot must not be discarded before display.
put(p..'TIME',-1)
local q='F22N_RADAR_CONTACT_40_'
put(q..'RANGE',500);put(q..'AZIMUTH',0);put(q..'ELEVATION',0);put(q..'TIME',0)
update();assert(val('F22_RADAR_MODE_TEXT')=='ACQ' and val('F22_RADAR_DRAWN_COUNT')>=1)
''')
print('ACM: repeated wide/vertical/bore transitions, live acquisition geometry, scope persistence, stale-return exclusion and slot 40 OK')
