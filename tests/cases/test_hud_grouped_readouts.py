"""Approved HUD grouping and native AFCS transition -> existing warning voice."""
import math
import unittest
from host import Host
from navigation_ports import avionics_sensors,seed_physical
from test_hud_ground_designation import marker,hud,shown


def declared(mode=2):
    h=marker();h.seed({'HUD_MODE':mode,'F22_FC_TARGET_VALID':1,'F22_FC_DLZ_VALID':1,
        'F22_FC_DLZ_SCALE_NM':20,'F22_FC_DLZ_RANGE_Y':.23,'HUD_ARMED':1,
        'F22_GUN_AMMO_VALID':1,'F22_GUN_AMMO_COUNT':480,'F22_WEAPON_NAME':'AIM-120',
        'F22_WEAPON_COUNT':5,'F22_RADAR_MODE_CODE':5,'F22_SIDE_VS_VALID':1,
        'F22_SIDE_RADAR_VALID':1,'F22_FC_RANGE_NM':12.4,'F22_FC_CLOSURE_KTS':450})
    return h,hud(h)


def numeric(nodes,param):
    return [n for n in nodes.values() if n['formats'] and n['element_params'] and n['element_params'][1]==param]


def status_host():
    h=Host();h.state.time=10;avionics_sensors(h);seed_physical(h,clock=10)
    h.execute('''
package.loaded.terrain={GetHeight=function()return 0 end,isVisible=function()return true end}
played={}
function create_sound_host()
 return {create_sound=function(_,path)
  local started
  return {update=function()end,stop=function()started=nil end,
   play_once=function()started=get_model_time();played[#played+1]=path end,
   is_playing=function()return started and get_model_time()-started<1 end}
 end}
end
''')
    h.load('Systems/Flight_Guidance.lua');h.env.post_initialize();guidance=h.env.update
    h.load('Systems/Pilot_Warning_System.lua');h.env.post_initialize();warning=h.env.update
    h.seed({'F22_AP_ACTIVE':0,'F22_AP_LIMITED':0,'F22_AP_REASON':0,'F22_AP_OFF_SEQUENCE':0,
        'EFM_FCS_INTEGRITY_VALID':1,'EFM_FCS_DAMAGED':0})
    return h,guidance,warning


def step(h,guidance,warning,now,values=None,generation=3):
    h.state.time=now;seed_physical(h,clock=now,generation=generation)
    h.seed(values or {});guidance();warning()


def flight_calls(h):
    return [p for p in h.env.played.values() if p.endswith('/flight_controls')]


