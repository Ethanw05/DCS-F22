"""Received-message motion estimates preserve clocks and PPLI membership."""
import unittest
from host import Host


class DatalinkMotion(unittest.TestCase):
    def setUp(self):
        self.h = Host()
        self.module = self.h.load('Systems/Datalink_Tracks.lua')

    def report(self, **values):
        row = dict(time=100, received=102, observation_known=False,
                   n=10000, u=3000, e=0, vn=200, vu=0, ve=50, ppli=False)
        row.update(values)
        return self.h.lua.table_from(row)

    def test_unknown_clock_moves_from_receipt_without_becoming_observed(self):
        row = self.report()
        point = self.module.position(row, 104)
        self.assertEqual((point.n, point.u, point.e), (10400, 3000, 100))
        self.assertEqual((point.age, point.receive_age, point.motion_age), (4, 2, 2))
        self.assertTrue(point.estimated)
        self.assertFalse(point.coast)
        self.assertFalse(point.observation_known)
        self.assertEqual((row.time, row.received), (100, 102))

    def test_prediction_stops_and_original_lifetime_still_expires(self):
        row = self.report()
        point = self.module.position(row, 120)
        self.assertEqual((point.n, point.e, point.state), (12600, 650, 3))
        self.assertEqual(point.receive_age, 18)
        self.assertTrue(point.coast)
        self.assertIsNone(self.module.position(row, 126.1))
        self.assertIsNone(self.module.position(self.report(ppli=True), 126.1))

    def test_known_clock_and_bad_input(self):
        known = self.report(observation_known=True)
        self.assertEqual(self.module.position(known, 104).n, 10800)
        self.assertIsNone(self.module.position(self.report(received=105), 104))
        self.assertIsNone(self.module.position(self.report(vn=float('nan')), 104))

    def test_observed_twelve_second_updates_do_not_coast_or_renew_old_clock(self):
        row = self.report(time=104.741, received=104.741)
        for now in (104.741, 110, 116.761):
            self.assertFalse(self.module.position(row, now).coast)
        self.assertTrue(self.module.position(row, 118).coast)
        self.assertEqual(row.received, 104.741)
        self.assertIsNone(self.module.position(row, 130.742))
        replacement = self.report(time=131, received=131)
        self.assertFalse(self.module.position(replacement, 131).coast)

    def test_ingress_preserves_ppli_and_epoch_independently(self):
        self.h.execute('''
            local D = dofile(LockOn_Options.script_path .. 'Systems/Datalink_Tracks.lua')
            local sensors = { getSelfCoordinates=function() return 0,3000,0 end,
                getHeading=function() return 0 end, getPitch=function() return 0 end,
                getRoll=function() return 0 end }
            function read(k) return get_param_handle(k):get() end
            function write(k,v) get_param_handle(k):set(v) end
            reader = D.new(read, sensors)
            write('F22_DL_RX_SCHEMA',2); write('F22_DL_RX_OWN',100)
            write('F22_DL_RX_EPOCH',7); write('F22_DL_RX_SEQUENCE',2)
            write('F22_DL_RX_TIME',100); write('F22_DL_RX_COUNT',2)
            for i=1,2 do
                local fields={SOURCE=200,REPORTER=200,LINK=1,TIME=100,
                    OBSERVATION_KNOWN=0,OBSERVATION_TIME=0,RECEIVE_TIME=100,
                    N=10000,U=3000,E=0,VN=100,VU=0,VE=0,AFFILIATION=1,
                    PPLI=i==1 and 1 or 0,FLIGHT=i==1 and 1 or 0}
                for k,v in pairs(fields) do write(string.format('F22_DL_RX_%02d_',i)..k,v) end
            end
            batch = reader:update(100,true)
            assert(batch.epoch==7 and #batch.contacts==2)
            local members=0
            for _,o in ipairs(batch.contacts) do
                if o.ppli then assert(o.flight); members=members+1 end
                assert(o.epoch==7 and not o.observation_known and o.received==100)
                assert(o.estimated_position and o.receive_age==0)
            end
            assert(members==1)
            write('F22_DL_RX_EPOCH',8); write('F22_DL_RX_SEQUENCE',0)
            batch=reader:update(100.1,true)
            assert(batch.epoch==8 and #batch.contacts==0)
        ''')


if __name__ == '__main__':
    unittest.main()
