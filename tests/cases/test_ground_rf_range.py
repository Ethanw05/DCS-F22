"""Received ground RF directions gain qualified estimates, never strength ranges."""
import math
import unittest

from host import Host
from test_threat_warning_presentation import defensive_page, showing


def receiver(height='0'):
    h = Host()
    h.state.time = 100
    h.seed(dict(MAIN_POWER=1, F22_ELECTRICAL_VALID=1, EFM_POWER_OWNER=1,
        EFM_PHYSICAL_VALID=1, EFM_PHYSICAL_GENERATION=2, EFM_PHYSICAL_STAMP=100,
        EFM_PHYSICAL_CLOCK_KIND=1, F22_AP_CLOCK=100, EFM_MISSION_POWER_AVAILABLE=1,
        F22_DEF_DISPLAY_RANGE_NM=40, F22_RADAR_RANGE_NM=40))
    for name in ('getHeading', 'getPitch', 'getRoll'):
        h.sensor(name, 0)
    h.sensor('getSelfCoordinates', (0, 1500, 0))
    h.execute('''
        terrain_reads=0
        function require(name)
            assert(name=='terrain')
            return {GetHeight=function(n,e)
                terrain_reads=terrain_reads+1
                return '''+height+'''
            end}
        end
        native={set_power=function()end}
        function GetDevice()return native end
    ''')
    h.load('Systems/RWR_System.lua')
    h.env.post_initialize()
    return h


def ground(h, distance=10*1852, age=0, general=2, power=.2):
    fields = dict(SOURCE=123, TIME=age, AZIMUTH=0,
        ELEVATION=-math.atan2(1500, distance), SIGNAL=1, UNIT_TYPE='8',
        GENERAL_TYPE=general, PRIORITY=1, POWER=power)
    h.seed({'RWR_CONTACT_01_'+key: value for key, value in fields.items()})
    h.update()


