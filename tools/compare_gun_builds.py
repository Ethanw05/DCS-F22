"""Paired actual Lua/native fire-control revisions in a synthetic offline host.

Both receive identical declared measurements. This cannot execute DCS's private
avSimpleRadar or validate real dispersion, damage, pilot performance or hits.
"""
from pathlib import Path
import argparse
import csv
import ctypes as C
import hashlib
from functools import lru_cache
import json
import math
import random
import statistics
import subprocess
import time
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
AXES = ('N', 'U', 'E')
OLD = 'b2650c945dbec6bd355f43d0c3695abbb9b6ab6e'
CURRENT = '9fa5fc210d1b67352a7f1e590fffcdf5539b5275'
DT = .02
TRUTH_DT = .002
WIND = (12., 0., 15.)


@lru_cache(maxsize=128)
def source(revision, path):
    if revision == 'candidate':
        return (ROOT/path).read_bytes() if path.rsplit('/',1)[-1] in ('Gun_Motion.lua','Gun_Maneuver_Observer.lua','Gun_Director.lua') else source(CURRENT, path)
    return subprocess.check_output(['git', 'show', f'{revision}:{path}'], cwd=ROOT)


def build(output):
    host = output/'host'
    host.mkdir(parents=True, exist_ok=True)
    (host/'host.cpp').write_bytes((ROOT/'tools/gun_comparison_host.cpp').read_bytes())
    native = ['NativeGunSight.cpp', 'NativeGunSight.h', 'GunIntercept.h',
              'GunTargetMotion.h', 'GunManeuver.h']
    cmake = ['cmake_minimum_required(VERSION 3.20)', 'project(GunComparison LANGUAGES CXX)']
    for label, revision in [('old', OLD), ('current', CURRENT), ('candidate', CURRENT), ('oracle', CURRENT)]:
        snapshot = host/label
        snapshot.mkdir(exist_ok=True)
        for name in native:
            (snapshot/name).write_bytes(source(revision, 'EFM/source/'+name))
        target = 'gun_'+label
        cmake += [f'add_library({target} SHARED "{(host/"host.cpp").as_posix()}")',
                  f'target_include_directories({target} PRIVATE "{snapshot.as_posix()}" "{(ROOT/"EFM/include").as_posix()}")',
                  f'target_compile_features({target} PRIVATE cxx_std_17)',
                  f'target_compile_definitions({target} PRIVATE NOMINMAX)',
                  f'target_compile_options({target} PRIVATE /W4 /WX)']
    (host/'CMakeLists.txt').write_text('\n'.join(cmake)+'\n')
    for command in [['cmake', '-S', str(host), '-B', str(host/'build'), '-A', 'x64'],
                    ['cmake', '--build', str(host/'build'), '--config', 'Release', '--parallel', '3']]:
        result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True)
        with (output/'build.log').open('a') as log:
            log.write(result.stdout+result.stderr)
        if result.returncode:
            raise RuntimeError(result.stdout+result.stderr)
    return {label: Host(host/'build/Release'/('gun_'+label+'.dll'))
            for label in ('old', 'current', 'candidate', 'oracle')}


class Host:
    def __init__(self, path):
        self.dll = C.CDLL(str(path))
        self.dll.benchmark_set.argtypes = [C.c_char_p, C.c_double]
        self.dll.benchmark_get.argtypes = [C.c_char_p]
        self.dll.benchmark_get.restype = C.c_double
        self.dll.benchmark_update.argtypes = [C.c_double]
        self.dll.benchmark_projectile.argtypes = [C.POINTER(C.c_double), C.POINTER(C.c_double),
                                                 C.c_double, C.POINTER(C.c_double)]
        self.reset()

    def reset(self):
        self.dll.benchmark_reset()

    def put(self, name, value):
        self.dll.benchmark_set(name.encode(), value)

    def get(self, name):
        return self.dll.benchmark_get(name.encode())

    def vector(self, prefix):
        return [self.get(prefix+axis) for axis in AXES]

    def bullet(self, aim, own_velocity, duration):
        velocity = (C.c_double*3)(*[1030*a+v for a, v in zip(aim, own_velocity)])
        wind = (C.c_double*3)(*WIND)
        result = (C.c_double*3)()
        self.dll.benchmark_projectile(velocity, wind, duration, result)
        return list(result)


