"""R-NAV-013: actual cockpit adapter, independent units and failure sequences."""
import math
import unittest
from navigation_ports import altitude_host, seed_physical


def references(h, stamp=2):
    h.seed({'F22_GINS_SCHEMA':2,'F22_GINS_VALID':1,'F22_GINS_SEQUENCE':2,'F22_GINS_GENERATION':h.get('EFM_PHYSICAL_GENERATION'),
            'F22_GINS_STAMP':stamp,'F22_NAV_REFERENCE':0,
            'F22_GINS_WORLD_CLOCK_KIND':2,'F22_GINS_WORLD_STAMP':h.state.time})
    for role,source,degrees in [('NAV',1,30),('SFG',2,80),('HUD',2,120)]:
        prefix=f'F22_GINS_{role}_'
        h.seed({prefix+'SOURCE':source,prefix+'POWER':1,prefix+'ATTITUDE_VALID':1,
                prefix+'HEADING_VALID':1,prefix+'POSITION_READY':1,prefix+'PITCH':0,
                prefix+'ROLL':0,prefix+'HEADING':math.radians(degrees)})


def side_host():
    h,produce=altitude_host()
    references(h)
    h.sensor('getAngleOfAttack',math.radians(12))
    h.load('Systems/Avionics.lua')
    return h,produce


def magnetic(h, stamp=10, generation=3, degrees=10):
    h.seed({'F22_MAG_SCHEMA':1,'F22_MAG_SEQUENCE':2,'F22_MAG_CLOCK_KIND':2,
            'F22_MAG_GENERATION':generation,'F22_MAG_STAMP':stamp,'F22_MAG_VALID':1,
            'F22_MAG_DECL':math.radians(degrees),'F22_NAV_REFERENCE':1})


