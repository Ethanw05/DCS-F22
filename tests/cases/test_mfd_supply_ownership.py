"""R-NAV-002/011: actual writer order and qualified supply/presentation chain."""
import unittest
from navigation_ports import altitude_host, seed_physical


class MfdSupplyOwnership(unittest.TestCase):
    def test_avionics_cannot_erase_any_selected_engine_page(self):
        h,_=altitude_host()
        h.load('Systems/Avionics.lua')
        h.execute("routing=dofile(LockOn_Options.script_path..'Systems/Display_Routing.lua');controller=dofile(LockOn_Options.script_path..'Systems/MFD_Controller.lua').new(get_param_handle,function() end,function() end);controller:update(true)")
        for panel in range(1,5):
            h.execute(f'controller:select({panel},routing.pages.eng)')
        for order in ['controller:update(true);update()', 'update();controller:update(true)']:
            h.execute(order)
            for name in ['LMFD','RMFD','CMFD','PMFD']:
                self.assertEqual(h.get(name+'_ENG_PAGE'),1,name)

    def test_actual_supply_chain_preserves_selection_across_limited_apu(self):
        h,_=altitude_host()
        h.load('Systems/MFD_System.lua')
        h.update()
        self.assertEqual(h.get('LMFD_HSI_PAGE'),1)
        h.seed({'MAIN_POWER':0,'APU_RPM_STATE':2})
        h.update()
        self.assertEqual(h.get('LMFD_ENG_PAGE'),1)
        self.assertEqual(h.get('F22_LMFD_FORMAT'),7)
        self.assertEqual(h.get('F22_LMFD_PRESENTED_FORMAT'),8)
        for name in ['RMFD','CMFD','PMFD']:
            self.assertEqual(h.get(name+'_BLANK_PAGE'),1)
        h.seed({'MAIN_POWER':1});h.update()
        self.assertEqual(h.get('LMFD_HSI_PAGE'),1)
        self.assertEqual(h.get('LMFD_ENG_PAGE'),0)
        self.assertEqual(h.get('F22_MFD_LIMITED_SUPPLY'),0)

    def test_stale_or_malformed_supply_withdraws_presentation(self):
        h,_=altitude_host();h.load('Systems/MFD_System.lua')
        for key,value in [('EFM_PHYSICAL_VALID',0),('F22_AP_CLOCK',3),('MAIN_POWER','1')]:
            seed_physical(h);h.seed({key:value});h.update()
            for name in ['LMFD','RMFD','CMFD','PMFD']:
                self.assertEqual(h.get('F22_'+name+'_PRESENTED_FORMAT'),-1,(key,name))
        seed_physical(h);h.update()
        self.assertEqual(h.get('F22_LMFD_PRESENTED_FORMAT'),7)

    def test_limited_supply_accepts_no_forwarded_bezel_request(self):
        h,_=altitude_host()
        h.execute("controller=dofile(LockOn_Options.script_path..'Systems/MFD_Controller.lua').new(get_param_handle,function(d,c,v) dispatch_action(nil,c,v) end,function() end);controller:update(false,true);controller:button(1,1,true)")
        self.assertEqual(len(h.state.actions),0)


if __name__=='__main__':
    unittest.main()
