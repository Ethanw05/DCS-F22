"""Current received manual recovery, independently specified transport/failure cases."""
import math
import unittest
from host import Host
from navigation_ports import seed_physical, avionics_sensors
from test_navigation_indication_rendering import declarations, normalized


def receiver():
    h=Host();h.state.time=10
    seed_physical(h)
    h.seed({'F22_TCN_CHANNEL':1,'F22_TCN_BAND':0,'F22_TCN_MODE':2,'F22_ILS_FREQ_KHZ':110300,
        'F22_RADIONAV_SEQUENCE':2,'F22_RADIONAV_SCHEMA':1,'F22_RADIONAV_VALID':1,
        'F22_RADIONAV_GENERATION':3,'F22_RADIONAV_CLOCK_KIND':2,'F22_RADIONAV_STAMP':10,
        'F22_RADIONAV_TCN_CHANNEL':1,'F22_RADIONAV_TCN_BAND':0,'F22_RADIONAV_TCN_MODE':2,
        'F22_RADIONAV_ILS_FREQ_KHZ':110300,'F22_TCN_POWER':1,'F22_ILS_POWER':1,
        'F22_TCN_BRG_VALID':1,'F22_TCN_RANGE_VALID':1,'F22_TCN_BRG_MAG':0,'F22_TCN_RANGE_M':0,
        'F22_ILS_LOC_VALID':1,'F22_ILS_GS_VALID':1,'F22_ILS_LOC':0,'F22_ILS_GS':0,
        'F22_NAV_REFERENCE':0,'F22_NAV_SOURCE':2,'HUD_MODE':1,'HUD_LANDING_CONFIG':0})
    h.execute("local handles={};local function handle(k) "
        "if not handles[k]then handles[k]=get_param_handle(k)end;return handles[k]end;"
        "function read_radio(k)return handle(k):get()end;"
        "function put_radio(k,v)handle(k):set(v)end;"
        "received=dofile(LockOn_Options.script_path..'Systems/Radio_Snapshot.lua').new(read_radio);"
        "draw_guidance=dofile(LockOn_Options.script_path..'Systems/Nav_Guidance.lua');"
        "radio_data=dofile(LockOn_Options.script_path..'Systems/Radio_Navigation.lua');"
        "function consume_radio()received:update();radio_data.publish_data(read_radio,put_radio,received);"
        "draw_guidance(read_radio,put_radio,nil,nil,received)end")
    return h


