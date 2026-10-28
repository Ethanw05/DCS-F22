"""Exercise the actual Lua motion estimator and C++ intercept against synthetic flight truth.
Synthetic drag/noise are declared test assumptions, not calibrated DCS flight results.
"""
import argparse,csv,math,random,statistics,subprocess
from pathlib import Path
from lupa.lua51 import LuaRuntime
ROOT=Path(__file__).resolve().parents[1]
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--output',type=Path,required=True)
 ap.add_argument('--simulator',type=Path,default=ROOT/'out/build/local-release/efm/Release/f22_gun_simulation.exe')
 args=ap.parse_args();args.output.mkdir(parents=True,exist_ok=True)
 lua=LuaRuntime(unpack_returned_tuples=True);lua.globals().LockOn_Options=lua.table_from({'script_path':(ROOT/'Cockpit/Scripts').as_posix()+'/'});module=lua.eval('dofile')(str(ROOT/'Cockpit/Scripts/Systems/Gun_Motion.lua'))
 rng=random.Random(20261025);inputs=args.output/'simulation-inputs.csv'
 with inputs.open('w',newline='')as f:
  writer=csv.writer(f);writer.writerow(['scenario','noise','age','range','speed','rate','heading','bank','px','py','pz','vx','vy','vz','new_ax','new_ay','new_az','old_ax','old_ay','old_az'])
  for scenario in range(3):
   for speed in (180,250,330):
    for rate in (0,.12,.25):
     for noise in (0,.1,.4):
      for age in (0,.05,.12):
       for distance in (500,1000,1500):
        for heading,bank in ((0,0),(math.pi/2,.6),(math.pi,-.6)):
         estimator=module.new();old=[0.,0.,0.];prior=None;measured=None;acc=None
         for i in range(101):
          t=-2+i*.02;angle=heading+rate*t
          truth=[speed*math.cos(angle),speed*math.sin(angle)*math.sin(bank),speed*math.sin(angle)*math.cos(bank)]
          measured=[v+rng.gauss(0,noise)for v in truth]
          acc=estimator.update(estimator,t,lua.table_from(measured),noise)
          if prior is not None:
           alpha=1-math.exp(-.02/.12)
           old=[old[k]+alpha*((measured[k]-prior[k])/.02-old[k])for k in range(3)]
          prior=measured
         if acc is None:raise RuntimeError('Estimator rejected synthetic bounded maneuver')
         point=[distance+rng.gauss(0,.25 if noise else 0),30+rng.gauss(0,.25 if noise else 0),80+rng.gauss(0,.25 if noise else 0)]
         writer.writerow([scenario,noise,age,distance,speed,rate,heading,bank,*point,*measured,*[acc[k]for k in (1,2,3)],*old])
 exe=args.simulator;results=args.output/'simulation-results.csv'
 subprocess.run([str(exe),str(inputs),str(results)],check=True)
 rows=list(csv.DictReader(results.open()))
 def describe(selected):
  lines=['| Predictor | Solved | Mean miss (m) | P90 miss (m) | Worst miss (m) |','|---|---:|---:|---:|---:|']
  for name in ('old_runtime','aligned_ca','turn_director'):
   values=[float(r[name])for r in selected if r[name]!='invalid'];values.sort()
   lines.append(f'| {name} | {len(values)}/{len(selected)} | {statistics.mean(values):.3f} | {values[int((len(values)-1)*.9)]:.3f} | {max(values):.3f} |')
  return '\n'.join(lines)
 steady=[r for r in rows if r['scenario']=='0'and float(r['rate'])>0]
 clean=[r for r in steady if float(r['noise'])==0]
 changing=[r for r in rows if r['scenario']!='0'and float(r['rate'])>0]
 straight=[r for r in rows if float(r['rate'])==0]
 assert all(r['turn_director']!='invalid'and float(r['turn_director'])<.3 for r in clean),'clean sustained-turn intercept regression'
 report=f"""# Gun director synthetic simulation

{len(rows)} encounters. Uses the actual Lua motion estimator and C++ inverse solver. It does **not** run DCS or reproduce either complete aircraft implementation.

## Steady turns, including assumed measurement noise

{describe(steady)}

## Steady turns, noise-free

{describe(clean)}

## Turn rollout and reversal after firing

{describe(changing)}

## Straight flight

{describe(straight)}

`old_runtime` reproduces our previous acceleration filter and its missing velocity-age correction. `aligned_ca` applies consistent measurement age to a constant-world-acceleration predictor, isolating the kinematic assumption found in the decoded Hornet/F-15 paths. It is **not** a simulation of their full avionics. `turn_director` uses the new estimator and rotating-velocity prediction. All use the same inverse root solver and synthetic projectile model.

Grid: 500/1000/1500 m; target speeds 180/250/330 m/s; turn rates 0/.12/.25 rad/s; three encounter headings and turn-plane orientations; sensor age 0/.05/.12 s; independent Gaussian velocity noise 0/.1/.4 m/s and position noise 0/.25 m. Wind is 12/0/15 m/s; own velocity 220/0/0 m/s; muzzle speed 1030 m/s. Projectile truth uses an explicitly synthetic quadratic drag coefficient .00012/m and gravity 9.8 m/s², integrated with RK4. Solver integration step .01 s is checked against .002 s integration. Target truth is independently integrated at .001 s.

Rollout/reversal begin .3 s after the modeled firing instant and evolve over .6 s. Those future control changes are not given to any predictor. Their misses demonstrate a limitation, not something a radar can know in advance. Native DCS shell behavior, dispersion, actual gun launch timing, real logging noise, head parallax and firing accuracy still require flight data.
"""
 (args.output/'Simulation-results.md').write_text(report,encoding='utf8');print(report)
if __name__=='__main__':main()
