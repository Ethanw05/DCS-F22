"""R-FLT-001: actual HUD owner preserves independent motion on atmosphere loss."""
import math
import unittest
from host import Host


def flight_host():
    host = Host()
    for name, sample in {
        'getAngleOfSlide': 0, 'getVerticalAcceleration': 1,
        'getAngleOfAttack': 0, 'getVerticalVelocity': 0,
    }.items():
        host.sensor(name, sample)
    # Explicit provider inputs, including physical/GINS provenance. These are
    # independently declared source samples, never expected HUD output values.
    host.seed({
        'EFM_POWER_OWNER': 1, 'EFM_PHYSICAL_VALID': 1,
        'EFM_PHYSICAL_GENERATION': 7, 'EFM_PHYSICAL_CLOCK_KIND': 1,
        'EFM_PHYSICAL_STAMP': 3, 'F22_AP_CLOCK': 3, 'MAIN_POWER': 1,
        'EFM_HUD_VALID': 1, 'EFM_HUD_KINEMATICS_VALID': 1,
        'EFM_HUD_VN': 200, 'EFM_HUD_VE': 0, 'EFM_HUD_VU': 0,
        'EFM_HUD_WN': 5, 'EFM_HUD_WE': 0,
        'EFM_GROUND_VALID': 1, 'EFM_WEIGHT_ON_WHEELS': 0,
        'EFM_GEAR_DOWN_LOCKED': 0, 'EFM_GEAR_UP_LOCKED': 1,
        'EFM_GEAR_UNSAFE': 0, 'EFM_NWS_SELECTED': 0,
        'EFM_AIRDATA_VALID': 1, 'EFM_AIRDATA_STAMP': 3,
        'EFM_AIRDATA_CAS_MPS': 140, 'EFM_AIRDATA_TAS_MPS': 200,
        'EFM_AIRDATA_HEALTH': 0,
        'F22_GINS_VALID': 1, 'F22_GINS_SCHEMA': 1,
        'F22_GINS_SEQUENCE': 4, 'F22_GINS_STAMP': 3,
        'F22_GINS_HUD_SOURCE': 1, 'F22_GINS_HUD_POWER': 1,
        'F22_GINS_HUD_ATTITUDE_VALID': 1, 'F22_GINS_HUD_HEADING_VALID': 1,
        'F22_GINS_HUD_POSITION_READY': 1,
        'F22_GINS_HUD_PITCH': 0, 'F22_GINS_HUD_ROLL': 0,
        'F22_GINS_HUD_HEADING': 0,
    })
    host.load('Systems/HUD_Flight_Data.lua')
    host.env.post_initialize()
    return host


class FlightFieldValidity(unittest.TestCase):
    def test_healthy_loss_recovery_keeps_independent_motion(self):
        host = flight_host()
        host.update()
        for name in ['HUD_GS_VALID', 'HUD_FPM_VALID', 'HUD_WIND_VALID',
                     'HUD_WIND_ARROW_VALID', 'HUD_AIRDATA_VALID']:
            self.assertEqual(host.get(name), 1, name)
        self.assertAlmostEqual(host.get('HUD_GS_MPS'), 200)
        host.seed({'EFM_HUD_VALID': 0, 'EFM_AIRDATA_VALID': 0,
                   'EFM_HUD_WN': 0, 'EFM_HUD_WE': 0})
        host.update()
        self.assertEqual(host.get('HUD_GS_VALID'), 1)
        self.assertEqual(host.get('HUD_FPM_VALID'), 1)
        self.assertAlmostEqual(host.get('HUD_GS_MPS'), 200)
        for name in ['HUD_WIND_VALID', 'HUD_WIND_ARROW_VALID', 'HUD_AIRDATA_VALID']:
            self.assertEqual(host.get(name), 0, name)
        host.seed({'EFM_HUD_VALID': 1, 'EFM_AIRDATA_VALID': 1,
                   'EFM_HUD_WN': 5, 'EFM_HUD_WE': 0})
        host.update()
        self.assertEqual(host.get('HUD_AIRDATA_VALID'), 1)
        self.assertEqual(host.get('HUD_WIND_ARROW_VALID'), 1)

    def test_motion_validity_and_finite_tuple_are_independent_guards(self):
        for fields in [
            {'EFM_HUD_KINEMATICS_VALID': 0},
            {'EFM_HUD_KINEMATICS_VALID': '1'},
            {'EFM_HUD_VN': math.nan},
            {'EFM_PHYSICAL_VALID': 0},
            {'EFM_PHYSICAL_STAMP': 2},
        ]:
            with self.subTest(fields=fields):
                host = flight_host()
                host.update()
                host.seed(fields)
                host.update()
                self.assertEqual(host.get('HUD_GS_VALID'), 0)
                self.assertEqual(host.get('HUD_FPM_VALID'), 0)
                self.assertEqual(host.get('HUD_WIND_ARROW_VALID'), 0)

    def test_adc_failure_keeps_motion_and_measured_wind(self):
        host = flight_host()
        host.seed({'EFM_AIRDATA_VALID': 0, 'EFM_AIRDATA_HEALTH': 1})
        host.update()
        self.assertEqual(host.get('HUD_AIRDATA_VALID'), 0)
        self.assertEqual(host.get('HUD_GS_VALID'), 1)
        self.assertEqual(host.get('HUD_FPM_VALID'), 1)
        self.assertEqual(host.get('HUD_WIND_VALID'), 1)
