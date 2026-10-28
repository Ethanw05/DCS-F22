"""Sampled replay of the player's 27 October gun flight, without running DCS.

The fixture preserves 20Hz logged target P/V, prior same-track covariance, and
the original gun TOF. Future positions are interpolated later RADAR estimates,
not independent truth or observed hits. Missing 25ms reports are not invented.
The optional native host evaluates the actual GunTargetMotion C++ kernel.
"""
from pathlib import Path
import argparse
import csv
import ctypes as C
import hashlib
import json
import math
import statistics
import subprocess
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
FIXTURE = ROOT/'tests/fixtures/gun-aesa-player-20261027.csv'
BASELINE = '9fa5fc210d1b67352a7f1e590fffcdf5539b5275'


def replay(source=None, native=None, revision=None):
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.globals().LockOn_Options = lua.table_from({'script_path': (ROOT/'Cockpit/Scripts').as_posix()+'/'})
    if revision:
        paths = ['Gun_Motion.lua']
        source = subprocess.check_output(['git','show',revision+':Cockpit/Scripts/Systems/Gun_Motion.lua'], cwd=ROOT).decode()
        for helper in ('Gun_Maneuver_Observer', 'Gun_Target_Estimator'):
            if helper in source:
                paths.append(helper+'.lua')
        bundle = {name: subprocess.check_output(['git','show',revision+':Cockpit/Scripts/Systems/'+name], cwd=ROOT).decode() for name in paths}
        lua.globals().snapshot_sources = lua.table_from(bundle)
        lua.execute("local original=dofile;function dofile(path) local name=path:match('([^/]+)$');return snapshot_sources[name] and assert(loadstring(snapshot_sources[name]))() or original(path) end")
    module = lua.execute(source) if source else lua.eval('dofile')(
        (ROOT/'Cockpit/Scripts/Systems/Gun_Motion.lua').as_posix())
    state = module.new()
    rows = [{k: float(v) for k,v in r.items()} for r in csv.DictReader(FIXTURE.open())]
    last_stamp, identity, acceleration, previous = None, None, None, None
    steps, errors, raw_steps, fitted_steps = [], [], [], []
    prior_velocity, prior_fitted = None, None
    accepted, rejected = 0, 0
    for row in rows:
        if row['track_id'] != identity:
            state.reset(state)
            last_stamp, previous, identity = None, None, row['track_id']
            prior_velocity, prior_fitted = None, None
        stamp = row['observed_time']
        assert 0 <= stamp-row['sigma_time'] <= .5
        velocity = [row['v'+axis] for axis in ('n','u','e')]
        if stamp != last_stamp:
            value = state.update(state, stamp, lua.table_from(velocity), row['velocity_sigma_mps'])
            last_stamp = stamp
            acceleration = [value[k] for k in (1,2,3)] if value is not None else None
            if acceleration is None:
                rejected += 1
                previous = None
            else:
                accepted += 1
                fitted = [state.velocity[k] for k in (1,2,3)] if state.velocity is not None else velocity
                if previous and row['range_m'] <= 2000:
                    steps.append(math.dist(acceleration, previous))
                if prior_velocity is not None and row['range_m'] <= 2000:
                    raw_steps.append(math.dist(velocity, prior_velocity))
                    fitted_steps.append(math.dist(fitted, prior_fitted))
                previous = acceleration
                prior_velocity, prior_fitted = velocity, fitted
        if native and acceleration and row['future_observed'] == 1:
            position = [row['p'+axis] for axis in ('n','u','e')]
            result = (C.c_double*3)()
            fitted = [state.velocity[k] for k in (1,2,3)] if state.velocity is not None else velocity
            native(*[(C.c_double*3)(*vector) for vector in (position,fitted,acceleration)],
                   row['horizon_s'], result)
            errors.append(math.dist(result, [row['future_'+axis] for axis in ('n','u','e')]))
    return {'accepted_reports': accepted, 'initial_or_invalid_reports': rejected,
            'acceleration_step_rms_mps2': math.sqrt(statistics.mean(x*x for x in steps)),
            'acceleration_step_p95_mps2': sorted(steps)[int(.95*len(steps))],
            'raw_velocity_step_rms_mps': math.sqrt(statistics.mean(x*x for x in raw_steps)),
            'solver_velocity_step_rms_mps': math.sqrt(statistics.mean(x*x for x in fitted_steps)),
            'forecast_comparisons': len(errors),
            'forecast_consistency_rms_m': math.sqrt(statistics.mean(x*x for x in errors)) if errors else None}


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--native-host', type=Path, required=True)
    ap.add_argument('--output', type=Path, required=True)
    args = ap.parse_args()
    host = C.CDLL(str(args.native_host.resolve()))
    native = host.benchmark_predict
    pointer = C.POINTER(C.c_double)
    native.argtypes = [pointer,pointer,pointer,C.c_double,pointer]
    baseline = subprocess.check_output(['git','show',BASELINE+':Cockpit/Scripts/Systems/Gun_Motion.lua'],
                                       cwd=ROOT).decode()
    report = {'baseline_revision': BASELINE, 'fixture_sha256': hashlib.sha256(FIXTURE.read_bytes()).hexdigest(),
              'limits': __doc__, 'baseline': replay(baseline,native), 'candidate': replay(native=native)}
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(report,indent=2)+'\n',encoding='utf8')
    print(json.dumps(report,indent=2))


if __name__ == '__main__':
    main()
