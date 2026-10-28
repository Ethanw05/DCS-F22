"""Ownship signature qualification observes host radar state without granting it."""
import unittest
from lupa.lua51 import LuaRuntime
from host import ROOT


class SignatureObservation(unittest.TestCase):
    def observer(self):
        lua = LuaRuntime(unpack_returned_tuples=True)
        module = lua.execute((ROOT / 'tools/diagnostics/observe_signature_sam.lua').read_text())
        lua.globals().observer_module = module
        lua.execute('''
            rows = {}
            own = {getID=function() return 22 end}
            other = {getID=function() return 99 end}
            targets = {}
            radar_on, radar_target = false, nil
            controller = {getDetectedTargets=function(_, kind)
                assert(kind==1); return targets
            end}
            sam = {getID=function() return 7 end,
                getRadar=function() return radar_on, radar_target end,
                getController=function() return controller end}
            group = {getUnits=function() return {sam} end,
                getName=function() return 'SAM' end}
            sam.getGroup=function() return group end
            api = {unit=function() return own end,group=function() return group end,
                radar_kind=1, shot_kind=2,
                emit=function(...) rows[#rows+1]={...} end}
            observer = observer_module.new(api, 'PLAYER', {'SAM'})
        ''')
        return lua

    def test_detection_tracking_and_shot_are_independent(self):
        lua = self.observer()
        lua.execute('radar_on=true;targets={{object=own}};observer:sample(1)')
        row = lua.globals().rows[1]
        self.assertTrue(row[4] and row[5] and row[7] and row[8])
        self.assertFalse(row[6])
        lua.execute('radar_target=own;observer:sample(2)')
        self.assertTrue(lua.globals().rows[2][6])
        lua.execute('observer:onEvent({id=2,time=2,initiator=sam,weapon={getTarget=function() return other end}})')
        self.assertEqual(lua.globals().rows[3][5], 99)

    def test_failed_or_oversized_report_is_unknown_not_no_detection(self):
        lua = self.observer()
        lua.execute('controller.getDetectedTargets=function() error("source unavailable") end;observer:sample(1)')
        self.assertFalse(lua.globals().rows[1][7])
        lua.execute('controller.getDetectedTargets=function() return targets end;for i=1,65 do targets[i]={object=other} end;observer:sample(2)')
        self.assertFalse(lua.globals().rows[2][7])

    def test_visual_detection_cannot_be_mislabeled_as_radar_acquisition(self):
        lua = self.observer()
        lua.execute('''
            api.visual_kind=2
            controller.getDetectedTargets=function(_,kind)
                if kind==2 then return {{object=own}} end
                return {}
            end
            observer:sample(1)
        ''')
        row = lua.globals().rows[1]
        self.assertTrue(row[7])
        self.assertFalse(row[8])
        self.assertTrue(row[10] and row[11])

    def test_clock_and_work_budgets_stop_without_changing_host(self):
        lua = self.observer()
        lua.execute('assert(observer:sample(10));assert(not observer:sample(10.1));assert(not observer:sample(9))')
        self.assertTrue(lua.globals().observer.stopped)
        self.assertEqual(len(lua.globals().rows), 1)
        self.assertFalse(lua.globals().radar_on)

    def telemetry(self):
        lua = LuaRuntime(unpack_returned_tuples=True)
        lua.execute('''
            now, calls, filename = 1, 0, 'C:/Missions/ordinary.miz'
            messages = {}
            log={INFO=1,write=function(_,_,message) messages[#messages+1]=message end}
            DCS={getMissionFilename=function() return filename end,
                 getModelTime=function() return now end,
                 setUserCallbacks=function(value) callbacks=value end}
            Export={LoGetAircraftDrawArgumentValue=function(arg)
                calls=calls+1;return arg==600 and .5 or 0 end,
                LoGetSelfData=function() return {Flags={Jamming=false},
                    Position={x=1,y=1500,z=2},Heading=0,Pitch=0,Bank=0} end}
        ''')
        lua.execute((ROOT / 'tools/diagnostics/F22RcsTelemetry.lua').read_text())
        return lua

    def test_passive_export_is_inert_outside_exact_dedicated_mission(self):
        lua = self.telemetry()
        lua.execute('callbacks.onSimulationStart();callbacks.onSimulationFrame()')
        self.assertEqual(lua.globals().calls, 0)
        self.assertEqual(len(lua.globals().messages), 0)

    def test_passive_export_records_achieved_arguments_and_unknown_reads(self):
        lua = self.telemetry()
        lua.execute('''
            filename='C:/Missions/F22-RCS-SAM-Qualification.miz'
            callbacks.onSimulationStart();callbacks.onSimulationFrame()
        ''')
        self.assertIn('|0.500000|', lua.globals().messages[3])
        self.assertIn('|false|1.000|1500.000|2.000|', lua.globals().messages[3])
        lua.execute('Export.LoGetAircraftDrawArgumentValue=nil;now=2;callbacks.onSimulationFrame()')
        self.assertIn('|unknown|unknown|', lua.globals().messages[4])


if __name__ == '__main__':
    unittest.main()
