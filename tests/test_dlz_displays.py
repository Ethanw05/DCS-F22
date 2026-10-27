"""Missile limits must span the actual HUD rail; radar LAR has a separate test."""
from pathlib import Path
import contextlib
import io
import runpy

ROOT = Path(__file__).resolve().parents[1]
with contextlib.redirect_stdout(io.StringIO()):
    runtime = runpy.run_path(str(ROOT / 'tests/test_display_startup.py'))['runtime']

sim = runtime()
sim.execute('''
function get_base_data()
 return setmetatable({getSelfCoordinates=function()return 0,5000,0 end},
  {__index=function()return function()return 0 end end})
end
for n,v in pairs({MAIN_POWER=1,RADAR_PWR=1,HUD_MODE=2,F22_RADAR_WEAPON_TARGET_ID=101,
 F22_RADAR_OBSERVATIONS_READY=1,F22_RADAR_OBSERVATION_COUNT=1,F22O_01_ID=101,
 F22O_01_ALTITUDE=5000,F22_DLZ_NATIVE_VALID=1,F22_DLZ_TARGET_ID=101,
 F22_DLZ_RMIN=700,F22_DLZ_RMAX=20000,F22_DLZ_RTR=10000})do get_param_handle(n):set(v)end
dofile(SCRIPT_ROOT..'Systems/Engagement_System.lua');post_initialize();dofile(SCRIPT_ROOT..'../../tests/legacy_measurement_fixture.lua')
''')


def value(name):
    return sim.globals().get_param_handle(name).get(sim.globals().get_param_handle(name))


for distance in (500, 10000, 60000):
    sim.globals().get_param_handle('F22O_01_NORTH').set(
        sim.globals().get_param_handle('F22O_01_NORTH'), distance)
    sim.globals().update()
    assert value('F22_FC_DLZ_VALID') == 1
    top = value('F22_FC_DLZ_SCALE_NM') * 1852
    for kind, meters in (('MIN', 700), ('MAX', 20000), ('TURN', 10000), ('RANGE', distance)):
        # The labelled scale and every marker describe the same real distance.
        assert abs(value(f'F22_FC_DLZ_{kind}_Y') / .46 - meters / top) < 1e-10

    for page, scale in (('HUD/page.lua', .00055),):
        ui = runtime()
        ui.globals().native_scale = scale
        ui.execute('function GetScale()return native_scale end; dofile(SCRIPT_ROOT..' + repr(page) + ')')
        elements = {e['name']: e for _, e in ui.globals().elements.items()}
        root = 'HUD_ENGAGEMENT_2_DLZ'
        # Measure emitted static geometry, rather than assuming a scale constant.
        rails = []
        for element in elements.values():
            if element['parent_element'] != root or not element['vertices']:
                continue
            points = list(element['vertices'].values())
            height = max(p[2] for p in points) - min(p[2] for p in points)
            width = max(p[1] for p in points) - min(p[1] for p in points)
            if height > .1 and height > width * 5:
                rails.append(height)
        assert len(rails) == 1
        rail = rails[0] * scale
        for kind in ('MIN', 'MAX', 'TURN', 'RANGE'):
            name = 'HUD_ENGAGEMENT_2_' + ('RANGE' if kind == 'RANGE' else 'TICK_' + kind)
            gain = elements[name]['controllers'][1][3]
            movement = value(f'F22_FC_DLZ_{kind}_Y') * gain
            assert abs(movement / rail - value(f'F22_FC_DLZ_{kind}_Y') / .46) < 1e-9, (page, kind)
        if distance <= 20000:
            max_name = 'HUD_ENGAGEMENT_2_TICK_MAX'
            fraction = value('F22_FC_DLZ_MAX_Y') * elements[max_name]['controllers'][1][3] / rail
            assert .8 < fraction < .9, 'maximum collapsed into bottom of rail'

sim.globals().get_param_handle('F22_RADAR_WEAPON_TARGET_ID').set(
    sim.globals().get_param_handle('F22_RADAR_WEAPON_TARGET_ID'), 202)
sim.globals().update()
assert value('F22_FC_DLZ_VALID') == 0, 'old target limits remained visible'
print('HUD DLZ: native limits and current range agree with labelled rail at near/in/out ranges; radar LAR is checked separately')