class GroundRfRange(unittest.TestCase):
    def test_actual_receiver_fusion_def_and_tsd_scale_ground_estimate(self):
        h = receiver()
        ground(h)
        self.assertEqual(h.get('F22_TACTICAL_01_GEO_VALID'), 1)
        self.assertAlmostEqual(h.get('F22_TACTICAL_01_GEO_N'), 18520, delta=1)
        self.assertEqual(h.get('F22_DEF_OV_01_GEO'), 1)
        self.assertEqual(h.get('F22_DEF_OV_01_RANGED'), 0)
        self.assertEqual(h.get('F22_DEF_OV_01_PROXIMITY'), 0)
        y40 = h.get('F22_DEF_OV_01_Y')
        tsd40 = h.get('F22_TSD_GEO_01_Y')
        h.seed(dict(F22_DEF_DISPLAY_RANGE_NM=20, F22_RADAR_RANGE_NM=20))
        ground(h)
        self.assertAlmostEqual(h.get('F22_DEF_OV_01_Y'), 2*y40)
        # TSD has a fixed screen origin; its displacement doubles too.
        layout = h.load('Systems/Radar_Display.lua')
        self.assertAlmostEqual(h.get('F22_TSD_GEO_01_Y')-layout.origin_y,
                               2*(tsd40-layout.origin_y))
        self.assertEqual(h.get('F22_TACTICAL_01_RANGE_VALID'), 0)
        self.assertEqual(h.get('F22_TACTICAL_01_WEAPON_AUTHORITY'), 0)

    def test_actual_range_buttons_and_offscale_marker(self):
        h = receiver()
        controller = h.load('Systems/MFD_Controller.lua').new(
            h.env.get_param_handle, lambda *_: None, lambda: None)
        controller.update(controller, True, False)
        self.assertEqual(h.get('F22_MFD_RMFD_KEY_14'), 'RNG+')
        self.assertEqual(h.get('F22_MFD_RMFD_KEY_15'), 'RNG-')
        values = []
        for expected in (40, 20, 10, 5):
            self.assertEqual(h.get('F22_DEF_DISPLAY_RANGE_NM'), expected)
            ground(h, distance=8*1852)
            values.append(h.get('F22_DEF_OV_01_Y'))
            controller.button(controller, 2, 15, True)
            controller.button(controller, 2, 15, False)
        self.assertAlmostEqual(values[1], values[0]*2)
        self.assertAlmostEqual(values[2], values[1]*2)
        self.assertAlmostEqual(values[3], .84)
        self.assertEqual(h.get('F22_DEF_OV_01_OFFSCALE'), 1)
        graph = defensive_page(h)
        self.assertTrue(showing(h, graph, 'E'))
        self.assertTrue(showing(h, graph, '>'))
        controller.button(controller, 2, 14, True)
        controller.button(controller, 2, 14, False)
        self.assertEqual(h.get('F22_DEF_DISPLAY_RANGE_NM'), 10)

    def test_strength_does_not_define_estimated_distance(self):
        positions = []
        for power in (.05, .95):
            h = receiver()
            ground(h, power=power)
            positions.append(h.get('F22_TACTICAL_01_GEO_N'))
        self.assertAlmostEqual(*positions)

    def test_air_measured_range_keeps_existing_scale(self):
        h = receiver()
        h.execute('''
            overview=dofile(LockOn_Options.script_path..'Systems/Defensive_Overview.lua').new(
                function(n)return get_param_handle(n):get()end,
                function(n,v)get_param_handle(n):set(v)end,get_base_data())
            tracks={{source=77,az=0,el=0,age=0,range=18520,observations={}}}
        ''')
        h.env.overview.update(h.env.overview, 100, h.env.tracks, True, False, None)
        y40 = h.get('F22_DEF_OV_01_Y')
        h.seed(dict(F22_DEF_DISPLAY_RANGE_NM=20))
        h.env.overview.update(h.env.overview, 100, h.env.tracks, True, False, None)
        self.assertEqual(h.get('F22_DEF_OV_01_RANGED'), 1)
        self.assertAlmostEqual(h.get('F22_DEF_OV_01_Y'), y40*2)

    def test_unusable_terrain_or_ray_retains_relative_contact(self):
        for height, general, distance in (('nil', 2, 18520),
                                          ('0/0', 2, 18520),
                                          ('error("unavailable")', 2, 18520),
                                          ('0', 1, 18520), ('0', 3, 18520),
                                          ('0', 2, 100000)):
            with self.subTest(height=height, general=general, distance=distance):
                h = receiver(height)
                ground(h, distance=distance, general=general)
                self.assertEqual(h.get('F22_TACTICAL_01_GEO_VALID'), 0)
                self.assertEqual(h.get('F22_DEF_OV_01_PROXIMITY'), 1)
                self.assertEqual(h.get('F22_DEF_OV_01_VALID'), 1)
                h.seed(dict(F22_DEF_DISPLAY_RANGE_NM=5))
                before = h.get('F22_DEF_OV_01_Y')
                ground(h, distance=distance, general=general)
                self.assertAlmostEqual(h.get('F22_DEF_OV_01_Y'), before)

    def test_expired_direction_and_power_loss_withdraw_estimate(self):
        h = receiver()
        ground(h)
        self.assertEqual(h.get('F22_TACTICAL_01_GEO_VALID'), 1)
        h.state.time = 106.1
        ground(h, age=6.1)
        self.assertEqual(h.get('F22_TACTICAL_01_GEO_VALID'), 0)
        h.seed(dict(MAIN_POWER=0))
        h.update()
        self.assertEqual(h.get('F22_DEF_OV_COUNT'), 0)
        self.assertEqual(h.get('F22_RWR_TERRAIN_GEO_STATUS'), 0)

    def test_terrain_slope_uses_height_along_received_direction(self):
        h = receiver('100+.02*n')
        ground(h)
        expected = 1400 / (1500/18520 + .02)
        self.assertAlmostEqual(h.get('F22_TACTICAL_01_GEO_N'), expected, delta=1)
        self.assertGreater(h.get('F22_TACTICAL_01_GEO_RADIUS_M'), 0)

    def test_bounded_work_fairness_and_no_reception_age_renewal(self):
        h = Host()
        h.execute('''
            reads=0
            local Terrain=dofile(LockOn_Options.script_path..'Systems/EW_Terrain_Geolocation.lua')
            model=Terrain.new(function()reads=reads+1;return 0 end)
            contacts={};bearings={}
            for i=1,20 do
                contacts[i]={source=i,general=2,bearing_compensated=true}
                bearings[i]={stamp=100,origin={n=0,u=1500,e=0,time=100},world={.8,-.6,0}}
            end
        ''')
        for index in range(16):
            h.execute('for _,c in ipairs(contacts)do c.geolocation=nil end')
            h.env.reads = 0
            h.env.model.update(h.env.model, 100+index*.05, h.env.contacts, h.env.bearings)
            self.assertLessEqual(h.env.reads, 171)
        self.assertEqual(len(list(h.env.model.tracks.items())), 16)
        self.assertTrue(all(h.env.model.tracks[i].fix for i in range(1, 17)))
        h.execute('for _,c in ipairs(contacts)do c.geolocation=nil end')
        h.env.model.update(h.env.model, 99, h.env.contacts, h.env.bearings)
        self.assertEqual(len(list(h.env.model.tracks.items())), 0)

    def test_solver_rejects_invalid_inputs_and_preserves_fix_time(self):
        h = Host()
        h.execute('''
            terrain=dofile(LockOn_Options.script_path..'Systems/EW_Terrain_Geolocation.lua')
            origin={n=0,u=1500,e=0,time=100}
            direction={.8,-.6,0}
            height=function()return 0 end
            fix=terrain.solve(height,origin,direction)
        ''')
        current = h.env.terrain.current(h.env.fix, 105)
        self.assertEqual(current.time, 100)
        self.assertEqual(current.age, 5)
        self.assertAlmostEqual(current.radius, h.env.fix.radius+150)
        for now in (99.9, 106.01, math.nan, math.inf):
            self.assertIsNone(h.env.terrain.current(h.env.fix, now))
        for expression in ('terrain.solve(nil,origin,direction)',
                           'terrain.solve(height,{},direction)',
                           'terrain.solve(height,origin,{0,0,0})',
                           'terrain.solve(height,origin,{0/0,-1,0})',
                           'terrain.solve(height,origin,{0,1,0})'):
            fix, reason = h.execute('return '+expression)
            self.assertIsNone(fix)
            self.assertIn(reason, (1, 4))

    def test_fresh_contradiction_withdraws_previous_ground_fix(self):
        h = Host()
        h.execute('''
            local Terrain=dofile(LockOn_Options.script_path..'Systems/EW_Terrain_Geolocation.lua')
            model=Terrain.new(function()return 0 end)
            contacts={{source=1,general=2,bearing_compensated=true}}
            bearings={[1]={stamp=100,origin={n=0,u=1500,e=0,time=100},world={.8,-.6,0}}}
        ''')
        h.env.model.update(h.env.model, 100, h.env.contacts, h.env.bearings)
        self.assertIsNotNone(h.env.contacts[1].geolocation)
        h.execute('''
            contacts[1].geolocation=nil
            bearings[1]={stamp=100.05,origin={n=0,u=1500,e=0,time=100.05},world={0,1,0}}
        ''')
        h.env.model.update(h.env.model, 100.05, h.env.contacts, h.env.bearings)
        self.assertIsNone(h.env.contacts[1].geolocation)


if __name__ == '__main__':
    unittest.main()
