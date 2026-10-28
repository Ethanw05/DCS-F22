"""R-NAV-001/003: actual producer, HUD, side, UFC and warning inputs."""
import unittest
from navigation_ports import altitude_host, seed_physical


class AltitudeOwners(unittest.TestCase):
    def test_actual_producer_publishes_distinct_clocks_and_independent_standby(self):
        h,produce=altitude_host()
        self.assertEqual(h.get('F22_ALT_SNAPSHOT_CLOCK_KIND'),2)
        self.assertEqual(h.get('F22_ALT_SNAPSHOT_GENERATION'),3)
        self.assertEqual(h.get('F22_ALT_SNAPSHOT_TIME'),10)
        self.assertEqual(h.get('F22_AP_CLOCK'),2)
        self.assertEqual(h.get('F22_ALT_BARO_VALID'),1)
        h.seed({'F22_ALTIMETER_NATIVE_VALID':0})
        produce()
        self.assertEqual(h.get('F22_ALT_BARO_VALID'),0)
        self.assertEqual(h.get('F22_ALT_STANDBY_VALID'),1)
        h.env.get_model_time=None
        produce()
        for name in ['BARO','RADAR','STANDBY']:
            self.assertEqual(h.get(f'F22_ALT_{name}_VALID'),0)

    def test_hud_and_side_withdraw_stalled_altitude_but_keep_motion(self):
        h,produce=altitude_host()
        h.load('Systems/HUD_Flight_Data.lua');hud=h.env.update
        h.load('Systems/Avionics.lua');side=h.env.update
        hud();side()
        self.assertEqual(h.get('HUD_ALT_VALID'),1)
        self.assertEqual(h.get('F22_SIDE_BARO_VALID'),1)
        seed_physical(h,clock=12);h.state.time=20
        hud();side()
        self.assertEqual(h.get('HUD_ALT_VALID'),0)
        self.assertEqual(h.get('F22_SIDE_BARO_VALID'),0)
        self.assertEqual(h.get('HUD_GS_VALID'),1)
        h.seed({'F22_ALTIMETER_RESULT_TIME':20,'F22_ALT_STANDBY_NATIVE_STAMP':20})
        produce();hud();side()
        self.assertEqual(h.get('HUD_ALT_VALID'),1)
        self.assertEqual(h.get('F22_SIDE_BARO_VALID'),1)

    def test_qualified_vertical_speed_uses_one_uppercase_fpm_channel(self):
        h,_=altitude_host()
        h.load('Systems/Avionics.lua')
        h.seed({'EFM_HUD_VU':1000/196.850394})
        h.update()
        self.assertAlmostEqual(h.get('VV'),1000)
        self.assertEqual(h.get('F22_SIDE_VS_VALID'),1)
        h.seed({'EFM_HUD_VU':0});h.update()
        self.assertEqual(h.get('VV'),0)
        self.assertEqual(h.get('F22_SIDE_VS_VALID'),1)
        h.seed({'EFM_HUD_KINEMATICS_VALID':0});h.update()
        self.assertEqual(h.get('F22_SIDE_VS_VALID'),0)

    def test_ufc_altitude_rows_expire_the_original_observation(self):
        h,_=altitude_host()
        h.execute("pages=dofile(LockOn_Options.script_path..'Systems/ICP_Flight_Pages.lua').new(function(k) return get_param_handle(k):get() end,function(k,v) get_param_handle(k):set(v) end,function() end,{OP1=1,OP2=2,OP3=3,OP4=4,OP5=5,N0=10,N1=11,guidance=1,altitude=2,warnings=3});pages:open(5);pages:update()")
        self.assertEqual(h.get('ICP_FLIGHT_ROW_1'),'BARO 3281 FT')
        seed_physical(h,clock=12);h.state.time=20
        h.execute('pages:update()')
        self.assertEqual(h.get('ICP_FLIGHT_ROW_1'),'BARO NO DATA')
        self.assertEqual(h.get('ICP_FLIGHT_ROW_2'),'RADAR NO DATA')

    def test_warning_owner_retires_stale_radar_low_authority(self):
        h,_=altitude_host()
        h.load('Systems/Pilot_Warning_System.lua')
        h.env.post_initialize()
        h.seed({'F22_ALT_RADAR_FLOOR':2500})
        h.update()
        self.assertEqual(h.get('F22_ALT_ALERT_SOURCE'),'RADAR LOW')
        seed_physical(h,clock=12);h.state.time=20
        h.update()
        self.assertEqual(h.get('F22_ALT_ALERT_SOURCE'),'')


if __name__=='__main__':
    unittest.main()
