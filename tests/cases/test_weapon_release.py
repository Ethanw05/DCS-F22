"""R-WPN-001: requests, independent native outcomes, loss and fresh consent."""
import unittest
from host import Host
from weapon_ports import WeaponHost


class ReleaseTransactions(unittest.TestCase):
    def test_only_matching_native_outcome_completes(self):
        h = WeaponHost()
        h.request()
        self.assertEqual(h.get('F22_SMS_RELEASE_PENDING'), 1)
        h.execute('payload[2].count=1')
        h.tick(solve=True)
        self.assertEqual(h.get('F22_AG_RELEASE_SEQUENCE'), 0)
        h.shot(station=3)
        h.tick(solve=True)
        self.assertEqual(h.get('F22_AG_RELEASE_SEQUENCE'), 0)
        h.shot(kind=901)
        h.tick(solve=True)
        self.assertEqual(h.get('F22_AG_RELEASE_SEQUENCE'), 0)
        h.shot()
        h.tick(solve=True)
        self.assertEqual(h.get('F22_AG_RELEASE_SEQUENCE'), 1)
        self.assertEqual(h.get('F22_SMS_RELEASE_PENDING'), 0)

    def test_device_loss_retires_pending_and_recovery_does_not_replay(self):
        for failure in ['missing', 'throw']:
            with self.subTest(failure=failure):
                h = WeaponHost()
                h.request()
                h.env.device_state = failure
                h.tick(solve=True)
                self.assertEqual(h.get('F22_SMS_RELEASE_PENDING'), 0)
                self.assertEqual(h.get('F22_SMS_RELEASE_FAILED'), 1)
                self.assertEqual(h.get('F22_WEAPON_SELECTED_VALID'), 0)
                self.assertEqual(h.get('F22_AG_RELEASE_CONSENT'), 0)
                h.env.device_state = 'ready'
                for _ in range(4):
                    h.tick(solve=True)
                h.command(10803, 1)
                h.tick(solve=True)
                self.assertEqual(h.env.launches, 1)
                # Count reconciliation does not itself grant new consent.
                h.execute('payload[2].count=1')
                for _ in range(15):
                    h.tick(solve=True)
                self.assertEqual(h.env.launches, 1)
                h.command(10803, 0)
                h.command(10803, 1)
                for _ in range(30):
                    h.tick(solve=True)
                    if h.env.launches == 2:
                        break
                self.assertEqual(h.env.launches, 2)

    def test_station_and_selection_exceptions_are_unavailable(self):
        for port, failure in [('station_state', 'throw'),
                              ('selection_state', 'throw'), ('selection_state', 'reject')]:
            with self.subTest(port=port, failure=failure):
                h = WeaponHost()
                h.env[port] = failure
                h.command(10800, 3)
                h.tick()
                self.assertEqual(h.get('F22_WEAPON_BACKEND_READY'), 0)
                self.assertEqual(h.get('F22_WEAPON_SELECTED_VALID'), 0)
                self.assertEqual(h.env.launches, 0)

    def test_throwing_launch_is_uncertain_and_never_retried(self):
        for failure in ['throw', 'reject']:
            h = WeaponHost()
            h.env.launch_state = failure
            h.request()
            self.assertEqual(h.get('F22_SMS_RELEASE_PENDING'), 0)
            self.assertEqual(h.get('F22_SMS_RELEASE_FAILED'), 1)
            for _ in range(15):
                h.tick(solve=True)
            self.assertEqual(h.env.launches, 1)

    def test_malformed_station_does_not_hide_independent_valid_station(self):
        h = WeaponHost()
        h.execute('payload[1]={count=1,weapon=7}')
        for _ in range(15):
            h.tick()
        self.assertEqual(h.get('F22_WEAPON_SELECTED_VALID'), 1)
        self.assertEqual(h.get('F22_WEAPON_STATION'), 2)
        self.assertEqual(h.get('F22_SMS_STATION_01_INVENTORY_VALID'), 0)
        self.assertEqual(h.get('F22_SMS_STATION_02_INVENTORY_VALID'), 1)

    def test_late_native_outcome_updates_history_without_restoring_consent(self):
        h = WeaponHost()
        h.request()
        released_at = h.state.time
        h.env.device_state = 'missing'
        h.tick()
        h.env.device_state = 'ready'
        h.tick(seconds=1)
        h.shot()
        h.seed({'F22_SHOT_01_TIME': released_at})
        for _ in range(15):
            h.tick()
        self.assertEqual(h.get('F22_SMS_STATUS_TEXT'), 'LATE RELEASE CONFIRMED')
        self.assertEqual(h.get('F22_AG_RELEASE_SEQUENCE'), 0)
        self.assertEqual(h.get('F22_AG_RELEASE_CONSENT'), 0)
        self.assertEqual(h.get('F22_SMS_RELEASE_PENDING'), 0)
        self.assertEqual(h.env.launches, 1)

    def test_rearm_and_safe_cancel_before_native_outcomes(self):
        for cancel in ['safe', 'rearm', 'power', 'generation']:
            with self.subTest(cancel=cancel):
                h = WeaponHost()
                h.request()
                if cancel == 'safe':
                    h.command(10007, 1)
                elif cancel == 'rearm':
                    h.env.CockpitEvent('WeaponRearmFirstStep', None)
                elif cancel == 'power':
                    h.seed({'EFM_MISSION_POWER_AVAILABLE': 0})
                else:
                    h.seed({'EFM_PHYSICAL_GENERATION': 4})
                h.tick()
                h.shot()
                h.tick()
                self.assertEqual(h.get('F22_SMS_RELEASE_PENDING'), 0)
                self.assertEqual(h.get('F22_AG_RELEASE_CONSENT'), 0)
                self.assertEqual(h.get('F22_AG_RELEASE_SEQUENCE'), 0)
                self.assertEqual(h.env.launches, 1)

    def test_station_boundary_contract_and_ir_consumer(self):
        h = Host()
        h.execute("caps=dofile(LockOn_Options.script_path..'Systems/Store_Capabilities.lua');ir=dofile(LockOn_Options.script_path..'Systems/IR_Seeker.lua')")
        for malformed in ['{count=1,weapon=7}', '{count=1,weapon=false}',
                          '{count=1,weapon="bad"}', '{count=1,CLSID={}}',
                          '{count=1,weapon={level4=0/0}}', '{count=129}',
                          '{count=1.5}', '{count=math.huge}']:
            h.execute('bad=' + malformed)
            self.assertIsNone(h.execute('return caps.describe(bad)'))
            self.assertEqual(h.execute('return ir.profile(bad)'), 0)
        self.assertIsNotNone(h.execute('return caps.station({count=0})'))
        self.assertIsNotNone(h.execute('return caps.station({count=128,weapon={level4=0}})'))


if __name__ == '__main__':
    unittest.main()
