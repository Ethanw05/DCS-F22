"""Final radar owner admits axes by actual format, including A/G and held loss."""
from pathlib import Path
import contextlib
import io
import runpy

ROOT = Path(__file__).resolve().parents[1]
with contextlib.redirect_stdout(io.StringIO()):
    runtime = runpy.run_path(str(ROOT / "tests/test_display_startup.py"))["runtime"]

for role in (2, 7):
    for panel, focus in (("PMFD", 2), ("LMFD", 3), ("RMFD", 4), ("CMFD", 5)):
        lua = runtime()
        lua.globals().ROLE, lua.globals().PANEL, lua.globals().FOCUS = role, panel, focus
        lua.execute(r'''
local now=1;function get_model_time()return now end
function get_base_data()return setmetatable({getSelfCoordinates=function()return 0,3000,0 end},
 {__index=function()return function()return 0 end end})end
package.preload.terrain=function()return {GetHeight=function()return 0 end}end
native={set_power=function()end};function GetDevice()return native end
local function p(n,v)get_param_handle(n):set(v)end
local function g(n)return get_param_handle(n):get()end
dofile(SCRIPT_ROOT..'Systems/Radar_System.lua');post_initialize()
for k,v in pairs({MAIN_POWER=1,HUD_MODE=ROLE,F22_SOI=FOCUS,F22_MFD_LAYOUT_READY=1,F22N_RADAR_MODE=1,
 F22_AG_RADAR_NATIVE_READY=1,F22_AG_VIDEO_READY=1,F22_AG_VIDEO_SOURCE_PRESENT=1,
 F22_AG_VIDEO_GEOMETRY_QUALIFIED=1})do p(k,v)end
for _,panel in ipairs({'LMFD','RMFD','CMFD','PMFD'})do p('F22_'..panel..'_FORMAT',7)end
p('F22_'..PANEL..'_FORMAT',1)
local function tick()now=now+.05;update()end
tick()
local parameter=ROLE==7 and 'F22_AG_CURSOR_X' or 'F22_RADAR_CURSOR_X'
local original=g(parameter)
SetCommand(10620,.8);for i=1,5 do tick()end
assert(g(parameter)>original,PANEL..' focused axis did not reach radar in role '..ROLE)
local moved=g(parameter)
p('F22_'..PANEL..'_FORMAT',7);tick();tick()
assert(g(parameter)==moved,'passive page retained held axis')
p('F22_'..PANEL..'_FORMAT',1);tick();tick()
assert(g(parameter)==moved,'reopen resumed old axis without input')
SetCommand(10620,.8);tick();assert(g(parameter)>moved,'fresh axis did not recover')
local before=g(parameter);p('MAIN_POWER',0);tick();p('MAIN_POWER',1);tick()
assert(g(parameter)==before,'power recovery resumed stale axis')
-- A zero on the other axis must not rebind a held X input to a new focus
-- before the activity callback has had a chance to retire the old owner.
SetCommand(10620,.8);tick();local held=g(parameter)
SetCommand(10621,0);tick()
assert(g(parameter)>held,'same-owner Y release cancelled independent held X input')
held=g(parameter)
for _,panel in ipairs({'LMFD','RMFD','CMFD','PMFD'})do p('F22_'..panel..'_FORMAT',1)end
p('F22_SOI',FOCUS==2 and 3 or 2)
SetCommand(10621,FOCUS%2==0 and 0 or devices.RADAR_COMPUTER+.25);tick();tick()
assert(g(parameter)==held,'other-axis release transferred held slew to another display')
SetCommand(10620,.6);tick();tick()
assert(g(parameter)>held,'fresh input failed to acquire the new display owner')
''')
print("Final owner: relocated A/A and A/G axes on all four panels; page/power loss and deliberate recovery PASS")
