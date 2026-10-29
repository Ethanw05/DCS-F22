"""User policy: coalition identifies detected radar contacts independently of RF/IFF."""
import math
import unittest

from host import Host
from test_radar_source_contract import system_host, current_frame


class RadarCoalitionMetadata(unittest.TestCase):
    def test_detected_non_emitter_colors_and_selected_friendly_protection(self):
        for side in (0, 1):
            with self.subTest(side=side):
                h = system_host()
                for now, sequence in ((10, 2), (10.1, 4)):
                    current_frame(h, now, sequence)
                    h.seed({'F22A_01_COALITION_KNOWN': 1,
                            'F22A_01_COALITION_AFFILIATION': side})
                    h.update()
                h.env.SetCommand(10618, 1)
                h.update()
                self.assertEqual(h.get('F22_SCOPE_01_VALID'), 1)
                self.assertEqual(h.get('F22_SCOPE_01_AFFILIATION'), side)
                self.assertEqual(h.get('F22_RADAR_SELECTED_FRIENDLY'), side)
                self.assertEqual(h.get('F22_SCOPE_01_EW_SIGNAL'), 0)
                self.assertEqual(h.get('F22_RADAR_IFF_ON'), 0)

    def test_unknown_neutral_and_absent_metadata_never_inherit_numeric_zero(self):
        for values in ({}, {'COALITION_KNOWN': 0, 'COALITION_AFFILIATION': 0},
                       {'COALITION_KNOWN': 1, 'COALITION_AFFILIATION': -1},
                       {'COALITION_KNOWN': 1, 'COALITION_AFFILIATION': 2}):
            h = system_host()
            current_frame(h, 10)
            h.seed({'F22A_01_'+key: value for key, value in values.items()})
            h.update()
            self.assertEqual(h.get('F22_SCOPE_01_AFFILIATION'), -1)

    def test_priority_lock_keeps_coalition_color_and_friendly_gate(self):
        for side in (0, 1):
            h = system_host()
            for now, sequence in ((10, 2), (10.1, 4)):
                current_frame(h, now, sequence)
                h.seed({'F22A_01_COALITION_KNOWN': 1, 'F22A_01_COALITION_AFFILIATION': side})
                h.update()
            h.env.SetCommand(10618, 1)
            h.env.SetCommand(10632, 1)
            h.update()
            current_frame(h, 10.2, 6)
            h.update()
            self.assertEqual(h.get('F22N_RADAR_MODE'), 3)
            self.assertEqual(h.get('F22_SCOPE_01_SELECTED'), 1)
            self.assertEqual(h.get('F22_SCOPE_01_AFFILIATION'), side)
            self.assertEqual(h.get('F22_RADAR_SELECTED_FRIENDLY'), side)
            self.assertEqual(h.get('F22_RADAR_STT_IFF'), -1)

    def test_association_age_and_invalid_clock_withdraw_coalition_identity(self):
        h = Host()
        display = h.load('Systems/Radar_Display.lua')
        track = h.lua.table_from(dict(coalition_known=1, coalition_affiliation=0,
                                     association_valid=True, observed=10))
        self.assertEqual(display.affiliation(-1, track, 10), 0)
        self.assertEqual(display.affiliation(-1, track, 22), 0)
        for now in (9.999, 22.001, math.nan, math.inf, None):
            self.assertEqual(display.affiliation(-1, track, now), -1)
        track.association_valid = False
        self.assertEqual(display.affiliation(-1, track, 10), -1)
        track.association_valid = True
        track.coalition_known = 0
        self.assertEqual(display.affiliation(-1, track, 10), -1)

    def test_epoch_change_and_new_sample_replace_prior_coalition(self):
        h = system_host()
        current_frame(h, 10)
        h.seed({'F22A_01_COALITION_KNOWN': 1, 'F22A_01_COALITION_AFFILIATION': 1})
        h.update()
        self.assertEqual(h.get('F22_SCOPE_01_AFFILIATION'), 1)
        current_frame(h, 10.1, 4)
        h.seed({'F22A_01_COALITION_AFFILIATION': 0})
        h.update()
        self.assertEqual(h.get('F22_SCOPE_01_AFFILIATION'), 0)
        current_frame(h, 10.2, 6)
        h.seed({'F22_AESA_GENERATION': 2, 'F22A_01_COALITION_KNOWN': 0})
        h.update()
        self.assertEqual(h.get('F22_SCOPE_01_AFFILIATION'), -1)

    def test_torn_packet_is_not_used_for_identity(self):
        h = system_host()
        current_frame(h, 10)
        h.seed({'F22A_01_COALITION_KNOWN': 1, 'F22A_01_COALITION_AFFILIATION': 0})
        h.execute("""
            local handle = get_param_handle
            function get_param_handle(name)
                local p = handle(name)
                if name == 'F22A_01_COALITION_AFFILIATION' then
                    local read = p.get
                    function p:get()
                        handle('F22_AESA_SEQUENCE'):set(3)
                        return read()
                    end
                end
                return p
            end
        """)
        h.update()
        self.assertEqual(h.get('F22_SCOPE_01_VALID'), 0)


if __name__ == '__main__':
    unittest.main()
