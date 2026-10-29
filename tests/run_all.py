"""Run only independent replacements, with reports in an explicit external path."""
import argparse
import importlib.util
import json
import os
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
    parser.add_argument('--scope', choices=['common','all'], default='common')
    args = parser.parse_args()
    os.environ.setdefault('F22_RADAR_INTERLEAVE_EXE', str(
        args.build_dir / 'tests' / args.config / 'f22_radar_interleave.exe'))
    os.environ.setdefault('F22_RADAR_GROUND_TARGET_EXE', str(
        args.build_dir / 'radar' / args.config / 'f22_radar_ground_target.exe'))
    args.output.mkdir(parents=True, exist_ok=True)
    common = ['test_host_contract.py','test_driver_protocol.py','test_lua_syntax.py']
    suite = unittest.TestSuite()
    for name in common:
        suite.addTests(unittest.defaultTestLoader.discover(str(ROOT / 'tests/cases'),pattern=name))
    with (args.output / 'python-results.txt').open('w', encoding='utf-8') as stream:
        results = unittest.TextTestRunner(stream=stream, verbosity=2).run(suite)
    native = subprocess.run(['ctest','--test-dir',str(args.build_dir),'-C',args.config,
                             '-R','^replacement_parameter_transport$',
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
    changed = any(x['status'] not in ['known_failure','resolved'] for x in observations)
    summary = dict(replacement_tests=results.testsRun,python_passed=results.wasSuccessful(),
                   native_passed=native.returncode == 0,pre_fix_observations=observations,
                   gate='HARNESS_READY' if results.wasSuccessful() and native.returncode == 0 and not changed else 'NOT_READY',
                   aircraft_qualified=False,legacy_acceptance_executed=False)
    if args.scope == 'all':
        domain = unittest.TestSuite()
        for path in sorted((ROOT / 'tests/cases').glob('test_*.py')):
            if path.name not in common:
                domain.addTests(unittest.defaultTestLoader.discover(str(path.parent),pattern=path.name))
        with (args.output / 'domain-results.txt').open('w', encoding='utf-8') as stream:
            domain_results = unittest.TextTestRunner(stream=stream, verbosity=2).run(domain)
        domain_native = subprocess.run(['ctest','--test-dir',str(args.build_dir),'-C',args.config,
                                        '--output-on-failure','--no-tests=error'],
                                       capture_output=True,text=True,timeout=180)
        (args.output / 'domain-native-results.txt').write_text(domain_native.stdout+domain_native.stderr,encoding='utf-8')
        summary['domain'] = dict(tests=domain_results.testsRun,python_passed=domain_results.wasSuccessful(),
                                 native_passed=domain_native.returncode == 0)
    (args.output / 'RESULTS.json').write_text(json.dumps(summary, indent=2)+'\n', encoding='utf-8')
    print(json.dumps(summary, indent=2))
    domain = summary.get('domain',dict(python_passed=True,native_passed=True))
    return 0 if summary['gate'] == 'HARNESS_READY' and domain['python_passed'] and domain['native_passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
