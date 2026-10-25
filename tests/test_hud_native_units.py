"""Match native matrix-controller distances to page-scaled static geometry."""
from pathlib import Path
import runpy,math
root=Path(__file__).resolve().parents[1]
runtime=runpy.run_path(str(root/'tests/test_display_startup.py'))['runtime']
for scale in (0.001,0.00055):
    lua=runtime()
    lua.globals().actual_page_scale=scale
    lua.execute('function GetScale() return actual_page_scale end; dofile(SCRIPT_ROOT.."HUD/page.lua")')
    elements={e['name']:e for _,e in lua.globals().elements.items()}
    attitude=elements['HUD_ATTITUDE']
    pitch_gain=attitude['controllers'][1][3]
    # Five degrees of pitch must shift one 5-degree static ladder interval.
    assert abs(pitch_gain*math.radians(5)+math.radians(5)*1000*scale)<1e-9
    fpm=elements['HUD_FPM']
    assert abs(fpm['controllers'][1][3]*math.radians(5)-math.radians(5)*1000*scale)<1e-9
    heading=elements['HUD_HDG_TAPE']
    # Ten degrees must move exactly one label interval, not 1000 intervals.
    layout=lua.execute('return dofile(SCRIPT_ROOT.."HUD/layout.lua")')
    interval=10*layout['heading_mrad_per_degree']*scale
    assert abs(heading['controllers'][1][3]*10+interval)<1e-9
    print('Native page/controller unit agreement at GetScale() =',scale,'OK')
