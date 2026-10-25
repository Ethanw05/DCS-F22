"""Actual controller with native method stub; catches ownership and routing bugs."""
import runpy
from pathlib import Path
root=Path(__file__).resolve().parents[1]
lua=runpy.run_path(str(root/'tests/test_display_startup.py'))['runtime']()
lua.execute('''
native={power=false,set_power=function(self,p) assert(type(p)=='boolean');self.power=p end}
function GetDevice(id) assert(id==13);return native end
dofile(SCRIPT_ROOT..'Systems/Radar_System.lua');dofile(SCRIPT_ROOT..'../../tests/radar_body_fixture.lua')
post_initialize();get_param_handle('MAIN_POWER'):set(1)
SetCommand(10600,1);get_param_handle('F22N_RADAR_MODE'):set(1);update()
assert(native.power and get_param_handle('RADAR_PWR'):get()==1)
assert(get_param_handle('F22_RADAR_MODE_TEXT'):get()=='RWS')
for _,name in ipairs({'PITCH_BANK','PITCH','BANK'}) do
 assert(get_param_handle('F22N_RADAR_'..name..'_STABILIZATION'):get()==0,'native stabilization double-rotated a body-frame scan')
end
-- Legacy weapon-cycle command 101 must not change radar mode.
SetCommand(101,1);update();assert(get_param_handle('F22_RADAR_MODE_TEXT'):get()=='RWS')
SetCommand(10602,1);update();assert(get_param_handle('F22_RADAR_MODE_TEXT'):get()=='TWS')
local p='F22N_RADAR_CONTACT_01_'
get_param_handle(p..'RANGE'):set(30000);get_param_handle(p..'AZIMUTH'):set(0)
get_param_handle(p..'ELEVATION'):set(0);get_param_handle(p..'TIME'):set(0)
update();update()
get_param_handle('F22N_RADAR_MODE'):set(3);update()
assert(get_param_handle('F22_RADAR_STT_VALID'):get()==0,'mode alone is not valid target geometry')
get_param_handle('F22N_RADAR_STT_RANGE'):set(30000)
get_param_handle('F22N_RADAR_STT_AZIMUTH'):set(0)
get_param_handle('F22N_RADAR_STT_ELEVATION'):set(0);update()
assert(get_param_handle('F22_RADAR_STT_VALID'):get()==1)
assert(get_param_handle('F22_RADAR_RANGE_NM'):get()==40,'STT must scale 30 km onto 40 NM')
assert(get_param_handle('F22_SCOPE_01_VALID'):get()==1,'valid locked target disappeared')
get_param_handle('F22N_RADAR_STT_RANGE'):set(500);update()
assert(get_param_handle('F22_RADAR_RANGE_NM'):get()==1,'close target must not remain at search scale')
get_param_handle('F22N_RADAR_STT_RANGE'):set(100);update()
assert(get_param_handle('F22_RADAR_STT_VALID'):get()==1,'old 300 m cutoff invalidated close lock')
get_param_handle('F22N_RADAR_STT_RANGE'):set(200000);update()
assert(get_param_handle('F22_SCOPE_01_VALID'):get()==1,'STT was clipped to old sensing range')
-- Pattern changes while locked must not send 509/510 or erase the track.
local old_actions=#actions
for _,id in ipairs({10604,10605,10622,10601,10602,10603}) do
 SetCommand(id,1);update()
 assert(get_param_handle('F22_RADAR_STT_VALID'):get()==1,'pattern selection discarded valid STT')
end
assert(#actions==old_actions,'pattern selection sent native unlock')
-- Vertical ACM must acquire at 0.1 NM, preserve progress on another press,
-- and request acquisition again after a native STT loss.
SetCommand(10604,1);get_param_handle('F22N_RADAR_MODE'):set(1)
get_param_handle(p..'RANGE'):set(185.2);get_param_handle(p..'ELEVATION'):set(math.rad(35));update()
assert(get_param_handle('F22_RADAR_MODE_TEXT'):get()=='ACQ')
local before=#actions;SetCommand(10604,1);get_param_handle('F22N_RADAR_MODE'):set(2);update()
assert(#actions==before,'reselecting VACQ reset native confirmation')
get_param_handle('F22N_RADAR_STT_RANGE'):set(185.2)
get_param_handle('F22N_RADAR_STT_ELEVATION'):set(math.rad(35))
get_param_handle('F22N_RADAR_MODE'):set(3);update()
assert(get_param_handle('F22_RADAR_STT_VALID'):get()==1)
get_param_handle('F22N_RADAR_MODE'):set(1);update()
assert(get_param_handle('F22_RADAR_MODE_TEXT'):get()=='ACQ','vertical loss failed to re-acquire')
assert(actions[#actions][1]==509,'vertical re-acquisition did not reach native radar')
SetCommand(10600,1);update();assert(get_param_handle('RADAR_PWR'):get()==0)
SetCommand(Keys.PlaneModeVS,1);update();assert(get_param_handle('RADAR_PWR'):get()==1,'legacy acquisition left radar off')
-- Native widths are full angles. Test coverage at the actual advertised edges.
SetCommand(10605,1);get_param_handle('F22N_RADAR_MODE'):set(1);update()
-- Clear old returns so this checks search volume rather than acquisition volume.
get_param_handle(p..'RANGE'):set(0);update()
local function v(n) return get_param_handle(n):get() end
assert(math.abs(math.deg(v('F22N_SCAN_ZONE_VOLUME_AZIMUTH'))-3.3)<1e-6,'BST command narrower than native 3-degree beam')
SetCommand(10604,1);update()
local center=math.deg(v('F22N_SCAN_ZONE_ORIGIN_ELEVATION'))
local width=math.deg(v('F22N_SCAN_ZONE_VOLUME_ELEVATION'))
assert(math.abs(center-width/2+13)<1e-6 and math.abs(center+width/2-46)<1e-6,'VACQ native volume does not reach advertised bounds')
-- Reproduce native ACQ -> short rejected STT -> search between Lua frames.
get_param_handle(p..'RANGE'):set(500);get_param_handle(p..'AZIMUTH'):set(0)
get_param_handle(p..'ELEVATION'):set(math.rad(35));update()
get_param_handle('F22N_RADAR_MODE'):set(2);update()
get_param_handle('F22N_RADAR_MODE'):set(1);local previous=#actions;update()
assert(#actions>previous and actions[#actions][1]==509,'old acquiring latch blocked native restart')
assert(v('F22_RADAR_DEVICE_ID')==13,'native configuration device ID not supplied')
get_param_handle('MAIN_POWER'):set(0);update()
assert(not native.power and get_param_handle('F22_RADAR_STT_VALID'):get()==0)
assert(get_param_handle('F22_SCOPE_01_VALID'):get()==0)
for _,a in ipairs(actions) do assert(a[1]~=84 and a[1]~=350,'radar fired weapon') end
-- A missing/incompatible coordinate adapter must not expose a mirrored beam
-- or allow native acquisition of an unintended neighbouring contact.
get_param_handle('MAIN_POWER'):set(1)
get_param_handle('F22N_RADAR_MODE'):set(1)
get_param_handle('F22_RADAR_ACQ_COORDINATES_READY'):set(0)
previous=#actions;update()
assert(not native.power and v('F22_RADAR_BACKEND_READY')==0)
assert(v('F22_RADAR_MODE_TEXT')=='SENSOR N/A' and v('F22_RADAR_STT_VALID')==0)
for i=previous+1,#actions do assert(actions[i][1]~=509,'unavailable coordinate adapter allowed acquisition') end
get_param_handle('F22_RADAR_ACQ_COORDINATES_READY'):set(1);update()
assert(native.power and v('F22_RADAR_BACKEND_READY')==1,'checked adapter did not recover sensor operation')
''')
print('Radar adapter: actual power, legacy mode IDs, native STT gate, power loss and no fire side effects OK')
