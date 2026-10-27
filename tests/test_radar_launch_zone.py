"""Range crossbars must share the ownship-contact ray in every missile mode."""
from pathlib import Path
import contextlib, io, runpy, math
ROOT=Path(__file__).resolve().parents[1]
with contextlib.redirect_stdout(io.StringIO()):
    runtime=runpy.run_path(str(ROOT/'tests/test_display_startup.py'))['runtime']
l=runtime()
project=l.execute("return dofile(SCRIPT_ROOT..'Systems/Radar_Launch_Zone.lua').project")
layout=l.execute("return dofile(SCRIPT_ROOT..'Systems/Radar_Display.lua')")
for heading in (0,math.pi/2,math.radians(274)):
    for bearing in map(math.radians,(-60,-40,0,35,60)):
        for altitude in (-5000,0,5000):
            relative=l.table_from([18000*math.cos(heading+bearing),altitude,18000*math.sin(heading+bearing)])
            bars=project(relative,heading,700,24000,12000,40000,layout,'STT')
            ax,ay=math.sin(bearing),math.cos(bearing)
            for name,slant in (('MIN',700),('MAX',24000),('TURN',12000)):
                p=bars[name];assert p is not None
                expected=math.sqrt(max(0,slant**2-altitude**2))/40000*layout.radius
                assert abs((p[1]+p[3])/2-expected*ax)<1e-10,'range crossbar midpoint missed the ownship-contact ray'
                assert abs((p[2]+p[4])/2-layout.origin_y-expected*ay)<1e-10
                assert abs((p[3]-p[1])*ax+(p[4]-p[2])*ay)<1e-10,'range crossbar does not cross the target ray at right angles'
                assert abs(math.hypot(p[3]-p[1],p[4]-p[2])-.09)<1e-10
            ray=bars['AXIS'];assert ray is not None
            assert abs(ray[1])<1e-10 and abs(ray[2]-layout.origin_y)<1e-10,'ray does not start at ownship centre'
            assert abs(ray[3]*ay-(ray[4]-layout.origin_y)*ax)<1e-10
            target_x,target_y=layout.point(18000,bearing,40000)
            assert abs(target_x*(ray[4]-ray[2])-(target_y-ray[2])*ray[3])<1e-10,'ray misses the selected contact'
            tws=project(relative,heading,700,24000,12000,40000,layout,'TWS')
            for name in ('MIN','MAX','TURN','AXIS'):
                assert all(abs(tws[name][i]-bars[name][i])<1e-10 for i in (1,2,3,4)),'STT/TWS range geometry differs'
relative=l.table_from([10000,0,0])
near=project(relative,0,700,24000,12000,40000,layout)
wide=project(relative,0,700,24000,12000,80000,layout)
assert abs(((near['MAX'][2]+near['MAX'][4])/2-layout.origin_y)/2-((wide['MAX'][2]+wide['MAX'][4])/2-layout.origin_y))<1e-10
off=project(relative,0,700,120000,90000,40000,layout)
assert off['MAX'] is None and off['TURN'] is None and off['AXIS'] is not None
assert project(relative,0,700,24000,None,40000,layout)['TURN'] is None
assert project(relative,0,700,24000,12000,0,layout) is None
# Side limits and the steering line are clipped to the actual LCD viewport.
side=project(l.table_from([0,0,20000]),0,700,60000,30000,40000,layout)
for segment in side.values():
    assert all(-.965-1e-9<=segment[i]<=.965+1e-9 for i in (1,3))
    assert all(-.925-1e-9<=segment[i]<=.985+1e-9 for i in (2,4))

sim=runtime()
sim.execute('''
function get_base_data()return setmetatable({getSelfCoordinates=function()return 0,5000,0 end},
 {__index=function()return function()return 0 end end})end
for n,v in pairs({MAIN_POWER=1,RADAR_PWR=1,HUD_MODE=2,F22_RADAR_WEAPON_TARGET_ID=101,
 F22_RADAR_OBSERVATIONS_READY=1,F22_RADAR_OBSERVATION_COUNT=1,F22O_01_ID=101,
 F22O_01_NORTH=10000,F22O_01_ALTITUDE=5000,F22_DLZ_NATIVE_VALID=1,F22_DLZ_TARGET_ID=101,
 F22_DLZ_RMIN=700,F22_DLZ_RMAX=24000,F22_DLZ_RTR=12000,F22_RADAR_RANGE_NM=40,F22N_RADAR_MODE=3})do get_param_handle(n):set(v)end
dofile(SCRIPT_ROOT..'Systems/Engagement_System.lua');post_initialize();dofile(SCRIPT_ROOT..'../../tests/legacy_measurement_fixture.lua');update()
''')
def get(name):
    h=sim.globals().get_param_handle(name)
    return h.get(h)
