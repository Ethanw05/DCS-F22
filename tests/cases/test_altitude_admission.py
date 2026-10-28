"""R-NAV-001 / VS-003: independent age, source and recovery expectations."""
import unittest
from host import Host


class AltitudeAdmission(unittest.TestCase):
    def setUp(self):
        self.h = Host()
        self.h.execute("altitude=dofile(LockOn_Options.script_path..'Systems/Altitude_Snapshot.lua').new(function(k) return get_param_handle(k):get() end)")
        self.good = {'F22_ALT_SNAPSHOT_SEQUENCE': 2, 'F22_ALT_SNAPSHOT_SCHEMA': 1,
                     'F22_ALT_SNAPSHOT_GENERATION': 3, 'F22_ALT_SNAPSHOT_CLOCK_KIND': 2,
                     'F22_ALT_SNAPSHOT_TIME': 10, 'F22_ALT_SNAPSHOT_SELECTION': 0}
        for name, value in [('BARO',3000),('RADAR',1500),('STANDBY',2800)]:
            self.good.update({f'F22_ALT_{name}_VALID': 1, f'F22_ALT_{name}_FT': value,
                              f'F22_ALT_{name}_STAMP': 10})
        self.h.seed(self.good)

    def read(self, now=10, generation=3):
        return self.h.execute(f'altitude:update({generation},true,{now}); return altitude:selected()')

    def test_normal_and_transport_lease_boundary(self):
        self.assertEqual(self.read(), (3000,'BARO',True))
        self.assertTrue(self.read(10.199999)[2])
        self.assertFalse(self.read(10.200001)[2])

    def test_stopped_producer_and_independent_fresh_restoration(self):
        self.assertTrue(self.read()[2])
        self.assertFalse(self.read(20)[2])
        self.h.seed({'F22_ALT_SNAPSHOT_TIME':20,'F22_ALT_SNAPSHOT_SEQUENCE':4})
        self.assertFalse(self.read(20)[2])  # Copying the old sample does not renew age.
        self.h.seed({'F22_ALT_BARO_STAMP':20})
        self.assertTrue(self.read(20)[2])

    def test_explicit_radar_fallback_and_standby_independence(self):
        self.h.seed({'F22_ALT_SNAPSHOT_SELECTION':1})
        self.assertEqual(self.read(),(1500,'RDR',True))
        self.h.seed({'F22_ALT_RADAR_VALID':0})
        self.assertEqual(self.read(),(3000,'BARO FB',True))
        self.h.seed({'F22_ALT_SNAPSHOT_SELECTION':2,'F22_ALT_STANDBY_VALID':0})
        self.assertEqual(self.read(),(None,'STBY',False))
        self.h.seed({'F22_ALT_STANDBY_VALID':1,'F22_ALT_BARO_VALID':0})
        self.assertEqual(self.read(),(2800,'STBY',True))

    def test_invalid_headers_and_field_types_withdraw_authority(self):
        for key,bad in [('F22_ALT_SNAPSHOT_SEQUENCE',3),('F22_ALT_SNAPSHOT_SCHEMA',2),
                        ('F22_ALT_SNAPSHOT_CLOCK_KIND',1),('F22_ALT_SNAPSHOT_GENERATION',4),
                        ('F22_ALT_SNAPSHOT_SELECTION',7),('F22_ALT_BARO_FT',float('nan')),
                        ('F22_ALT_BARO_FT','3000'),('F22_ALT_BARO_VALID','1'),
                        ('F22_ALT_BARO_STAMP',10.01001),('F22_ALT_SNAPSHOT_TIME',float('inf'))]:
            self.h.seed(self.good);self.h.seed({key:bad})
            self.assertFalse(self.read()[2],(key,bad))

    def test_torn_payload_is_rejected(self):
        self.h.execute("local get=altitude.get; altitude.get=function(k) if k=='F22_ALT_RADAR_FT' then get_param_handle('F22_ALT_SNAPSHOT_SEQUENCE'):set(4) end; return get(k) end")
        self.assertFalse(self.read()[2])

    def test_clock_rollback_requires_new_generation(self):
        self.assertTrue(self.read()[2])
        self.h.seed({'F22_ALT_SNAPSHOT_TIME':9,'F22_ALT_BARO_STAMP':9})
        self.assertFalse(self.read(9)[2])
        self.h.seed(self.good)
        self.assertFalse(self.read(10)[2])
        self.h.seed({'F22_ALT_SNAPSHOT_GENERATION':4})
        self.assertTrue(self.read(10,4)[2])
        self.h.seed({'F22_ALT_SNAPSHOT_GENERATION':3})
        self.assertFalse(self.read(10,3)[2])


if __name__ == '__main__':
    unittest.main()
