"""SCS depress executes focused-format functions; directions never change pages."""
from pathlib import Path
import contextlib, io, runpy
ROOT=Path(__file__).resolve().parents[1]
with contextlib.redirect_stdout(io.StringIO()):
    runtime=runpy.run_path(str(ROOT/'tests/test_display_startup.py'))['runtime']
l=runtime()
l.execute("""
local events={};local s=dofile(SCRIPT_ROOT..'Systems/Combat_Logic.lua').new(function(n,v)events[#events+1]={n,v}end)
local c={locked=false,ground=false,primary_page=1,left_page=3,right_page=7,center_page=8}
local function press(n)s:input(n,1,c);s:input(n,0,c)end
local function reset()events={}end
s:set_mode(2);reset()
for _,pair in ipairs({{'dms_right',4},{'dms_left',3},{'dms_down',2},{'dms_up',1}})do
 press(pair[1]);press(pair[1]);assert(s.soi==pair[2] and #events==0,'hat direction changed page or executed sensor')
end
press('dms_right');press('scs_depress');assert(events[1][1]=='ew_priority')
press('dms_left');reset();press('scs_depress');assert(#events==0,'passive system page had unrelated action')
c.left_page=8;press('scs_depress');assert(events[1][1]=='nav_zoom')
press('dms_down');reset();press('scs_depress');assert(events[1][1]=='stt')
-- Press once on down, never repeat while held, and release cannot execute again.
reset();s:input('scs_depress',1,c)
for i=1,50 do s:input('scs_depress',1,c);s:update(.02,c)end
s:input('scs_depress',0,c);assert(#events==1 and events[1][1]=='stt')
c.locked=true;reset();press('scs_depress');assert(#events==0,'SCS depress broke existing STT')
c.primary_page=3;press('tdc');press('tms_up');assert(#events==0,'system format designated hidden radar target')
c.primary_page=1;c.locked=false
reset();press('tdc');assert(events[1][1]=='designate','TDC lost its separate TWS designation behavior')
press('dms_up');reset();press('scs_depress');assert(events[1][1]=='boresight')
s:set_mode(7);reset();press('scs_depress');assert(events[1][1]=='ag_mark')
press('tdc');assert(events[2][1]=='ag_mark','HUD TDC designation changed')
press('dms_down');reset();press('scs_depress');assert(#events==2 and events[1][1]=='ground_acquire' and events[1][2]==1 and events[2][2]==0)
-- Focus changes cancel a delayed old-sensor action.
s:set_mode(2);reset();s:input('tms_right',1,c);press('dms_right');s:update(2,c);s:input('tms_right',0,c)
assert(#events==0)
s:focus(5);press('scs_depress');assert(events[1][1]=='nav_zoom')
""")
l=runtime()
l.execute("""
function get_aircraft_property()return 1 end
dofile(SCRIPT_ROOT..'Systems/MFD_System.lua');post_initialize()
local mfd_command,mfd_update=SetCommand,update
dofile(SCRIPT_ROOT..'Systems/PMFD_System.lua');post_initialize()
local primary_command,primary_update=SetCommand,update
dofile(SCRIPT_ROOT..'Systems/Combat_System.lua');post_initialize()
get_param_handle('MAIN_POWER'):set(1);get_param_handle('HUD_MODE'):set(2)
local control_command=SetCommand
function dispatch_action(device,command,value)
 actions[#actions+1]={command,value,device}
 if device==devices.COMBAT_SYSTEM then control_command(command,value)end
end
mfd_update();primary_update();update()
local function press(c)control_command(c,16.375);control_command(c,16.25)end
local function value(n)return get_param_handle(n):get()end
local previous=value('LMFD_PAGE');press(10707);press(10707);mfd_update()
assert(value('LMFD_PAGE')==previous and value('F22_SOI')==3)
-- Actual lower-center bezel assigns control without another hat direction.
mfd_command(10123,1);assert(value('F22_SOI')==5)
-- Focus notification release is not another focus/action.
control_command(10742,3);actions={};press(10741);assert(#actions==0,'system page sent sensor commands')
control_command(10742,4);get_param_handle('RMFD_PAGE'):set(7);actions={};press(10741)
assert(#actions==1 and actions[1][1]==10902 and actions[1][3]==devices.RWR_SYSTEM)
control_command(10742,2);get_param_handle('F22_PMFD_PAGE'):set(1);actions={};press(10741)
assert(#actions==1 and actions[1][1]==10632 and actions[1][3]==devices.RADAR_COMPUTER)
actions={};press(10733);assert(#actions==1 and actions[1][1]==10606)
get_param_handle('MAIN_POWER'):set(0);actions={};press(10741);assert(#actions==0)
""")
for focus,folder in ((2,'PMFD_CENTER'),(3,'MFD_LEFT'),(4,'MFD_RIGHT'),(5,'MFD_CENTER')):
    ui=runtime();ui.execute('dofile(SCRIPT_ROOT..'+repr(folder+'/sensor_control.lua')+')')
    elements={e['name']:e for e in ui.globals().elements.values()}
    assert f'F22_SCS_{focus}_FOCUS' in elements
    assert sum('CORNER_' in name for name in elements)==8
    assert not any('MENU' in name for name in elements)
    for e in elements.values():
        assert e['h_clip_relation'] is not None and e['name']
        if e['vertices']:
            assert all(abs(p[1])<=1 and abs(p[2])<=1 for p in e['vertices'].values())
print('SCS: directions select focus only; depress runs format action; TDC unchanged; held/lock/power gates; bezel focus and four LCD indicators PASS')

# Focus corners follow each rectangular LCD aperture, never the format margins.
for aspect in (.67,1,1.35):
    ui=runtime();ui.globals().preview_aspect=aspect
    ui.execute('function GetAspect()return preview_aspect end;dofile(SCRIPT_ROOT.."PMFD_CENTER/sensor_control.lua")')
    points=[p for e in ui.globals().elements.values() if 'CORNER_' in e['name'] for p in e['vertices'].values()]
    assert abs(max(abs(p[1]) for p in points)-.984)<1e-12
    assert abs(max(abs(p[2]) for p in points)-(aspect-.016))<1e-12
    assert all(abs(p[1])<1 and abs(p[2])<aspect for p in points)
print('SCS focus corners: 1.6% aperture inset on square, wide and tall LCDs PASS')
