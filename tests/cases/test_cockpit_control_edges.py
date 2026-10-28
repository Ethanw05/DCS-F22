"""R-NAV-014: declared saved aliases and actual clickable/owner press cycles."""
import re
import unittest
from host import ROOT
from navigation_ports import altitude_host


class CockpitControlEdges(unittest.TestCase):
    def avionics(self):
        h,_=altitude_host();h.load('Systems/Avionics.lua');h.update()
        return h

    def test_maintained_day_night_and_down_only_toggle_are_distinct(self):
        h=self.avionics()
        for value,expected in [(1,1),(1,1),(0,0),(0,0)]:
            h.env.SetCommand(10017,value);h.update()
            self.assertEqual(h.get('DAY_NIGHT'),expected)
        for value,expected in [(1,1),(0,1),(1,0),(0,0)]:
            h.env.SetCommand(10018,value);h.update()
            self.assertEqual(h.get('DAY_NIGHT'),expected)
        for value in [None,'1',float('nan'),float('inf'),-.1,1.1]:
            h.env.SetCommand(10017,value);h.update()
            self.assertEqual(h.get('DAY_NIGHT'),0)

    def test_decoded_maintained_position_and_power_restore_do_not_toggle(self):
        h=self.avionics();device=h.env.devices.AVIONICS
        h.env.SetCommand(10017,device+.375);h.update()
        self.assertEqual(h.get('DAY_NIGHT'),1)
        h.seed({'MAIN_POWER':0});h.update()
        h.seed({'MAIN_POWER':1});h.update()
        self.assertEqual(h.get('DAY_NIGHT'),1)
        h.env.SetCommand(10017,device+.25);h.update()
        self.assertEqual(h.get('DAY_NIGHT'),0)

    def test_real_smfd_constructor_supplies_release_for_two_press_cycles(self):
        h=self.avionics()
        h.lua.execute("package.preload['i_18n']=function() return {translate=function(s) return s end} end")
        source=(ROOT/'Cockpit/Scripts/clickabledata.lua').read_text(encoding='utf-8-sig')
        kinds=sorted(set(re.findall(r'class_type\.([A-Za-z_]+)',source)))
        h.env.class_type=h.lua.table_from({name:index+1 for index,name in enumerate(kinds)})
        h.load('clickabledata.lua')
        for name in ['L_SMFD_1_PNT','R_SMFD_1_PNT']:
            element=h.env.elements[name]
            self.assertTrue(element.use_release_message[1])
            initial=h.get('R_ADI_OPACITY')
            h.env.SetCommand(element.action[1],1);h.update()
            changed=h.get('R_ADI_OPACITY');self.assertNotEqual(initial,changed)
            h.env.SetCommand(element.action[1],1);h.update()
            self.assertEqual(h.get('R_ADI_OPACITY'),changed)
            h.env.SetCommand(element.stop_action[1],0)
            h.env.SetCommand(element.action[1],1);h.update()
            self.assertEqual(h.get('R_ADI_OPACITY'),initial)
            h.env.SetCommand(element.stop_action[1],0)


if __name__=='__main__':
    unittest.main()
