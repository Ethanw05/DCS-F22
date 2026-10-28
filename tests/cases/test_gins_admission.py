"""R-NAV-001/007/013: current selected references, independent failures and restart."""
import unittest
from host import Host
from navigation_ports import avionics_sensors, seed_physical


def producer():
    h=Host();h.state.time=10
    avionics_sensors(h);seed_physical(h)
    h.execute("function sample(k)return get_param_handle(k):get()end;"
        "function publish(k,v)get_param_handle(k):set(v)end;"
        "references=dofile(LockOn_Options.script_path..'Systems/Gins_References.lua');"
        "owner=references.new(sample,publish,get_base_data());owner:reset(true);"
        "primary=references.reader(sample,'NAV');standby=references.reader(sample,'SFG');"
        "function consume()primary:update();standby:update()end;consume()")
    return h


class GinsAdmission(unittest.TestCase):
    def test_actual_producer_declares_generation_and_uses_explicit_host_observations(self):
        h=producer()
        self.assertEqual(h.get('F22_GINS_SCHEMA'),2)
        self.assertEqual(h.get('F22_GINS_GENERATION'),3)
        self.assertTrue(h.execute('return primary.valid and standby.valid'))
        self.assertEqual(h.get('F22_GINS_NAV_ATTITUDE_VALID'),1)
        self.assertEqual(h.get('F22_GINS_NAV_HEADING_VALID'),1)
        self.assertEqual(h.get('F22_GINS_SFG_SOURCE'),2)

    def test_selected_resource_failure_is_independent_and_recovers_without_raw_fallback(self):
        h=producer()
        h.seed({'F22_GINS_1_HEADING_FAILURE':1})
        h.execute('owner:update();consume()')
        self.assertEqual(h.get('F22_GINS_NAV_HEADING_VALID'),0)
        self.assertEqual(h.get('F22_GINS_NAV_ATTITUDE_VALID'),1)
        self.assertEqual(h.get('F22_GINS_SFG_HEADING_VALID'),1)
        h.execute("assert(owner:select('NAV',2));consume()")
        self.assertEqual(h.get('F22_GINS_NAV_SOURCE'),2)
        self.assertEqual(h.get('F22_GINS_NAV_HEADING_VALID'),1)
        h.seed({'F22_GINS_2_POWER_FAILURE':1});h.execute('owner:update();consume()')
        self.assertEqual(h.get('F22_GINS_NAV_HEADING_VALID'),0)
        self.assertEqual(h.get('F22_GINS_SFG_ATTITUDE_VALID'),0)
        h.seed({'F22_GINS_2_POWER_FAILURE':0});h.execute('owner:update();consume()')
        self.assertEqual(h.get('F22_GINS_NAV_HEADING_VALID'),1)

    def test_stopped_physics_cannot_be_renewed_by_a_live_lua_copy(self):
        h=producer();h.state.time=10.3
        h.execute('owner:update();consume()')
        self.assertEqual(h.get('F22_GINS_VALID'),0)
        self.assertFalse(h.execute('return primary.valid'))
        h.state.time=10.31;seed_physical(h,clock=2.31)
        h.execute('owner:update();consume()')
        self.assertEqual(h.get('F22_GINS_VALID'),1)
        self.assertTrue(h.execute('return primary.valid'))

    def test_stopped_reference_expires_even_with_healthy_physics(self):
        h=producer();h.state.time=10.3;seed_physical(h,clock=2.2)
        h.execute('consume()')
        self.assertFalse(h.execute('return primary.valid'))
        self.assertFalse(h.execute('return standby.valid'))

    def test_new_physical_generation_retires_alignment_and_old_frame(self):
        h=producer()
        seed_physical(h,clock=2,generation=4)
        h.execute('consume()')
        self.assertFalse(h.execute('return primary.valid'))
        h.execute('owner:update();consume()')
        self.assertEqual(h.get('F22_GINS_GENERATION'),4)
        self.assertEqual(h.get('F22_GINS_NAV_HEADING_VALID'),0)
        self.assertEqual(h.get('F22_INS_READY'),0)
        h.execute('owner:reset(true);consume()')
        self.assertEqual(h.get('F22_GINS_NAV_HEADING_VALID'),1)

    def test_sequence_exhaustion_is_bounded_and_new_generation_can_publish_again(self):
        h=producer();h.execute('owner.sequence=16777215;owner:update()')
        self.assertEqual(h.get('F22_GINS_VALID'),0)
        seed_physical(h,generation=4)
        h.execute('owner:update();consume()')
        self.assertEqual(h.get('F22_GINS_VALID'),1)
        self.assertEqual(h.get('F22_GINS_SEQUENCE'),1)
        self.assertEqual(h.get('F22_GINS_NAV_HEADING_VALID'),0)

    def test_missing_observation_drops_its_axis_and_keeps_the_other_axis(self):
        h=producer()
        h.state.sensors['getHeading']=h.lua.eval('function()return nil end')
        h.execute('owner:update();consume()')
        self.assertEqual(h.get('F22_GINS_NAV_HEADING_VALID'),0)
        self.assertEqual(h.get('F22_GINS_NAV_ATTITUDE_VALID'),1)
        h.state.sensors['getHeading']=h.lua.eval('function()return 0 end')
        h.execute('owner:update();consume()')
        self.assertEqual(h.get('F22_GINS_NAV_HEADING_VALID'),1)
        self.assertEqual(h.get('F22_GINS_NAV_HEADING'),0)

    def test_reader_rejects_generation_switch_during_protected_payload(self):
        h=producer()
        h.execute("local changed=false;function mixed(k)local value=sample(k);"
            "if k=='F22_GINS_NAV_PITCH' and not changed then changed=true;"
            "publish('F22_GINS_GENERATION',4)end;return value end;"
            "mixed_reader=references.reader(mixed,'NAV');mixed_reader:update()")
        self.assertFalse(h.execute('return mixed_reader.valid'))

    def test_world_rewind_cannot_restore_old_generation_authority(self):
        h=producer();h.state.time=9.9;seed_physical(h,world=9.9)
        h.execute('owner:update()')
        self.assertEqual(h.get('F22_GINS_VALID'),0)
        h.state.time=10.1;seed_physical(h,world=10.1)
        h.execute('owner:update()')
        self.assertEqual(h.get('F22_GINS_VALID'),0)
        seed_physical(h,generation=4,world=10.1)
        h.execute('owner:update()')
        self.assertEqual(h.get('F22_GINS_VALID'),1)


if __name__=='__main__':
    unittest.main()
