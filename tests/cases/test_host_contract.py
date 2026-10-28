"""R-INT-002: explicit absence, native storage, epochs and bounded work."""
import unittest
from host import Host


class HostContract(unittest.TestCase):
    def test_absence_is_distinct_from_valid_zero(self):
        h = Host()
        self.assertIsNone(h.get('MISSING'))
        h.seed({'ZERO': 0})
        self.assertEqual(h.get('ZERO'), 0)
        with self.assertRaisesRegex(Exception, 'Unconfigured host export'):
            h.execute('return get_base_data().getMachNumber()')

    def test_coercion_and_write_only_native_elements(self):
        h = Host()
        h.execute("get_param_handle('A'):set('70.0')")
        self.assertEqual(h.get('A'), 70)
        h.execute("e=CreateElement('ceStringPoly');e.name='sample';Add(e)")
        with self.assertRaisesRegex(Exception, 'write-only'):
            h.execute('return e.name')

    def test_restart_retires_samples_and_pending_requests(self):
        h = Host()
        h.seed({'VALID': 1, 'REQUEST': 23})
        h.state.action(h.state, 20, 1)
        h.state.advance(h.state, 4)
        h.state.restart(h.state)
        self.assertEqual(h.state.epoch, 2)
        self.assertEqual(h.state.time, 0)
        self.assertIsNone(h.get('REQUEST'))
        self.assertEqual(len(h.state.actions), 0)

    def test_capacity_and_callback_reentrancy_are_bounded(self):
        h = Host()
        for _ in range(64):
            h.state.action(h.state, 1, 1)
        with self.assertRaisesRegex(Exception, 'capacity'):
            h.state.action(h.state, 1, 1)
        with self.assertRaisesRegex(Exception, 'capacity'):
            h.execute('function SetCommand(c,v) GetSelf():performClickableAction(c,v) end; GetSelf():performClickableAction(1,1)')

    def test_finite_type_clock_generation_and_torn_physical_sample(self):
        h = Host()
        h.execute("snapshot=dofile(LockOn_Options.script_path..'Systems/Physical_Snapshot.lua').new(function(k) return get_param_handle(k):get() end, {'MAIN_POWER'})")
        good = {'EFM_POWER_OWNER': 1, 'EFM_PHYSICAL_VALID': 1,
                'EFM_PHYSICAL_GENERATION': 3, 'EFM_PHYSICAL_STAMP': 8,
                'EFM_PHYSICAL_CLOCK_KIND': 1, 'F22_AP_CLOCK': 8, 'MAIN_POWER': 1}
        h.seed(good)
        self.assertTrue(h.execute('return snapshot:update().valid'))
        for field, bad in [('EFM_PHYSICAL_GENERATION', 0), ('EFM_PHYSICAL_GENERATION', 1.5),
                           ('EFM_PHYSICAL_CLOCK_KIND', 2), ('EFM_PHYSICAL_VALID', '1'),
                           ('EFM_PHYSICAL_STAMP', float('nan')), ('F22_AP_CLOCK', float('inf')),
                           ('F22_AP_CLOCK', 8.250001), ('EFM_PHYSICAL_STAMP', 8.050001)]:
            h.seed(good)
            h.seed({field: bad})
            self.assertFalse(h.execute('return snapshot:update().valid'), (field, bad))
        h.seed(good)
        self.assertTrue(h.execute('return snapshot:update().valid'))
        h.execute("local get=snapshot.get; snapshot.get=function(k) if k=='MAIN_POWER' then get_param_handle('EFM_PHYSICAL_GENERATION'):set(4) end; return get(k) end")
        self.assertFalse(h.execute('return snapshot:update().valid'))


if __name__ == '__main__':
    unittest.main()
