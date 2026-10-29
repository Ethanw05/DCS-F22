"""Profile actual radio admission/guidance in an isolated Lua5.1 fixture."""
import argparse
import json
from pathlib import Path
import statistics
import sys
import time

ROOT=Path(__file__).resolve().parents[3]
sys.path[:0]=[str(ROOT/'tests'),str(ROOT/'tests/cases')]
from test_received_navigation import receiver
from navigation_ports import seed_physical


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args();output=args.output.resolve()
    if output==ROOT or ROOT in output.parents:parser.error('Output must be outside the checkout')
    h=receiver()
    for _ in range(10):h.env.consume_radio()
    h.lua.execute('collectgarbage("collect")')
    before=h.lua.eval('collectgarbage("count")')
    h.lua.execute('collectgarbage("stop")')  # This fixture only; never the DCS runtime.
    samples=[]
    for index in range(500):
        world=10+index*.05;h.state.time=world
        seed_physical(h,clock=2+index*.05)
        h.seed({'F22_RADIONAV_STAMP':world,'F22_RADIONAV_SEQUENCE':2+index*2})
        begin=time.perf_counter_ns();h.env.consume_radio()
        samples.append((time.perf_counter_ns()-begin)/1e6)
    peak=h.lua.eval('collectgarbage("count")')
    h.lua.execute('collectgarbage("restart");collectgarbage("collect")')
    retained=h.lua.eval('collectgarbage("count")')
    ordered=sorted(samples)
    result=dict(owner='Radio_Snapshot, Radio_Navigation and Nav_Guidance with no IRS position',
        calls=500,requested_period_ms=50,p50_ms=statistics.median(samples),p95_ms=ordered[474],
        p99_ms=ordered[494],maximum_ms=max(samples),transient_kib_per_call=(peak-before)/500,
        retained_kib_delta=retained-before,
        limits='Isolated Lupa Lua5.1 host; no DCS cadence, GC, native lifetime or optics qualification.')
    output.write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8');print(json.dumps(result,indent=2))


if __name__=='__main__':main()
