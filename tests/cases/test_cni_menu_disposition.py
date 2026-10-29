"""R-NAV-005 optional voice decision and actual ICP menu/feedback lifecycle."""
import unittest
from host import Host


def cockpit():
    h=Host();h.seed({'MAIN_POWER':1})
    h.load('Systems/ICP_System.lua');h.env.post_initialize()
    return h


def actions(h):
    return [(row['command'],row['value']) for _,row in h.state.actions.items()]


class CniMenuDisposition(unittest.TestCase):
    def test_clear_voice_backend_is_explicitly_unselected(self):
        h=cockpit();profile=h.load('Systems/Equipment_Profile.lua')
        self.assertFalse(profile.supports('clear_voice_backend'))
        self.assertEqual(profile.id,'public_f22_manual_recovery')
        self.assertTrue(profile.supports('manual_recovery'))
        self.assertTrue(profile.supports('tacan'));self.assertTrue(profile.supports('ils'))

    def test_com1_exposes_only_host_menu_and_one_dispatch_per_mouse_press(self):
        h=cockpit();h.env.SetCommand(3001,1);h.env.SetCommand(3001,0)
        self.assertEqual(h.get('F22_UFC_PAGE'),'COM1')
        self.assertEqual(h.get('F22_UFC_ROW_1'),'COMMS MENU')
        self.assertEqual(actions(h),[])
        h.env.SetCommand(3008,1);h.env.SetCommand(3008,1)
        self.assertEqual(actions(h),[(179,1)])
        h.env.SetCommand(3008,0);h.env.SetCommand(3008,1)
        self.assertEqual(actions(h),[(179,1),(179,1)])
        self.assertNotIn('TRANSMIT',h.get('F22_UFC_SCRATCH'))

    def test_saved_keyboard_aliases_remain_down_only_impulses(self):
        h=cockpit();h.env.SetCommand(10041,1)
        for _ in range(2):h.env.SetCommand(10048,1)
        self.assertEqual(actions(h),[(179,1),(179,1)])
        h.env.SetCommand(10041,1)
        self.assertEqual(h.get('F22_UFC_PAGE'),'')

    def test_com2_is_unavailable_without_tuning_or_transmit_requests(self):
        h=cockpit();h.env.SetCommand(10042,1)
        self.assertEqual(h.get('F22_UFC_SCRATCH'),'RADIO 2 UNAVAILABLE')
        for command in range(10048,10053):h.env.SetCommand(command,1)
        self.assertEqual(actions(h),[])
        self.assertEqual(h.get('F22_UFC_SELECTED'),0)

    def test_encoded_cockpit_press_release_preserves_mouse_ownership(self):
        h=cockpit();device=h.env.devices.ICP_SYSTEM
        h.env.SetCommand(3001,device+.375);h.env.SetCommand(3001,device+.25)
        h.env.SetCommand(3008,device+.375);h.env.SetCommand(3008,device+.375)
        h.env.SetCommand(3008,device+.25)
        self.assertEqual(h.get('F22_UFC_PAGE'),'COM1')
        self.assertEqual(actions(h),[(179,1)])

    def test_power_loss_restart_and_page_change_do_not_replay_menu(self):
        h=cockpit();h.env.SetCommand(3001,1);h.env.SetCommand(3001,0)
        h.seed({'MAIN_POWER':0});h.update();h.env.SetCommand(3008,1)
        h.seed({'MAIN_POWER':1});h.update()
        self.assertEqual(h.get('F22_UFC_PAGE'),'');self.assertEqual(actions(h),[])
        h.env.SetCommand(3008,0);h.env.SetCommand(10041,1)
        h.env.SetCommand(10042,1);h.env.SetCommand(10048,1)
        self.assertEqual(actions(h),[])
        h.env.post_initialize();h.update()
        self.assertEqual(h.get('F22_UFC_PAGE'),'');self.assertEqual(actions(h),[])

    def test_malformed_events_do_not_open_menu_or_fill_command_latches(self):
        for command,value in [(10041,float('nan')),(10041,float('inf')),(10041,'1'),
                              (float('nan'),1),(None,1),(10041.5,1),(900000,1)]:
            h=cockpit();h.env.SetCommand(command,value);h.update()
            self.assertEqual(h.get('F22_UFC_PAGE'),'');self.assertEqual(actions(h),[])


if __name__=='__main__':unittest.main()
