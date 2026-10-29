"""Coherent target evidence through the current production Lua owners."""
import unittest
from host import Host, ROOT
from weapon_ports import WeaponHost


def actual_sources():
    names = ('AG_Mark_System', 'AG_Stores', 'Weapon_System', 'Navigation_System', 'AG_Ballistic_Computer')
    return {'Cockpit/Scripts/Systems/'+name+'.lua':
            (ROOT/'Cockpit/Scripts/Systems'/(name+'.lua')).read_text(encoding='utf-8-sig')
            for name in names}


def radar_packet(h, now=10, sample=10, kind=1, logical=1, valid=1, epoch=7,
                 commit=4, live=None):
    if live is None:
        live = int(kind != 3)
    h.seed(dict(F22_AG_NATIVE_SOURCE_EPOCH=epoch,
        F22_AG_NATIVE_SCHEMA=1, F22_AG_NATIVE_SEQUENCE=commit,
        F22_AG_NATIVE_CONTROL_SCHEMA=1, F22_AG_NATIVE_CONTROL_SEQUENCE=commit,
        F22_AG_NATIVE_CONTROL_EPOCH=epoch, F22_AG_NATIVE_CONTROL_TIME=now,
        F22_AG_DESIGNATION_SCHEMA=1, F22_AG_DESIGNATION_SEQUENCE=logical,
        F22_AG_DESIGNATION_VALID=valid, F22_AG_DESIGNATION_TIME=sample,
        F22_AG_DESIGNATION_EPOCH=epoch, F22_AG_DESIGNATION_REQUEST=4,
        F22_AG_DESIGNATION_TYPE=kind, F22_AG_DESIGNATION_LIVE=live,
        F22_AG_DESIGNATION_NORTH=2000, F22_AG_DESIGNATION_ALTITUDE=100,
        F22_AG_DESIGNATION_EAST=300))


def mark_host(observer=None):
    h = Host()
    h.state.time = 10
    h.sensor('getSelfCoordinates', (0, 1000, 0))
    for name in ('getHeading', 'getPitch', 'getRoll'):
        h.sensor(name, 0)
    h.execute("package.loaded.terrain={GetHeight=function() return 100 end}")
    h.seed(dict(MAIN_POWER=1, HUD_MODE=7))
    radar_packet(h, logical=0, valid=0, commit=2)
    if observer is not None:
        h.env.observe_write = lambda key, value: observer(h, key, value)
        h.execute("local acquire=get_param_handle; function get_param_handle(key) "
                  "local value=acquire(key); return {get=function() return value:get() end,"
                  "set=function(_,v) value:set(v); observe_write(key,v) end} end")
    h.load('Systems/AG_Mark_System.lua')
    h.env.post_initialize()
    return h


def read_target(h, now=None, delivery=False, getter=None):
    module = h.load('Systems/AG_Target_Snapshot.lua')
    fn = module.read_delivery if delivery else module.read
    return fn(getter or h.get, h.state.time if now is None else now)


def guided_handoff(kind=3):
    h = WeaponHost()
    h.execute("payload[2]={count=1,CLSID='{GBU_32_V_2B}',"
              "weapon={level1=4,level2=5,level3=36,level4=901}}")
    for _ in range(20):
        h.tick()  # Let the actual bounded inventory poll observe the replacement.
    h.command(10809, 1)  # Select AUTO through the real saved control route.
    h.tick()
    weapon_update, weapon_command = h.env.update, h.env.SetCommand
    h.sensor('getSelfCoordinates', (0, 1000, 0))
    for name in ('getHeading', 'getPitch', 'getRoll'):
        h.sensor(name, 0)
    h.execute("package.loaded.terrain={GetHeight=function() return 100 end}")
    radar_packet(h, now=h.state.time, logical=0, valid=0, commit=2)
    h.load('Systems/AG_Mark_System.lua')
    h.env.post_initialize()
    marker = h.env.update
    radar_packet(h, now=h.state.time, sample=h.state.time-.2, kind=kind)
    marker()
    h.env.update, h.env.SetCommand = weapon_update, weapon_command
    h.command(10987, 1)
    return h, marker


