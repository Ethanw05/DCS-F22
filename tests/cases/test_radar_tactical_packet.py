"""D-R-WPN-003: actual Lua writer/reader, complete old/new/unavailable only."""
import unittest
from host import Host


def setup():
    h=Host()
    h.execute("publisher=dofile(LockOn_Options.script_path..'Systems/Radar_Tactical.lua');"
        "computer=dofile(LockOn_Options.script_path..'Systems/Radar_Computer.lua').new();"
        "reader=dofile(LockOn_Options.script_path..'Systems/Radar_Tactical_Snapshot.lua').new("
        "function(k) return get_param_handle(k):get() end);computer.power=true;computer.clock=10;"
        "computer.tracks[1]={id=1,native_id=84,observed=9.5,north=1000,altitude=2000,east=3000,"
        "vn=10,vu=20,ve=30,measurement_source=2,hits=3,association_valid=true,velocity_valid=true,"
        "filter_valid=true,position_sigma_m=2,velocity_sigma_mps=3,range=5000,az=0,el=0,"
        "ident_time=7,iff=1};"
        "function publish(epoch) publisher.publish(computer,function(k,v) get_param_handle(k):set(v) end,true,nil,epoch) end;"
        "publish(1)")
    return h


class TacticalPacket(unittest.TestCase):
    def test_original_geometry_and_identity_clocks_remain_independent(self):
        h=setup()
        packet=h.execute('return reader:read(10.2)')
        self.assertEqual(packet.epoch,1)
        self.assertEqual(packet.contacts[1].SOURCE,84)
        self.assertEqual(packet.time-packet.contacts[1].AGE,9.5)
        self.assertEqual(packet.contacts[1].IDENTITY_TIME,7)
        self.assertEqual(packet.contacts[1].IDENTITY_KNOWN,1)
        h.execute('computer.clock=10.1;publish(1)')
        packet=h.execute('return reader:read(10.2)')
        self.assertEqual(packet.time-packet.contacts[1].AGE,9.5)
        self.assertEqual(packet.contacts[1].IDENTITY_TIME,7)

    def test_every_actual_writer_prefix_is_complete_or_unavailable(self):
        h=setup()
        h.execute("writes={};computer.clock=10.1;computer.tracks[1].native_id=88;"
            "computer.tracks[1].north=4000;computer.tracks[1].altitude=5000;computer.tracks[1].east=6000;"
            "computer.tracks[1].observed=10;computer.tracks[1].ident_time=nil;computer.tracks[1].iff=-1;"
            "publisher.publish(computer,function(k,v) writes[#writes+1]={k,v} end,true,nil,2)")
        # Use actual ordered puts, including sequence and all metadata writes.
        base={k:v for k,v in h.state['values'].items()}
        writes=h.env.writes
        h.env.old_values=h.lua.table_from(base)
        h.env.test_values=h.state['values']
        h.execute("function prefix_snapshot(count) "
            "for k,v in pairs(old_values) do test_values[k]=v end;"
            "for i=1,count do local pair=writes[i];test_values[pair[1]]=pair[2] end;"
            "return reader:read(10.2) end")
        for prefix in range(len(writes)+1):
            packet=h.env.prefix_snapshot(prefix)
            if prefix==0:
                self.assertEqual(packet.contacts[1].SOURCE,84)
            elif prefix==len(writes):
                self.assertEqual(packet.contacts[1].SOURCE,88)
                self.assertEqual(packet.contacts[1].N,4000)
                self.assertEqual(packet.contacts[1].IDENTITY_KNOWN,0)
            else:
                self.assertIsNone(packet,prefix)

    def test_reader_boundary_preemption_does_not_mix_epochs(self):
        for boundary in range(1,103):
            h=setup()
            h.execute("calls=0;local get=reader.get;reader.get=function(k) calls=calls+1;local v=get(k);"
                f"if calls=={boundary} then computer.clock=10.1;computer.tracks[1].native_id=88;"
                "computer.tracks[1].north=4000;computer.tracks[1].altitude=5000;computer.tracks[1].east=6000;publish(2) end;return v end")
            packet=h.execute('return reader:read(10.2)')
            if packet is not None:
                c=packet.contacts[1]
                self.assertIn((packet.epoch,c.SOURCE,c.N,c.U,c.E),
                              ((1,84,1000,2000,3000),(2,88,4000,5000,6000)))

    def test_rejected_read_cannot_mutate_last_accepted_packet(self):
        h=setup()
        old=h.execute('return reader:read(10.2)')
        h.seed({'F22_RADAR_TACTICAL_01_N':9000,'F22_RADAR_TACTICAL_01_U':float('nan')})
        self.assertIsNone(h.execute('return reader:read(10.2)'))
        self.assertEqual(old.contacts[1].N,1000)
        self.assertEqual(old.contacts[1].U,2000)

    def test_epoch_change_refreshes_cached_metadata_for_equal_id_and_time(self):
        h=setup()
        self.assertEqual(h.get('F22_RADAR_TACTICAL_01_POSITION_SIGMA_M'),2)
        h.execute('computer.tracks[1].position_sigma_m=9;publish(2)')
        self.assertEqual(h.get('F22_RADAR_TACTICAL_01_POSITION_SIGMA_M'),9)

    def test_invalid_fields_zero_and_recovery(self):
        good=setup()
        baseline={k:v for k,v in good.state['values'].items()}
        for field,bad in [('F22_RADAR_TACTICAL_SEQUENCE',3),('F22_RADAR_TACTICAL_SOURCE_EPOCH',0),
                          ('F22_RADAR_TACTICAL_TIME',9),('F22_RADAR_TACTICAL_01_N',float('inf')),
                          ('F22_RADAR_TACTICAL_01_SOURCE',0),('F22_RADAR_TACTICAL_01_AGE',-1),
                          ('F22_RADAR_TACTICAL_01_AGE',11),('F22_RADAR_TACTICAL_01_MEASUREMENT_SOURCE',3),
                          ('F22_RADAR_TACTICAL_01_IDENTITY_TIME',11),
                          ('F22_RADAR_TACTICAL_01_VALID','1')]:
            good.seed(baseline);good.seed({field:bad})
            self.assertIsNone(good.execute('return reader:read(10.2)'),field)
        good.seed(baseline);good.seed({'F22_RADAR_TACTICAL_01_N':0,'F22_RADAR_TACTICAL_01_VN':0})
        self.assertIsNotNone(good.execute('return reader:read(10.2)'))


if __name__=='__main__':
    unittest.main()
