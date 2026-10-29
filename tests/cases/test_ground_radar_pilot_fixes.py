"""Flight-reported MAP clutter and ground track -> HUD designation behavior."""
import unittest

from test_ground_radar_packets import ground_host, update, selected
from test_radar_pilot_presentation import page_host, visible


def mover(h, now, mode):
    h.seed(dict(F22_AG_NATIVE_MAP=int(mode == 1), F22_AG_NATIVE_SEA=0,
                F22_AG_GMT_COUNT=1, F22_AG_GMT_LAST_TIME=now))
    values = dict(ID=71, TIME=now, N=10000, U=0, E=0, VN=5, VU=0, VE=0,
                  AZ=0, RANGE=10000, ASSOCIATION_VALID=1)
    h.seed({'F22_AG_GMT_1_'+key: value for key, value in values.items()})


class GroundPilotFixes(unittest.TestCase):
    def test_map_retains_internal_returns_without_drawing_gmt_search_bricks(self):
        h = ground_host()
        mover(h, 10, 1)
        update(h)
        self.assertEqual(len(h.env.ground.model.movers), 1)
        self.assertEqual(h.get('F22_AG_GMT_DISPLAY_1_VALID'), 0)
        h.env.ground.command(h.env.ground, 'tws', 1, True, 10)
        mover(h, 10.1, 2)
        h.seed({'F22_AG_NATIVE_SEQUENCE': 4})
        update(h, 10.1)
        self.assertEqual(h.get('F22_AG_GMT_DISPLAY_1_VALID'), 1)

    def test_actual_indicator_rejects_map_bricks_even_with_retained_old_valid_flag(self):
        h, records = page_host('ag_radar_format')
        h.seed(dict(MFD_OPACITY=1, TEST_PMFD_PAGE=1, HUD_MODE=7,
                    F22_AG_RADAR_OPERATING=1, F22_AG_GMT_DISPLAY_1_VALID=1,
                    F22_AG_GMT_DISPLAY_1_ALPHA=1))
        for mode, expected in ((1, False), (2, True), (3, True), (4, True), (5, True), (6, False)):
            h.seed({'F22_AG_MODE': mode})
            self.assertEqual(visible(h, records, 'TEST_F22_AG_GMT_BRICK_1'), expected)

    def test_ground_object_designation_reaches_actual_hud_owner_and_withdraws_on_loss(self):
        h = ground_host()
        h.sensor('getSelfCoordinates', (0, 1000, 0))
        for name in ('getHeading', 'getPitch', 'getRoll'):
            h.sensor(name, 0)
        h.execute('package.loaded.terrain={GetHeight=function()return 0 end}')
        h.seed({'MAIN_POWER': 1, 'HUD_MODE': 7})
        h.load('Systems/AG_Mark_System.lua')
        h.env.post_initialize()
        mark_update = h.env.update
        h.env.ground.command(h.env.ground, 'tws', 1, True, 10)
        update(h)
        h.env.ground.command(h.env.ground, 'acquire', 1, True, 10)
        selected(h, stamp=10.1)
        h.seed(dict(F22_AG_NATIVE_MAP=0, F22_AG_NATIVE_SEQUENCE=4,
                    F22_AG_GMT_LAST_TIME=10.1, F22_AG_NATIVE_TRACK_N=20000,
                    F22_AG_NATIVE_TRACK_U=800))
        update(h, 10.1)
        mark_update()
        self.assertEqual(h.get('F22_AG_DESIGNATION_VALID'), 1)
        self.assertEqual(h.get('HUD_AG_TARGET_VALID'), 1)
        self.assertEqual(h.get('HUD_AG_CUE_VALID'), 1)
        self.assertEqual(h.get('F22_AG_TARGET_OBSERVATION_TIME'), 10.1)
        self.assertEqual(h.get('F22_AG_TARGET_PACKET_SEQUENCE') % 2, 0)
        h.seed({'F22_AG_NATIVE_TRACK_MEMORY': 1})
        update(h, 10.1)
        mark_update()
        self.assertEqual(h.get('HUD_AG_TARGET_VALID'), 0)
        self.assertEqual(h.get('HUD_AG_CUE_VALID'), 0)


if __name__ == '__main__':
    unittest.main()