def rate(scenario, t):
    if scenario == 'straight':
        return 0
    if scenario == 'onset':
        return .18 if t >= 3 else 0
    if scenario == 'rollout':
        return .18*max(0, 1-max(0, t-4)/.6)
    if scenario == 'reversal':
        return .18*(1-2*min(1, max(0, t-4)/.6))
    return .18


class Truth:
    def __init__(self, scenario, distance):
        self.rows = []
        target = [distance, 5000., 0.]
        own = [0., 5000., 0.]
        angle = 0.
        for index in range(round(12/TRUTH_DT)+1):
            t = index*TRUTH_DT
            w = rate(scenario, t)
            velocity = [220*math.cos(angle), 0., 220*math.sin(angle)]
            acceleration = [-w*velocity[2], 0., w*velocity[0]]
            heading = math.atan2(target[2]-own[2], target[0]-own[0])
            own_velocity = [220*math.cos(heading), 0., 220*math.sin(heading)]
            self.rows.append((target[:], velocity, acceleration, own[:], own_velocity, heading))
            midpoint = angle+w*TRUTH_DT*.5
            midpoint_velocity = [220*math.cos(midpoint), 0., 220*math.sin(midpoint)]
            angle += w*TRUTH_DT
            target = [p+v*TRUTH_DT for p, v in zip(target, midpoint_velocity)]
            own = [p+v*TRUTH_DT for p, v in zip(own, own_velocity)]

    def at(self, t):
        x = max(0., min(t, 12.))*1/TRUTH_DT
        index = min(len(self.rows)-2, int(x))
        f = x-index
        a, b = self.rows[index:index+2]
        vectors = [[v+(w-v)*f for v, w in zip(a[i], b[i])] for i in range(5)]
        return (*vectors, a[5]+(b[5]-a[5])*f)


OUTPUTS = ['F22_GUN_RESPONSE_SEQUENCE', 'F22_GUN_SOLUTION_VALID',
           'F22_GUN_SOLUTION_SEQUENCE', 'F22_GUN_RESULT_TRACK_ID', 'F22_GUN_RESULT_TIME']
for name in ('AIM', 'BORE'):
    OUTPUTS += ['F22_GUN_'+name+'_'+axis for axis in AXES]