class SideIndications(unittest.TestCase):
    def test_units_and_selected_primary_standby_heading_ignore_raw_truth(self):
        h,_=side_host()
        for name in ['getIndicatedAirSpeed','getTrueAirSpeed','getHeading','getMachNumber','getRadarAltitude']:
            h.state.sensors[name]=h.lua.eval("function() error('Raw fallback was called') end")
        h.update()
        self.assertAlmostEqual(h.get('IAS'),100*1.943844492)
        self.assertAlmostEqual(h.get('TAS'),110*1.943844492)
        self.assertEqual(h.get('MACH'),.5)
        self.assertAlmostEqual(h.get('AOA'),12)
        self.assertEqual(h.get('NAV'),30)
        self.assertEqual(h.get('F22_SFG_HEADING'),80)
        self.assertAlmostEqual(h.get('RADALT'),600*3.280839895)
        for field in ['IAS','MACH','AOA','G','HEADING','SFG_HEADING','RADAR','VS']:
            self.assertEqual(h.get('F22_SIDE_'+field+'_VALID'),1)

    def test_failed_field_does_not_withdraw_independent_neighbours(self):
        h,_=side_host()
        h.seed({'EFM_AIRDATA_CAS_MPS':float('nan')})
        h.sensor('getAngleOfAttack',None)
        h.sensor('getVerticalAcceleration',float('inf'))
        h.update()
        for field in ['IAS','AOA','G']:
            self.assertEqual(h.get('F22_SIDE_'+field+'_VALID'),0)
        for field in ['MACH','RADAR','HEADING','SFG_HEADING','VS']:
            self.assertEqual(h.get('F22_SIDE_'+field+'_VALID'),1)
        h.seed({'EFM_AIRDATA_CAS_MPS':0})
        h.sensor('getAngleOfAttack',0);h.sensor('getVerticalAcceleration',0)
        h.update()
        for field,key in [('IAS','IAS'),('AOA','AOA'),('G','GFORCE')]:
            self.assertEqual(h.get('F22_SIDE_'+field+'_VALID'),1)
            self.assertEqual(h.get(key),0)

    def test_adc_loss_preserves_healthy_motion_height_and_references(self):
        h,_=side_host()
        h.seed({'EFM_AIRDATA_VALID':0,'EFM_HUD_VU':5})
        h.update()
        for field in ['IAS','MACH','AOA']:
            self.assertEqual(h.get('F22_SIDE_'+field+'_VALID'),0)
        for field in ['G','VS','RADAR','HEADING','SFG_HEADING']:
            self.assertEqual(h.get('F22_SIDE_'+field+'_VALID'),1)
        self.assertAlmostEqual(h.get('VV'),5*196.850394)

    def test_stopped_physics_expires_with_independent_world_clock(self):
        h,_=side_host();h.update()
        h.state.time=10.251
        h.update()
        for field in ['IAS','MACH','AOA','G','VS','RADAR','HEADING','SFG_HEADING']:
            self.assertEqual(h.get('F22_SIDE_'+field+'_VALID'),0)
        h.state.time=10.3;seed_physical(h,clock=2.3);references(h,stamp=2.3)
        h.update()
        self.assertEqual(h.get('F22_SIDE_IAS_VALID'),1)
        self.assertEqual(h.get('F22_SIDE_HEADING_VALID'),1)

    def test_copy_does_not_renew_original_air_or_reference_age(self):
        h,_=side_host()
        h.state.time=10.1;seed_physical(h,clock=2.2,world=10)
        h.seed({'EFM_AIRDATA_STAMP':2,'F22_GINS_WORLD_STAMP':9.8})
        h.update()
        self.assertEqual(h.get('F22_SIDE_IAS_VALID'),0)
        self.assertEqual(h.get('F22_SIDE_HEADING_VALID'),0)
        self.assertEqual(h.get('F22_SIDE_G_VALID'),1)

    def test_primary_and_sfg_heading_can_fail_independently(self):
        h,_=side_host()
        h.seed({'F22_GINS_NAV_HEADING_VALID':0});h.update()
        self.assertEqual(h.get('F22_SIDE_HEADING_VALID'),0)
        self.assertEqual(h.get('F22_SIDE_SFG_HEADING_VALID'),1)
        h.seed({'F22_GINS_NAV_HEADING_VALID':1,'F22_GINS_SFG_HEADING_VALID':0});h.update()
        self.assertEqual(h.get('F22_SIDE_HEADING_VALID'),1)
        self.assertEqual(h.get('F22_SIDE_SFG_HEADING_VALID'),0)

    def test_magnetic_reference_requires_current_typed_committed_declination(self):
        h,_=side_host();magnetic(h);h.update()
        self.assertEqual(h.get('NAV'),20)
        for changes in [{'F22_MAG_SEQUENCE':3},{'F22_MAG_STAMP':9.7},
                        {'F22_MAG_STAMP':10.02},{'F22_MAG_GENERATION':2},
                        {'F22_MAG_CLOCK_KIND':1},{'F22_MAG_DECL':'bad'}]:
            magnetic(h);h.seed(changes);h.update()
            self.assertEqual(h.get('F22_SIDE_HEADING_VALID'),0)
            self.assertEqual(h.get('F22_SIDE_IAS_VALID'),1)
        magnetic(h,degrees=0);h.update()
        self.assertEqual(h.get('F22_SIDE_HEADING_VALID'),1)

    def test_rollback_needs_new_generation_and_old_generation_cannot_return(self):
        h,_=side_host();h.update()
        h.state.time=9.9;seed_physical(h,world=9.9);h.update()
        self.assertEqual(h.get('F22_SIDE_IAS_VALID'),0)
        seed_physical(h,generation=4,world=9.9);h.update()
        self.assertEqual(h.get('F22_SIDE_IAS_VALID'),1)
        seed_physical(h,generation=3,world=9.9);h.update()
        self.assertEqual(h.get('F22_SIDE_IAS_VALID'),0)

    def test_hud_heading_uses_hud_reference_without_side_overwrite(self):
        h,_=side_host()
        h.load('Systems/HUD_Flight_Data.lua');hud=h.env.update
        h.load('Systems/Avionics.lua');side=h.env.update
        hud();side()
        self.assertAlmostEqual(h.get('HUD_HEADING_DISPLAY'),120,delta=1)
        self.assertEqual(h.get('HUD_TICK_C00'),120)
        h.sensor('getAngleOfAttack',None);h.sensor('getAngleOfSlide',None)
        hud()
        self.assertEqual(h.get('HUD_AOA_VALID'),0)
        self.assertEqual(h.get('HUD_SLIP_VALID'),0)
        self.assertEqual(h.get('HUD_GS_VALID'),1)

    def test_old_binary_without_explicit_world_clock_contract_is_unavailable(self):
        h,_=side_host()
        h.seed({'EFM_PHYSICAL_WORLD_CLOCK_KIND':0,'EFM_PHYSICAL_WORLD_STAMP':0})
        h.state.time=0;h.update()
        self.assertEqual(h.get('F22_SIDE_IAS_VALID'),0)


if __name__=='__main__':
    unittest.main()
