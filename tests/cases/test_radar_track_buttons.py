"""Pilot-requested TRACK pair: actual selection, routing and native declarations."""
import unittest

from host import Host
from test_radar_pilot_presentation import page_host, visible, array
from test_radar_source_contract import system_host, current_frame


def controller_host():
    h = Host()
    h.seed({'HUD_MODE': 2})
    h.execute("""
        computer=dofile(LockOn_Options.script_path..'Systems/Radar_Computer.lua').new()
        computer.clock=10
        computer.tracks={
            [7]={hits=1,observed=10,range=20000,az=.1},
            [12]={hits=2,observed=10,range=21000,az=.11},
            [22]={hits=1,observed=-30,range=10000,az=0}}
        local commands=dofile(LockOn_Options.script_path..'Systems/Radar_Commands.lua')
        local reverse={};for name,id in pairs(commands)do reverse[id]=name end
        routing=dofile(LockOn_Options.script_path..'Systems/Display_Routing.lua')
        controller=dofile(LockOn_Options.script_path..'Systems/MFD_Controller.lua').new(
            get_param_handle,function(device,command,value)
                if device=='RADAR_COMPUTER' and value==1 then
                    computer:command(reverse[command])
                end
            end,function()end)
        controller:update(true);controller:select(4,routing.pages.tsd)
    """)
    return h


class RadarTrackButtons(unittest.TestCase):
    def test_physical_keys_step_both_directions_wrap_and_ignore_held_repeat(self):
        h = controller_host()
        for button, expected in ((4, 12), (4, 7), (4, 12), (5, 7), (5, 12)):
            h.execute(f'controller:button(4,{button},true)')
            self.assertEqual(h.env.computer.selected, expected)
            h.execute(f'controller:button(4,{button},true)')
            self.assertEqual(h.env.computer.selected, expected)
            self.assertTrue(h.env.computer.cursor_follow)
            self.assertFalse(h.env.computer.locked)
            h.execute(f'controller:button(4,{button},false)')

    def test_empty_single_and_lost_selection_recover_without_stale_target(self):
        h = controller_host()
        h.execute("computer.tracks={};computer:command('previous_track')")
        self.assertIsNone(h.env.computer.selected)
        self.assertFalse(h.env.computer.cursor_follow)
        h.execute("computer.tracks={[9]={hits=1,observed=10,range=18000,az=.2}}")
        for command in ('previous_track', 'next_track', 'previous_track'):
            h.env.computer.command(h.env.computer, command)
            self.assertEqual(h.env.computer.selected, 9)
            self.assertEqual(h.env.computer.cursor_range, 18000)
        h.execute("computer.selected=99;computer:command('previous_track')")
        self.assertEqual(h.env.computer.selected, 9)

    def test_default_top_row_is_swap_and_shared_track_only(self):
        h = controller_host()
        self.assertEqual(h.get('F22_MFD_PMFD_KEY_3'), 'SWAP')
        for button in (1, 2, 4, 5):
            self.assertEqual(h.get(f'F22_MFD_PMFD_KEY_{button}'), '')
        self.assertEqual(h.get('F22_MFD_PMFD_TRACK_PAIR'), 1)

    def test_track_pair_withdraws_on_page_subpage_ground_and_power_changes(self):
        h = controller_host()
        for panel, name in enumerate(('LMFD', 'RMFD', 'CMFD', 'PMFD'), 1):
            h.execute(f'controller:select({panel},routing.pages.tsd)')
            self.assertEqual(h.get(f'F22_MFD_{name}_TRACK_PAIR'), 1)
            for view in (1, 6):
                h.execute(f'controller.panels[{panel}].view={view};controller:publish()')
                self.assertEqual(h.get(f'F22_MFD_{name}_TRACK_PAIR'), 0)
            h.execute(f'controller:select({panel},routing.pages.nav)')
            self.assertEqual(h.get(f'F22_MFD_{name}_TRACK_PAIR'), 0)
        h.execute('controller:select(4,routing.pages.tsd)')
        h.seed({'HUD_MODE': 7});h.execute('controller:publish()')
        self.assertEqual(h.get('F22_MFD_PMFD_TRACK_PAIR'), 0)
        h.seed({'HUD_MODE': 2});h.execute('controller:update(false)')
        self.assertEqual(h.get('F22_MFD_PMFD_TRACK_PAIR'), 0)

    def test_previous_numeric_command_reaches_actual_radar_device(self):
        h = system_host();current_frame(h, 10);h.update()
        h.env.SetCommand(10653, 1);h.update()
        self.assertEqual(h.get('F22_RADAR_SELECTED_VALID'), 1)

    def test_native_caption_and_arrow_span_actual_keys_on_every_display(self):
        for panel in ('LMFD', 'RMFD', 'CMFD', 'PMFD'):
            h, _ = page_host()
            h.load('MFD_COMMON/bezel.lua')(panel)
            records = {r.name: r for _, r in h.state.elements.items() if r.added and r.name}
            prefix = f'F22_BEZEL_{panel}_'
            caption, arrow = records[prefix+'TRACK_CAPTION'], records[prefix+'TRACK_ARROW']
            self.assertEqual(caption.value, 'TRACK')
            vertices = array(arrow.vertices)
            self.assertLess(vertices[0][1], vertices[1][1])
            self.assertAlmostEqual(caption.init_pos[1], (vertices[0][1]+vertices[1][1])/2)
            h.seed({'MFD_OPACITY': 1, f'F22_MFD_{panel}_TRACK_PAIR': 1})
            self.assertTrue(visible(h, records, prefix+'TRACK_CAPTION'))
            h.seed({f'F22_MFD_{panel}_TRACK_PAIR': 0})
            self.assertFalse(visible(h, records, prefix+'TRACK_ARROW'))
