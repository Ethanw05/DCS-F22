"""Designated-track/HUD flow, off-glass cue, and master-mode regressions."""
from pathlib import Path
import contextlib,io,runpy,math
root=Path(__file__).resolve().parents[1]
with contextlib.redirect_stdout(io.StringIO()):runtime=runpy.run_path(str(root/'tests/test_display_startup.py'))['runtime']
l=runtime()
l.execute('''
local events={};local s=dofile(SCRIPT_ROOT..'Systems/Combat_Logic.lua').new(function(n,v) events[#events+1]={n,v} end)
local c={locked=true,ground=false};local function press(n) s:input(n,1,c);s:input(n,0,c) end
for _,pair in ipairs({{'gun',5},{'srm',3},{'mrm',2}}) do
 press(pair[1]);assert(s.mode==pair[2]);press(pair[1]);assert(s.mode==pair[2],'direct direction cycled weapon')
end
assert(events[#events][1]=='bvr','locked MRM selection left ACM return pattern')
press('aa');assert(s.mode==1);press('aa');assert(s.mode==2)
press('srm');press('ag');assert(s.mode==7);press('aa');assert(s.mode==3,'A/A forgot last air weapon')
press('ag');assert(s.mode==7);press('ag');assert(s.mode==1)
for _,m in ipairs({2,3,5}) do
 s:set_mode(m);events={};s:input('tdc',1,c);s:input('tdc',1,c);s:input('tdc',0,c)
 assert(#events==1 and events[1][1]=='designate','TDC changed scan mode or repeated designation')
end
''')
print('Direct weapons: idempotent selection; A/A memory/NAV; A/G/NAV; BVR emitted during STT OK')

from radar_test_runtime import owned_runtime
l=owned_runtime()
l.execute("""
f.lock(42);f.command(10602,1)
f.put('HUD_MODE',5);f.tick();f.put('HUD_MODE',2);f.tick()
assert(f.get('F22_RADAR_STT_VALID')==1 and f.get('F22_ACM_MODE')==0)
assert(f.get('PMFD_RADAR_SELECTION')==1 and #actions==0)
f.tick(.6);assert(f.get('F22_RADAR_MODE_TEXT')=='TWS')
f.command(10618,1);f.tick()
assert(f.get('F22_RADAR_DESIGNATION_VALID')==1 and f.get('F22_RADAR_STT_VALID')==0)
assert(math.abs(f.get('F22_RADAR_DESIGNATION_RANGE')-10000)<1e-5)
f.put('MAIN_POWER',0);f.tick();assert(f.get('F22_RADAR_DESIGNATION_VALID')==0)
""")
print('Owned MRM transition: lock retained, ACM cleared, TWS restored; search designation LOS/power gates PASS')

l=runtime()
l.execute('''
dofile(SCRIPT_ROOT..'Systems/Radar_Data_Bridge.lua');post_initialize()
local function put(n,v) get_param_handle(n):set(v) end
local function val(n) return get_param_handle(n):get() end
put('MAIN_POWER',1);put('RADAR_PWR',1);put('HUD_MODE',2);put('F22_RADAR_BACKEND_READY',1)
put('F22N_RADAR_MODE',1);put('F22_RADAR_DESIGNATION_VALID',1)
put('F22_RADAR_DESIGNATION_RANGE',12964);put('F22_RADAR_DESIGNATION_AZ',.03);put('F22_RADAR_DESIGNATION_EL',-.04)
put('F22_RADAR_DESIGNATION_AGE',0);update()
assert(val('HUD_TD_VALID')==1 and val('HUD_TD_BOX_VALID')==1 and val('HUD_TD_LOCKED')==0)
assert(val('HUD_AA_TARGET_VALID')==0 and val('HUD_GUN_TARGET_VALID')==0,'designation became weapon lock')
put('F22_RADAR_DESIGNATION_AGE',2);update();assert(val('HUD_TD_COAST')==1)
put('F22_RADAR_DESIGNATION_AGE',11);update();assert(val('HUD_TD_VALID')==0,'expired designation survived')
dofile(SCRIPT_ROOT..'../../tests/stt_snapshot_fixture.lua')
publish_test_stt(12964,.03,-.04,-1);update()
assert(val('HUD_TD_LOCKED')==1 and val('HUD_AA_TARGET_VALID')==1)
assert(math.abs(val('HUD_TD_X')-math.tan(.03))<1e-9)
for _,p in ipairs({{.5,0},{-.5,0},{0,.5},{0,-.5}}) do
 publish_test_stt(12964,p[1],p[2],-1);update()
 assert(val('HUD_TD_ARROW_VALID')==1 and val('HUD_TD_BOX_VALID')==0)
 assert(val('HUD_TD_ARROW_X')*p[1]+val('HUD_TD_ARROW_Y')*p[2]>0,'locator pointed away from target')
end
put('HUD_MODE',1);update();assert(val('HUD_TD_VALID')==1 and val('HUD_AA_TARGET_VALID')==0,'NAV weapon/display states confused')
put('MAIN_POWER',0);update();assert(val('HUD_TD_VALID')==0 and val('HUD_TD_ARROW_VALID')==0)
''')
print('HUD: designation/confirmed track distinction, nominal projection, four locator directions, coast/expiry, NAV/power OK')

l=runtime()
project=l.execute("return dofile(SCRIPT_ROOT..'Systems/HUD_TargetMath.lua').new(dofile(SCRIPT_ROOT..'HUD/glass.lua'))")
assert project(0,0)['visible']
assert not project(math.radians(12),0)['visible'], 'old 15-degree cutoff missed physical edge'
for az,el in [(0,0),(.5,0),(-.5,0),(0,.5),(0,-.5),(math.pi,0)]:
    p=project(az,el)
    assert math.isfinite(p['arrow_x']) and math.isfinite(p['arrow_y'])
    assert project(math.atan(p['arrow_x']),math.atan2(p['arrow_y'],math.sqrt(1+p['arrow_x']**2)))['visible']
assert abs(project(math.pi,0)['angle']-180)<1e-9
assert project(0,.5)['arrow_y']<=.045, 'upper locator overlaps heading'
print('Nominal glass aperture: 12-degree edge, bounded locator, and rear-hemisphere geometry OK')
