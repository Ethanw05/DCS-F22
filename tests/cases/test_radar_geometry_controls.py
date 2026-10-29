"""Independent physical-frame/routing cases through actual Lua 5.1 owners."""
import math
from pathlib import Path
import re
import unittest

from host import Host, ROOT
from test_radar_source_contract import system_host, current_frame


def table(h, values):
    return h.lua.table_from(values)


def rotate(vector, heading, pitch, roll):
    """Independent matrix composition in body/world N/U/E ordering."""
    ch, sh, cp, sp, cr, sr = (math.cos(heading), math.sin(heading),
        math.cos(pitch), math.sin(pitch), math.cos(roll), math.sin(roll))
    matrices = (((1, 0, 0), (0, cr, -sr), (0, sr, cr)),
                ((cp, -sp, 0), (sp, cp, 0), (0, 0, 1)),
                ((ch, 0, -sh), (0, 1, 0), (sh, 0, ch)))
    result = vector
    for matrix in matrices:
        result = tuple(sum(matrix[i][j]*result[j] for j in range(3)) for i in range(3))
    return result


def ground_packet(h, now, map_mode=True, sea=False, count=0):
    h.seed(dict(F22_AG_NATIVE_SCHEMA=1, F22_AG_NATIVE_SEQUENCE=2,
        F22_AG_NATIVE_SOURCE_EPOCH=1, F22_AG_NATIVE_MAP=int(map_mode), F22_AG_NATIVE_SEA=int(sea),
        F22_AG_GMT_READY=1, F22_AG_GMT_LAST_TIME=now, F22_AG_GMT_COUNT=count,
        F22_AG_AGR_VALID=0, F22_AG_AGR_TIME=0, F22_AG_AGR_RANGE_FT=0, F22_AG_AGR_VELOCITY_KT=0,
        F22_AG_RADAR_NATIVE_READY=1))


