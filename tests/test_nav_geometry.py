"""Behavioral regression tests using the actual NavGeometry.lua under Lua 5.1.

No DCS host is required. Confirms world axes, heading, pitch/roll coupling,
forward-only projection and unit/slant-range math. Optical HUD calibration and
DCS's live heading sign are separate runtime tests.
"""
import math
from pathlib import Path

from lupa.lua51 import LuaRuntime

runtime = LuaRuntime(unpack_returned_tuples=True)
source = Path("Cockpit/Scripts/Systems/NavGeometry.lua").read_text(encoding="utf-8")
geometry = runtime.execute(source)

def project(north, east, up, heading=0.0, pitch=0.0, roll=0.0):
    return geometry.project(north, east, up, heading, pitch, roll)

def near(actual, expected, message, tolerance=1e-6):
    assert actual is not None, f"{message}: got nil"
    assert math.isclose(actual, expected, rel_tol=1e-6, abs_tol=tolerance), (
        f"{message}: got {actual}, expected {expected}"
    )

def test_cardinal() -> None:
    for heading, north, east in (
        (0, 1000, 0),
        (math.pi/2, 0, 1000),
        (math.pi, -1000, 0),
        (3*math.pi/2, 0, -1000),
    ):
        az, el, distance = project(north,east,0,heading)
        near(az,0,"on-boresight azimuth")
        near(el,0,"on-boresight elevation")
        near(distance,1000,"slant-range meters")
    az,el,distance=project(1000,0,0,0)
    near(distance,1000,"1000-m slant")
    az,el,distance=project(1000,1000,0,0)
    near(az,math.pi/4,"target right 45 deg")
    az,el,distance=project(1000,-1000,0,0)
    near(az,-math.pi/4,"target left 45 deg")

def test_attitude() -> None:
    az,el,d=project(1000,0,100,0)
    near(el,math.atan(0.1),"up elevation")
    near(d,math.hypot(1000,100),"slant range")
    az,el,d=project(1000,0,100,0,math.atan(0.1))
    near(el,0,"pitch-aligned cue")
    az,el,d=project(1000,100,0,0,0,math.pi/2)
    near(az,0,"90-deg roll transforms right displacement")
    near(el,math.atan(0.1),"90-deg roll up displacement")

def test_invalid() -> None:
    az,el,d=project(-1000,0,0)
    assert az is None and el is None, "Behind aircraft cue must not appear"
    near(d,1000,"range behind")
    az,el,d=project(0,0,0)
    assert az is None and el is None, "Zero-distance cue must not appear"
    az,el,d=project(float("nan"),0,0)
    assert az is None and el is None, "NaN input cue must not appear"

if __name__ == "__main__":
    test_cardinal()
    test_attitude()
    test_invalid()
    print("Navigation geometry: cardinal directions, attitude, range, invalids OK")
