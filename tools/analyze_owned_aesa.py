"""Summarize measured AESA telemetry; no mission truth or simulator required."""
from pathlib import Path
import argparse
import collections
import json
import math
import statistics


def norm(values):
    return math.sqrt(sum(v*v for v in values))


def distribution(values):
    if not values:
        return None
    return {"count": len(values), "min": min(values), "median": statistics.median(values), "max": max(values)}


def positive_covariance(row):
    lower = [[0.0]*6 for _ in range(6)]
    for i in range(6):
        for j in range(i+1):
            value = row[f'COV_{j}{i}']-sum(lower[i][k]*lower[j][k] for k in range(j))
            if not math.isfinite(value) or (i == j and value <= 0):
                return False
            lower[i][j] = math.sqrt(value) if i == j else value/lower[j][j]
    return True


def analyze(path):
    schemas, rows = {}, collections.defaultdict(list)
    schema_types = {'schema': 'sample', 'avionics_schema': 'avionics_sample',
                    'service_schema': 'service', 'aesa_schema': 'aesa'}
    with path.open(encoding='utf-8', errors='replace') as source:
        for line in source:
            marker = 'F22_RADAR_TEST (Main): '
            if marker not in line:
                continue
            cells = line.split(marker, 1)[1].strip().split(',')
            if len(cells) < 3:
                continue
            kind = cells[1]
            if kind in schema_types:
                schemas[schema_types[kind]] = cells[2:]
            elif kind in schemas and len(rows[kind]) < 100000:
                try:
                    rows[kind].append(dict(zip(schemas[kind], map(float, cells[2:]), strict=True)))
                except (ValueError, TypeError):
                    continue
    samples = rows['sample']
    observed, speeds, steps, raw_steps, rate_residual, sigmas = {}, [], [], [], [], []
    covariance_ok = 0
    for row in rows['aesa']:
        key = row['generation'], row['ID']
        previous = observed.get(key)
        if previous and row['TIME'] <= previous['TIME']:
            continue
        covariance_ok += positive_covariance(row)
        if row['VELOCITY_VALID'] == 1:
            velocity = [row[k] for k in ('VN', 'VU', 'VE')]
            speeds.append(norm(velocity))
            sigmas.append(row['VELOCITY_SIGMA_MPS'])
            delta = [row[k]-row[o] for k, o in zip(('N','U','E'), ('ORIGIN_N','ORIGIN_U','ORIGIN_E'))]
            relative_velocity = [row[k]-row[o] for k, o in zip(('VN','VU','VE'), ('OWN_VN','OWN_VU','OWN_VE'))]
            rate_residual.append(abs(sum(v*d for v, d in zip(relative_velocity, delta))/norm(delta)-row['RANGE_RATE']))
            if previous and previous['VELOCITY_VALID'] == 1:
                steps.append(norm([row[k]-previous[k] for k in ('VN','VU','VE')]))
                dt = row['TIME']-previous['TIME']
                raw = [(row[k]-previous[k])/dt for k in ('RAW_N','RAW_U','RAW_E')]
                if 'raw_velocity' in previous:
                    raw_steps.append(norm([a-b for a,b in zip(raw, previous['raw_velocity'])]))
                row['raw_velocity'] = raw
        observed[key] = row
    envelopes = [r for r in rows['avionics_sample'] if r['F22_FC_DLZ_VALID'] == 1 and r['F22_FC_DLZ_DYNAMIC'] == 1]
    ranges = [r['F22_FC_MAX_NM']*1852 for r in envelopes]
    nav_changes = []
    for row in rows['service']:
        state = [row.get('F22_TSD_NAV_LAYER'), row.get('F22_TSD_NAV_LEG_01_VALID')]
        if state[0] is not None and (not nav_changes or nav_changes[-1]['state'] != state):
            nav_changes.append({'time_s': row['t_model_s'], 'state': state,
                                'envelope_axis': row.get('F22_RDR_LAR_AXIS_VALID')})
    return {
        'model_duration_s': samples[-1]['t_model_s'] if samples else None,
        'rows': {key: len(value) for key, value in rows.items()},
        'last_service': rows['service'][-1] if rows['service'] else None,
        'stt_samples': sum(r['F22_RADAR_STT_VALID'] == 1 for r in samples),
        'estimated_speed_mps': distribution(speeds), 'estimated_velocity_step_mps': distribution(steps),
        'raw_position_derivative_step_mps': distribution(raw_steps),
        'doppler_posterior_residual_mps': distribution(rate_residual),
        'worst_axis_velocity_sigma_mps': distribution(sigmas),
        'positive_covariance_reports': covariance_ok,
        'dynamic_rmax_m': distribution(ranges),
        'successive_rmax_change_m': distribution([abs(a-b) for a,b in zip(ranges[1:],ranges)]),
        'native_weapon_launch_sequence': max((r['F22_LAUNCH_SEQUENCE'] for r in rows['avionics_sample']), default=0),
        'nav_layer_and_route_transitions': nav_changes,
    }


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('log', type=Path)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    result = json.dumps(analyze(args.log), indent=2, allow_nan=False)
    if args.output:
        args.output.write_text(result+'\n', encoding='utf-8')
    print(result)
