from lupa.lua51 import LuaRuntime
from pathlib import Path
import math
lua=LuaRuntime(unpack_returned_tuples=True)
m=lua.execute(Path("Cockpit/Scripts/Systems/Ballistic_Point_Mass.lua").read_text())
# DCS provides a Lua function. Lupa exposes a raw Python callback as userdata,
# which the real module correctly rejects at its function-type guard.
flat=lua.eval('function(n,e) return 0 end')
t=math.sqrt(2000/9.80665)
p=m.impact(0,0,1000,200,0,0,flat)
assert p and abs(p.fall_time-t)<0.001 and abs(p.north-200*t)<0.3
assert m.impact(0,0,1000,200,0,50,flat).fall_time>t
assert m.impact(0,0,1000,200,0,0,lua.eval('function(n,e)return .02*n end')).fall_time<t
assert m.impact(0,0,0,200,0,0,flat) is None
assert m.impact(float("nan"),0,1000,200,0,0,flat) is None
print("Ballistics: flat, climb, terrain slope and invalid samples OK")

# With 1000m release height, 200m/s north motion, a mark 5000m ahead:
# freefall is about 14.28 sec, followed by another ~10.7 sec to the release
# location if aircraft speed remains constant.
ccrp=lua.execute(Path("Cockpit/Scripts/Systems/AG_Release_Geometry.lua").read_text())
release=ccrp.timeToRelease(0,0,1000,200,0,0,5000,0,0)
assert release is not None
assert abs(release.seconds-(5000-200*t)/200)<0.01
assert release.cross_track<0.001
assert ccrp.timeToRelease(0,0,1000,200,0,0,2000,0,0) is None # too late
assert ccrp.timeToRelease(0,0,1000,200,0,0,5000,2000,0) is None # off-axis
assert ccrp.timeToRelease(0,0,1000,0,0,0,5000,0,0) is None
print("CCRP-style non-authoritative timing and gating: OK")
