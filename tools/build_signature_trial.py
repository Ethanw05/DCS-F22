"""Build an external, passive SAM signature observation mission; never install/run DCS."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import zipfile
from lupa.lua51 import LuaRuntime
from build_ew_gauntlet import ground_group, lua, mission_overrides, waypoint, set_route_timing

ROOT = Path(__file__).resolve().parents[1]
NAME = 'F22-RCS-SAM-Qualification.miz'


def plain(value, depth=0):
    if depth > 24:
        raise ValueError('Mission table depth exceeds24')
    if hasattr(value, 'items'):
        items = list(value.items())
        if len(items) > 4096:
            raise ValueError('Mission table exceeds4096 items')
        return {key: plain(item, depth + 1) for key, item in items}
    return value


def observer_script(names):
    module = (ROOT / 'tools/diagnostics/observe_signature_sam.lua').read_text()
    return ('local module=(function()\n' + module + '\nend)()\n'
            'local function emit(...)\n'
            ' local row={"F22_RCS_SAM"}\n'
            ' for i=1,select("#",...) do row[#row+1]=tostring(select(i,...)) end\n'
            ' env.info(table.concat(row,"|"))\nend\n'
            'local observer=module.new({unit=Unit.getByName,group=Group.getByName,\n'
            ' radar_kind=Controller.Detection.RADAR,shot_kind=world.event.S_EVENT_SHOT,\n'
            ' visual_kind=Controller.Detection.VISUAL,optic_kind=Controller.Detection.OPTIC,\n'
            ' ir_kind=Controller.Detection.IRST,\n'
            ' emit=emit},"F22 RCS Player",' + lua(names) + ')\n'
            'world.addEventHandler(observer)\n'
            'timer.scheduleFunction(function(_,now)\n'
            ' observer:sample(now)\n'
            ' if observer.stopped then world.removeEventHandler(observer);return nil end\n'
            ' return now+1\nend,nil,timer.getTime()+1)\n')


def build(output, altitude, original=None):
    if output.name != NAME or ROOT == output or ROOT in output.parents:
        raise ValueError('Use the dedicated mission filename in an external output directory')
    if not math.isfinite(altitude) or not 100 <= altitude <= 10000:
        raise ValueError('Trial altitude must be100..10000 m MSL')
    template = original or ROOT / 'Missions/Ground Attack/F-22A - Ground Attack - JDAM AUTO.miz'
    with zipfile.ZipFile(template) as archive:
        entries = {name: archive.read(name) for name in archive.namelist()}
    runtime = LuaRuntime()
    runtime.execute(entries['mission'].decode('utf-8-sig'))
    mission = plain(runtime.globals().mission)
    # Independent short-range self-contained systems avoid missing battery components.
    centre = (-278100, 658400)
    kinds = ['Tor 9A331', 'Osa 9A33 ln', '2S6 Tunguska']
    groups = []
    for index in range(20):
        position = (centre[0] + (index % 5) * 700, centre[1] + (index // 5) * 700)
        groups.append(ground_group(index + 1, f'RCS SAM {index + 1:02}',
                                   [kinds[index % 3]], position))
    if original:
        player = mission['coalition']['blue']['country'][1]['plane']['group'][1]
        groups = list(mission['coalition']['red']['country'][1]['vehicle']['group'].values())
    else:
        mission.update(mission_overrides(groups))
        player = mission['coalition']['blue']['country'][0]['plane']['group'][0]
    start = (centre[0], centre[1] - 30000)
    route = [waypoint('START 16NM', start, altitude, 200),
             waypoint('SAM FIELD', (centre[0], centre[1] + 1000), altitude, 200),
             waypoint('EXIT', (centre[0], centre[1] + 40000), altitude, 200)]
    set_route_timing(route)
    if not original:
        player.update(name='F22 RCS Player Flight', x=start[0], y=start[1], route={'points': route})
        player['units'][0].update(x=start[0], y=start[1], alt=altitude,
                                 speed=200, heading=math.pi / 2, psi=-math.pi / 2)
    unit = player['units'][1 if original else 0]
    unit['name'] = 'F22 RCS Player'
    brief = ('RCS HOST QUALIFICATION:20 active Excellent Tor/Osa/Tunguska systems, '
             'alarm RED and weapons FREE. No invisible/immortal or forced detection/lock. '
             'Fly repeated matched passes, ECM OFF, bay closed/open, then external stores. '
             'Do not infer stealth from an RWR silence or a single1nm pass. '
             'Mission log records actual RADAR detection, current radar target and shot events '
             'separately. The optional passive F22RcsTelemetry hook records achieved bay/gear '
             'arguments and exported jammer flag. No hook is installed by this builder. '
             'This mission measures behavior; it does not implement dynamic ownship RCS.')
    if original:
        brief = ('Instrumented copy of the supplied EW-Gauntlet. Original units, route, '
                 'altitude, payload, ROE and activation are retained. Actual radar/visual/'
                 'optical/IR detections, current radar targets and shots are logged separately. '
                 'No signature or engagement behavior is modified.\n\n' + mission['descriptionText'])
    mission.update(sortie='F22 RCS SAM Qualification', descriptionText=brief,
                   descriptionBlueTask=brief)
    script = observer_script([group['name'] for group in groups])
    # Lua strings are escaped by the bounded serializer; no arbitrary shell text.
    mission['trig'] = dict(custom={}, events={}, func={}, flag={1: True},
        conditions={1: 'return(true)'}, actions={1: 'a_do_script(' + lua(script) + ');'},
        funcStartup={1: 'if mission.trig.conditions[1]() then mission.trig.actions[1]() end'})
    mission['trigrules'] = {1: dict(comment='Passive signature observations', predicate='triggerStart',
        rules={}, actions={1: dict(predicate='a_do_script', text=script)}, colorItem='0xffffffff')}
    entries['mission'] = ('mission=' + lua(mission) + '\n').encode()
    entries['l10n/DEFAULT/dictionary'] = b'dictionary={}\n'
    output.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(output, 'w', zipfile.ZIP_DEFLATED) as archive:
        for name, data in entries.items():
            archive.writestr(name, data)
    with zipfile.ZipFile(output) as archive:
        if archive.testzip() is not None:
            raise ValueError('Trial ZIP integrity failed')
        runtime.execute(archive.read('mission').decode())
    check = runtime.eval('function(s) return loadstring(s)~=nil end')
    if not check(script):
        raise ValueError('Mission observer is not Lua5.1 syntax')
    print(json.dumps({'path': str(output), 'sha256': hashlib.sha256(output.read_bytes()).hexdigest(),
                      'observed_groups': len(groups), 'altitude_msl_m': unit['alt'],
                      'preserved_original': str(original) if original else None, 'executed': False}))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--altitude', type=float, default=1500)
    parser.add_argument('--observe-original', type=Path,
                        help='Instrument an external copy while preserving the original mission setup')
    args = parser.parse_args()
    build(args.output.resolve(), args.altitude, args.observe_original)