class ReceivedNavigation(unittest.TestCase):
    def test_tacan_modes_and_component_failures_preserve_received_zero(self):
        for mode,bearing,range_available in [(0,0,0),(1,1,0),(2,1,1),(3,0,1),(4,0,1)]:
            h=receiver();h.seed({'F22_NAV_REFERENCE':1,'F22_TCN_MODE':mode,'F22_RADIONAV_TCN_MODE':mode})
            h.env.consume_radio()
            self.assertEqual(h.get('F22_NAV_TCN_BRG_AVAILABLE'),bearing,mode)
            self.assertEqual(h.get('F22_NAV_TCN_RANGE_AVAILABLE'),range_available,mode)
            self.assertEqual(h.get('HUD_ILS_GS_VALID'),1)
        for value,flag,other in [('F22_TCN_BRG_MAG','BRG','RANGE'),('F22_TCN_RANGE_M','RANGE','BRG')]:
            h=receiver();h.seed({'F22_NAV_REFERENCE':1,value:float('nan')});h.env.consume_radio()
            self.assertEqual(h.get('F22_NAV_TCN_'+flag+'_AVAILABLE'),0)
            self.assertEqual(h.get('F22_NAV_TCN_'+other+'_AVAILABLE'),1)

    def test_true_tacan_requires_current_declination_and_range_stays_independent(self):
        h=receiver();h.env.consume_radio()
        self.assertEqual(h.get('F22_NAV_TCN_BRG_AVAILABLE'),0)
        self.assertEqual(h.get('F22_NAV_TCN_RANGE_AVAILABLE'),1)
        h.seed({'F22_MAG_SCHEMA':1,'F22_MAG_SEQUENCE':2,'F22_MAG_VALID':1,'F22_MAG_CLOCK_KIND':2,
            'F22_MAG_GENERATION':3,'F22_MAG_STAMP':10,'F22_MAG_DECL':math.radians(10)})
        h.env.consume_radio()
        self.assertEqual(h.get('F22_NAV_TCN_BRG_TEXT'),'BRG 010T')
        h.seed({'F22_MAG_STAMP':9});h.env.consume_radio()
        self.assertEqual(h.get('F22_NAV_TCN_BRG_AVAILABLE'),0)
        self.assertEqual(h.get('F22_NAV_TCN_RANGE_AVAILABLE'),1)
        h.seed({'F22_NAV_REFERENCE':1});h.env.consume_radio()
        self.assertEqual(h.get('F22_NAV_TCN_BRG_TEXT'),'BRG 000M')

    def test_flight_guidance_does_not_relabel_true_heading_when_magnetic_source_expires(self):
        h=receiver();avionics_sensors(h)
        h.load('Systems/Flight_Guidance.lua');h.env.post_initialize()
        h.seed({'F22_NAV_REFERENCE':1,'F22_AP_HEADING':120,'F22_MAG_SCHEMA':1,'F22_MAG_SEQUENCE':2,
            'F22_MAG_VALID':1,'F22_MAG_CLOCK_KIND':2,'F22_MAG_GENERATION':3,
            'F22_MAG_STAMP':10,'F22_MAG_DECL':math.radians(10)})
        h.update();self.assertEqual(h.get('F22_AP_HDG_TEXT'),'HDG 110M')
        self.assertEqual(h.get('F22_NAV_COURSE_REF_VALID'),1)
        h.state.time=10.3;seed_physical(h);h.update()
        self.assertEqual(h.get('F22_AP_HDG_TEXT'),'HDG ---M')
        self.assertEqual(h.get('F22_NAV_COURSE_REF_VALID'),0)
        h.seed({'F22_NAV_REFERENCE':0});h.state.time=10.4;seed_physical(h);h.update()
        self.assertEqual(h.get('F22_AP_HDG_TEXT'),'HDG 120T')

    def test_valid_zero_and_approach_survive_missing_ins_and_tacan(self):
        h=receiver();h.seed({'F22_INS_READY':0,'F22_TCN_BRG_VALID':0,'F22_TCN_RANGE_VALID':0})
        h.env.consume_radio()
        for axis in ['LOC','GS']:
            self.assertEqual(h.get('HUD_ILS_'+axis+'_VALID'),1)
            self.assertEqual(h.get('HUD_ILS_'+axis),0)
        self.assertEqual(h.get('F22_NAV_TCN_BRG_AVAILABLE'),0)
        self.assertEqual(h.get('HUD_ILS_DISPLAY_ENABLE'),1)

    def test_each_axis_fails_and_recovers_independently(self):
        for axis,other in [('LOC','GS'),('GS','LOC')]:
            for bad in [float('nan'),float('inf'),4]:
                h=receiver();h.seed({'F22_ILS_'+axis:bad});h.env.consume_radio()
                self.assertEqual(h.get('HUD_ILS_'+axis+'_VALID'),0)
                self.assertEqual(h.get('F22_NAV_ILS_'+axis+'_AVAILABLE'),0)
                self.assertEqual(h.get('HUD_ILS_'+other+'_VALID'),1)
                h.seed({'F22_ILS_'+axis:0});h.env.consume_radio()
                self.assertEqual(h.get('HUD_ILS_'+axis+'_VALID'),1)
            h=receiver()
            h.execute("local original=received.get;received.get=function(k) "
                f"if k=='F22_ILS_{axis}' then return nil end;return original(k)end")
            h.env.consume_radio()
            self.assertEqual(h.get('HUD_ILS_'+axis+'_VALID'),0)
            self.assertEqual(h.get('HUD_ILS_'+other+'_VALID'),1)
            h=receiver();h.seed({'F22_ILS_'+axis+'_VALID':0});h.env.consume_radio()
            self.assertEqual(h.get('HUD_ILS_'+axis+'_VALID'),0)
            self.assertEqual(h.get('HUD_ILS_'+other+'_VALID'),1)

    def test_documented_scaling_direction_saturation_and_selection(self):
        h=receiver();h.seed({'F22_ILS_LOC':.6*math.radians(1.25),'F22_ILS_GS':.6*math.radians(.35)})
        h.env.consume_radio()
        self.assertAlmostEqual(h.get('HUD_ILS_LOC'),.5)
        self.assertAlmostEqual(h.get('HUD_ILS_GS'),-.5)
        h.seed({'F22_ILS_LOC':-.2,'F22_ILS_GS':-.2});h.env.consume_radio()
        self.assertEqual(h.get('HUD_ILS_LOC'),-1);self.assertEqual(h.get('HUD_ILS_GS'),1)
        h.seed({'F22_NAV_SOURCE':0});h.env.consume_radio()
        self.assertEqual(h.get('HUD_ILS_LOC_VALID'),0)
        self.assertEqual(h.get('F22_NAV_ILS_LOC_AVAILABLE'),1)
        h.seed({'HUD_LANDING_CONFIG':1});h.env.consume_radio()
        self.assertEqual(h.get('HUD_ILS_GS_VALID'),1)

    def test_tuning_mismatch_withdraws_only_affected_receiver(self):
        h=receiver();h.seed({'F22_ILS_FREQ_KHZ':110500,'F22_NAV_REFERENCE':1});h.env.consume_radio()
        self.assertEqual(h.get('HUD_ILS_LOC_VALID'),0)
        self.assertEqual(h.get('F22_NAV_TCN_BRG_AVAILABLE'),1)
        h.seed({'F22_RADIONAV_ILS_FREQ_KHZ':110500,'F22_TCN_CHANNEL':2});h.env.consume_radio()
        self.assertEqual(h.get('HUD_ILS_LOC_VALID'),1)
        self.assertEqual(h.get('F22_NAV_TCN_RANGE_AVAILABLE'),0)
        h.seed({'F22_RADIONAV_TCN_CHANNEL':2,'F22_ILS_FREQ_KHZ':110320});h.env.consume_radio()
        self.assertEqual(h.get('HUD_ILS_GS_VALID'),0)
        self.assertEqual(h.get('F22_NAV_TCN_RANGE_AVAILABLE'),1)

    def test_stopped_radio_and_stopped_physical_source_expire_independently(self):
        for stopped in ['radio','physical']:
            h=receiver();h.env.consume_radio();h.state.time=10.251
            if stopped=='radio':seed_physical(h)
            else:h.seed({'F22_RADIONAV_STAMP':h.state.time})
            h.env.consume_radio()
            self.assertEqual(h.get('HUD_ILS_LOC_VALID'),0,stopped)
            self.assertEqual(h.get('HUD_ILS_GS_VALID'),0,stopped)
            seed_physical(h);h.seed({'F22_RADIONAV_STAMP':h.state.time});h.env.consume_radio()
            self.assertEqual(h.get('HUD_ILS_LOC_VALID'),1)

    def test_packet_and_clock_failures_require_current_generation_recovery(self):
        for field,bad in [('F22_RADIONAV_SEQUENCE',3),('F22_RADIONAV_SCHEMA',0),
            ('F22_RADIONAV_CLOCK_KIND',1),('F22_RADIONAV_GENERATION',2),
            ('F22_RADIONAV_VALID',0),('F22_RADIONAV_STAMP',10.02),('MAIN_POWER',0)]:
            h=receiver();h.seed({field:bad});h.env.consume_radio()
            self.assertEqual(h.get('HUD_ILS_LOC_VALID'),0,field)
        h=receiver();h.env.consume_radio();h.state.time=9
        seed_physical(h);h.seed({'F22_RADIONAV_STAMP':9});h.env.consume_radio()
        self.assertEqual(h.get('HUD_ILS_GS_VALID'),0)
        seed_physical(h,generation=4);h.seed({'F22_RADIONAV_GENERATION':4});h.env.consume_radio()
        self.assertEqual(h.get('HUD_ILS_GS_VALID'),1)

    def test_payload_mutation_cannot_commit_a_torn_packet(self):
        for field in ['F22_TCN_BRG_MAG','F22_ILS_LOC','F22_ILS_GS_VALID']:
            h=receiver()
            h.execute("local original=received.get;local once=true;received.get=function(k) "
                f"local v=original(k);if once and k=='{field}' then once=false;"
                "put_radio('F22_RADIONAV_SEQUENCE',4)end;return v end")
            h.env.consume_radio()
            self.assertEqual(h.get('HUD_ILS_LOC_VALID'),0,field)
            self.assertEqual(h.get('F22_NAV_TCN_RANGE_AVAILABLE'),0,field)
            h.env.consume_radio();self.assertEqual(h.get('HUD_ILS_LOC_VALID'),1)

    def test_actual_navigation_device_publishes_approach_without_position(self):
        h=receiver();avionics_sensors(h)
        h.load('Systems/Navigation_System.lua');h.env.post_initialize();h.update()
        self.assertEqual(h.get('F22_NAV_OWN_VALID'),0)
        self.assertEqual(h.get('HUD_ILS_LOC_VALID'),1)
        self.assertEqual(h.get('HUD_ILS_GS_VALID'),1)
        h.state.time=10.3;seed_physical(h);h.update()
        self.assertEqual(h.get('HUD_ILS_LOC_VALID'),0)

    def test_adi_axes_use_independent_current_inputs_and_keep_geometry(self):
        current=declarations('MFD_COMMON/adi_page.lua')
        baseline=declarations('MFD_COMMON/adi_page.lua',baseline=True)
        for suffix,value,valid,axis in [('LOCALIZER','HUD_ILS_LOC','HUD_ILS_LOC_VALID','move_left_right_using_parameter'),
                ('GLIDESLOPE','HUD_ILS_GS','HUD_ILS_GS_VALID','move_up_down_using_parameter')]:
            node=next(x for x in current if str(x['name']).startswith('ADI_ILS_'+suffix))
            self.assertEqual(node['element_params'][3],value)
            self.assertEqual(node['element_params'][4],valid)
            controls=list(node['controllers'].values())
            self.assertTrue(any(c[1]=='parameter_in_range' and c[2]==3 for c in controls))
            self.assertTrue(any(c[1]==axis and c[2]==2 for c in controls))
            old_key='ILS_HORIZON' if suffix=='LOCALIZER' else 'ILS_VERT'
            old=next(x for x in baseline if x['element_params'] and x['element_params'][3]==old_key)
            for key in ['material','vertices','indices','tex_coords','init_pos','init_rot','level','h_clip_relation']:
                self.assertEqual(normalized(node[key]),normalized(old[key]),key)


if __name__=='__main__':unittest.main()