class Pipeline:
    def __init__(self, revision, host, truth):
        self.host, self.truth = host, truth
        self.host.reset()
        self.lua = LuaRuntime(unpack_returned_tuples=True)
        scripts = 'Cockpit/Scripts/Systems/'
        names = ['Gun_Motion', 'Gun_Frames', 'Radar_Display']
        if revision == 'candidate': names.append('Gun_Maneuver_Observer')
        modules = self.lua.table_from({name: source(revision, scripts+name+'.lua').decode() for name in names})
        self.lua.globals().modules = modules
        self.lua.execute('''
        LockOn_Options={script_path='snapshot/'}
        function dofile(path)
          local name=path:match('([^/]+)%.lua$')
          return assert(loadstring(assert(modules[name],name)))()
        end
        values={};now=0;pose={north=0,altitude=5000,east=0,heading=0,pitch=0,roll=0}
        function get_model_time()return now end
        function read(k)return values[k]or 0 end
        sensors={getSelfCoordinates=function()return pose.north,pose.altitude,pose.east end,
          getHeading=function()return -pose.heading end,getPitch=function()return 0 end,getRoll=function()return 0 end}
        display=dofile('Radar_Display.lua')
        ''')
        self.g = self.lua.globals()
        self.values = self.g['values']
        self.g.write = self.put
        self.g.dispatch = self.dispatch
        module = self.lua.execute(source(revision, scripts+'Gun_Director.lua').decode())
        self.director = module.new(self.g.sensors, self.g.read, self.g.write,
                                   self.g.dispatch, self.g.display, 15)
        self.module = module
        self.g.director_module = module
        self.lua.execute("local frames=dofile('Gun_Frames.lua')\nfunction ideal_pipper(aim,target)\n local frame=frames.from_pose(pose)\n local bore=frames.world(frame,{1,0,0})\n local los={target[1]-pose.north,target[2]-pose.altitude,target[3]-pose.east}\n local p=director_module.pipper(aim,bore,los)\n local body=frames.body(frame,p)\n return math.atan2(body[3],body[1]),math.atan2(body[2],body[1])\nend")
        self.shots = []
        self.requests = 0

    def put(self, key, value):
        self.values[key] = value
        self.host.put(key, value)

    def dispatch(self, _, command, dt):
        assert command == 10851
        self.requests += 1
        fire = float(self.g.now)+.002
        actual = self.truth.at(fire)
        for axis, value in zip(AXES, actual[3]):
            self.host.put('BENCH_'+axis, value)
        self.host.put('BENCH_HEADING', actual[5])
        self.host.dll.benchmark_update(fire)
        if self.host.get('F22_GUN_SOLUTION_VALID') > .5:
            aim = self.host.vector('F22_GUN_AIM_')
            tof = self.host.get('F22_GUN_TOF')
            muzzle = self.host.vector('F22_GUN_MUZZLE_')
            bullet = self.host.bullet(aim, actual[4], tof)
            target = self.truth.at(fire+tof)[0]
            miss = math.dist([p+d for p, d in zip(muzzle, bullet)], target)
            self.shots.append({'time': fire, 'miss_m': miss, 'tof': tof, 'aim': aim})

    def step(self, now, stamp, measured, velocity, sigma):
        # Deliver the preceding native response at the next real cockpit tick.
        for key in OUTPUTS:
            self.values[key] = self.host.get(key)
        target, true_v, true_a, own, own_v, heading = self.truth.at(now)
        self.g.now = now
        pose = self.g.pose
        pose['north'], pose['altitude'], pose['east'], pose['heading'] = *own, heading
        for key, value in {'F22_RADAR_STT_VALID': 1, 'F22_STT_MOTION_VALID': 1,
                           'EFM_HUD_VALID': 1, 'F22_STT_ID': 42, 'F22_STT_TIME': stamp,
                           'F22_GUN_DEVICE_ID': 15, 'F22_STT_VELOCITY_SIGMA_MPS': sigma}.items():
            self.put(key, value)
        age = now-stamp
        # Native radar geometry is propagated with the same measured velocity.
        propagated = [p+v*age for p, v in zip(measured, velocity)]
        observation = self.lua.table_from(dict(zip(('north', 'altitude', 'east'), propagated)))
        r, az, el = self.g.display.body_observation(observation, pose, 0)
        for key, value in zip(('RANGE', 'AZIMUTH', 'ELEVATION'), (r, az, el)):
            self.put('F22N_RADAR_STT_'+key, value)
        for prefix, vector in [('F22_STT_P', measured), ('F22_STT_V', velocity),
                               ('EFM_HUD_V', own_v), ('EFM_HUD_W', WIND)]:
            for axis, value in zip(AXES, vector):
                self.put(prefix+axis, value)
        result = self.director.update(self.director, True)
        if result is None:
            return None
        return result


def rms(values):
    return math.sqrt(statistics.mean(x*x for x in values)) if values else None


