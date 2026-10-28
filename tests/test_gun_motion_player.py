"""Recorded noisy AESA velocity/covariance must not become pipper maneuver chatter."""
from pathlib import Path
import runpy
ROOT=Path(__file__).resolve().parents[1]
replay=runpy.run_path(str(ROOT/'tools/replay_gun_motion.py'))['replay']
result=replay()
assert result['accepted_reports']==179 and result['initial_or_invalid_reports']==3,result
assert result['acceleration_step_rms_mps2']<4.1,result
assert result['acceleration_step_p95_mps2']<8,result
print('Sampled player flight: unchanged report acceptance; acceleration step RMS '
      f"{result['acceleration_step_rms_mps2']:.3f}m/s2, p95 {result['acceleration_step_p95_mps2']:.3f} PASS")