assert get('F22_RDR_LAR_MAX_VALID')==1
assert get('F22_RDR_LAR_AXIS_VALID')==1
assert get('F22_RDR_LAR_AXIS_X1')==0 and get('F22_RDR_LAR_AXIS_Y1')==layout.origin_y
assert abs(get('F22_RDR_LAR_MAX_Y1')-(layout.origin_y+24000/(40*1852)*layout.radius))<1e-10
for scale in (.07,.18):
    ui=runtime();ui.globals().native_scale=scale
    ui.execute('function GetScale()return native_scale end;dofile(SCRIPT_ROOT.."PMFD_CENTER/radar_page.lua")')
    elements={e['name'].removeprefix('F22_COMPAT_AA_'):e for e in ui.globals().elements.values()}
    assert 'F22_RDR_DLZ_RANGE' not in elements,'old HUD-style radar caret remained'
    assert 'F22_RDR_LAR_STEER' not in elements
    for name in ('MIN','MAX','TURN','AXIS'):
        e=elements['F22_RDR_LAR_'+name]
        assert e['kind']=='ceSimpleLineObject' and e['width']>0
        for _,c in e['controllers'].items():
            if c[1]=='line_object_set_point_using_parameters':
                assert abs(c[5]-scale*.82)<1e-12 and abs(c[6]-scale*.82)<1e-12
    assert elements['F22_RDR_COVERAGE_-1']['parent_element']=='F22_COMPAT_AA_F22_RDR_SEARCH_COVERAGE'
    assert elements['F22_RDR_SEARCH_COVERAGE']['element_params'][1]=='F22N_RADAR_MODE'
    assert 'F22_RDR_TRACK_WITHOUT_ENVELOPE' not in elements
    coverage=elements['F22_RDR_SEARCH_COVERAGE']
    assert any(c[1]=='parameter_in_range' and c[4]==3.1 for _,c in coverage['controllers'].items())
def put(name,value):
    h=sim.globals().get_param_handle(name);h.set(h,value)
# The actual engagement owner must use this geometry for both radar and IR
# missiles, in STT, TWS and LTWS, not only in the pure projection helper.
put('F22O_01_EAST',3000);put('F22O_01_AGE',0)
for weapon_mode in (2,3):
    for native_mode,radar_mode in ((3,5),(1,3),(1,2)):
        put('HUD_MODE',weapon_mode);put('F22N_RADAR_MODE',native_mode)
        put('F22_RADAR_MODE_CODE',radar_mode);put('F22_SOI',2)
        # Advance time to publish a new observed target position.
        sim.execute('test_time=(test_time or 1)+.05;function get_model_time()return test_time end')
        sim.globals().update()
        assert get('F22_RDR_LAR_VISIBLE')==1 and get('F22_RDR_LAR_AXIS_VALID')==1
        for name in ('MIN','MAX','TURN'):
            x=(get('F22_RDR_LAR_'+name+'_X1')+get('F22_RDR_LAR_'+name+'_X2'))/2
            y=(get('F22_RDR_LAR_'+name+'_Y1')+get('F22_RDR_LAR_'+name+'_Y2'))/2-layout.origin_y
            assert abs(x*10000-y*3000)<1e-8,'engagement owner displaced a range mark'
put('F22_DLZ_NATIVE_VALID',0);sim.globals().update()
assert get('F22_RDR_LAR_VISIBLE')==0,'missing native solution left an envelope on screen'
put('F22_DLZ_NATIVE_VALID',1)
sim.globals().get_param_handle('F22_RADAR_WEAPON_TARGET_ID').set(sim.globals().get_param_handle('F22_RADAR_WEAPON_TARGET_ID'),202)
sim.globals().update()
assert all(get('F22_RDR_LAR_'+name+'_VALID')==0 for name in ('MIN','MAX','TURN','AXIS'))
print('Radar envelope: shared ownship-contact ray, centred actual range limits, STT/TWS/LTWS and radar/IR modes, scale/altitude projection, no duplicate STT line and invalid clearing PASS')
