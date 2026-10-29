"""Prepare matched SP/client-slot signature trials externally; never install or run DCS."""
import argparse
import hashlib
import json
from pathlib import Path

from build_signature_trial import ROOT, NAME, build


def comparison(output, altitude=1500):
    output = Path(output).resolve()
    if output == ROOT or ROOT in output.parents or output.exists():
        raise ValueError('Choose a new external comparison directory')
    reports = []
    for client in (False, True):
        mode = 'mp' if client else 'sp'
        for aircraft, label in (('F-22A', 'f22'), ('FA-18C_hornet', 'hornet')):
            report = build(output / (mode + '-' + label) / NAME, altitude,
                           aircraft=aircraft, clean=True, client=client, mixed_sensors=True)
            reports.append(report)
    manifest = {
        'schema': 1, 'purpose': 'Matched native radar/IR/visual engagement observations',
        'trials': reports, 'production_RCS_changed': False, 'executed': False,
        'source_F22_registration_sha256': hashlib.sha256((ROOT / 'F-22A.lua').read_bytes()).hexdigest(),
        'loaded_registration_verified': False,
        'conditions': ['Fresh mission for each pass; no respawn or prior detection memory',
                       'Same route, altitude and speed; ECM off with recorded evidence',
                       'F22 closed bays first, then a fresh repeat with open bays',
                       'No stores, gun rounds, flares or chaff; no invisibility/immortality',
                       'Collect server dcs.log for MP; these client slots are preparation, not MP proof'],
        'interpretation': ['First positive native report is not necessarily detection onset',
                           'A radar report, current radar target and an attributed shot are separate',
                           'Draw-argument read success does not prove argument support or radar effects',
                           'No real-aircraft RCS or threat-range calibration is inferred']}
    (output / 'comparison.json').write_text(json.dumps(manifest, indent=2) + '\n')
    return manifest


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--altitude', type=float, default=1500, help='Metres MSL')
    args = parser.parse_args()
    comparison(args.output, args.altitude)
