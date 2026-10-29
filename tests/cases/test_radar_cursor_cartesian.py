"""A/A manual slew is Cartesian on the existing polar scope; A/G remains separate."""
import math
import unittest
from host import Host
from test_radar_source_contract import system_host, current_frame


def xy(c):
    return c.cursor_range*math.sin(c.cursor_az), c.cursor_range*math.cos(c.cursor_az)


class CartesianRadarCursor(unittest.TestCase):
    def test_actual_axis_right_is_horizontal_in_rws_and_tws(self):
        for mode in (10601, 10602):
            h = system_host();current_frame(h, 10);h.update()
            h.env.SetCommand(mode, 1)
            h.env.SetCommand(10613, 1)  # Begin off-centre through the actual key route.
            h.update()
            y = h.get('F22_RADAR_CURSOR_Y');x = h.get('F22_RADAR_CURSOR_X')
            h.env.SetCommand(10620, .5)
            for i in range(1, 31):
                current_frame(h, 10+i/60, 2+2*i);h.update()
                self.assertAlmostEqual(h.get('F22_RADAR_CURSOR_Y'), y, delta=1e-10)
            self.assertAlmostEqual(h.get('F22_RADAR_CURSOR_X')-x, 1.45*.1, delta=1e-9)

    def test_actual_axis_up_is_vertical_and_diagonal_preserves_input_ratio(self):
        for horizontal in (0, .5):
            h = system_host();current_frame(h, 10);h.update()
            h.env.SetCommand(10613, 1);h.update()
            x, y = h.get('F22_RADAR_CURSOR_X'), h.get('F22_RADAR_CURSOR_Y')
            h.env.SetCommand(10620, horizontal);h.env.SetCommand(10621, .25)
            for i in range(1, 31):
                current_frame(h, 10+i/60, 2+2*i);h.update()
                dx, dy = h.get('F22_RADAR_CURSOR_X')-x, h.get('F22_RADAR_CURSOR_Y')-y
                self.assertAlmostEqual(dx, 2*dy if horizontal else 0, delta=1e-10)
            self.assertGreater(dy, 0)

    def test_keys_and_display_expansion_keep_screen_directions_and_step_size(self):
        h = Host();c = h.load('Systems/Radar_Computer.lua').new()
        for expanded in (False, True):
            c.expand = expanded;c.cursor_display_range = None
            c.cursor_range, c.cursor_az = 20000, .3
            scale = c.range(c)/(2 if expanded else 1)
            for command, dx, dy in (('cursor_right', .025, 0), ('cursor_left', -.025, 0),
                                    ('cursor_up', 0, .025), ('cursor_down', 0, -.025)):
                before = xy(c);c.command(c, command);after = xy(c)
                self.assertAlmostEqual((after[0]-before[0])/scale, dx, delta=1e-12)
                self.assertAlmostEqual((after[1]-before[1])/scale, dy, delta=1e-12)

    def test_scope_edge_stops_without_bending_the_requested_line(self):
        h = Host();c = h.load('Systems/Radar_Computer.lua').new()
        maximum = c.range(c);c.cursor_range, c.cursor_az = maximum*.99, .25
        y = xy(c)[1]
        for _ in range(20):
            c.move_cursor(c, .1, 0)
            self.assertAlmostEqual(xy(c)[1], y, delta=1e-8)
            self.assertLessEqual(c.cursor_range, maximum+1e-7)
            self.assertLessEqual(abs(c.cursor_az), math.pi/3+1e-12)

    def test_moved_cursor_still_designates_the_track_at_its_display_position(self):
        h = Host();c = h.load('Systems/Radar_Computer.lua').new()
        c.clock, c.cursor_range, c.cursor_az = 10, 20000, .15
        c.command(c, 'cursor_right')
        c.tracks[9] = h.lua.table_from(dict(range=c.cursor_range, az=c.cursor_az,
                                           observed=10, hits=2, native_id=42))
        c.command(c, 'designate')
        self.assertEqual(c.selected, 9)

    def test_near_ownship_step_stops_before_crossing_minimum_range(self):
        h = Host();c = h.load('Systems/Radar_Computer.lua').new()
        c.cursor_range, c.cursor_az = 50, math.pi/3
        y = xy(c)[1]
        c.move_cursor(c, -83.3/c.range(c), 0)
        self.assertAlmostEqual(xy(c)[1], y, delta=1e-10)
        self.assertGreater(xy(c)[0], 0)
        self.assertGreaterEqual(c.cursor_range, 40-1e-10)

    def test_nonfinite_slew_does_not_change_cursor_or_follow_state(self):
        h = Host();c = h.load('Systems/Radar_Computer.lua').new();c.cursor_follow = True
        before = xy(c)
        for value in (float('nan'), float('inf'), -float('inf')):
            c.move_cursor(c, value, 0)
            self.assertEqual(xy(c), before)
            self.assertTrue(c.cursor_follow)