class RadarTargetHandoff(unittest.TestCase):
    def test_current_target_owners_are_lua51_syntax_valid(self):
        h = Host()
        compile_lua = h.lua.eval('function(text) return loadstring(text) ~= nil end')
        for path, source in actual_sources().items():
            self.assertTrue(compile_lua(source), path)
        self.assertTrue(compile_lua((ROOT/'Cockpit/Scripts/Systems/AG_Target_Snapshot.lua').read_text()))

    def test_original_measurement_time_survives_mark_copy_and_refresh(self):
        h = mark_host()
        radar_packet(h, now=10.49, sample=10)
        h.state.time = 10.49
        h.update()
        point = read_target(h)
        self.assertIsNotNone(point)
        self.assertEqual((point.n, point.u, point.e), (2000, 100, 300))
        self.assertEqual((point.time, point.epoch, point.request, point.kind), (10, 7, 4, 1))
        self.assertTrue(point.observation_known)
        self.assertEqual(point.packet_time, 10.49)
        radar_packet(h, now=10.8, sample=10)
        h.state.time = 10.8
        h.update()
        self.assertEqual(read_target(h).time, 10)
        self.assertEqual(read_target(h).packet_time, 10.8)

    def test_torn_request_is_not_consumed_and_same_logical_commit_recovers(self):
        h = mark_host()
        radar_packet(h, valid=0, commit=3)
        h.update()
        self.assertIsNone(read_target(h))
        radar_packet(h, valid=1, commit=4)
        h.update()
        self.assertIsNotNone(read_target(h))
        self.assertEqual(read_target(h).observation_sequence, 1)

    def test_live_object_stale_association_and_epoch_loss_withdraw(self):
        for failure in ('age', 'association', 'epoch'):
            with self.subTest(failure=failure):
                h = mark_host()
                radar_packet(h)
                h.update()
                self.assertIsNotNone(read_target(h))
                if failure == 'age':
                    h.state.time = 15.2501
                    radar_packet(h, now=15.2501, sample=10)
                elif failure == 'association':
                    radar_packet(h, live=0)
                else:
                    h.seed({'F22_AG_NATIVE_SOURCE_EPOCH': 8})
                h.update()
                self.assertIsNone(read_target(h))
                self.assertEqual(h.get('HUD_AG_TARGET_VALID'), 0)

    def test_fixed_coordinate_retains_original_time_until_cancel_or_reset(self):
        h = mark_host()
        radar_packet(h, kind=3)
        h.update()
        h.state.time = 40
        radar_packet(h, now=40, sample=10, kind=3)
        h.update()
        point = read_target(h)
        self.assertIsNotNone(point)
        self.assertEqual((point.kind, point.time, point.live), (3, 10, False))
        radar_packet(h, now=40, kind=3, logical=2, valid=0)
        h.update()
        self.assertIsNone(read_target(h))
        radar_packet(h, now=40, sample=40, kind=3, logical=3)
        h.update()
        self.assertIsNotNone(read_target(h))
        h.seed({'F22_AG_NATIVE_SOURCE_EPOCH': 8})
        h.update()
        self.assertIsNone(read_target(h))

    def test_snapshot_rejects_each_torn_protected_field(self):
        fields = ['F22_AG_TARGET_PACKET_TIME', 'F22_AG_TARGET_PACKET_EPOCH',
                  'HUD_AG_MARK_NORTH', 'HUD_AG_MARK_ALT', 'HUD_AG_MARK_EAST',
                  'F22_AG_TARGET_SOURCE', 'F22_AG_TARGET_SEQUENCE',
                  'F22_AG_TARGET_OBSERVATION_KNOWN', 'F22_AG_TARGET_OBSERVATION_TIME',
                  'F22_AG_TARGET_OBSERVATION_SEQUENCE', 'F22_AG_TARGET_SOURCE_EPOCH',
                  'F22_AG_TARGET_SOURCE_REQUEST', 'F22_AG_TARGET_SOURCE_TYPE',
                  'F22_AG_TARGET_SOURCE_LIVE', 'F22_NAV_TARGET_ACK_SEQUENCE',
                  'F22_NAV_TARGET_ACK_TARGET_SEQUENCE', 'F22_NAV_TARGET_RESULT']
        for field in fields:
            h = mark_host()
            radar_packet(h)
            h.update()
            mutated = False
            def get(name):
                nonlocal mutated
                value = h.get(name)
                if name == field and not mutated:
                    mutated = True
                    h.seed({'F22_AG_TARGET_PACKET_SEQUENCE': h.get('F22_AG_TARGET_PACKET_SEQUENCE')+2})
                return value
            self.assertIsNone(read_target(h, getter=get), field)
            self.assertTrue(mutated, field)

    def test_snapshot_types_geometry_clock_and_fixed_kind_cannot_mask_live(self):
        bad_values = [('HUD_AG_MARK_NORTH', float('nan')),
                      ('HUD_AG_MARK_ALT', float('inf')), ('HUD_AG_MARK_EAST', None),
                      ('F22_AG_TARGET_PACKET_SCHEMA', 0),
                      ('F22_AG_TARGET_PACKET_SEQUENCE', 3),
                      ('F22_AG_TARGET_PACKET_TIME', 9.4999),
                      ('F22_AG_TARGET_PACKET_TIME', 10.001),
                      ('F22_AG_TARGET_OBSERVATION_TIME', '10'),
                      ('F22_AG_TARGET_OBSERVATION_KNOWN', 0),
                      ('F22_AG_TARGET_SOURCE_EPOCH', 0),
                      ('F22_AG_TARGET_SOURCE_REQUEST', .5),
                      ('F22_AG_TARGET_SOURCE_TYPE', 3)]
        for key, value in bad_values:
            h = mark_host()
            radar_packet(h)
            h.update()
            h.seed({key: value})
            self.assertIsNone(read_target(h), (key, value))

    def test_actual_writer_exposes_only_completed_or_unavailable_tuple(self):
        observations = []
        watching = False
        def observe(h, key, value):
            if watching:
                point = read_target(h)
                observations.append((key, value, None if point is None else
                                     (point.n, point.e, point.time, point.observation_sequence)))
        h = mark_host(observe)
        radar_packet(h)
        h.update()
        radar_packet(h, logical=2)
        h.seed({'F22_AG_DESIGNATION_NORTH': 3100})
        watching = True
        h.update()
        self.assertGreater(len(observations), 20)
        for key, value, point in observations:
            if key == 'F22_AG_TARGET_PACKET_SEQUENCE' and value % 2 == 0:
                self.assertEqual(point, (3100, 300, 10, 2))
            else:
                self.assertIsNone(point, key)

    def test_zero_time_and_exact_packet_lease_boundaries(self):
        h = mark_host()
        h.state.time = 0
        radar_packet(h, now=0, sample=0, kind=3)
        h.update()
        point = read_target(h)
        self.assertIsNotNone(point)
        self.assertTrue(point.observation_known)
        self.assertEqual(point.time, 0)
        self.assertIsNotNone(read_target(h, now=.5))
        self.assertIsNone(read_target(h, now=.500001))

    def test_failed_parameter_adapter_withdraws_and_recovers_without_throw(self):
        h = mark_host()
        radar_packet(h)
        h.update()
        module = h.load('Systems/AG_Target_Snapshot.lua')
        def failed(name):
            if name == 'HUD_AG_MARK_NORTH':
                raise RuntimeError('parameter context unavailable')
            return h.get(name)
        self.assertIsNone(module.read(failed, 10))
        self.assertTrue(module.read_failure)
        self.assertIsNotNone(module.read(h.get, 10))
        self.assertFalse(module.read_failure)

    def test_nav_ack_and_hud_los_remain_unmeasured_coordinates(self):
        h = mark_host()
        h.seed(dict(F22_NAV_TARGET_REQUEST_SEQUENCE=9, F22_NAV_TARGET_REQUEST_VALID=1,
                    F22_NAV_TARGET_REQUEST_N=4000, F22_NAV_TARGET_REQUEST_E=200))
        h.env.SetCommand(10843, 1)
        h.update()
        point = read_target(h)
        self.assertIsNotNone(point)
        self.assertEqual((point.source, point.n, point.e, point.u), (3, 4000, 200, 100))
        self.assertEqual(h.get('F22_NAV_TARGET_ACK_SEQUENCE'), 9)
        self.assertEqual(h.get('F22_NAV_TARGET_ACK_TARGET_SEQUENCE'), point.sequence)
        self.assertEqual((point.nav_request, point.nav_target_sequence, point.nav_result),
                         (9, point.sequence, 1))
        self.assertFalse(point.observation_known)
        self.assertEqual(point.time, -100)
        h.env.SetCommand(10843, 0)
        h.sensor('getPitch', -.2)
        h.env.SetCommand(10810, 1)
        h.update()
        point = read_target(h)
        self.assertIsNotNone(point)
        self.assertEqual(point.source, 1)
        self.assertFalse(point.observation_known)

    def test_completed_nav_failure_ack_remains_available_without_target_authority(self):
        h = mark_host()
        h.execute('package.loaded.terrain.GetHeight=function() return nil end')
        h.seed(dict(F22_NAV_TARGET_REQUEST_SEQUENCE=9, F22_NAV_TARGET_REQUEST_VALID=1,
                    F22_NAV_TARGET_REQUEST_N=4000, F22_NAV_TARGET_REQUEST_E=200))
        h.env.SetCommand(10843, 1)
        h.update()
        self.assertIsNone(read_target(h))
        module = h.load('Systems/AG_Target_Snapshot.lua')
        packet = module.read_packet(h.get, 10)
        self.assertIsNotNone(packet)
        self.assertFalse(packet.valid)
        self.assertEqual((packet.nav_request, packet.nav_target_sequence, packet.nav_result), (9, 0, 3))
        h.seed({'F22_AG_TARGET_PACKET_SEQUENCE': h.get('F22_AG_TARGET_PACKET_SEQUENCE')+1})
        self.assertIsNone(module.read_packet(h.get, 10))

    def test_actual_navigation_target_capture_rejects_uncommitted_mark(self):
        h = mark_host()
        radar_packet(h, kind=3)
        h.update()
        h.seed({'F22_AP_CLOCK': 2})  # NAV marks use their separate declared clock.
        h.load('Systems/Navigation_System.lua')
        h.env.SetCommand(11818, 1)
        self.assertEqual(h.get('F22_NAV_MARK_COUNT'), 1)
        h.seed({'F22_AG_TARGET_PACKET_SEQUENCE': h.get('F22_AG_TARGET_PACKET_SEQUENCE')+1})
        h.env.SetCommand(11818, 1)
        self.assertEqual(h.get('F22_NAV_MARK_COUNT'), 1)

    def test_store_and_program_copy_every_original_evidence_field(self):
        h = mark_host()
        radar_packet(h)
        h.update()
        point = read_target(h)
        stores = h.load('Systems/AG_Stores.lua').new()
        h.env.stores = stores
        h.execute("stores:refresh({[2]={count=1,CLSID='{GBU_32_V_2B}',"
                  "weapon={level1=4,level2=5,level3=36,level4=901}}})")
        self.assertTrue(stores.capture_target(stores, 2, point))
        stored = stores.target(stores, 2)
        for field in ('source', 'time', 'epoch', 'request', 'kind', 'live',
                      'observation_known', 'observation_sequence', 'packet_time', 'packet_epoch'):
            self.assertEqual(stored[field], point[field], field)
        self.assertTrue(stores.start(stores, 10, point.sequence, point))
        copied = stores.program.live_target
        self.assertEqual(copied.time, 10)
        point.time = 99
        self.assertEqual(copied.time, 10)  # Immutable consent, no alias/receipt renewal.

    def test_actual_weapon_capture_preserves_original_time_and_reset_withdraws(self):
        h, marker = guided_handoff()
        point = read_target(h, delivery=True)
        self.assertIsNotNone(point)
        self.assertEqual((point.source, point.delivery_source, point.epoch, point.kind), (2, 2, 7, 3))
        original_time = point.time
        self.assertAlmostEqual(point.packet_time-original_time, .2)
        h.tick(seconds=.1)
        self.assertEqual(read_target(h, delivery=True).time, original_time)
        h.seed({'F22_AG_NATIVE_SOURCE_EPOCH': 8})
        marker()
        h.tick()
        self.assertIsNone(read_target(h, delivery=True))
        self.assertEqual(h.get('F22_SMS_TARGET_VALID'), 0)
        self.assertEqual(h.env.launches, 0)

    def test_actual_weapon_program_cancels_when_live_association_withdraws(self):
        h, marker = guided_handoff(kind=1)
        self.assertIsNotNone(read_target(h, delivery=True))
        h.command(10803, 1)
        h.tick()
        self.assertEqual(h.env.launches, 0)
        radar_packet(h, now=h.state.time, sample=h.state.time-.2, live=0)
        marker()
        h.tick()
        self.assertIsNone(read_target(h, delivery=True))
        self.assertEqual(h.get('F22_AG_RELEASE_CONSENT'), 0)
        self.assertEqual(h.get('F22_SMS_RELEASE_PENDING'), 0)
        self.assertEqual(h.env.launches, 0)

    def test_actual_prediction_owner_requires_coherent_delivery_point(self):
        h, _ = guided_handoff()
        h.seed(dict(HUD_AG_SUBMODE=3, EFM_HUD_VALID=1, F22_AG_BOMB_SELECTED=1,
                    F22_AG_BOMB_ASYNC_SUPPORTED=2, F22_AG_WEAPON_TYPE3=36,
                    F22_AG_WEAPON_TYPE4=901, EFM_HUD_VN=100,
                    EFM_HUD_VU=0, EFM_HUD_VE=0, F22_AG_GUIDED_SELECTED=1))
        h.load('Systems/AG_Ballistic_Computer.lua')
        h.env.post_initialize()
        h.update()
        self.assertEqual(h.get('F22_AG_BOMB_REQUEST_VALID'), 1)
        before = h.get('F22_AG_DELIVERY_TARGET_PACKET_SEQUENCE')
        h.seed({'F22_AG_DELIVERY_TARGET_PACKET_SEQUENCE': before+1,
                'HUD_AG_TARGET_VALID': 1})  # Raw HUD validity cannot bypass a torn owner.
        h.update()
        self.assertEqual(h.get('F22_AG_BOMB_REQUEST_VALID'), 0)
        self.assertEqual(h.get('F22_AG_SOLUTION_VALID'), 0)


if __name__ == '__main__':
    unittest.main()
