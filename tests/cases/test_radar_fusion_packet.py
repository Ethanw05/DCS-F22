"""I-DEEP-005: checked own-radar packet through actual reviewed fusion owners."""
import unittest
from test_radar_tactical_packet import setup


def chain():
    h = setup()
    h.execute("function sample(k) return get_param_handle(k):get() end;"
        "function put(k,v) get_param_handle(k):set(v) end;"
        "picture=dofile(LockOn_Options.script_path..'Systems/Tactical_Picture.lua').new(sample,put,get_base_data());"
        "get_param_handle('F22_RADAR_RANGE_NM'):set(40);"
        "picture:update(10,{},true)")
    return h


class RadarFusionPacket(unittest.TestCase):
    def test_original_identity_clock_survives_geometry_copy(self):
        h=chain()
        self.assertEqual(h.execute('return picture.store.batches.radar.contacts[84].time'),9.5)
        self.assertEqual(h.execute('return picture.store.batches.radar.contacts[84].identity_time'),7)
        h.execute('computer.clock=10.1;publish(1);picture:update(10.1,{},true)')
        self.assertEqual(h.execute('return picture.store.batches.radar.contacts[84].identity_time'),7)
        self.assertEqual(h.get('F22_TACTICAL_01_WEAPON_AUTHORITY'),0)

    def test_unknown_identity_time_preserves_friendly_protection(self):
        h=chain()
        h.execute('computer.clock=10.1;computer.tracks[1].ident_time=nil;publish(1);picture:update(10.1,{},true)')
        self.assertFalse(h.execute('return picture.store.contacts[1].identity_evidence.radar.time_known'))
        self.assertTrue(h.execute('return picture.store.contacts[1].friendly_protected'))
        self.assertEqual(h.get('F22_TACTICAL_01_FRIENDLY_PROTECTED'),1)

    def test_no_reply_remains_unknown(self):
        h=chain()
        h.execute('computer.clock=10.1;computer.tracks[1].iff=-1;computer.tracks[1].ident_time=nil;'
                  'publish(2);picture:update(10.1,{},true)')
        self.assertFalse(h.execute('return picture.store.contacts[1].friendly_protected') or False)
        self.assertFalse(h.execute('return picture.store.contacts[1].hostile_evidence') or False)
        self.assertEqual(h.get('F22_TACTICAL_01_AFFILIATION'),-1)

    def test_new_source_epoch_can_have_an_earlier_fresh_clock(self):
        h=chain()
        h.execute('computer.clock=9.95;computer.tracks[1].observed=9.9;'
            'computer.tracks[1].north=4000;publish(2);picture:update(10.1,{},true)')
        self.assertEqual(h.execute('return picture.store.batches.radar.epoch'),2)
        self.assertEqual(h.execute('return picture.store.batches.radar.time'),9.95)
        self.assertEqual(h.execute('return picture.store.batches.radar.contacts[84].n'),4000)
        self.assertEqual(h.execute('return picture.store.batches.radar.contacts[84].epoch'),2)

    def test_bad_packet_does_not_refresh_accepted_evidence(self):
        h=chain()
        h.seed({'F22_RADAR_TACTICAL_SEQUENCE':3,'F22_RADAR_TACTICAL_01_N':9000})
        h.execute('picture:update(10.2,{},true)')
        self.assertEqual(h.execute('return picture.store.batches.radar.time'),10)
        self.assertEqual(h.execute('return picture.store.batches.radar.contacts[84].n'),1000)
        self.assertEqual(h.execute('return picture.store.batches.radar.contacts[84].time'),9.5)

    def test_epoch_retirement_preserves_independent_rf_and_restarts_radar_history(self):
        h=chain()
        h.execute("local store=picture.store;store:update(10,{rf={sequence=1,time=10,contacts={"
            "{source=91,age=0,az=1,el=0,signal=2}}}},true);"
            "old_rf=store.batches.rf.contacts[91];"
            "computer.clock=9.95;computer.tracks[1].observed=9.9;computer.tracks[1].north=4000;publish(2);")
        h.execute("local packet=picture.radar:read(10.1);local v=packet.contacts[1];"
            "picture.store:update(10.1,{radar={sequence=packet.sequence,time=packet.time,epoch=packet.epoch,"
            "contacts={{source=v.SOURCE,age=v.AGE,az=v.AZ,el=v.EL,range=v.RANGE,"
            "n=v.N,u=v.U,e=v.E,vn=v.VN,vu=v.VU,ve=v.VE,epoch=packet.epoch,"
            "position_sigma_m=v.POSITION_SIGMA_M}}}},true)")
        self.assertTrue(h.execute('return picture.store.batches.rf.contacts[91]==old_rf'))
        self.assertEqual(h.execute('return picture.store.batches.rf.contacts[91].time'),10)
        self.assertEqual(h.execute('return picture.store.association.history.epoch'),2)
        self.assertEqual(h.execute('return picture.store.association.history.tracks[84].count'),1)
        self.assertEqual(h.execute('return picture.store.association.history.tracks[84].time'),9.9)


if __name__=='__main__':
    unittest.main()
