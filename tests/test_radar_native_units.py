"""DCS matrix translations must use the same scale as static radar geometry."""
from pathlib import Path
import runpy,contextlib,io
ROOT=Path(__file__).resolve().parents[1]
with contextlib.redirect_stdout(io.StringIO()):
    runtime=runpy.run_path(str(ROOT/'tests/test_display_startup.py'))['runtime']
for scale in (.07,.1,.18):
    lua=runtime();lua.globals().native_scale=scale
    lua.execute('function GetScale() return native_scale end; dofile(SCRIPT_ROOT.."PMFD_CENTER/radar_page.lua")')
    elements={e['name']:e for _,e in lua.globals().elements.items()}
    # A return half-way up a 20-NM display must move the same physical distance
    # as a static line drawn at that normalized coordinate, at any LCD size.
    x,y=.2,-.4
    for name in ('F22_RDR_TRACK_1','F22_RDR_CURSOR','F22_RDR_WAYPOINT','F22_RDR_COMPASS_1'):
        c=elements[name]['controllers']
        assert abs(c[1][3]*x-x*scale*.95)<1e-12,(name,'horizontal units')
        assert abs(c[2][3]*y-y*scale*.95)<1e-12,(name,'vertical units')
print('Radar native units: contact, cursor, waypoint and compass positions agree with static LCD geometry at three physical scales')