class HudGroupedReadouts(unittest.TestCase):
    def test_source_pressure_and_pre_release_estimate_are_absent_from_actual_hud(self):
        h,nodes=declared()
        for field in ['HUD_ALT_SOURCE_TEXT','F22_ALT_DISPLAY_TEXT','F22_TOF_SECONDS']:
            self.assertEqual(numeric(nodes,field),[],field)

    def test_flight_radar_and_weapon_groups_share_one_anchor_without_overlapping_rows(self):
        for mode in [2,3,4,5,6]:
            h,nodes=declared(mode)
            fields=['VV','RADALT','F22_FC_RANGE_NM','F22_FC_CLOSURE_KTS']
            rows=[n for field in fields for n in numeric(nodes,field) if shown(h,nodes,n['name'])]
            rows.append(next(n for n in nodes.values() if n['value']=='STT' and shown(h,nodes,n['name'])))
            selected=[n for n in numeric(nodes,'F22_WEAPON_NAME') if shown(h,nodes,n['name'])]
            if mode==5:selected=[n for n in nodes.values() if n['value']=='GUN' and shown(h,nodes,n['name'])]
            count=[n for n in numeric(nodes,'F22_GUN_AMMO_COUNT' if mode==5 else 'F22_WEAPON_COUNT') if shown(h,nodes,n['name'])]
            arm=[n for n in nodes.values() if n['value']=='ARM' and shown(h,nodes,n['name'])]
            self.assertEqual([len(selected),len(count),len(arm)],[1,1,1])
            rows+=selected+count+arm
            self.assertTrue(all(n['alignment']=='RightCenter' for n in rows))
            self.assertEqual(len({round(n['init_pos'][1],6) for n in rows}),1)
            ordered=sorted(rows,key=lambda n:n['init_pos'][2],reverse=True)
            for upper,lower in zip(ordered,ordered[1:]):
                # Actual stroke metrics plus a small inter-row gap, in radians.
                gap=(upper['init_pos'][2]-lower['init_pos'][2])/1000
                glyph_height=max(upper['stringdefs'][1],lower['stringdefs'][1])/.55
                self.assertGreater(gap,glyph_height,(mode,upper['name'],lower['name']))

    def test_envelope_starts_at_altitude_dial_centre_preserves_length_and_maps_full_range(self):
        h,nodes=declared()
        dial=numeric(nodes,'HUD_ALT_FT')[0]
        bars=[n for n in nodes.values() if n['parent_element']=='HUD_ENGAGEMENT_2_DLZ' and n['vertices']]
        bar=max(bars,key=lambda n:max(v[2] for v in n['vertices'].values())-min(v[2] for v in n['vertices'].values()))
        ys=[v[2] for v in bar['vertices'].values()]
        self.assertAlmostEqual(max(ys),dial['init_pos'][2])
        self.assertAlmostEqual((max(ys)-min(ys))/220,.55)
        pointer=nodes['HUD_ENGAGEMENT_2_RANGE']
        motion=next(c for c in pointer['controllers'].values() if c[1]=='move_up_down_using_parameter')
        base=pointer['init_pos'][2]*.00055
        self.assertAlmostEqual(base,min(ys)*.00055)
        self.assertAlmostEqual(base+.46*motion[3],max(ys)*.00055)

    def test_gun_ammunition_failure_uses_same_group_and_ground_weapon_rows_are_grouped(self):
        h,nodes=declared(5)
        ammo=next(n for n in numeric(nodes,'F22_GUN_AMMO_COUNT') if shown(h,nodes,n['name']))
        h.seed({'F22_GUN_AMMO_VALID':0})
        missing=next(n for n in nodes.values() if n['value']=='AMMO N/A' and shown(h,nodes,n['name']))
        self.assertEqual(tuple(ammo['init_pos'].values()),tuple(missing['init_pos'].values()))
        h,nodes=declared(7);h.seed({'HUD_AG_SUBMODE':2})
        name=next(n for n in numeric(nodes,'F22_WEAPON_NAME') if shown(h,nodes,n['name']))
        count=next(n for n in numeric(nodes,'F22_WEAPON_COUNT') if shown(h,nodes,n['name']))
        self.assertEqual(name['init_pos'][1],count['init_pos'][1])
        self.assertGreater(name['init_pos'][2],count['init_pos'][2])

    def test_normal_off_is_blank_on_is_visible_and_limits_clear_without_verbose_modes(self):
        h,g,w=status_host();step(h,g,w,10)
        self.assertEqual(h.get('F22_AP_STATUS_TEXT'),'')
        step(h,g,w,10.1,{'F22_AP_ACTIVE':1,'F22_AP_ROLL_MODE':3,'F22_AP_PITCH_MODE':2,'F22_AP_AT':1})
        self.assertEqual(h.get('F22_AP_STATUS_TEXT'),'AP ON')
        step(h,g,w,10.2,{'F22_AP_LIMITED':1});self.assertEqual(h.get('F22_AP_STATUS_TEXT'),'AP LIMIT')
        step(h,g,w,10.3,{'F22_AP_LIMITED':0});self.assertEqual(h.get('F22_AP_STATUS_TEXT'),'AP ON')
        step(h,g,w,10.4,{'F22_AP_ACTIVE':0,'F22_AP_OFF_SEQUENCE':1})
        self.assertEqual(h.get('F22_AP_STATUS_TEXT'),'');self.assertEqual(flight_calls(h),[])

    def test_unexpected_native_reasons_show_for_five_seconds_and_play_existing_voice_once(self):
        for reason,text in [(2,'AP LIMIT'),(4,'AP NAV LOST'),(5,'AP ALT LOST'),(6,'AP HDG LOST')]:
            h,g,w=status_host();step(h,g,w,10,{'F22_AP_ACTIVE':1})
            step(h,g,w,10.1,{'F22_AP_ACTIVE':0,'F22_AP_REASON':reason})
            self.assertEqual(h.get('F22_AP_STATUS_TEXT'),text)
            step(h,g,w,10.2);step(h,g,w,14.9)
            self.assertEqual(len(flight_calls(h)),1)
            self.assertEqual(h.get('EFM_FCS_DAMAGED'),0)
            step(h,g,w,15.2)
            self.assertEqual(h.get('F22_AP_STATUS_TEXT'),'')
            self.assertEqual(h.get('F22_AP_ANN_VALID'),0)
            self.assertEqual(len(flight_calls(h)),1)

    def test_deliberate_override_and_inhibited_engagement_do_not_play_fault_voice(self):
        for reason,text in [(1,'AP INHIBIT'),(3,'AP OVERRIDE')]:
            h,g,w=status_host();step(h,g,w,10,{'F22_AP_ACTIVE':int(reason==3)})
            step(h,g,w,10.1,{'F22_AP_ACTIVE':0,'F22_AP_REASON':reason})
            self.assertEqual(h.get('F22_AP_STATUS_TEXT'),text)
            self.assertEqual(flight_calls(h),[])
            step(h,g,w,15.2);self.assertEqual(h.get('F22_AP_STATUS_TEXT'),'')

    def test_reengagement_clears_feedback_and_a_new_failure_is_a_new_audio_event(self):
        h,g,w=status_host();step(h,g,w,10,{'F22_AP_ACTIVE':1})
        step(h,g,w,10.1,{'F22_AP_ACTIVE':0,'F22_AP_REASON':4});step(h,g,w,10.2)
        step(h,g,w,11.3,{'F22_AP_ACTIVE':1,'F22_AP_REASON':0})
        self.assertEqual(h.get('F22_AP_STATUS_TEXT'),'AP ON')
        step(h,g,w,11.4,{'F22_AP_ACTIVE':0,'F22_AP_REASON':4})
        self.assertEqual(len(flight_calls(h)),2)

    def test_missile_voice_priority_blocks_then_releases_ap_warning_and_expired_events_do_not_queue(self):
        for release,expected in [(11,1),(16,0)]:
            h,g,w=status_host();step(h,g,w,10,{'F22_AP_ACTIVE':1,'F22_MWS_ALERT':1})
            step(h,g,w,10.1,{'F22_AP_ACTIVE':0,'F22_AP_REASON':5})
            self.assertEqual(flight_calls(h),[])
            step(h,g,w,release,{'F22_MWS_ALERT':0})
            self.assertEqual(len(flight_calls(h)),expected)

    def test_source_loss_invalid_data_rewind_and_new_generation_do_not_replay_old_drop(self):
        h,g,w=status_host();step(h,g,w,10,{'F22_AP_ACTIVE':1})
        step(h,g,w,10.1,{'F22_AP_ACTIVE':float('nan')})
        self.assertEqual(h.get('F22_AP_STATUS_TEXT'),'')
        step(h,g,w,10.2,{'F22_AP_ACTIVE':0,'F22_AP_REASON':4})
        self.assertEqual(flight_calls(h),[])
        h.state.time=10.6;g();w()
        self.assertEqual(h.get('F22_AP_STATUS_TEXT'),'')
        step(h,g,w,9,{'F22_AP_ACTIVE':0,'F22_AP_REASON':4},generation=4)
        step(h,g,w,9.1,generation=4)
        self.assertEqual(flight_calls(h),[])

    def test_audio_notification_rejects_torn_stale_expired_and_wrong_generation_packets(self):
        h,g,w=status_host();step(h,g,w,10,{'F22_AP_ACTIVE':1})
        step(h,g,w,10.1,{'F22_AP_ACTIVE':0,'F22_AP_REASON':5})
        reader=h.load('Systems/AP_Annunciation.lua').read
        self.assertIsNotNone(reader(h.get,10.1,3))
        self.assertIsNone(reader(h.get,10.4,3));self.assertIsNone(reader(h.get,10.1,4))
        for field in ['SCHEMA','EPOCH','GENERATION','TIME','VALID','TICKET','ONSET','UNTIL']:
            key='F22_AP_ANN_'+field
            def torn(name):
                value=h.get(name)
                if name==key:h.seed({'F22_AP_ANN_SEQUENCE':h.get('F22_AP_ANN_SEQUENCE')+2})
                return value
            self.assertIsNone(reader(torn,10.1,3),field)


if __name__=='__main__':unittest.main()
