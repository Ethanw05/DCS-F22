from lupa.lua51 import LuaRuntime
from pathlib import Path
import math
lua=LuaRuntime(unpack_returned_tuples=True)
m=lua.execute(Path("Cockpit/Scripts/Systems/Ballistic_Point_Mass.lua").read_text())
flat=lambda n,e:0.0
t=math.sqrt(2000/9.80665)
p=m.impact(0,0,1000,200,0,0,flat)
assert p and abs(p.fall_time-t)<0.001 and abs(p.north-200*t)<0.3
assert m.impact(0,0,1000,200,0,50,flat).fall_time>t
assert m.impact(0,0,1000,200,0,0,lambda n,e:0.02*n).fall_time<t
assert m.impact(0,0,0,200,0,0,flat) is None
assert m.impact(float("nan"),0,1000,200,0,0,flat) is None
print("Ballistics: flat, climb, terrain slope and invalid samples OK")
