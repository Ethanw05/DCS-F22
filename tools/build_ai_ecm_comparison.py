"""Prepare matched Hornet/AI F-22 ECM missions externally; never install/run DCS."""
import argparse
import copy
import hashlib
import json
import math
from pathlib import Path
import zipfile

from lupa.lua51 import LuaRuntime
from build_ew_gauntlet import action, lua, mission_overrides, set_route_timing, waypoint
from build_signature_trial import ROOT, plain


def read_mission(data):
    """Load only the fixed repository template or our serialized output in an empty environment."""
    runtime = LuaRuntime(register_eval=False, register_builtins=False)
    load = runtime.eval('''function(text)
        local environment = {}
        local chunk = assert(loadstring(text))
        setfenv(chunk, environment)
        chunk()
        return environment.mission
    end''')
    return plain(load(data.decode('utf-8-sig')))


def aircraft_group(original, player, client):
    group = copy.deepcopy(original)
    name = 'Hornet ECM Observer' if player else 'AI F22 ECM Target'
    number = 1 if player else 2
    start = (-300000, 550000 if player else 624080)
    heading = math.pi / 2 if player else -math.pi / 2
    route = [waypoint('START', start, 10000, 230),
             waypoint('EXIT', (start[0], start[1] + (160000 if player else -160000)), 10000, 230)]
    set_route_timing(route)
    group.update(name=name, groupId=number, task='Nothing', start_time=0,
                 x=start[0], y=start[1], route={'points': route})
    unit = group['units'][0]
    unit.update(name=name, unitId=number, type='FA-18C_hornet' if player else 'F-22A',
                skill=('Client' if client else 'Player') if player else 'Excellent',
                x=start[0], y=start[1], alt=10000, alt_type='BARO', speed=230,
                heading=heading, psi=-heading, livery_id='', AddPropAircraft={})
    # me_crutches.lua maps the airborne Ace label to "Excellent".
    unit['payload'] = dict(fuel=4900 if player else 8200, flare=0, chaff=0, gun=0, pylons={})
    return group


def make_plan(template, ecm, client):
    mission = copy.deepcopy(template)
    mission.update(mission_overrides([]))
    blue = mission['coalition']['blue']['country'][0]
    original = blue['plane']['group'][0]
    player = aircraft_group(original, True, client)
    enemy = aircraft_group(original, False, client)
    enemy['route']['points'][0]['task']['params']['tasks'] = [
        action(1, 'Option', {'name': 0, 'value': 4}),  # Weapons HOLD.
        action(2, 'Option', {'name': 1, 'value': 0}),  # No evasive route changes.
        action(3, 'Option', {'name': 13, 'value': ecm})]
    blue['plane']['group'] = [player]
    red = mission['coalition']['red']['country'][0]
    red.pop('vehicle', None)
    red['plane'] = {'group': [enemy]}
    label = 'ALWAYS' if ecm == 3 else 'NEVER'
    brief = (f'HORNET VS AI F-22: ECM {label}. AI ECM Using is explicitly set to '
             f'{label} USE at waypoint 1 (option 13, value {ecm}). This is a policy '
             'request, not a measurement of transmission. You fly a clean F/A-18C '
             'against one clean, unarmed Ace F-22. Start 40 NM head-on at 10,000 m '
             'MSL and 230 m/s each. AI weapons HOLD; no evasive route changes. '
             'Set your radar and compare search/track/HOJ behavior at matched ranges '
             'in fresh ALWAYS and NEVER missions. Keep your ECM off. Do not infer '
             'failure from a close-range lock alone; burn-through is possible. '
             'No player radar controls are forced, no hooks are needed, and the '
             'production F-22 RCS is unchanged. Client variants require the F-22 '
             'mod on the server. Actual transmission and multiplayer effects remain '
             'unqualified until observed.')
    mission.update(sortie='Hornet vs AI F22 ECM ' + label,
                   descriptionText=brief, descriptionBlueTask=brief,
                   trig=dict(custom={}, events={}, func={}, flag={}, conditions={},
                             actions={}, funcStartup={}), trigrules={})
    mission['weather']['wind'] = {key: dict(speed=0, dir=0)
                                  for key in ('atGround', 'at2000', 'at8000')}
    mission['weather']['clouds'] = dict(density=0, base=2500, thickness=200, iprecptns=0)
    return mission


def verify_mission(mission, ecm, client):
    player = mission['coalition']['blue']['country'][1]['plane']['group'][1]['units'][1]
    enemy = mission['coalition']['red']['country'][1]['plane']['group'][1]
    unit = enemy['units'][1]
    assert player['type'] == 'FA-18C_hornet' and player['skill'] == ('Client' if client else 'Player')
    assert unit['type'] == 'F-22A' and unit['skill'] == 'Excellent'
    assert not unit['payload']['pylons'] and not unit['payload']['gun']
    tasks = enemy['route']['points'][1]['task']['params']['tasks']
    params = [task['params']['action']['params'] for task in tasks.values()]
    assert params == [{'name': 0, 'value': 4}, {'name': 1, 'value': 0}, {'name': 13, 'value': ecm}]
    assert math.isclose(math.hypot(player['x']-unit['x'], player['y']-unit['y']), 40 * 1852)
    assert player['alt'] == unit['alt'] == 10000
    assert not mission['trigrules'] and not mission['trig']['actions']


def build(output):
    output = Path(output).resolve()
    if output.exists() or output == ROOT or ROOT in output.parents:
        raise ValueError('Choose a new external output directory')
    template = ROOT / 'Missions/Ground Attack/F-22A - Ground Attack - JDAM AUTO.miz'
    with zipfile.ZipFile(template) as archive:
        entries = {name: archive.read(name) for name in archive.namelist()}
    mission = read_mission(entries['mission'])
    reports = []
    for client in (False, True):
        for ecm in (0, 3):
            mode, policy = ('MP' if client else 'SP'), ('NEVER' if ecm == 0 else 'ALWAYS')
            target = output / f'Hornet-vs-AI-F22-ECM-{policy}-{mode}.miz'
            data = ('mission=' + lua(make_plan(mission, ecm, client)) + '\n').encode()
            verify_mission(read_mission(data), ecm, client)
            target.parent.mkdir(parents=True, exist_ok=True)
            with zipfile.ZipFile(target, 'w', zipfile.ZIP_DEFLATED) as archive:
                for name, content in entries.items():
                    if name == 'mission':
                        content = data
                    elif name == 'l10n/DEFAULT/dictionary':
                        content = b'dictionary={}\n'
                    archive.writestr(name, content)
            with zipfile.ZipFile(target) as archive:
                assert archive.testzip() is None
                verify_mission(read_mission(archive.read('mission')), ecm, client)
            reports.append(dict(path=str(target), sha256=hashlib.sha256(target.read_bytes()).hexdigest(),
                                ai_ecm_option=ecm, player_slot='Client' if client else 'Player'))
    receipt = dict(schema=1, purpose='Isolate AI ECM activation policy from Ace skill',
                   missions=reports, production_changed=False, installed=False,
                   simulator_executed=False, transmission_observed=False,
                   template_sha256=hashlib.sha256(template.read_bytes()).hexdigest(),
                   source_registration_sha256=hashlib.sha256((ROOT / 'F-22A.lua').read_bytes()).hexdigest())
    (output / 'comparison.json').write_text(json.dumps(receipt, indent=2) + '\n')
    return receipt


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    print(json.dumps(build(parser.parse_args().output), indent=2))
