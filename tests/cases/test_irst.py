"""Podded IRST: actual Lua owners, packet freshness, displays and cue authority."""
import unittest
from host import Host, ROOT


class IRST(unittest.TestCase):
    def owner(self):
        h = Host()
        h.state.time = 100
        h.execute("""pod_count=2
            GetDevice=function(id)
                assert(id==15)
                return {get_station_info=function(_,station)
                    assert(station==5)
                    return {count=pod_count,CLSID='{F22_IRST}',weapon={}}
                end}
            end""")
        h.load('Systems/IRST_System.lua')
        h.env.post_initialize()
        h.seed({'EFM_POWER_OWNER': 1, 'EFM_PHYSICAL_VALID': 1,
                'EFM_PHYSICAL_GENERATION': 7, 'EFM_PHYSICAL_STAMP': 10,
                'EFM_PHYSICAL_CLOCK_KIND': 1, 'F22_AP_CLOCK': 10,
                'MAIN_POWER': 1, 'F22_ELECTRICAL_VALID': 1,
                'EFM_MISSION_POWER_AVAILABLE': 1,
                'EFM_PHYSICAL_WORLD_STAMP': 100, 'EFM_PHYSICAL_WORLD_CLOCK_KIND': 2,
                'F22_IRST_NATIVE_SEQ': 2, 'F22_IRST_NATIVE_TIME': 100,
                'F22_IRST_NATIVE_EPOCH': 1, 'F22_IRST_NATIVE_READY': 1,
                'F22_IRST_NATIVE_AVAILABLE': 1, 'F22_IRST_NATIVE_01_VALID': 1,
                'F22_IRST_NATIVE_01_ID': 12, 'F22_IRST_NATIVE_01_TIME': 100,
                'F22_IRST_NATIVE_01_AZ': .05, 'F22_IRST_NATIVE_01_EL': .03})
        return h

    def press(self, h, command):
        h.env.SetCommand(command, 1)
        h.env.SetCommand(command, 0)

    def test_real_owner_select_track_hud_and_control_packet(self):
        h = self.owner()
        h.update()
        self.assertEqual(h.get('F22_IRST_STATUS'), 6)
        self.assertEqual(h.get('F22_IRST_COUNT'), 1)
        self.assertEqual(h.get('F22_IRST_CONTROL_POWER'), 1)
        self.press(h, 11307)
        self.press(h, 11308)
        h.update()
        self.assertEqual(h.get('F22_IRST_HUD_VALID'), 1)
        self.assertEqual(h.get('F22_IRST_SELECTED'), 12)
        self.assertEqual(h.get('F22_IRST_CONTROL_SELECTED'), 12)
        self.press(h, 11310)
        self.assertEqual(h.state.actions[1].command, 11311)
        # Holding a toggle cannot repeat it.
        h.env.SetCommand(11300, 30.375)
        h.env.SetCommand(11300, 30.375)
        h.update()
        self.assertEqual(h.get('F22_IRST_READY'), 0)
        self.assertEqual(h.get('F22_IRST_COUNT'), 0)

    def test_pod_power_and_frozen_physical_source_withdraw(self):
        for failure in ['pod', 'power', 'physical']:
            h = self.owner()
            h.update()
            if failure == 'pod':
                h.env.pod_count = 0
                h.state.time = 100.21
                h.seed({'EFM_PHYSICAL_WORLD_STAMP': 100.21})
            elif failure == 'power':
                h.seed({'EFM_MISSION_POWER_AVAILABLE': 0})
            else:
                h.state.time = 100.26
            h.update()
            self.assertEqual(h.get('F22_IRST_CONTROL_POWER'), 0, failure)
            self.assertEqual(h.get('F22_IRST_READY'), 0, failure)
            self.assertEqual(h.get('F22_IRST_COUNT'), 0, failure)

    def test_reader_rejects_partial_future_and_stale_packets(self):
        h = self.owner()
        for field, value in [('SEQ', 3), ('TIME', 99), ('TIME', 101)]:
            h.seed({'F22_IRST_NATIVE_SEQ': 2, 'F22_IRST_NATIVE_TIME': 100})
            h.seed({'F22_IRST_NATIVE_' + field: value})
            h.update()
            self.assertEqual(h.get('F22_IRST_READY'), 0)
        # A marker change during row capture cannot produce any contact.
        h.seed({'F22_IRST_NATIVE_SEQ': 2, 'F22_IRST_NATIVE_TIME': 100})
        h.execute("""reader=dofile(LockOn_Options.script_path..'Systems/IRST_Snapshot.lua').new(
            function(n)
                local v=get_param_handle(n):get()
                if tear and n=='F22_IRST_NATIVE_01_AZ' then get_param_handle('F22_IRST_NATIVE_SEQ'):set(4)end
                return v
            end)
            tear=true;packet=reader:read(100)""")
        self.assertFalse(h.env.packet.ready)
        self.assertEqual(len(h.env.packet.contacts), 0)

    def test_radar_cue_requires_live_bearing_and_preserves_radar_authority(self):
        h = self.owner()
        h.update()
        self.press(h, 11307)
        h.update()
        h.execute("""cue=dofile(LockOn_Options.script_path..'Systems/IRST_Radar_Cue.lua').new(
            function(n)return get_param_handle(n):get()end,
            function(n,v)get_param_handle(n):set(v)end)
            assert(not cue:request(100,false,false))
            assert(not cue:request(100,true,true))
            assert(cue:request(100,true,false))
            scan=cue:apply(100,{az=0,el=0,half_az=1,half_el=1},true)
            assert(math.abs(scan.az-.05)<1e-9 and math.abs(scan.el-.03)<1e-9)
            assert(scan.range==nil and scan.target==nil)
            assert(cue:apply(101,nil,false)==nil)""")

    def test_fusion_keeps_irst_unknown_bearing_only_and_epoch_scoped(self):
        h = Host()
        h.execute("""store=dofile(LockOn_Options.script_path..'Systems/Tactical_Tracks.lua').new()
            store:update(100,{irst={time=100,sequence=2,epoch=1,contacts={
                {source=12,age=0,az=.1,el=.05,range=50000,label='U',epoch=1}}}},true)
            assert(#store.contacts==1)
            local t=store.contacts[1]
            assert(t.mask==16 and t.range==nil and t.affiliation==-1)
            assert(not t.hostile_evidence and not t.selected)
            old=t.source
            store:update(100.1,{irst={time=100.1,sequence=4,epoch=2,contacts={
                {source=12,age=0,az=.1,el=.05,label='U',epoch=2}}}},true)
            assert(store.contacts[1].source~=old)""")

    def test_page_control_and_registered_formats(self):
        h = Host()
        h.execute("""routing=dofile(LockOn_Options.script_path..'Systems/Display_Routing.lua')
            controls=dofile(LockOn_Options.script_path..'Systems/MFD_Controls.lua')
            assert(routing.pages.irst==14 and #routing.order==10)
            for _,panel in ipairs(routing.panels)do assert(routing.flag(panel,14)==panel..'_IRST_PAGE')end
            local c=controls.for_page(14,0,function()return 0 end)
            assert(c[13].action=='menu' and c[6].command==11310 and c[4].device=='IRST_SYSTEM')""")
        # Execute the real declaration through write-only native element proxies.
        h.execute("""MakeMaterial=function()return 'material'end; SetScale=function()end
            GetAspect=function()return 1 end;GetScale=function()return 1 end
            FOV=1;h_clip_relations={COMPARE=1,REWRITE_LEVEL=2,INCREASE_IF_LEVEL=3}
            local real=dofile
            dofile=function(path)
                if path:match('MFD_COMMON/definitions.lua$')or path:match('/fonts.lua$')then return end
                return real(path)
            end
            dofile(LockOn_Options.script_path..'MFD_COMMON/irst_page.lua')('PMFD_IRST_PAGE')""")
        self.assertGreater(len(list(h.state.elements.items())), 150)


if __name__ == '__main__':
    unittest.main()
