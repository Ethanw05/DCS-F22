"""Actual fusion owners: independent evidence, all sensors and coherent warning input."""
import unittest
from host import Host
from test_radar_fusion_packet import chain


def store():
    h = Host()
    h.execute('''
        store=dofile(LockOn_Options.script_path..'Systems/Tactical_Tracks.lua').new()
        r={source=1,age=0,az=0,el=0,n=20000,u=0,e=0,vn=200,vu=0,ve=0,
            velocity_valid=true,position_sigma_m=5,velocity_sigma_mps=2,range=20000,label='U'}
        f={source=16777984,age=0,az=0,el=0,signal=1,general=1,label='22',
            friendly=true,identity_time=100,world={1,0,0},bearing_origin={n=0,u=0,e=0,time=100}}
        d={source=4,reporter=800,link=1,ppli=false,age=0,az=0,el=0,n=20020,u=0,e=0,
            vn=200,vu=0,ve=0,received=100,observation_known=false}
        i={source=8,age=0,az=0,el=0}
        m={source=9,age=0,az=0,el=0}
        function batch(rows,seq,epoch,stamp)
            return {sequence=seq or 1,epoch=epoch or 1,time=stamp or 100,contacts=rows}
        end
    ''')
    return h


class FusionLifecycle(unittest.TestCase):
    def test_without_wingman_radar_and_rwr_share_identity_and_range(self):
        h = store()
        h.execute('store:update(100,{radar=batch({r}),rf=batch({f})},true)')
        self.assertEqual(h.execute('return #store.contacts'), 1)
        self.assertEqual(h.execute('return store.contacts[1].mask'), 3)
        self.assertEqual(h.execute('return store.contacts[1].affiliation'), 1)
        self.assertEqual(h.execute('return store.contacts[1].label'), '22')
        self.assertEqual(h.execute('return store.contacts[1].range'), 20000)
        self.assertEqual(h.execute('return store.contacts[1].observations.radar.source'), 1)

    def test_all_sensors_combine_aircraft_but_keep_missile_independent(self):
        h = store()
        h.execute('''store:update(100,{radar=batch({r}),rf=batch({f}),datalink=batch({d}),
            irst=batch({i}),mws=batch({m})},true)
            for _,t in ipairs(store.contacts) do if t.observations.radar then air=t else missile=t end end''')
        self.assertEqual(h.execute('return #store.contacts'), 2)
        self.assertEqual(h.execute('return air.mask'), 27)
        self.assertEqual(h.execute('return missile.mask'), 4)
        self.assertEqual(h.execute('return air.direction_sensor'), 'radar')
        self.assertFalse(h.execute('return air.observations.datalink.observation_known'))

    def test_multi_donor_masks_and_identity_conflict_keep_provenance(self):
        h = store()
        h.execute('''d.friendly=true
            other={};for k,v in pairs(d) do other[k]=v end
            other.reporter=801;other.source=44;other.friendly=false;other.hostile=true
            store:update(100,{radar=batch({r}),datalink=batch({d,other})},true)''')
        self.assertEqual(h.execute('return #store.contacts'), 1)
        self.assertEqual(h.execute('return store.contacts[1].mask'), 9)
        self.assertTrue(h.execute('return store.contacts[1].identity_conflict'))
        self.assertEqual(h.execute('return store.contacts[1].affiliation'), 1)

    def test_power_reset_retires_every_source(self):
        h = store()
        h.execute('store:update(100,{radar=batch({r}),rf=batch({f})},true);epoch=store.epoch;'
                  'store:update(100.1,{},false)')
        self.assertEqual(h.execute('return #store.contacts'), 0)
        self.assertTrue(h.execute('return store.epoch>epoch'))
        h.execute('store:update(100.2,{},true)')
        self.assertEqual(h.execute('return #store.contacts'), 0)

    def test_actual_picture_commits_schema_and_radar_epoch(self):
        h = chain()
        self.assertEqual(h.get('F22_TACTICAL_SCHEMA'), 2)
        self.assertEqual(h.get('F22_TACTICAL_SEQUENCE') % 2, 0)
        self.assertEqual(h.get('F22_TACTICAL_01_RADAR_EPOCH'), 1)
        self.assertEqual(h.get('F22_TACTICAL_01_WEAPON_AUTHORITY'), 0)

    def test_torn_missile_batch_never_enters_picture(self):
        h = Host()
        h.seed({'F22_MWS_PUBLISH_SCHEMA':1,'F22_MWS_PUBLISH_SEQUENCE':2,
                'F22_MWS_EPOCH':1,'F22_MWS_PUBLISH_TIME':100,
                'F22_MWS_01_VALID':1,'F22_MWS_01_SOURCE':99,'F22_MWS_01_AGE':0})
        h.execute('''reader=dofile(LockOn_Options.script_path..'Systems/Tactical_MWS_Snapshot.lua')
            function get(k)
                if k=='F22_MWS_01_AZ' then get_param_handle('F22_MWS_PUBLISH_SEQUENCE'):set(3) end
                return get_param_handle(k):get()
            end
            packet=reader.read(get,100)''')
        self.assertIsNone(h.env.packet)


if __name__ == '__main__':
    unittest.main()
