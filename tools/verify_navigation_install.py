"""Run navigation fixtures through the intended installed Lua dependency set.

With --plan, only explicitly planned files come from the primary source checkout;
every other module comes from the existing normal installation. No file is copied.
Without --plan, the actual installed files are exercised. This is not DCS execution.
"""
import argparse
import hashlib
import json
from pathlib import Path
import sys
import unittest

ROOT=Path(__file__).resolve().parents[1]
sys.path[:0]=[str(ROOT/'tests'),str(ROOT/'tests/cases')]
from host import Host

CASES=['test_cni_menu_disposition','test_received_navigation','test_side_indications',
    'test_navigation_indication_rendering','test_gins_admission','test_altitude_owners','test_flight_field_validity']


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--installed-root',type=Path,required=True)
    parser.add_argument('--plan',type=Path)
    parser.add_argument('--case',action='append',default=[],help='Additional replacement case module')
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args();output=args.output.resolve()
    if output==ROOT or ROOT in output.parents:parser.error('Results must be outside the checkout')
    candidates=set(json.loads(args.plan.read_text())['changed']) if args.plan else set()
    source=ROOT/'Cockpit/Scripts';installed=args.installed_root.resolve()/'Cockpit/Scripts'
    original_init=Host.__init__
    dependencies={}
    def create_host(self):
        original_init(self)
        original_dofile=self.env.dofile
        def load(path):
            try:relative=Path(str(path)).relative_to(source).as_posix()
            except ValueError:return original_dofile(path)
            owner=source if relative in candidates else installed
            selected=owner/relative
            digest=hashlib.sha256(selected.read_bytes()).hexdigest()
            key=selected.as_posix()
            if key in dependencies and dependencies[key]!=digest:
                raise RuntimeError('Lua dependency changed during verification: '+key)
            dependencies[key]=digest
            return original_dofile(selected.as_posix())
        self.env.dofile=load
    Host.__init__=create_host
    suite=unittest.TestSuite(unittest.defaultTestLoader.loadTestsFromName(case) for case in CASES+args.case)
    output.mkdir(parents=True,exist_ok=True)
    with (output/'tests.txt').open('w',encoding='utf-8') as stream:
        result=unittest.TextTestRunner(stream=stream,verbosity=2).run(suite)
    stable=all(hashlib.sha256(Path(path).read_bytes()).hexdigest()==digest for path,digest in dependencies.items())
    report={'tests':result.testsRun,'passed':result.wasSuccessful() and stable,'planned_source_files':len(candidates),
        'dependency_hashes_stable':stable,'dependencies':len(dependencies),
        'other_modules':str(installed),'actual_DCS_executed':False}
    (output/'DEPENDENCIES.json').write_text(json.dumps(dependencies,indent=2)+'\n',encoding='utf-8')
    (output/'RESULTS.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(report,indent=2))
    return 0 if report['passed'] else 1


if __name__=='__main__':raise SystemExit(main())
