"""Real gun motion estimator with declared fast-radar velocity noise."""
from pathlib import Path
import math
import random
import statistics
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
lua = LuaRuntime(unpack_returned_tuples=True)
motion = lua.eval('dofile')((ROOT/'Cockpit/Scripts/Systems/Gun_Motion.lua').as_posix())
rng = random.Random(271026)
for rate in (0, .18):
    estimator = motion.new()
    errors = []
    rejected = 0
    for index in range(801):
        time = index*.025
        velocity = [220*math.cos(rate*time), 220*math.sin(rate*time), 0]
        truth = [-rate*velocity[1], rate*velocity[0], 0]
        measured = [v+rng.gauss(0, 2.34) for v in velocity]
        value = estimator.update(estimator, time, lua.table_from(measured))
        if index < 40:
            continue
        if value is None:
            rejected += 1
        else:
            errors.append(math.dist(truth, [value[k] for k in (1, 2, 3)]))
    rms = math.sqrt(statistics.mean(x*x for x in errors))
    assert rejected == 0, ('noise repeatedly discarded a valid track', rate, rejected)
    assert rms < 18, ('fast-cadence noise became target maneuver acceleration', rate, rms)
    print(f'Fast measured-motion rate={rate}: acceleration error RMS={rms:.3f} m/s2; rejects={rejected}')

# Cadence and lifecycle limits remain independent of the estimator window.
estimator = motion.new()
v = lua.table_from([220, 0, 0])
assert estimator.update(estimator, 10, v) is None
assert estimator.update(estimator, 10.306, v) is not None
assert estimator.update(estimator, 10.807, v) is None
assert estimator.update(estimator, 10.7, v) is None
estimator.reset(estimator)
assert estimator.update(estimator, 11, v) is None
print('Motion estimator: slow measured cadence, stale gap, time rewind and explicit reset PASS')

lua.globals().motion_module = motion
lua.execute('''
local m=motion_module;local state=m.new();local velocity={220,0,0}
local first=state.samples[1];local first_vector=first.v
for i=1,1000 do state:update(i*.004,velocity)end
collectgarbage('collect');collectgarbage('stop')
local before=collectgarbage('count')
for i=1001,11000 do state:update(i*.004,velocity)end
local growth=collectgarbage('count')-before
collectgarbage('restart')
assert(state.count<=m.capacity and state.samples[1]==first and first.v==first_vector)
assert(growth<1,'recurring motion estimate allocated a growing history')
assert(not state:update(45,{0/0,0,0})and state.count==0)
assert(not state:update(45,{1501,0,0})and state.count==0)
assert(not state:update(45,42)and state.count==0)
print(string.format('Motion fixed32 storage: 10000 callbacks, %.3f KiB heap growth; invalid inputs reset',growth))
''')
