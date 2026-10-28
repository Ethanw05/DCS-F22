"""R-WPN-003: unavailable event source, real clock and observed CM effects."""
import unittest
from host import Host


class CMHost(Host):
    def __init__(self):
        super().__init__()
        self.seed({'EFM_POWER_OWNER': 1, 'EFM_PHYSICAL_VALID': 1,
                   'EFM_PHYSICAL_GENERATION': 2, 'EFM_PHYSICAL_STAMP': 10,
                   'EFM_PHYSICAL_CLOCK_KIND': 1, 'F22_AP_CLOCK': 10,
                   'MAIN_POWER': 1, 'F22_ELECTRICAL_VALID': 1,
                   'EFM_MISSION_POWER_AVAILABLE': 1})
        self.state.time = 10
        self.execute("""
            LockOn_Options.init_conditions.birth_place='AIR_HOT'
            chaff,flare,calls=8,8,0
            effects=true; backend=true
            weapon={}
            function weapon:get_chaff_count() return chaff end
            function weapon:get_flare_count() return flare end
            function weapon:drop_chaff(count)
                calls=calls+1
                if effects then chaff=chaff-count end
            end
            function weapon:drop_flare(count)
                calls=calls+1
                if effects then flare=flare-count end
            end
            function GetDevice(_) if backend then return weapon end end
        """)
        self.load('Systems/EW_System.lua')
        self.env.post_initialize()
        self.tick()

    def press(self, command):
        self.env.SetCommand(command, 1)
        self.env.SetCommand(command, 0)

    def tick(self, seconds=.05):
        self.state.time += seconds
        self.seed({'EFM_PHYSICAL_STAMP': self.state.time,
                   'F22_AP_CLOCK': self.state.time})
        self.update()


class Countermeasures(unittest.TestCase):
    def test_semi_auto_remain_unavailable_without_qualified_event_provider(self):
        for mode in [2, 3]:
            h = CMHost()
            for _ in range(mode - 1):
                h.press(11107)
            h.press(11111)
            h.press(11110)
            h.tick()
            self.assertEqual(h.get('F22_CM_AUTO_AVAILABLE'), 0)
            self.assertEqual(h.get('F22_CM_EVENT_SOURCE_READY'), 0)
            self.assertEqual(h.get('F22_CM_AUTHORIZED'), 0)
            self.assertEqual(h.get('F22_CM_AWAITING_CONSENT'), 0)
            self.assertEqual(h.env.calls, 0)
            h.execute("controls=dofile(LockOn_Options.script_path..'Systems/Defensive_Controls.lua').for_page(0,function(k)return get_param_handle(k):get()end)")
            self.assertEqual(h.env.controls[3].label, 'CM UNAV')
            self.assertIsNone(h.env.controls[3].command)

    def test_missing_throwing_and_nonfinite_clocks_revoke_readiness(self):
        for clock in ['nil', "function()error('clock lost')end",
                      'function()return 0/0 end', 'function()return math.huge end',
                      'function()return -1 end']:
            h = CMHost()
            h.execute('get_model_time=' + clock)
            h.tick()
            self.assertEqual(h.get('F22_CM_CLOCK_VALID'), 0)
            self.assertEqual(h.get('F22_CM_READY'), 0)
            h.press(11100)
            h.press(11114)
            h.tick()
            self.assertEqual(h.env.calls, 0)

    def test_man_normal_and_direct_observe_counts_and_complete(self):
        for command in [11100, 11101]:
            h = CMHost()
            bank = h.get('F22_CM_NORMAL_BANK' if command == 11100 else 'F22_CM_DIRECT_BANK')
            prefix = f'F22_CM_PROGRAM_{int(bank)}_'
            nc, nf = h.get(prefix+'CHAFF'), h.get(prefix+'FLARE')
            cycles = h.get(prefix+'CYCLES')
            h.press(command)
            for _ in range(40):
                h.tick()
            self.assertEqual(h.env.chaff, 8 - nc * cycles)
            self.assertEqual(h.env.flare, 8 - nf * cycles)
            self.assertEqual(h.get('F22_CM_COMPLETED_SEQUENCE'), 1)
            self.assertEqual(h.get('F22_CM_OBSERVED_CHAFF'), nc * cycles)
            self.assertEqual(h.get('F22_CM_OBSERVED_FLARE'), nf * cycles)

    def test_dispatch_alone_cannot_complete_and_loss_does_not_replay(self):
        h = CMHost()
        h.env.effects = False
        h.press(11100)
        for _ in range(20):
            h.tick()
        self.assertEqual(h.get('F22_CM_COMPLETED_SEQUENCE'), 0)
        self.assertEqual(h.get('F22_CM_UNCONFIRMED'), 1)
        before = h.env.calls
        h.env.backend = False
        h.tick()
        h.env.backend = True
        for _ in range(10):
            h.tick()
        self.assertEqual(h.env.calls, before)

    def test_rollback_and_clock_recovery_require_fresh_request(self):
        h = CMHost()
        h.press(11100)
        h.tick()
        h.tick(seconds=-1)
        before = h.env.calls
        for _ in range(10):
            h.tick()
        self.assertEqual(h.env.calls, before)
        self.assertEqual(h.get('F22_CM_PROGRAM_RUNNING'), 0)
        h.press(11100)
        h.tick()
        self.assertGreater(h.env.calls, before)

    def test_draft_is_independent_of_saved_normal_and_direct_banks(self):
        h = Host()
        h.execute("library=dofile(LockOn_Options.script_path..'Systems/EW_Programs.lua');p=library.new();before=p:capture(p.normal);p:command(10910);p:command(10911);after=p:capture(p.normal)")
        self.assertEqual(h.env.before.chaff, h.env.after.chaff)
        self.assertEqual(h.env.p.normal, 1)
        self.assertEqual(h.env.p.direct, 2)
        for invalid in ['{chaff=0,flare=0,interval=.25,repetitions=1}',
                        '{chaff=5,flare=1,interval=.25,repetitions=1}',
                        '{chaff=1,flare=1,interval=0/0,repetitions=1}',
                        '{chaff=1,flare=1,interval=.25,repetitions=9}']:
            self.assertFalse(h.execute('return library.valid(' + invalid + ')'))


if __name__ == '__main__':
    unittest.main()
