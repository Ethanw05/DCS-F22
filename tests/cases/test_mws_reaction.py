"""Actual MWS/RWR owners: launch-tone arbitration and pre-audio rejection."""
import unittest
from host import Host


def warning_host():
    h = Host()
    h.state.time = 100
    h.seed(dict(MAIN_POWER=1, F22_ELECTRICAL_VALID=1, EFM_POWER_OWNER=1,
                EFM_PHYSICAL_VALID=1, EFM_PHYSICAL_GENERATION=2, EFM_PHYSICAL_STAMP=100,
                EFM_PHYSICAL_CLOCK_KIND=1, F22_AP_CLOCK=100, EFM_MISSION_POWER_AVAILABLE=1))
    for field in ('getHeading', 'getPitch', 'getRoll'):
        h.sensor(field, 0)
    h.sensor('getSelfCoordinates', (0, 10000, 0))
    h.execute('''
        sound_ports={}
        function create_sound_host()
            return {create_sound=function(_,name)
                local sound={on=false}
                function sound:update()end
                function sound:is_playing()return self.on and 1 or 0 end
                function sound:play_continue()self.on=true end
                function sound:play_once()self.on=true end
                function sound:stop()self.on=false end
                sound_ports[name]=sound;return sound
            end}
        end
        native={set_power=function()end};function GetDevice()return native end
    ''')
    h.load('Systems/RWR_System.lua')
    h.env.post_initialize()
    h.execute('rwr_update=update')
    h.seed({'RWR_CONTACT_01_SOURCE': 123, 'RWR_CONTACT_01_TIME': 0,
            'RWR_CONTACT_01_AZIMUTH': 0, 'RWR_CONTACT_01_ELEVATION': 0,
            'RWR_CONTACT_01_SIGNAL': 3, 'RWR_CONTACT_01_UNIT_TYPE': 'MiG-29S',
            'RWR_CONTACT_01_GENERAL_TYPE': 1, 'RWR_CONTACT_01_PRIORITY': 1,
            'RWR_CONTACT_01_POWER': .2})
    h.env.rwr_update()
    h.load('Systems/MWS_System.lua')
    h.env.post_initialize()
    h.seed({'F22_MWS_NATIVE_READY': 1, 'F22_MWS_NATIVE_TIME': 100,
            'F22_MWS_NATIVE_01_VALID': 1, 'F22_MWS_NATIVE_01_SOURCE': 17,
            'F22_MWS_NATIVE_01_TIME': 100, 'F22_MWS_NATIVE_01_AZ': .2,
            'F22_MWS_NATIVE_01_EL': 0, 'F22_MWS_NATIVE_01_THREAT': 1})
    return h


class MWSReaction(unittest.TestCase):
    def test_mws_takes_priority_over_an_already_playing_radar_launch_tone(self):
        h = warning_host()
        self.assertEqual(h.get('F22_RWR_ALERT'), 3)
        self.assertEqual(h.get('F22_RWR_AUDIO_LOOP'), 3)
        h.update()
        self.assertEqual(h.get('F22_MWS_ALERT'), 1)
        self.assertEqual(h.get('F22_MWS_AUDIO_PRIORITY'), 1)
        self.assertTrue(h.execute("return sound_ports['Aircrafts/F-22A/MWS/approach'].on"))
        h.state.time = 100.05
        h.env.rwr_update()
        self.assertEqual(h.get('F22_RWR_ALERT'), 3)
        self.assertEqual(h.get('F22_RWR_AUDIO_LOOP'), 0)
        self.assertEqual(h.get('F22_MWS_ALERT'), 1)
        h.seed({'F22_MWS_NATIVE_01_THREAT': 0})
        h.update()
        h.env.rwr_update()
        self.assertEqual(h.get('F22_RWR_AUDIO_LOOP'), 3)

    def test_critical_voice_holds_only_audio_and_expiry_restores_it(self):
        h = warning_host()
        h.seed({'F22_PILOT_AUDIO_PRIORITY': 3, 'F22_PILOT_AUDIO_UNTIL': 100.1})
        h.update()
        self.assertEqual(h.get('F22_MWS_ALERT'), 1)
        self.assertEqual(h.get('F22_MWS_AUDIO_PRIORITY'), 0)
        h.state.time = 100.15
        h.update()
        self.assertEqual(h.get('F22_MWS_AUDIO_PRIORITY'), 1)

    def test_advisory_voice_does_not_block_mws(self):
        h = warning_host()
        h.seed({'F22_PILOT_AUDIO_PRIORITY': 1, 'F22_PILOT_AUDIO_UNTIL': 101})
        h.update()
        self.assertEqual(h.get('F22_MWS_AUDIO_PRIORITY'), 1)

    def test_non_threat_is_rejected_before_audio_and_rejection_is_logged(self):
        h = warning_host()
        h.seed({'F22_MWS_NATIVE_01_THREAT': 0, 'F22_MWS_NATIVE_COUNT': 1,
                'F22_MWS_NATIVE_CANDIDATE': 17, 'F22_MWS_NATIVE_DECISION': 2,
                'F22_MWS_NATIVE_CLOSING_MPS': -100, 'F22_MWS_NATIVE_CLOSEST_SECONDS': -1})
        h.execute("log={INFO=1,ERROR=2};function log.write(name,_,text) if name=='F22_MWS_SAMPLE'then sample=text end end")
        h.update()
        self.assertEqual(h.get('F22_RWR_ALERT'), 3)
        self.assertEqual(h.get('F22_MWS_ALERT'), 0)
        self.assertIn('accepted=1 incoming=0 candidate=17 decision=2 closing=-100.0', h.env.sample)


if __name__ == '__main__':
    unittest.main()
