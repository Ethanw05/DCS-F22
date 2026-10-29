"""One associated object has one map symbol, with independent sensor freshness."""
import unittest

from host import Host
from test_radar_source_contract import system_host, current_frame
from test_radar_pilot_presentation import page_host, visible
from test_threat_warning_presentation import defensive_page, showing


def picture_host():
    h = Host()
    for name in ('getHeading', 'getPitch', 'getRoll'):
        h.sensor(name, 0)
    h.sensor('getSelfCoordinates', (0, 1000, 0))
    h.seed({'F22_RADAR_RANGE_NM': 40})
    h.execute('''
        function get(k) return get_param_handle(k):get() end
        function put(k,v) get_param_handle(k):set(v) end
        situation=dofile(LockOn_Options.script_path..'Systems/Tactical_Situation.lua').new(get,put,get_base_data())
        overview=dofile(LockOn_Options.script_path..'Systems/Defensive_Overview.lua').new(get,put,get_base_data())
        track={source=9,age=0,az=0,el=0,affiliation=3,signal=2,label='22',
            observations={rf={time=100,az=0,el=0,signal=2}}}
        track.datalink={time=100,received=100,n=10000,u=1000,e=0,vn=200,vu=0,ve=0,
            link=1,reporter=7,observation_known=false}
        function publish(now)
            situation:update(now,{track},true)
            overview:update(now,{track},true,false,nil)
        end
    ''')
    return h


def metadata(h, now=10, radar_source=88):
    h.seed({'F22_TACTICAL_SCHEMA': 2, 'F22_TACTICAL_SEQUENCE': 2,
            'F22_TACTICAL_EPOCH': 4, 'F22_TACTICAL_TIME': now})
    fields = dict(VALID=1, SOURCE=19, RADAR_SOURCE=radar_source, RADAR_EPOCH=1,
                  SOURCES=27, AFFILIATION=3, RF_SIGNAL=2, RF_AGE=.2,
                  LABEL_CODE=22, DATALINK=1, IRST_AGE=.1, IDENTITY_CONFLICT=0)
    h.seed({'F22_TACTICAL_01_'+key: value for key, value in fields.items()})


