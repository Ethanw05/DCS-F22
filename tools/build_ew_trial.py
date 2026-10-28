"""Create the playable EW mission from a known working local F-22 mission."""
import argparse
import copy
import json
import math
from pathlib import Path
import zipfile
from lupa.lua51 import LuaRuntime


def plain(value):
    if hasattr(value, 'items'):
        return {k: plain(v) for k, v in value.items()}
    return value


def lua(value):
    if isinstance(value, dict):
        return '{'+','.join('['+lua(k)+']='+lua(v) for k, v in value.items())+'}'
    if isinstance(value, str):
        return json.dumps(value, ensure_ascii=False)
    if isinstance(value, bool):
        return 'true' if value else 'false'
    if value is None:
        return 'nil'
    return repr(value)


def waypoint(x, y, heading, distance, name, speed=230, altitude=10000):
    return dict(x=x+math.cos(heading)*distance, y=y+math.sin(heading)*distance,
                alt=altitude, alt_type='BARO', type='Turning Point', action='Turning Point',
                speed=speed, speed_locked=True, ETA=0, ETA_locked=False, name=name,
                task=dict(id='ComboTask', params=dict(tasks={})))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--template', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parent
    with zipfile.ZipFile(args.template) as archive:
        entries = {name: archive.read(name) for name in archive.namelist()}
    runtime = LuaRuntime()
    runtime.execute(entries['mission'].decode('utf-8-sig'))
    mission = plain(runtime.globals().mission)
    blue = mission['coalition']['blue']['country'][1]
    red = mission['coalition']['red']['country'][1]
    player = blue['plane']['group'][1]
    jammer = copy.deepcopy(red['plane']['group'][1])
    x, y = -300000.0, 555000.0
    heading = math.atan2(80000, -18000)
    player.update(name='F22 EW Player Flight', x=x, y=y, groupId=9001, task='Nothing',
                  lateActivation=False, uncontrolled=False)
    unit = player['units'][1]
    unit.update(name='F22 EW Player', unitId=9001, x=x, y=y, heading=heading,
                psi=-heading, alt=10000, speed=230, skill='Player')
    player['units'] = {1: unit}
    player['route'] = {'points': {1: waypoint(x,y,heading,0,'EW START'),
                                  2: waypoint(x,y,heading,50000,'SAM APPROACH'),
                                  3: waypoint(x,y,heading,110000,'COAST EXIT')}}
    unit['payload'] = dict(fuel=8200, flare=120, chaff=120, gun=100, pylons={
        1: {'CLSID': '{AIM9X-BLKII}'}, 3: {'CLSID': '{AIM-120C-7}'},
        4: {'CLSID': '{AIM-120C-7}'}, 11: {'CLSID': '{AIM9X-BLKII}'}})
    jx, jy = x+math.cos(heading)*65000, y+math.sin(heading)*65000
    jammer.update(name='EW Jammer Flight', groupId=9010, x=jx, y=jy, task='Nothing',
                  lateActivation=False, uncontrolled=False, start_time=0)
    enemy = jammer['units'][1]
    enemy.update(name='EW Jammer', unitId=9010, type='F-15C', x=jx, y=jy, alt=10000,
                 heading=heading, psi=-heading, speed=230, skill='Excellent', livery_id='')
    enemy['payload'] = dict(fuel=6000, flare=0, chaff=0, gun=0, pylons={})
    jammer['units'] = {1: enemy}
    jammer['route'] = {'points': {1: waypoint(jx,jy,heading,0,'JAMMER'),
                                  2: waypoint(jx,jy,heading,160000,'JAMMER EXIT')}}
    hold = dict(enabled=True, auto=False, id='WrappedAction', number=1,
                params=dict(action=dict(id='Option', params=dict(name=0,value=4))))
    jammer['route']['points'][1]['task']['params']['tasks'] = {1: hold}
    blue['plane']['group'] = {1: player}
    red['plane']['group'] = {1: jammer}
    ground_units = {}
    for index, (name, kind, dx, dy) in enumerate([
        ('EW Buk Search','SA-11 Buk SR 9S18M1',0,0),
        ('EW Buk Tracker','SA-11 Buk LN 9A310M1',100,150),
        ('EW Buk Command','SA-11 Buk CC 9S470M1',-80,100)], 1):
        ground_units[index] = dict(name=name,type=kind,unitId=9020+index,
            x=-318000+dx,y=635000+dy,heading=0,skill='Excellent',playerCanDrive=False)
    ground_point = dict(x=-318000,y=635000,speed=0,action='Off Road',type='Turning Point',
                        task=dict(id='ComboTask',params=dict(tasks={})))
    ground_group = dict(name='EW SAM Site',groupId=9020,task='Ground Nothing',
        visible=False,hidden=False,lateActivation=False,start_time=0,x=-318000,y=635000,
        units=ground_units,route={'points': {1: ground_point}})
    red['vehicle'] = {'group': {1: ground_group}}
    mission['sortie'] = 'F-22A - EW Duel and Radar Trial'
    mission['descriptionText'] = (
        'Airborne EW training, Caucasus. Heading 103 degrees TRUE, 33,000 ft, about 450 KTAS. '
        'One unarmed F-15C 35 NM ahead at your altitude follows a parallel route and cycles ECM. '
        'A Buk radar site near Kobuleti watches your approach. SAM starts on weapon hold; '
        'Radio menu -> F10 Other -> EW Trial can enable live fire. Aircraft damage remains enabled.\n\n'
        '0-45s: ECM OFF baseline. 45-90s: use Radio menu -> F10 Other -> EW Trial -> Toggle YOUR ECM to switch ON. '
        '90s: switch YOUR ECM OFF. Enemy jammer requests ON at 135s, OFF at 180s, ON at 225s, '
        'and OFF at 270s. Afterward use F10 for either jammer and continue free flight. '
        'Radar and RWR are enabled by the dedicated test hook; saved controls are unchanged.\n\n'
        'Logging is automatic in dcs.log for 20 minutes. Enemy commands, real receiver J/N, '
        'track timestamps/uncertainty, own host ECM enabled state, enemy radar detection/lock '
        'and weapon events are logged separately. An ECM enabled light alone does not prove '
        'RF transmission. Incoming model uses estimated equivalent noise; advanced ECCM is unfinished.')
    mission['descriptionBlueTask'] = mission['descriptionText']
    mission['forcedOptions'].update(immortal=False, easyFlight=False, easyCommunication=True,
                                    externalViews=True, f10View='optview_all')
    mission['weather']['wind'] = {key: dict(speed=0,dir=0) for key in ('atGround','at2000','at8000')}
    mission['weather']['clouds'].update(density=0,base=2500,thickness=200)
    mission['weather']['clouds'].pop('preset',None)
    script = (root/'diagnostics/F22EWTrialMission.lua').read_text(encoding='utf-8')
    mission['trig'] = dict(custom={},events={},func={},flag={1:True},
        conditions={1:'return(true)'},actions={1:'a_do_script('+lua(script)+');'},
        funcStartup={1:'if mission.trig.conditions[1]() then mission.trig.actions[1]() end'})
    mission['trigrules'] = {1: dict(comment='EW Trial initialization',predicate='triggerStart',
        rules={},actions={1:dict(predicate='a_do_script',text=script)},colorItem='0xffffffff')}
    entries['mission'] = ('mission='+lua(mission)+'\n').encode('utf-8')
    entries['l10n/DEFAULT/dictionary'] = b'dictionary={}\n'
    args.output.parent.mkdir(parents=True,exist_ok=True)
    with zipfile.ZipFile(args.output,'w',zipfile.ZIP_DEFLATED) as archive:
        for name,data in entries.items(): archive.writestr(name,data)
    print(args.output)


if __name__ == '__main__':
    main()