class RadarGeometryControls(unittest.TestCase):
    def test_body_world_rotation_and_inverse_use_physical_frames(self):
        h = Host()
        display = h.load('Systems/Radar_Display.lua')
        for heading in (0, math.radians(179), math.radians(-179)):
            for pitch in (0, math.radians(25), math.radians(-30)):
                for roll in (0, math.radians(45), math.radians(-90)):
                    for azimuth, elevation in ((0, 0), (.3, -.2), (-.4, .25)):
                        radius = 12000
                        ray = (radius*math.cos(elevation)*math.cos(azimuth),
                               radius*math.sin(elevation), radius*math.cos(elevation)*math.sin(azimuth))
                        expected = rotate(ray, heading, pitch, roll)
                        pose = table(h, dict(north=1200, altitude=6000, east=-700,
                            heading=heading, pitch=pitch, roll=roll))
                        observation = table(h, dict(range=radius, az=azimuth, el=elevation))
                        display.world_observation(observation, pose)
                        for name, origin, offset in zip(('north', 'altitude', 'east'), (1200, 6000, -700), expected):
                            self.assertAlmostEqual(observation[name], origin+offset, delta=1e-6)
                        back = display.body_observation(observation, pose, 0)
                        self.assertAlmostEqual(back[0], radius, delta=1e-6)
                        self.assertAlmostEqual(math.remainder(back[1]-azimuth, 2*math.pi), 0, delta=1e-10)
                        self.assertAlmostEqual(back[2], elevation, delta=1e-10)

    def test_heading_map_prediction_is_separate_from_body_slant_ray(self):
        h = Host(); display = h.load('Systems/Radar_Display.lua')
        target = table(h, dict(north=1100, altitude=3000, east=700,
            vn=10, vu=5, ve=-2, velocity_valid=True))
        for pitch, roll in ((0, 0), (.4, -.8)):
            pose = table(h, dict(north=100, altitude=1000, east=200,
                heading=math.pi/2, pitch=pitch, roll=roll))
            distance, azimuth = display.scope_observation(target, pose, 2)
            self.assertAlmostEqual(distance, math.hypot(1020, 496), delta=1e-8)
            self.assertAlmostEqual(azimuth, math.atan2(-1020, 496), delta=1e-10)
            x, y = display.plot(target, pose, 10000, 2)
            self.assertAlmostEqual(x, -1.45*1020/10000, delta=1e-10)
            self.assertAlmostEqual(y, -.66+1.45*496/10000, delta=1e-10)
        self.assertEqual(target.north, 1100)  # Display prediction never replaces measured coordinates.

    def test_native_world_metres_become_scope_only_at_consumer(self):
        h = system_host(); current_frame(h, 10, degrees=30); h.update()
        self.assertEqual(h.get('F22_SCOPE_01_SOURCE'), 42)
        self.assertEqual(h.get('F22_SCOPE_01_VALID'), 1)
        scale = h.get('F22_RADAR_RANGE_NM')*1852
        self.assertAlmostEqual(h.get('F22_SCOPE_01_X'), 1.45*20000*.5/scale, delta=1e-8)
        self.assertAlmostEqual(h.get('F22_SCOPE_01_Y'), -.66+1.45*20000*math.cos(math.pi/6)/scale, delta=1e-8)
        self.assertAlmostEqual(h.get('F22_SCOPE_01_ALT_FT'), 5000*3.280839895, delta=1e-6)
        h.seed({'F22A_01_N': float('nan')}); h.update()
        self.assertEqual(h.get('F22_SCOPE_01_VALID'), 0)
        current_frame(h, 10.1, 4); h.update()
        self.assertEqual(h.get('F22_SCOPE_01_VALID'), 1)

    def test_scope_capacity_is_bounded_without_losing_native_authority(self):
        h = system_host(); current_frame(h, 10)
        for slot in range(1, 81):
            values = dict(VALID=1, ID=100+slot, TIME=10, N=20000, U=5000, E=(slot-40)*200,
                VN=50, VU=0, VE=0, ASSOCIATION_VALID=1, FILTER_VALID=1, VELOCITY_VALID=1,
                VELOCITY_SIGMA_MPS=2, RANGE_SIGMA_M=10, HITS=3)
            h.seed({f'F22A_{slot:02}_{key}': value for key, value in values.items()})
        h.update()
        self.assertEqual(h.get('F22_RADAR_TRACK_COUNT'), 64)
        self.assertLessEqual(h.get('F22_RADAR_DRAWN_COUNT'), 24)
        self.assertIsNone(h.get('F22_SCOPE_25_VALID'))

    def test_launch_zone_crossbars_follow_horizontal_ray_and_clip(self):
        h = Host(); zone = h.load('Systems/Radar_Launch_Zone.lua')
        layout = table(h, dict(radius=1.45, origin_y=-.66))
        for heading, relative in ((0, (6000, 3000, 8000)), (math.pi/2, (10000, 3000, 0))):
            result = zone.project(table(h, relative), heading, 5000, 9000, 7000, 20000, layout, 'TWS')
            self.assertIsNotNone(result)
            north, altitude, east = relative
            right = -north*math.sin(heading)+east*math.cos(heading)
            forward = north*math.cos(heading)+east*math.sin(heading)
            norm = math.hypot(north, east)
            for name, slant in (('MIN', 5000), ('MAX', 9000), ('TURN', 7000)):
                segment = result[name]
                self.assertIsNotNone(segment)
                x, y = (segment[1]+segment[3])/2, (segment[2]+segment[4])/2
                horizontal = math.sqrt(slant*slant-altitude*altitude)/20000*1.45
                self.assertAlmostEqual(x, horizontal*right/norm, delta=1e-9)
                self.assertAlmostEqual(y, -.66+horizontal*forward/norm, delta=1e-9)
                for coordinate, low, high in ((segment[1], -.965, .965), (segment[3], -.965, .965),
                        (segment[2], -.925, .985), (segment[4], -.925, .985)):
                    self.assertGreaterEqual(coordinate, low-1e-9); self.assertLessEqual(coordinate, high+1e-9)
        for bad in (float('nan'), float('inf'), -1, 0):
            self.assertIsNone(zone.project(table(h, (1000, 0, 0)), 0, 100, 1000, 500, bad, layout, 'STT'))
        self.assertIsNone(zone.project(table(h, (0, 5000, 0)), 0, 100, 1000, 500, 20000, layout, 'STT'))

    def test_saved_ids_and_device_press_release_remain_stable(self):
        h = system_host(); commands = h.load('Systems/Radar_Commands.lua')
        expected = dict(power=10600, rws=10601, tws=10602, vertical=10604, boresight=10605,
            designate=10606, undesignate=10609, wide=10622, bvr=10627, stt=10632,
            designate_begin=10634, designate_end=10635, preview_cancel=10636)
        for name, command in expected.items():
            self.assertEqual(commands[name], command)
            self.assertTrue(h.state.commands[command])
        for kind in ('keyboard', 'joystick'):
            content = re.sub(r'\s+', '', (ROOT/'Input/F-22A'/kind/'default.lua').read_text(encoding='utf-8'))
            for command in (10601, 10602, 10605):
                self.assertIn(f'down={command},value_down=1,cockpit_device_id=14', content)
        current_frame(h, 10); h.update()
        h.env.SetCommand(10600, 14.375); h.update()
        self.assertEqual(h.get('RADAR_PWR'), 0)
        h.env.SetCommand(10600, 14.25); h.update()
        self.assertEqual(h.get('RADAR_PWR'), 0)
        h.env.SetCommand(10600, 14.375); h.update()
        self.assertEqual(h.get('RADAR_PWR'), 1)

    def test_nonfinite_discrete_and_axes_cannot_create_or_retain_input(self):
        for bad in (float('nan'), float('inf'), -float('inf'), 'bad', object()):
            h = system_host(); current_frame(h, 10); h.update()
            h.env.SetCommand(10600, bad); h.update()
            self.assertEqual(h.get('RADAR_PWR'), 1)
            self.assertEqual(h.get('F22_ACM_MODE'), 0)
            h.env.SetCommand(10605, bad); h.update()
            self.assertEqual(h.get('F22_ACM_MODE'), 0)
        h = system_host(); current_frame(h, 10); h.update()
        h.env.SetCommand(10620, 1)
        current_frame(h, 10.1, 4); h.update()
        held = h.get('F22_RADAR_CURSOR_X')
        h.env.SetCommand(10620, float('nan'))
        current_frame(h, 10.2, 6); h.update()
        self.assertAlmostEqual(h.get('F22_RADAR_CURSOR_X'), held, delta=1e-12)
        h.env.SetCommand(10620, 1)
        current_frame(h, 10.3, 8); h.update()
        self.assertGreater(h.get('F22_RADAR_CURSOR_X'), held)

    def test_radar_focus_relocation_and_loss_cancels_held_axes(self):
        names = {2:'PMFD', 3:'LMFD', 4:'RMFD', 5:'CMFD'}
        for focus, panel in names.items():
            h = system_host(); current_frame(h, 10)
            h.seed({f'F22_{name}_FORMAT': 7 for name in names.values()})
            h.seed({f'F22_{panel}_FORMAT': 1, 'F22_SOI': focus}); h.update()
            before = h.get('F22_RADAR_CURSOR_X')
            h.env.SetCommand(10620, 1); current_frame(h, 10.1, 4); h.update()
            self.assertGreater(h.get('F22_RADAR_CURSOR_X'), before, panel)
            moved = h.get('F22_RADAR_CURSOR_X')
            h.seed({f'F22_{panel}_FORMAT': 7}); current_frame(h, 10.2, 6); h.update()
            self.assertAlmostEqual(h.get('F22_RADAR_CURSOR_X'), moved, delta=1e-12)
            h.seed({f'F22_{panel}_FORMAT': 1}); current_frame(h, 10.3, 8); h.update()
            self.assertAlmostEqual(h.get('F22_RADAR_CURSOR_X'), moved, delta=1e-12)
            h.env.SetCommand(10620, 1); current_frame(h, 10.4, 10); h.update()
            self.assertGreater(h.get('F22_RADAR_CURSOR_X'), moved)

    def test_weapon_specific_acm_patterns_and_power_intent(self):
        h = system_host(); current_frame(h, 10); h.update()
        for index, (role, code, half_width) in enumerate(((5, 3, 15), (3, 0, 60), (2, 0, 60))):
            current_frame(h, 10.1+index*.1, 4+index*2); h.seed({'HUD_MODE': role}); h.update()
            self.assertEqual(h.get('F22_ACM_MODE'), code)
            self.assertAlmostEqual(h.get('F22_AESA_CONTROL_HALF_AZ'), math.radians(half_width), delta=1e-12)
        h.seed({'HUD_MODE': 3}); current_frame(h, 10.4, 10); h.update()
        h.env.SetCommand(10604, 1); h.update()
        self.assertEqual(h.get('F22_ACM_MODE'), 2)
        self.assertAlmostEqual(h.get('F22_AESA_CONTROL_EL'), math.radians(16.5), delta=1e-12)
        self.assertAlmostEqual(h.get('F22_AESA_CONTROL_HALF_EL'), math.radians(29.5), delta=1e-12)
        self.assertEqual(h.get('F22_AESA_CONTROL_RANGE'), 10*1852)
        h.env.SetCommand(10600, 1); h.update()
        for index, role in enumerate((2, 3, 5)):
            current_frame(h, 10.5+index*.1, 12+index*2); h.seed({'HUD_MODE': role}); h.update()
            self.assertEqual(h.get('RADAR_PWR'), 0)

    def test_request_requires_new_measurement_before_lock_and_reject_retains_pattern(self):
        h = system_host(); current_frame(h, 10); h.env.SetCommand(10602, 1); h.update()
        current_frame(h, 10.1, 4); h.update(); h.env.SetCommand(10618, 1); h.env.SetCommand(10632, 1); h.update()
        self.assertNotEqual(h.get('F22N_RADAR_MODE'), 3)
        self.assertEqual(h.get('F22_RADAR_STT_VALID'), 0)
        current_frame(h, 10.2, 6); h.update()
        self.assertEqual(h.get('F22N_RADAR_MODE'), 3)
        self.assertEqual(h.get('F22_RADAR_STT_VALID'), 1)
        h.env.SetCommand(10605, 1); h.update()
        self.assertEqual(h.get('F22N_RADAR_MODE'), 3)
        self.assertEqual(h.get('F22_RADAR_STT_SOURCE_ID'), 42)
        h.env.SetCommand(10609, 1); h.update()
        self.assertEqual(h.get('F22_RADAR_STT_VALID'), 0)
        self.assertEqual(h.get('F22_ACM_MODE'), 1)

    def test_air_reports_remain_tactical_background_in_ground_role(self):
        h = system_host(); current_frame(h, 10)
        h.seed({'HUD_MODE': 7}); ground_packet(h, 10); h.update()
        self.assertEqual(h.get('F22_AESA_CONTROL_SURFACE'), 1)
        self.assertEqual(h.get('F22_RADAR_SEARCH_REQUEST_VALID'), 0)
        self.assertEqual(h.get('F22_RADAR_TACTICAL_01_SOURCE'), 42)
        self.assertEqual(h.get('F22_RADAR_TACTICAL_01_VALID'), 1)
        self.assertEqual(h.get('F22_RADAR_STT_VALID'), 0)

    def test_completed_search_reports_cannot_change_map_gmt_sea_family_at_command(self):
        h = Host(); ground_packet(h, 10, map_mode=True, count=1)
        h.seed(dict(F22_AG_GMT_1_ID=1, F22_AG_GMT_1_TIME=10, F22_AG_GMT_1_N=10000,
            F22_AG_GMT_1_U=0, F22_AG_GMT_1_E=0, F22_AG_GMT_1_VN=0,
            F22_AG_GMT_1_VU=0, F22_AG_GMT_1_VE=0, F22_AG_GMT_1_AZ=0,
            F22_AG_GMT_1_RANGE=10000, F22_AG_GMT_1_ASSOCIATION_VALID=1))
        h.execute("ground=dofile(LockOn_Options.script_path..'Systems/AG_Radar_System.lua').new("
            "function(k)return get_param_handle(k):get()end,function(k,v)get_param_handle(k):set(v)end,function()end);"
            "pose={north=0,altitude=5000,east=0,heading=0,pitch=0,roll=0};ground:update(pose,10,0,true,true)")
        # MAP suppresses mover symbols; GMT displays them after the mode reply.
        self.assertEqual(h.get('F22_AG_GMT_DISPLAY_1_VALID'), 0)
        h.execute("ground:command('tws',1,true,10);ground:update(pose,10.01,.01,true,true)")
        self.assertEqual(h.get('F22_AG_MODE'), 2)
        self.assertEqual(h.get('F22_AG_GMT_DISPLAY_1_VALID'), 0)
        ground_packet(h, 10.02, map_mode=False, count=1)
        h.seed({'F22_AG_NATIVE_SEQUENCE': 4, 'F22_AG_GMT_1_VN': 10})
        h.execute('ground:update(pose,10.02,.01,true,true)')
        self.assertEqual(h.get('F22_AG_GMT_DISPLAY_1_VALID'), 1)


if __name__ == '__main__':
    unittest.main()
