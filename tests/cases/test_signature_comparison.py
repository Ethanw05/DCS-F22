"""Matched control setup and native report interpretation, independent of RCS tuning."""
import contextlib
import io
from pathlib import Path
import sys
import tempfile
import unittest
import zipfile

from lupa.lua51 import LuaRuntime
from host import ROOT

sys.path.insert(0, str(ROOT / 'tools'))
sys.path.insert(0, str(ROOT / 'tools/diagnostics'))
from build_signature_comparison import comparison
from build_signature_trial import build, NAME, plain, observer_script
from summarize_signature_trial import summarize


def mission(path):
    lua = LuaRuntime()
    with zipfile.ZipFile(path) as archive:
        lua.execute(archive.read('mission').decode())
    return plain(lua.globals().mission)


class SignatureComparison(unittest.TestCase):
    def test_matched_clean_player_and_client_trials_preserve_threats_and_route(self):
        with tempfile.TemporaryDirectory() as directory, contextlib.redirect_stdout(io.StringIO()):
            output = Path(directory) / 'comparison'
            manifest = comparison(output)
            trials = [mission(Path(item['path'])) for item in manifest['trials']]
            self.assertEqual(len(trials), 4)
            baseline = trials[0]
            for trial, report in zip(trials, manifest['trials']):
                self.assertEqual(trial['coalition']['red'], baseline['coalition']['red'])
                group = trial['coalition']['blue']['country'][1]['plane']['group'][1]
                self.assertEqual(group['route'], baseline['coalition']['blue']['country'][1]['plane']['group'][1]['route'])
                unit = group['units'][1]
                self.assertEqual(unit['type'], report['aircraft'])
                self.assertEqual(unit['skill'], report['slot'])
                self.assertEqual(unit['payload']['pylons'], {})
                self.assertEqual((unit['payload']['gun'], unit['payload']['flare'], unit['payload']['chaff']), (0, 0, 0))
                self.assertFalse(trial['forcedOptions']['immortal'])
            groups = baseline['coalition']['red']['country'][1]['vehicle']['group']
            kinds = [g['units'][1]['type'] for g in groups.values()]
            self.assertEqual(len(kinds), 20)
            self.assertEqual(kinds.count('Strela-10M3'), 4)
            self.assertEqual(kinds.count('ZU-23 Emplacement Closed'), 4)
            for g in groups.values():
                options = g['route']['points'][1]['task']['params']['tasks']
                self.assertEqual(options[1]['params']['action']['params'], {'name': 9, 'value': 2})
                self.assertEqual(options[2]['params']['action']['params'], {'name': 0, 'value': 0})
            with self.assertRaises(ValueError):
                comparison(output)

    def test_original_instrumentation_remains_a_preserving_mode(self):
        with tempfile.TemporaryDirectory() as directory, contextlib.redirect_stdout(io.StringIO()):
            original = Path(directory) / 'base' / NAME
            observed = Path(directory) / 'observed' / NAME
            build(original, 1500)
            build(observed, 1500, original)
            before, after = mission(original), mission(observed)
            self.assertEqual(before['coalition'], after['coalition'])
            self.assertEqual(before['forcedOptions'], after['forcedOptions'])
            with self.assertRaises(ValueError):
                build(Path(directory) / 'rejected' / NAME, 1500, original, clean=True)

    def observer(self):
        lua = LuaRuntime(unpack_returned_tuples=True)
        lua.globals().module = lua.execute((ROOT / 'tools/diagnostics/observe_signature_sam.lua').read_text())
        lua.execute('''
            rows={}; own_point={x=3,y=4,z=12}; sam_point={x=0,y=0,z=0}
            own={getID=function()return 22 end,getTypeName=function()return 'F-22A'end,
                 getPoint=function()return own_point end,
                 getDrawArgumentValue=function(_,arg)return arg==600 and .5 or 0 end}
            control={getDetectedTargets=function()return {}end}
            sam={getID=function()return 7 end,getPoint=function()return sam_point end,
                 getController=function()return control end,getRadar=function()return true,nil end}
            group={getUnits=function()return{sam}end,getName=function()return'SAM'end}
            sam.getGroup=function()return group end
            observer=module.new({unit=function()return own end,group=function()return group end,
                radar_kind=1,visual_kind=2,optic_kind=3,ir_kind=4,shot_kind=2,observe_ownship=true,
                emit=function(...)rows[#rows+1]={...}end},'PLAYER',{'SAM'})
        ''')
        return lua

    def test_slant_distance_and_server_argument_reads_preserve_zero_and_unknown(self):
        lua = self.observer()
        lua.execute('observer:sample(1)')
        own, sam = lua.globals().rows[1], lua.globals().rows[2]
        self.assertEqual((own[5], own[10], own[11], own[12], own[13]), ('F-22A', True, .5, True, 0))
        self.assertEqual((sam[16], sam[17]), (True, 13))
        lua.execute('own_point={x=0,y=0,z=0};observer:sample(2)')
        self.assertEqual((lua.globals().rows[4][16], lua.globals().rows[4][17]), (True, 0))
        lua.execute('own_point={x=0/0,y=0,z=0};own.getDrawArgumentValue=nil;observer:sample(3)')
        self.assertFalse(lua.globals().rows[5][6])
        self.assertFalse(lua.globals().rows[5][10])
        self.assertFalse(lua.globals().rows[6][16])

    def test_first_reports_tracking_and_attributed_shots_stay_distinct_per_run(self):
        prefix = 'INFO SCRIPTING: F22_RCS_SAM|'
        own = '1|OWN|22|true|F-22A|true|0|1500|0|' + '|'.join(['true', '0'] * 7)
        report = '2|SAM|7|true|true|false|true|true|false|true|false|true|false|true|false|true|9000'
        track = '3|SAM|7|true|true|true|true|true|false|true|false|true|false|true|false|true|8000'
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'dcs.log'
            rows = ['SCHEMA|2|fields', 'TRIAL_AIRCRAFT|F-22A', own, report, track,
                    '3.5|SHOT|SAM|7|99|true|7900', '4|SHOT|SAM|7|22|false|0',
                    '4.5|SHOT|SAM|7|unknown|true|7800', 'SCHEMA|2|fields', own]
            path.write_text('\n'.join(prefix + row for row in rows))
            runs = summarize(path)['runs']
            first = runs[0]['units']['SAM/7']['first']
            self.assertEqual(first['radar_report'], {'time_s': 2, 'slant_m': 9000})
            self.assertEqual(first['radar_target'], {'time_s': 3, 'slant_m': 8000})
            self.assertNotIn('ir_report', first)
            self.assertEqual([s['attributed_to_ownship'] for s in runs[0]['shots']], [False, True, None])
            self.assertIsNone(runs[0]['shots'][1]['slant_m'])
            self.assertEqual(runs[1]['units'], {})
            path.write_text(prefix + report)
            with self.assertRaises(ValueError):
                summarize(path)

    def test_battery_and_total_unit_budgets_remain_bounded(self):
        lua = self.observer()
        lua.execute('''
            group.getUnits=function()local units={};for i=1,17 do units[i]=sam end;return units end
            local names={};for i=1,9 do names[i]='SAM'..i end
            observer=module.new({unit=function()return own end,group=function()return group end,
                radar_kind=1,observe_ownship=true,emit=function(...)rows[#rows+1]={...}end},'PLAYER',names)
            assert(not observer:sample(1))
        ''')
        self.assertEqual(len(lua.globals().rows), 130)
        self.assertTrue(lua.globals().rows[2][9])
        self.assertEqual(lua.globals().rows[130][2], 'UNIT_BUDGET')

    def test_generated_mission_observer_logs_gun_bursts_and_native_records_end_to_end(self):
        lua = self.observer()
        lua.execute('''
            messages={};env={info=function(line)messages[#messages+1]=line end}
            Unit={getByName=function()return own end};Group={getByName=function()return group end}
            Controller={Detection={RADAR=1,VISUAL=2,OPTIC=3,IRST=4}}
            world={event={S_EVENT_SHOT=2,S_EVENT_SHOOTING_START=23,S_EVENT_SHOOTING_END=24},
                   addEventHandler=function(value)handler=value end,removeEventHandler=function()end}
            timer={getTime=function()return 0 end,scheduleFunction=function(value)scheduled=value end}
            control.getDetectedTargets=function(_,kind)if kind==1 then return{{object=own}}end;return{}end
        ''')
        lua.execute(observer_script(['SAM']))
        lua.execute('''
            scheduled(nil,1)
            handler:onEvent({id=2,time=1.5,initiator=sam,weapon={getTarget=function()return own end}})
            handler:onEvent({id=23,time=2,initiator=sam})
            handler:onEvent({id=24,time=3,initiator=sam})
        ''')
        messages = lua.globals().messages
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'native.log'
            path.write_text('\n'.join(messages[i] for i in range(1, len(messages) + 1)))
            run = summarize(path)['runs'][0]
            self.assertEqual(run['reported_types'], ['F-22A'])
            self.assertEqual(run['units']['SAM/7']['first']['radar_report']['slant_m'], 13)
            self.assertEqual(run['units']['SAM/7']['minimum_slant_m'], 13)
            self.assertTrue(run['shots'][0]['attributed_to_ownship'])
            self.assertEqual([event['event'] for event in run['gun_bursts']], ['GUN_START', 'GUN_END'])
            self.assertIsNone(run['gun_bursts'][0]['attributed_to_ownship'])

    def test_fire_storm_hits_a_reported_limit_without_unbounded_logging(self):
        lua = self.observer()
        lua.execute('for i=1,1040 do observer:onEvent({id=2,time=i,initiator=sam}) end')
        self.assertEqual(lua.globals().observer.events, 1024)
        self.assertEqual(len(lua.globals().rows), 1025)
        self.assertEqual(lua.globals().rows[1025][2], 'EVENT_BUDGET')


if __name__ == '__main__':
    unittest.main()
