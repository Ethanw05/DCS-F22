"""Exercise the passive recorder through the DCS callback/export boundaries."""
from pathlib import Path
import csv,tempfile,unittest
from lupa import LuaRuntime

HOOK=Path(__file__).resolve().parents[1]/'tools/diagnostics/F22TrimTelemetry.lua'

class TrimRecorderTests(unittest.TestCase):
    def test_sampling_pause_player_filter_and_restart(self):
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder);(root/'Logs/F22-Trim').mkdir(parents=True)
            lua=LuaRuntime(unpack_returned_tuples=True)
            g=lua.globals();g.destination=root.as_posix()+'/'
            lua.execute('''
                now=0; aircraft='F-15C'; valid=1; mode='normal'; calls=0
                DCS={getModelTime=function()return now end,setUserCallbacks=function(c) cb=c end}
                lfs={writedir=function()return destination end,mkdir=function()end}
                log={INFO=1,ERROR=2,write=function()end}
                LoGetSelfData=function()return {Name=aircraft,Position={y=3000},Pitch=.1,Bank=.2}end
                LoGetIndicatedAirSpeed=function()return 150 end
                get_param_handle=function(n)return {get=function()
                    if n=='EFM_TRIM_VALID'then return valid end
                    return 1
                end}end
                net={dostring_in=function(where,code)
                    calls=calls+1
                    if mode=='malformed'then return 'bad,row' end
                    if mode=='error'then error('export unavailable')end
                    return assert(load(code))()
                end}
            ''')
            lua.execute(HOOK.read_text())
            # DCS can invoke frame callbacks while loading, before start.
            g.cb.onSimulationFrame();self.assertEqual(g.calls,0)
            g.cb.onSimulationStart()
            def frame(t):g.now=t;g.cb.onSimulationFrame()
            frame(0);self.assertEqual(list(root.rglob('*.csv')),[])
            g.aircraft='F-22A';g.valid=0;frame(1)
            self.assertEqual(list(root.rglob('*.csv')),[])
            g.valid=1;frame(2);frame(2);frame(2.01);frame(2.06)
            g.mode='malformed';frame(3);g.mode='error';frame(4)
            g.mode='normal';frame(5);g.cb.onSimulationStop()
            old_calls=g.calls;frame(6);self.assertEqual(g.calls,old_calls)
            files=list(root.rglob('*.csv'));self.assertEqual(len(files),1)
            with files[0].open() as stream:rows=list(csv.DictReader(stream))
            self.assertEqual(len(rows),3)
            self.assertEqual(len(rows[0]),54)
            self.assertEqual(float(rows[0]['EFM_TRIM_AUTO_INHIBIT']),1)
            self.assertEqual(float(rows[0]['EXPORT_IAS_MPS']),150)
            self.assertTrue(all(None not in r for r in rows))
            # Restart must create a new session even inside the same wall second.
            g.cb.onSimulationStart();frame(0);frame(3601);g.cb.onSimulationStop()
            self.assertEqual(len(list(root.rglob('*.csv'))),2)

if __name__=='__main__':unittest.main()
