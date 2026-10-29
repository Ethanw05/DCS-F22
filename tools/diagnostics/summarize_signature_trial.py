"""Summarize bounded schema-2 passive trial logs; never infer detection from silence."""
import argparse
import json
import math
from pathlib import Path

PREFIX = 'F22_RCS_SAM|'
MAX_BYTES = 128 * 1024 * 1024
MAX_LINES = 500000
MAX_RUNS = 64
MAX_UNITS = 128


def number(value):
    try:
        value = float(value)
    except (ValueError, TypeError):
        return None
    return value if math.isfinite(value) and value >= 0 else None


def observation(row, known_field, value_field):
    return row[known_field] == 'true' and row[value_field] == 'true'


def ranged_event(row, known_field, range_field):
    return {'time_s': number(row[0]),
            'slant_m': number(row[range_field]) if row[known_field] == 'true' else None}


def new_run():
    return {'expected_type': None, 'reported_types': [], 'own_ids': [],
            'own_samples': 0, 'units': {}, 'shots': [], 'gun_bursts': [], 'coverage_issues': [],
            'gun_event_ids': {'start': None, 'end': None},
            'last_own_argument_reads': {}, 'loaded_identity_verified': False}


def own_record(run, row):
    if len(row) != 23:
        raise ValueError('Malformed OWN record')
    if row[2] not in run['own_ids']:
        if run['own_ids']:
            raise ValueError('Ownship identity changed; split runs using fresh missions')
        run['own_ids'].append(row[2])
    if row[3] == 'true' and row[4] not in run['reported_types']:
        run['reported_types'].append(row[4])
    run['own_samples'] += 1
    for index, argument in enumerate((600, 601, 602, 0, 3, 5, 22)):
        field = 9 + index * 2
        run['last_own_argument_reads'][str(argument)] = {
            'read_ok': row[field] == 'true',
            'value': number(row[field + 1]) if row[field] == 'true' else None}


def unit_record(run, row):
    if len(row) != 17:
        raise ValueError('Malformed threat observation')
    key = row[1] + '/' + row[2]
    if key not in run['units']:
        if len(run['units']) >= MAX_UNITS:
            raise ValueError('Threat-unit budget exceeded')
        run['units'][key] = {'samples': 0, 'known_reports': {}, 'first': {}, 'minimum_slant_m': None}
    unit = run['units'][key]
    unit['samples'] += 1
    distance = number(row[16]) if row[15] == 'true' else None
    if distance is not None:
        previous = unit['minimum_slant_m']
        unit['minimum_slant_m'] = distance if previous is None else min(previous, distance)
    fields = {'radar_report': (6, 7), 'visual_report': (9, 10),
              'optic_report': (11, 12), 'ir_report': (13, 14)}
    for name, (known, value) in fields.items():
        unit['known_reports'][name] = unit['known_reports'].get(name, 0) + (row[known] == 'true')
        if observation(row, known, value) and name not in unit['first']:
            unit['first'][name] = ranged_event(row, 15, 16)
    if row[3:6] == ['true', 'true', 'true'] and 'radar_target' not in unit['first']:
        unit['first']['radar_target'] = ranged_event(row, 15, 16)
    if row[8] == 'true' and 'truncated_battery' not in run['coverage_issues']:
        run['coverage_issues'].append('truncated_battery')


def summarize(path):
    path = Path(path)
    if path.stat().st_size > MAX_BYTES:
        raise ValueError('Trial log exceeds 128 MiB')
    runs, run = [], None
    with path.open(encoding='utf-8-sig', errors='replace') as source:
        for index, line in enumerate(source):
            if index >= MAX_LINES:
                raise ValueError('Trial log exceeds line budget')
            if PREFIX not in line:
                continue
            row = line.split(PREFIX, 1)[1].strip().split('|')
            if row[:2] == ['SCHEMA', '2']:
                if len(runs) >= MAX_RUNS:
                    raise ValueError('Trial run budget exceeded')
                run = new_run()
                runs.append(run)
                continue
            if run is None:
                raise ValueError('Missing schema-2 header; use the matching observer')
            if row[0] == 'TRIAL_AIRCRAFT' and len(row) == 2:
                run['expected_type'] = row[1]
                continue
            if row[0] == 'GUN_EVENTS' and len(row) == 3:
                run['gun_event_ids'] = {'start': number(row[1]), 'end': number(row[2])}
                continue
            if len(row) < 2 or number(row[0]) is None:
                raise ValueError('Invalid trial record')
            kind = row[1]
            if kind == 'OWN':
                own_record(run, row)
            elif kind in ('SHOT', 'GUN_START', 'GUN_END') and len(row) == 7:
                if len(run['shots']) + len(run['gun_bursts']) >= 1024:
                    raise ValueError('Shot budget exceeded')
                shot = ranged_event(row, 5, 6)
                shot.update(event=kind, group=row[2], unit_id=row[3], target_id=row[4])
                collection = run['shots'] if kind == 'SHOT' else run['gun_bursts']
                collection.append(shot)
            elif len(row) == 17:
                unit_record(run, row)
            else:
                issue = row[-1]
                if issue not in ('OWN_UNAVAILABLE', 'UNIT_UNAVAILABLE', 'GROUP_UNAVAILABLE', 'UNIT_BUDGET', 'EVENT_BUDGET'):
                    raise ValueError('Unknown trial record')
                if issue not in run['coverage_issues']:
                    run['coverage_issues'].append(issue)
    for run in runs:
        for shot in run['shots'] + run['gun_bursts']:
            shot['attributed_to_ownship'] = (shot['target_id'] in run['own_ids']
                if run['own_ids'] and shot['target_id'] != 'unknown' else None)
    return {'schema': 1, 'runs': runs, 'meaning': 'First positive reports in recorded windows; not calibrated detection ranges'}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('log', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    options = parser.parse_args()
    if options.output.resolve() == options.log.resolve() or options.output.exists():
        raise ValueError('Choose a new summary file, distinct from the input log')
    options.output.write_text(json.dumps(summarize(options.log), indent=2) + '\n')
