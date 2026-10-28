"""Run only independent replacements, with reports in an explicit external path."""
import argparse
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tests'))


def external(path):
    result = Path(path).resolve()
    if result == ROOT or ROOT in result.parents:
        raise argparse.ArgumentTypeError('Reports/builds must be outside the aircraft checkout')
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=external, required=True)
    parser.add_argument('--build-dir', type=external, required=True)
    parser.add_argument('--config', choices=['Debug','Release','RelWithDebInfo'], default='Release')
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    suite = unittest.defaultTestLoader.discover(str(ROOT / 'tests/cases'))
    with (args.output / 'python-results.txt').open('w', encoding='utf-8') as stream:
        results = unittest.TextTestRunner(stream=stream, verbosity=2).run(suite)
    native = subprocess.run(['ctest','--test-dir',str(args.build_dir),'-C',args.config,
                             '--output-on-failure','--no-tests=error'],
                            capture_output=True, text=True, timeout=180)
    (args.output / 'native-results.txt').write_text(native.stdout + native.stderr, encoding='utf-8')
    spec = importlib.util.spec_from_file_location('known_failures', ROOT / 'tests/probes/known_failures.py')
    probes = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(probes)
    observations = []
    for fn in [probes.stopped_altitude, probes.competing_page,
               lambda: probes.native_read(args.build_dir / 'tests' / args.config / 'f22_parameter_host.exe')]:
        try:
            observations.append(fn())
        except Exception as error:
            observations.append(dict(status='probe_error',error=str(error)))
    changed = any(x['status'] != 'known_failure' for x in observations)
    summary = dict(replacement_tests=results.testsRun,python_passed=results.wasSuccessful(),
                   native_passed=native.returncode == 0,pre_fix_observations=observations,
                   gate='HARNESS_READY' if results.wasSuccessful() and native.returncode == 0 and not changed else 'NOT_READY',
                   aircraft_qualified=False,legacy_acceptance_executed=False)
    (args.output / 'RESULTS.json').write_text(json.dumps(summary, indent=2)+'\n', encoding='utf-8')
    print(json.dumps(summary, indent=2))
    return 0 if summary['gate'] == 'HARNESS_READY' else 1


if __name__ == '__main__':
    raise SystemExit(main())