class FusionPresentation(unittest.TestCase):
    def test_fused_rf_datalink_has_one_symbol_with_its_warning(self):
        h = picture_host()
        h.execute('publish(100)')
        self.assertEqual(h.get('F22_TSD_DL_COUNT'), 1)
        self.assertEqual(h.get('F22_TSD_BEARING_TOTAL'), 0)
        self.assertEqual(h.get('F22_TSD_DL_01_RF_SIGNAL'), 2)
        self.assertEqual(h.get('F22_TSD_DL_01_AFFILIATION'), 3)
        self.assertEqual(h.get('F22_DEF_OV_COUNT'), 1)
        # The donor position still has unknown observation age, but its fresh RF
        # observation keeps the common object current and its lock warning alive.
        self.assertEqual(h.get('F22_TSD_DL_01_COAST'), 0)
        self.assertEqual(h.get('F22_DEF_OV_01_COAST'), 0)
        h.execute('publish(104)')
        self.assertEqual(h.get('F22_TSD_DL_01_RF_SIGNAL'), 0)
        self.assertEqual(h.get('F22_DEF_OV_01_COAST'), 0)
        h.execute('publish(114)')
        self.assertEqual(h.get('F22_TSD_DL_01_COAST'), 1)
        self.assertEqual(h.get('F22_DEF_OV_01_COAST'), 1)

    def test_visible_coasting_radar_does_not_get_a_second_donor_symbol(self):
        h = picture_host()
        h.seed({'F22_SCOPE_01_VALID': 1, 'F22_SCOPE_01_SOURCE': 4, 'F22_SCOPE_01_COAST': 1})
        h.execute('track.observations.radar={source=4,time=100};track.range=10000;publish(100)')
        self.assertEqual(h.get('F22_TSD_DL_COUNT'), 0)
        self.assertEqual(h.get('F22_TSD_BEARING_TOTAL'), 0)
        self.assertEqual(h.get('F22_DEF_OV_01_RANGED'), 1)
        self.assertEqual(h.get('F22_DEF_OV_01_DATALINK'), 1)
        self.assertEqual(h.get('F22_DEF_OV_01_RADAR'), 1)
        # If own radar leaves the visible scope, the same fused object returns
        # once as an offboard symbol, retaining its picture ID.
        h.seed({'F22_SCOPE_01_VALID': 0})
        h.execute('publish(100.1)')
        self.assertEqual(h.get('F22_TSD_DL_COUNT'), 1)
        self.assertEqual(h.get('F22_TSD_DL_01_SOURCE'), 9)
        self.assertEqual(h.get('F22_TSD_BEARING_TOTAL'), 0)

    def test_irst_is_bearing_awareness_and_never_a_missile_warning(self):
        h = picture_host()
        h.execute('''track={source=10,age=0,az=.1,el=0,affiliation=-1,signal=0,
            observations={irst={time=100,az=.1,el=0}}};publish(100)''')
        self.assertEqual(h.get('F22_TSD_BEARING_TOTAL'), 1)
        self.assertEqual(h.get('F22_TSD_BEARING_01_IRST'), 1)
        self.assertEqual(h.get('F22_TSD_BEARING_01_OPTICAL'), 0)
        self.assertEqual(h.get('F22_DEF_OV_01_IRST'), 1)
        self.assertEqual(h.get('F22_DEF_OV_01_RANGED'), 0)
        self.assertEqual(h.get('F22_DEF_OV_01_MWS_CURRENT'), 0)
        self.assertEqual(h.get('F22_DEF_OV_01_ALERT'), 0)
        page = defensive_page(h)
        self.assertTrue(showing(h, page, 'IR'))
        self.assertFalse(showing(h, page, 'MISSILE'))
        h.execute('publish(102.6)')
        self.assertEqual(h.get('F22_TSD_BEARING_TOTAL'), 0)

    def test_irst_and_unassociated_rf_are_not_visually_relabelled_as_one_source(self):
        h = picture_host()
        h.execute('''local second={source=11,age=0,az=.02,el=0,affiliation=3,signal=0,
            observations={irst={time=100,az=.02,el=0}}}
            track.datalink=nil;situation:update(100,{track,second},true)''')
        self.assertEqual(h.get('F22_TSD_BEARING_TOTAL'), 2)
        self.assertEqual(h.get('F22_TSD_BEARING_SHOWN'), 2)
        h.execute('''track.observations.irst={time=100,az=0,el=0};
            situation:update(100,{track},true)''')
        self.assertEqual(h.get('F22_TSD_BEARING_TOTAL'), 1)
        self.assertEqual(h.get('F22_TSD_BEARING_01_IRST_CONTRIBUTOR'), 1)

    def test_actual_scope_consumes_fused_identity_without_changing_target_authority(self):
        h = system_host()
        current_frame(h, 10)
        source = h.get('F22A_01_ID')
        metadata(h, radar_source=source)
        h.update()
        self.assertEqual(h.get('F22_SCOPE_01_VALID'), 1)
        self.assertEqual(h.get('F22_SCOPE_01_AFFILIATION'), 3)
        self.assertEqual(h.get('F22_SCOPE_01_PICTURE_SOURCE'), 19)
        self.assertEqual(h.get('F22_SCOPE_01_DATALINK'), 1)
        self.assertEqual(h.get('F22_SCOPE_01_IRST'), 1)
        self.assertEqual(h.get('F22_RADAR_STT_IFF'), -1)
        self.assertEqual(h.get('F22_RADAR_SELECTED_FRIENDLY'), 0)

    def test_metadata_rejects_old_radar_epoch_and_torn_fusion_snapshot(self):
        h = Host()
        metadata(h)
        h.execute('''metadata=dofile(LockOn_Options.script_path..'Systems/Radar_Contact_Metadata.lua')
            function sample(k)
                local v=get_param_handle(k):get()
                if tear and k=='F22_TACTICAL_01_AFFILIATION' then
                    get_param_handle('F22_TACTICAL_EPOCH'):set(5)
                end
                return v
            end''')
        self.assertIsNotNone(h.execute('return metadata.read(sample,10,1)[88]'))
        self.assertIsNone(h.execute('return metadata.read(sample,10,2)[88]'))
        self.assertIsNone(h.execute('tear=true;return metadata.read(sample,10,1)[88]'))
        for values in ({'F22_TACTICAL_SEQUENCE': 3}, {'F22_TACTICAL_TIME': 9.7},
                       {'F22_TACTICAL_SCHEMA': 1}):
            metadata(h)
            h.seed(values)
            self.assertIsNone(h.execute('tear=false;return metadata.read(sample,10,1)[88]'))

    def test_scope_provenance_is_visible_on_one_actual_indicator(self):
        h, records = page_host()
        h.seed({'TEST_PMFD_PAGE': 1, 'RADAR_PWR': 1, 'MFD_OPACITY': 1, 'F22_AG_RADAR_PAGE': 0,
                'F22_SCOPE_01_VALID': 1, 'F22_SCOPE_01_DATALINK': 1,
                'F22_SCOPE_01_IRST': 1, 'F22_SCOPE_01_EW_SIGNAL': 2})
        for name in ('TEST_F22_RDR_TRACK_1_DL', 'TEST_F22_RDR_TRACK_1_IRST',
                     'TEST_F22_RDR_TRACK_1_RF_2'):
            self.assertTrue(visible(h, records, name), name)
        h.seed({'F22_SCOPE_01_VALID': 0})
        self.assertFalse(visible(h, records, 'TEST_F22_RDR_TRACK_1_DL'))


if __name__ == '__main__':
    unittest.main()
