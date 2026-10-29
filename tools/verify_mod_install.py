"""Exercise actual installed Lua dependencies through the explicit software host.

No source overlays, simulator operation or physical weapon effects are supplied.
The matching external native fixture is required for the cross-language JDAM case.
"""
import argparse
import json
import os
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path[:0] = [str(ROOT / 'tests'), str(ROOT / 'tests/cases')]
from host import Host

CASES = (
    'test_jdam_handoff', 'test_radar_target_handoff', 'test_weapon_release',
    'test_store_profile', 'test_irst', 'test_mws_reaction', 'test_radar_interleave',
    'test_radar_fusion_packet', 'test_received_navigation', 'test_altitude_owners',
)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--installed-root', type=Path, required=True)
    parser.add_argument('--build-dir', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    source = ROOT / 'Cockpit/Scripts'
    installed = args.installed_root.resolve() / 'Cockpit/Scripts'
    output = args.output.resolve()
    if output.is_relative_to(ROOT):
        parser.error('Validation output must be outside the source checkout')
    output.mkdir(parents=True, exist_ok=True)
    os.environ['F22_RADAR_INTERLEAVE_EXE'] = str(
        args.build_dir / 'tests/Release/f22_radar_interleave.exe')
    os.environ['F22_RADAR_GROUND_TARGET_EXE'] = str(
        args.build_dir / 'radar/Release/f22_radar_ground_target.exe')
    original = Host.__init__
    loaded = set()

    def create_host(self):
        original(self)
        load = self.env.dofile

        def actual(path):
            candidate = Path(str(path)).resolve()
            if candidate.is_relative_to(source):
                relative = candidate.relative_to(source)
                loaded.add(relative.as_posix())
                return load((installed / relative).as_posix())
            return load(path)

        self.env.dofile = actual

    Host.__init__ = create_host
    suite = unittest.TestSuite(unittest.defaultTestLoader.loadTestsFromName(name) for name in CASES)
    with (output / 'tests.txt').open('w', encoding='utf-8') as stream:
        result = unittest.TextTestRunner(stream=stream, verbosity=2).run(suite)
    report = {'cases': result.testsRun, 'passed': result.wasSuccessful(), 'modules': list(CASES),
              'actual_installed_lua': sorted(loaded), 'source_overlays': False,
              'simulator_executed': False, 'physical_weapon_effect_verified': False}
    (output / 'RESULTS.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({'cases': result.testsRun, 'passed': result.wasSuccessful(),
                      'installed_dependencies': len(loaded)}))
    return 0 if result.wasSuccessful() else 1


if __name__ == '__main__':
    raise SystemExit(main())
