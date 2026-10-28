"""Measure the actual cockpit owner in an isolated explicit Lua5.1 host port."""
import argparse
import json
from pathlib import Path
import statistics
import sys
import time

ROOT=Path(__file__).resolve().parents[3]
sys.path[:0]=[str(ROOT/'tests'),str(ROOT/'tests/cases')]
from test_side_indications import side_host,references
from navigation_ports import seed_physical


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args()
    output=args.output.resolve()
    if output==ROOT or ROOT in output.parents:
        parser.error('Raw profiling output belongs outside the source checkout')
    h,produce=side_host()
    for _ in range(10):h.update()
    h.lua.execute('collectgarbage("collect")')
    before=h.lua.eval('collectgarbage("count")')
    h.lua.execute('collectgarbage("stop")')  # This isolated runtime only; never DCS.
    samples=[]
    for index in range(500):
        world,spawn=10+index*.006,2+index*.006
        h.state.time=world
        seed_physical(h,clock=spawn);references(h,stamp=spawn)
        h.seed({'F22_ALTIMETER_RESULT_TIME':world,'F22_ALT_STANDBY_NATIVE_STAMP':world})
        produce()
        begin=time.perf_counter_ns();h.update()
        samples.append((time.perf_counter_ns()-begin)/1e6)
    peak=h.lua.eval('collectgarbage("count")')
    h.lua.execute('collectgarbage("restart");collectgarbage("collect")')
    retained=h.lua.eval('collectgarbage("count")')
    ordered=sorted(samples)
    result=dict(actual_owner='Avionics.lua with current side/GINS/altitude readers',calls=500,
        requested_period_ms=6,p50_ms=statistics.median(samples),p95_ms=ordered[474],
        p99_ms=ordered[494],maximum_ms=max(samples),transient_kib_per_call=(peak-before)/500,
        retained_kib_delta=retained-before,
        limits='Isolated Lua5.1/Lupa host port; Python ports contribute cost. '
               'No DCS timing, GC budget, optics or aircraft calibration claim.')
    output.parent.mkdir(parents=True,exist_ok=True)
    output.write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(result,indent=2))


if __name__=='__main__':
    main()
