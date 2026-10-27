"""Pinned, scoped complexity gate for new navigation/reference contract helpers."""
from importlib.metadata import version
from pathlib import Path

import lizard

ROOT = Path(__file__).resolve().parents[1]
MODULES = (
    'Gins_Alignment', 'Gins_References', 'Attitude_References', 'Altitude_Alerts',
    'Recovery_Context', 'Physical_Snapshot', 'Equipment_Conditions', 'Entry_Transaction',
    'Cockpit_References', 'Nav_Marks_Time', 'Nav_Publication', 'Mission_Data',
)
NAV_HELPERS = {
    'reference_estimates', 'observed_angle', 'host_observations', 'estimate_observations',
    'navigation_reference', 'hud_projection_reference', 'ground_speed', 'ownship',
}


def main():
    if version('lizard') != '1.17.31':
        raise SystemExit('Install tools/requirements-navigation.txt: lizard 1.17.31 is required')
    paths = [ROOT / 'Cockpit/Scripts/Systems' / (name + '.lua') for name in MODULES]
    paths.extend(ROOT / 'EFM/source' / name for name in ('CniPower.h', 'NavigationSnapshot.h'))
    nav = ROOT / 'Cockpit/Scripts/Systems/Navigation_System.lua'
    paths.append(nav)
    measured = []
    for path in paths:
        for function in lizard.analyze_file(str(path)).function_list:
            if path == nav and function.name not in NAV_HELPERS:
                continue
            measured.append((path, function))
    failures = 0
    for path, function in measured:
        if function.nloc > 60 or function.cyclomatic_complexity > 15:
            print(f'{path.relative_to(ROOT)}:{function.start_line}: '
                  f'{function.name}: CCN={function.cyclomatic_complexity} NLOC={function.nloc}')
            failures += 1
    print(f'Lizard 1.17.31: {len(measured)} focused helpers; '
          f'max CCN={max(f.cyclomatic_complexity for _, f in measured)}, '
          f'NLOC={max(f.nloc for _, f in measured)}; {failures} violations')
    print('Scope excludes retained large HUD/UFC/legacy callbacks; no whole-file compliance claim.')
    raise SystemExit(bool(failures))


if __name__ == '__main__':
    main()
