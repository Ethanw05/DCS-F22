"""Original static terrain time versus live provider lease; public terrain ports."""
import unittest
from host import Host


def provider():
    host = Host()
    host.execute("calls=0;kind='land';changed=0;fail_height=false;fail_type=false;"
                 "terrain={GetHeight=function(n,e) calls=calls+1;"
                 "if fail_height then error('height port unavailable')end;return n*.1+e*.01+changed end,"
                 "GetSurfaceType=function() calls=calls+1;"
                 "if fail_type then error('surface port unavailable')end;return kind end}")
    module = host.load('Systems/SAR_Terrain_Scene.lua')
    owner = module.new(host.env.terrain)
    request = host.lua.table_from(dict(schema=1, source_epoch=2, environment_epoch=9,
        navigation_epoch=3, clock_epoch=4, grid_epoch=5, columns=4, rows=4,
        north=1000, east=2000, column_n=2, column_e=0, row_n=0, row_e=3))
    return host, owner, request


class SarTerrainScene(unittest.TestCase):
    def test_bounded_actual_terrain_calls_and_independent_grid_geometry(self):
        host, owner, request = provider()
        self.assertTrue(owner.begin(owner, request, 10))
        self.assertFalse(owner.step(owner, 10, 8))
        self.assertEqual(host.env.calls, 16)
        self.assertTrue(owner.step(owner, 10.02, 8))
        frame = owner.frame(owner, 10.02)
        self.assertTrue(frame.geometry_available)
        self.assertTrue(frame.provider_available)
        self.assertEqual(frame.count, 16)
        point = frame.points[1]
        self.assertEqual((point.north, point.east), (1001, 2001.5))
        self.assertAlmostEqual(point.altitude, 120.115)
        self.assertEqual(point.area_m2, 6)
        self.assertEqual(point.proxy_power_density, 1)
        self.assertFalse(frame.scene_available)
        self.assertFalse(frame.objects_known)
        self.assertFalse(frame.visibility_known)

    def test_provider_probe_never_refreshes_original_geometry_clock(self):
        host, owner, request = provider()
        owner.begin(owner, request, 0)
        owner.step(owner, 0, 8)
        owner.step(owner, .02, 8)
        first = owner.frame(owner, .02)
        original = (first.geometry_first_time, first.geometry_last_time,
                    first.points[1].geometry_time)
        self.assertTrue(owner.probe(owner, 10, 2, 9))
        after = owner.frame(owner, 10)
        self.assertEqual((after.geometry_first_time, after.geometry_last_time,
                          after.points[1].geometry_time), original)
        self.assertEqual(after.provider_lease_time, 10)
        self.assertTrue(after.provider_available)
        stale = owner.frame(owner, 10.051)
        self.assertFalse(stale.provider_available)
        self.assertTrue(stale.geometry_available)
        self.assertEqual(stale.reason, 'provider_stale')

    def test_height_zero_is_real_geometry_and_unknown_surface_withdraws(self):
        host, owner, request = provider()
        host.execute('terrain.GetHeight=function()calls=calls+1;return 0 end')
        owner.begin(owner, request, 0)
        owner.step(owner, 0, 8)
        self.assertTrue(owner.step(owner, .02, 8))
        self.assertEqual(owner.frame(owner, .02).points[1].altitude, 0)
        host.env.kind = 'unsupported_material'
        self.assertFalse(owner.probe(owner, .03, 2, 9))
        self.assertFalse(owner.frame(owner, .03).provider_available)
        self.assertEqual(owner.reason, 'surface_unknown')

    def test_public_port_failures_and_geometry_mutation_are_explicit(self):
        for fault, reason in [('fail_height', 'height_unavailable'),
                              ('fail_type', 'surface_unavailable')]:
            host, owner, request = provider()
            owner.begin(owner, request, 10)
            host.env[fault] = True
            self.assertFalse(owner.step(owner, 10, 8))
            self.assertEqual(owner.reason, reason)
            self.assertFalse(owner.frame(owner, 10).geometry_available)
        host, owner, request = provider()
        owner.begin(owner, request, 10)
        owner.step(owner, 10, 8)
        owner.step(owner, 10.02, 8)
        host.env.changed = 1
        self.assertFalse(owner.probe(owner, 10.03, 2, 9))
        self.assertEqual(owner.reason, 'geometry_changed')
        self.assertFalse(owner.frame(owner, 10.03).provider_available)

    def test_epoch_change_and_rewind_retire_provider_lease(self):
        host, owner, request = provider()
        owner.begin(owner, request, 10)
        owner.step(owner, 10, 8)
        owner.step(owner, 10.02, 8)
        self.assertFalse(owner.probe(owner, 10.03, 2, 10))
        self.assertEqual(owner.reason, 'epoch_changed')
        self.assertFalse(owner.probe(owner, 9, 2, 9))
        self.assertEqual(owner.reason, 'clock_reset')
        self.assertFalse(owner.frame(owner, 10.03).provider_available)

    def test_request_is_copied_and_bad_rotated_corner_is_rejected(self):
        host, owner, request = provider()
        owner.begin(owner, request, 10)
        request.north = -999
        owner.step(owner, 10, 8)
        self.assertEqual(owner.points[1].north, 1001)
        request.north = 29999999
        request.column_n, request.row_n = 10000, -10000
        request.column_e, request.row_e = 0, .01
        self.assertFalse(owner.begin(owner, request, 10))
        self.assertEqual(owner.reason, 'request_invalid')

    def test_capacity_and_work_budget_are_checked_without_native_calls(self):
        host, owner, request = provider()
        request.columns, request.rows = 16, 16
        owner.begin(owner, request, 10)
        self.assertFalse(owner.step(owner, 10, 9))
        self.assertEqual(host.env.calls, 0)
        owner.begin(owner, request, 10)
        for index in range(32):
            owner.step(owner, 10 + index * .01, 8)
        self.assertEqual(owner.frame(owner, 10.31).count, 256)
        request.columns = 17
        self.assertFalse(owner.begin(owner, request, 11))


if __name__ == '__main__':
    unittest.main()
