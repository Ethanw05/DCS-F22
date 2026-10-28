"""I-WPN-007: explicit no-go is a provider decision, never IFF capability."""
import unittest
from host import Host


class IFFProvider(unittest.TestCase):
    def setUp(self):
        self.host = Host()
        self.provider = self.host.load('Systems/IFF_Provider.lua').new()

    def assert_unavailable(self, value):
        self.assertEqual(value.schema, 1)
        self.assertTrue(value.provider_ready)
        self.assertFalse(value.available)
        self.assertEqual(value.status, 'HOST_UNQUALIFIED')
        self.assertEqual(value.identity, -1)
        self.assertFalse(value.identity_known)
        self.assertIsNone(value.identity_time)
        self.assertIsNone(value.received_time)
        self.assertEqual(value.clock_kind, 0)
        self.assertEqual(value.source_epoch, 0)
        self.assertEqual(value.source_id, 0)
        self.assertEqual(value.request_id, 0)

    def test_initial_decision_has_no_reply_or_fabricated_source_clock(self):
        self.assert_unavailable(self.provider.sample(self.provider))
        self.assertEqual(len(list(self.host.state.actions.items())), 0)

    def test_requests_reject_without_accepting_scene_or_script_identity(self):
        for mode in ['interrogate', 'interrogate_los', 'automatic', None]:
            for identity in [-1, 0, 1, 3]:
                request = self.host.lua.table_from(dict(mode=mode,
                    source=42, identity=identity, friendly=True, coalition=2,
                    time=100, epoch=9, powered=True))
                accepted, reason = self.provider.request(self.provider, request)
                self.assertFalse(accepted)
                self.assertEqual(reason, 'HOST_UNQUALIFIED')
                self.assert_unavailable(self.provider.sample(self.provider))
        self.assertEqual(len(list(self.host.state.actions.items())), 0)

    def test_power_clock_generation_reset_cannot_replay_a_reply(self):
        for clock in [10, 0, -1, float('nan'), float('inf')]:
            self.host.state.time = clock
            self.host.seed(dict(F22_IFF_REPLY_SEQUENCE=100,
                F22_IFF_RESPONDER_READY=1, F22_RADAR_STT_IFF=1,
                F22_PHYSICAL_GENERATION=12, MAIN_POWER=1))
            self.assert_unavailable(self.provider.reset(self.provider))
            self.assert_unavailable(self.provider.sample(self.provider))
        other = self.host.load('Systems/IFF_Provider.lua').new()
        self.assert_unavailable(other.sample(other))

    def test_stale_borrowed_output_does_not_authenticate_future_samples(self):
        value = self.provider.sample(self.provider)
        value.available = True
        value.identity = 1
        value.identity_known = True
        value.identity_time = 123
        value.source_epoch = 17
        self.assert_unavailable(self.provider.sample(self.provider))
        self.assertFalse(self.provider.request(self.provider)[0])


if __name__ == '__main__':
    unittest.main()