def oracle_aim(host, truth, now):
    target, velocity, acceleration, own, own_velocity, heading = truth.at(now)
    for key, value in {'F22_GUN_REQUEST_VALID': 1, 'F22_GUN_DEVICE_ID': 15,
                       'F22_GUN_REQUEST_SEQUENCE': round(now/DT)+1, 'F22_GUN_TRACK_ID': 42,
                       'F22_GUN_REQUEST_TIME': now, 'F22_GUN_MEASUREMENT_AGE': 0,
                       'BENCH_HEADING': heading}.items():
        host.put(key, value)
    for prefix, vector in [('F22_GUN_TARGET_', target), ('F22_GUN_V', velocity),
                           ('F22_GUN_A', acceleration), ('F22_GUN_OWN_', own),
                           ('EFM_HUD_V', own_velocity), ('EFM_HUD_W', WIND), ('BENCH_', own)]:
        for axis, value in zip(AXES, vector):
            host.put(prefix+axis, value)
    host.dll.benchmark_update(now)
    assert host.get('F22_GUN_SOLUTION_VALID') > .5, 'known-state reference failed'
    return host.vector('F22_GUN_AIM_')


def run_case(hosts, scenario, distance, noise, cadence, duration, correlation=0.):
    truth = Truth(scenario, distance)
    pipelines = {label: Pipeline(revision, hosts[label], truth)
                 for label, revision in [('old', OLD), ('current', CURRENT), ('candidate', 'candidate')]}
    rng = random.Random(20261027)
    noise_state = [rng.gauss(0, 1) for _ in range(6)]
    rho = math.exp(-cadence/correlation) if correlation else 0.
    innovation = math.sqrt(1-rho*rho)
    errors = {label: [] for label in pipelines}
    samples = {label: 0 for label in pipelines}
    available = {label: 0 for label in pipelines}
    measured, velocity, stamp = None, None, None
    held_report = -1
    lag = {label: None for label in pipelines}
    hosts['oracle'].reset()
    for index in range(round(duration/DT)+1):
        now = .1+index*DT
        report = math.floor(max(0., now-.045)/cadence)
        if report != held_report:
            stamp = report*cadence
            actual = truth.at(stamp)
            noise_state = [rho*x+innovation*rng.gauss(0, 1) for x in noise_state]
            measured = [p+(.49 if noise else 0)*x for p, x in zip(actual[0], noise_state[:3])]
            velocity = [v+noise*x for v, x in zip(actual[1], noise_state[3:])]
            held_report = report
        ideal = oracle_aim(hosts['oracle'], truth, now) if now >= 1 else None
        for label, pipeline in pipelines.items():
            result = pipeline.step(now, stamp, measured, velocity, max(.0001, noise))
            if now < 1:
                continue
            samples[label] += 1
            if result is not None:
                available[label] += 1
                # Remove known-state lead/ownship motion before scoring jitter.
                target, _, actual_a, _, _, _ = truth.at(now)
                az, el = pipeline.g.ideal_pipper(pipeline.lua.table_from(ideal),
                                                 pipeline.lua.table_from(target))
                errors[label].append((now, result[0]-az, result[1]-el))
                if scenario == 'onset' and noise == 0 and now >= 3 and lag[label] is None:
                    a = pipeline.director.motion.a
                    if a is not None:
                        ratio = sum(a[i+1]*actual_a[i] for i in range(3))/sum(x*x for x in actual_a)
                        if ratio >= .9:
                            lag[label] = (now-3)*1000
    result = []
    for label, pipeline in pipelines.items():
        shots = [x for x in pipeline.shots if 1 <= x['time'] <= duration]
        misses = sorted(x['miss_m'] for x in shots)
        steps = [math.hypot(b[1]-a[1], b[2]-a[2])*1000
                 for a, b in zip(errors[label], errors[label][1:]) if b[0]-a[0] < DT*1.1]
        result.append({'scenario': scenario, 'range_m': distance, 'velocity_noise_mps': noise,
                       'cadence_s': cadence, 'build': label, 'shots': len(shots),
                       'noise_correlation_s': correlation,
                       'miss_rms_m': rms(misses),
                       'miss_p95_m': misses[int(.95*(len(misses)-1))] if misses else None,
                       'cue_step_rms_mrad': rms(steps),
                       'onset_response_90_ms': lag[label],
                       'available_pct': 100*available[label]/samples[label]})
    return result


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--output', type=Path, required=True)
    ap.add_argument('--quick', action='store_true')
    args = ap.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    began = time.monotonic()
    print('Building both actual native gun revisions...', flush=True)
    hosts = build(output)
    rows = []
    scenarios = ('straight', 'turn', 'onset', 'rollout', 'reversal')
    distances = (1000,) if args.quick else (500, 1000, 1500)
    noises = (0., 2.34) if args.quick else (0., .4, 2.34)
    for scenario in scenarios:
        for distance in distances:
            for noise in noises:
                for correlation in ((0., .1) if noise else (0.,)):
                    rows += run_case(hosts, scenario, distance, noise, .025, 7., correlation)
        print('Completed', scenario, flush=True)
    rows += run_case(hosts, 'straight', 1000, .4, .306, 7.)
    # Numerical/reference sanity checks and the concrete regression goals.
    clean = [r for r in rows if r['velocity_noise_mps']==0 and r['scenario'] in ('straight','turn')]
    assert all(r['miss_rms_m'] is not None and r['miss_rms_m']<.1 for r in clean)
    for correlation in (0., .1):
        group = {label: [r for r in rows if r['build']==label and r['velocity_noise_mps']==2.34
                         and r['noise_correlation_s']==correlation and r['cadence_s']==.025]
                 for label in ('old','candidate')}
        def pooled(values):
            return math.sqrt(sum(r['miss_rms_m']**2*r['shots'] for r in values)/sum(r['shots'] for r in values))
        assert pooled(group['candidate'])<pooled(group['old']), 'noisy miss regression'
        assert statistics.mean(r['cue_step_rms_mrad']**2 for r in group['candidate']) < statistics.mean(
            r['cue_step_rms_mrad']**2 for r in group['old']), 'cue jitter regression'
    onset = {label: [r['onset_response_90_ms'] for r in rows if r['build']==label
                    and r['scenario']=='onset' and r['velocity_noise_mps']==0]
             for label in ('old','candidate')}
    assert all(b<=a+1e-8 for a,b in zip(onset['old'],onset['candidate'])), 'onset response regression'
    with (output/'comparison.csv').open('w', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=list(rows[0]))
        writer.writeheader();writer.writerows(rows)
    provenance = {'old_revision': OLD, 'current_revision': CURRENT,
                  'scope': 'Actual Lua director/motion and native gun adapter; paired identical synthetic measurements',
                  'limits': 'DCS native radar unavailable offline; declared white/AR1-correlated noise; synthetic RK4 projectile; no dispersion/pilot/hit validation',
                  'harness_sha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
                  'host_sha256': hashlib.sha256((output/'host/host.cpp').read_bytes()).hexdigest(),
                  'candidate_motion_sha256': hashlib.sha256(source('candidate','Cockpit/Scripts/Systems/Gun_Motion.lua')).hexdigest(),
                  'candidate_observer_sha256': hashlib.sha256(source('candidate','Cockpit/Scripts/Systems/Gun_Maneuver_Observer.lua')).hexdigest(),
                  'candidate_director_sha256': hashlib.sha256(source('candidate','Cockpit/Scripts/Systems/Gun_Director.lua')).hexdigest(),
                  'duration_s': time.monotonic()-began, 'rows': rows}
    (output/'comparison.json').write_text(json.dumps(provenance, indent=2)+'\n')
    for noise in noises:
        for label in ('old', 'current', 'candidate'):
            selected = [r for r in rows if r['build']==label and r['velocity_noise_mps']==noise and r['cadence_s']==.025]
            print(label, 'velocity_noise=', noise,
                  'mean_case_miss_RMS=', statistics.mean(r['miss_rms_m'] for r in selected if r['miss_rms_m'] is not None),
                  'mean_cue_step_mrad=', statistics.mean(r['cue_step_rms_mrad'] for r in selected if r['cue_step_rms_mrad'] is not None),
                  'availability_pct=', statistics.mean(r['available_pct'] for r in selected), flush=True)
    print('Results:', output/'comparison.csv', flush=True)


if __name__ == '__main__':
    main()
