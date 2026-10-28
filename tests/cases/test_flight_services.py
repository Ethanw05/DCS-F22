"""R-FLT-004/014: request, achieved readiness, transfer and contact are distinct."""
import math
import unittest
from host import Host


class FlightServices(unittest.TestCase):
    def adapter(self):
        h = Host()
        h.execute("service=dofile(LockOn_Options.script_path..'Systems/Vehicle_Service_Adapter.lua').new()")
        return h

    def sample(self, h, position=1, ready=1, transfer=0):
        h.seed({'EFM_POWER_OWNER': 1, 'EFM_PHYSICAL_VALID': 1,
                'EFM_PHYSICAL_GENERATION': 3, 'EFM_PHYSICAL_STAMP': 2,
                'EFM_PHYSICAL_CLOCK_KIND': 1, 'F22_AP_CLOCK': 2,
                'EFM_REFUEL_DOOR_POSITION': position,
                'EFM_REFUEL_READY': ready, 'EFM_REFUEL_TRANSFER': transfer})

    def test_request_does_not_create_achieved_readiness(self):
        h = self.adapter()
        h.execute('assert(service:select(1));service:update()')
        self.assertEqual(h.get('F22_REFUEL_DOOR_REQUEST'), 1)
        self.assertEqual(h.get('F22_REFUEL_DISCONNECT_REQUEST'), 0)
        self.assertEqual(h.env.service.ready, 0)
        self.sample(h, .5, 0)
        h.execute('service:update()')
        self.assertEqual(h.env.service.ready, 0)
        self.sample(h)
        h.execute('service:update()')
        self.assertEqual(h.env.service.ready, 1)

    def test_transfer_never_authenticates_tanker_contact_and_close_cancels(self):
        h = self.adapter()
        h.execute('service:select(1)')
        self.sample(h, transfer=1)
        h.execute('service:update()')
        self.assertTrue(h.env.service.transfer)
        self.assertEqual(h.get('F22_REFUEL_CONTACT_VALID'), 0)
        h.execute('service:select(0);service:update()')
        self.assertEqual(h.env.service.ready, 0)
        self.assertEqual(h.get('F22_REFUEL_DISCONNECT_REQUEST'), 1)

    def test_invalid_stale_and_restoration_preserve_selection(self):
        for bad in [math.nan, -1, 1.1, 'open']:
            h = self.adapter()
            h.execute('service:select(1)')
            self.sample(h, bad)
            h.execute('service:update()')
            self.assertFalse(h.env.service.valid)
            self.assertEqual(h.get('F22_REFUEL_READY_VALID'), 0)
            self.sample(h)
            h.execute('service:update()')
            self.assertEqual(h.env.service.ready, 1)
            h.seed({'F22_AP_CLOCK': 3})
            h.execute('service:update()')
            self.assertFalse(h.env.service.valid)
            self.assertEqual(h.env.service.selected, 1)

    def test_matching_momentary_release_and_switch_takeover(self):
        h = self.adapter()
        h.execute('assert(not service:momentary(0));assert(service:momentary(1));assert(not service:momentary(1))')
        self.assertEqual(h.env.service.selected, 1)
        h.execute('service:momentary(0)')
        self.assertEqual(h.env.service.selected, 0)
        h.execute('service:momentary(1);service:select(1);service:momentary(0)')
        self.assertEqual(h.env.service.selected, 1)

    def test_generation_change_retires_prior_door_consent(self):
        h = self.adapter()
        self.sample(h)
        h.execute('service:momentary(1);service:update()')
        h.seed({'EFM_PHYSICAL_GENERATION': 4})
        h.execute('service:update()')
        self.assertEqual(h.env.service.selected, 0)
        self.assertEqual(h.get('F22_REFUEL_DISCONNECT_REQUEST'), 1)
        self.assertFalse(h.env.service.valid)

    def test_actual_electrical_device_routes_saved_edges_to_physical_requests(self):
        h = Host()
        h.execute('function get_cockpit_draw_argument_value(_) return 0 end')
        h.load('Systems/Electrical_System.lua')
        h.env.post_initialize()
        h.env.SetCommand(10015, 1)
        self.assertEqual(h.get('F22_REFUEL_DOOR_REQUEST'), 1)
        count = len(h.state.actions)
        h.env.SetCommand(10015, 1)
        self.assertEqual(len(h.state.actions), count)
        h.env.SetCommand(10015, 0)
        self.assertEqual(h.get('F22_REFUEL_DISCONNECT_REQUEST'), 1)
        h.env.SetCommand(10016, 1)
        self.sample(h)
        h.update()
        self.assertEqual(h.get('AAR_READY'), 1)
        self.assertEqual(h.get('F22_REFUEL_CONTACT_VALID'), 0)
        h.seed({'EFM_PHYSICAL_VALID': 0})
        h.update()
        self.assertEqual(h.get('AAR_READY'), 0)
        self.sample(h)
        h.seed({'EFM_PHYSICAL_GENERATION': 4})
        h.update()
        self.assertEqual(h.get('AAR'), 0)
        self.assertEqual(h.get('F22_REFUEL_DOOR_REQUEST'), 0)

    def test_clickable_decoding_and_invalid_values_cannot_rewrite_request(self):
        h = Host()
        h.load('Systems/Electrical_System.lua')
        h.env.post_initialize()
        command = h.env.device_commands.Button_1
        device = h.env.devices.ELECTRICAL_SYSTEM
        h.env.SetCommand(command, device + .375)
        self.assertEqual(h.get('F22_REFUEL_DOOR_REQUEST'), 1)
        for bad in [None, '0', math.nan, math.inf, -.1, 1.1]:
            h.env.SetCommand(command, bad)
            self.assertEqual(h.get('F22_REFUEL_DOOR_REQUEST'), 1)
        h.env.SetCommand(command, device + .25)
        self.assertEqual(h.get('F22_REFUEL_DOOR_REQUEST'), 0)
