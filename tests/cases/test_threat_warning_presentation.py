"""Native RF states and optical detections retain distinct, current pilot cues."""
import math
import unittest

from host import Host
from test_radar_pilot_presentation import page_host, visible


def rwr_host():
    h = Host()
    h.state.time = 100
    h.seed(dict(MAIN_POWER=1, F22_ELECTRICAL_VALID=1, EFM_POWER_OWNER=1,
        EFM_PHYSICAL_VALID=1, EFM_PHYSICAL_GENERATION=2, EFM_PHYSICAL_STAMP=100,
        EFM_PHYSICAL_CLOCK_KIND=1, F22_AP_CLOCK=100, EFM_MISSION_POWER_AVAILABLE=1))
    for field in ('getHeading', 'getPitch', 'getRoll'):
        h.sensor(field, 0)
    h.sensor('getSelfCoordinates', (0, 10000, 0))
    h.execute('native={set_power=function()end};function GetDevice()return native end')
    h.load('Systems/RWR_System.lua')
    h.env.post_initialize()
    return h


def native_contact(h, signal, age=0, bearing=0):
    fields = dict(SOURCE=123, TIME=age, AZIMUTH=bearing, ELEVATION=0, SIGNAL=signal,
                  UNIT_TYPE='MiG-29S', GENERAL_TYPE=1, PRIORITY=1, POWER=.2)
    h.seed({'RWR_CONTACT_01_'+key: value for key, value in fields.items()})
    h.update()


def records(h):
    return {record.name: record for _, record in h.state.elements.items()
            if record.added and record.name}


def defensive_page(h):
    h.execute('''
        FOV=1;MILLYRADIANS=2
        h_clip_relations={REWRITE_LEVEL=1,INCREASE_IF_LEVEL=2,COMPARE=3}
        function SetScale(_)end
        function GetScale()return .0932 end
        function GetAspect()return 1 end
        function MakeMaterial(_,color)return color end
        function MakeFont(_,_,name)return name end
        local load=dofile
        function dofile(path)
            if path=='common/elements_defs.lua'then return end
            return load(path)
        end
    ''')
    h.load('MFD_RIGHT/defensive_overview.lua')('TEST_DEF_PAGE', 'TEST_DEF_', 'TEST_DETAIL')
    h.seed(dict(MFD_OPACITY=1, TEST_DEF_PAGE=1, TEST_DETAIL=0, F22_DEF_OV_CURRENT=1))
    return records(h)


def showing(h, graph, text):
    return [name for name, record in graph.items()
            if record.value == text and visible(h, graph, name)]


def hud_page(h):
    h.execute('''
        local function add(kind,name,x,y,parent)
            local element=CreateElement(kind)
            element.name=name;element.init_pos={x,y,0};element.parent_element=parent
            return element
        end
        hud_api={}
        function hud_api.group(name,x,y,params,controllers,parent)
            local element=add('ceSimple',name,x,y,parent)
            element.element_params=params;element.controllers=controllers;Add(element)
        end
        function hud_api.static(x,y,text,size,parent)
            hud_number=(hud_number or 0)+1
            local element=add('ceStringSLine','HUD_TEXT_'..hud_number,x,y,parent)
            element.value=text;element.stringdefs={size};Add(element)
        end
        function hud_api.label(x,y,param,format,size,parent)
            hud_number=(hud_number or 0)+1
            local element=add('ceStringSLine','HUD_TEXT_'..hud_number,x,y,parent)
            element.formats={format};element.element_params={param};Add(element)
        end
        function hud_api.line()end
    ''')
    h.load('HUD/engagement.lua')(h.env.hud_api)
    h.seed(dict(HUD_POWER=1, F22_DEF_OV_CURRENT=1))
    return records(h)


class ThreatWarningPresentation(unittest.TestCase):
    def test_native_search_lock_launch_reach_view_and_existing_audio(self):
        h = rwr_host()
        for signal, audio in ((1, 0), (2, 0), (3, 3)):
            native_contact(h, signal)
            self.assertEqual(h.get('F22_RWR_ALERT'), signal)
            self.assertEqual(h.get('F22_DEF_OV_01_SIGNAL'), signal)
            self.assertEqual(h.get('F22_RWR_AUDIO_LOOP'), audio)
            self.assertEqual(h.get('F22_DEF_OV_01_MWS_CURRENT'), 0)
            if signal == 2:
                self.assertEqual(h.get('F22_RWR_AUDIO_EVENT'), 4)
        native_contact(h, 3, age=4)
        self.assertEqual(h.get('F22_RWR_ALERT'), 0)
        self.assertEqual(h.get('F22_DEF_OV_01_SIGNAL'), 0)
        self.assertEqual(h.get('F22_RWR_AUDIO_LOOP'), 0)
        self.assertEqual(h.get('F22_DEF_OV_01_COAST'), 1)

    def test_defensive_page_names_each_warning_and_retains_bearing(self):
        h = rwr_host()
        graph = defensive_page(h)
        for signal, headline, label in ((1, None, None),
                                       (2, 'RADAR LOCK', 'LOCK'),
                                       (3, 'RWR LAUNCH', 'LAUNCH')):
            native_contact(h, signal)
            for text in ('RADAR LOCK', 'RWR LAUNCH'):
                self.assertEqual(bool(showing(h, graph, text)), text == headline)
            for text in ('LOCK', 'LAUNCH', 'MISSILE'):
                self.assertEqual(bool(showing(h, graph, text)), text == label)
            self.assertEqual(h.get('F22_DEF_OV_01_VALID'), 1)
            self.assertAlmostEqual(h.get('F22_DEF_OV_01_X'), 0)
            self.assertGreater(h.get('F22_DEF_OV_01_Y'), 0)
        # Muting audio must not conceal the warning.
        h.seed({'F22_RWR_MUTE': 1})
        self.assertTrue(showing(h, graph, 'RWR LAUNCH'))

    def test_optical_warning_is_distinct_and_cannot_be_renewed_by_radar(self):
        h = rwr_host()
        graph = defensive_page(h)
        h.execute('''
            overview=dofile(LockOn_Options.script_path..'Systems/Defensive_Overview.lua').new(
                function(k)return get_param_handle(k):get()end,
                function(k,v)get_param_handle(k):set(v)end,get_base_data())
            track={source=7,age=0,az=0,el=0,signal=3,label='29',affiliation=-1,
                observations={radar={time=100},rf={time=100,signal=3},mws={time=100}}}
            overview:update(100,{track},true,false,nil)
        ''')
        self.assertTrue(showing(h, graph, 'MISSILE'))
        self.assertFalse(showing(h, graph, 'LAUNCH'))
        h.execute('overview:update(100.75,{track},true,false,nil)')
        self.assertEqual(h.get('F22_DEF_OV_01_MWS_CURRENT'), 0)
        self.assertEqual(h.get('F22_DEF_OV_01_SIGNAL'), 3)
        self.assertTrue(showing(h, graph, 'LAUNCH'))
        h.execute('track.observations.radar.time=104;overview:update(104,{track},true,false,nil)')
        self.assertEqual(h.get('F22_DEF_OV_01_SIGNAL'), 0)
        self.assertFalse(showing(h, graph, 'LAUNCH'))
        self.assertFalse(showing(h, graph, 'MISSILE'))

    def test_blink_never_hides_the_source_or_relabels_memory_as_current(self):
        h = rwr_host()
        graph = defensive_page(h)
        native_contact(h, 3)
        h.seed({'F22_DEF_OV_01_PULSE': 0})
        self.assertFalse(showing(h, graph, 'LAUNCH'))
        self.assertTrue(showing(h, graph, 'RWR LAUNCH'))
        self.assertEqual(h.get('F22_DEF_OV_01_VALID'), 1)
        native_contact(h, 3, age=4)
        self.assertFalse(showing(h, graph, 'RWR LAUNCH'))
        self.assertFalse(showing(h, graph, 'LAUNCH'))

    def test_requested_lock_pulse_is_slower_than_launch_and_memory_is_steady(self):
        h = rwr_host()
        computer = h.load('Systems/RWR_Computer.lua')
        for stamp, lock, launch in ((100, 1, 1), (100.35, 1, 0),
                                    (100.65, 0, 1), (100.9, 0, 0)):
            self.assertEqual(computer.pulse(stamp, 2), lock)
            self.assertEqual(computer.pulse(stamp, 3), launch)
            self.assertEqual(computer.pulse(stamp, 0), 1)
        native_contact(h, 2)
        graph = defensive_page(h)
        h.seed({'F22_DEF_OV_01_PULSE': 0})
        self.assertFalse(showing(h, graph, 'LOCK'))
        self.assertTrue(showing(h, graph, 'RADAR LOCK'))
        for bad in (float('nan'), float('inf')):
            self.assertEqual(computer.pulse(bad, 3), 0)

    def test_audio_status_change_once_launch_repeats_and_no_sweep_or_loss_tone(self):
        h = rwr_host()
        audio = h.load('Systems/RWR_Audio.lua').new()
        contact = h.lua.table_from(dict(source=123, signal=1, age=0))
        contacts = h.lua.table_from([contact])
        def tick(alert, muted=False):
            return audio.update(audio, .05, contacts, True, muted, alert)
        self.assertEqual(tick(1).event, 'new_contact')
        self.assertIsNone(tick(1).event)
        contact.signal = 2
        self.assertEqual(tick(2).event, 'lock')
        self.assertIsNone(tick(2).loop)
        self.assertIsNone(tick(2).event)
        contact.signal = 3
        for _ in range(3):
            cue = tick(3)
            self.assertEqual(cue.loop, 'launch')
            self.assertIsNone(cue.event)
        contact.signal = 2
        self.assertIsNone(tick(2).event, 'A downgrade must not produce a new lock tone')
        contacts = h.lua.table_from([])
        self.assertIsNone(tick(0).event)
        contact.signal = 2
        contacts = h.lua.table_from([contact])
        self.assertIsNone(tick(2, muted=True).event)
        self.assertIsNone(tick(2).event, 'Unmute must not replay an old lock')
        contact.signal, contact.age = 3, 4
        self.assertIsNone(tick(0).loop)

    def test_lock_recording_is_not_cut_off_at_the_next_owner_update(self):
        h = rwr_host()
        h.execute('''
            sounds={}
            function create_sound_host()
                return {create_sound=function(_,name)
                    local sound={playing=false,starts=0}
                    function sound:update()end
                    function sound:is_playing()return self.playing end
                    function sound:stop()self.playing=false end
                    function sound:play_once()self.playing=true;self.starts=self.starts+1 end
                    function sound:play_continue()self.playing=true;self.starts=self.starts+1 end
                    sounds[name]=sound;return sound
                end}
            end
            post_initialize()
        ''')
        native_contact(h, 2)
        sound = h.env.sounds['Aircrafts/F-22A/RWR/lock']
        self.assertTrue(sound.playing)
        self.assertEqual(sound.starts, 1)
        native_contact(h, 2)
        self.assertTrue(sound.playing)
        self.assertEqual(sound.starts, 1)
        native_contact(h, 3)
        self.assertFalse(sound.playing)
        self.assertTrue(h.env.sounds['Aircrafts/F-22A/RWR/launch'].playing)

    def test_active_missile_radar_is_M_without_fabricating_optical_detection(self):
        h = rwr_host()
        native_contact(h, 3)
        h.seed({'RWR_CONTACT_01_GENERAL_TYPE': 4})
        h.update()
        self.assertEqual(h.get('F22_EW_01_LABEL_CODE'), 101)
        self.assertEqual(h.get('F22_DEF_OV_01_LABEL_CODE'), 101)
        self.assertEqual(h.get('F22_DEF_OV_01_MWS_CURRENT'), 0)
        self.assertEqual(h.get('F22_RWR_AUDIO_LOOP'), 3)

    def test_aa_and_ag_repeat_rwr_states_and_withdraw_on_invalid_source(self):
        for kind, mode in (('radar_format', 2), ('ag_radar_format', 7)):
            h, graph = page_host(kind)
            base = dict(MFD_OPACITY=1, TEST_PMFD_PAGE=1, HUD_MODE=mode,
                F22_AG_RADAR_PAGE=0, F22_DEF_OV_CURRENT=1, F22_RWR_POWER=1,
                F22_RWR_READY=1, F22_EW_01_COAST=0, F22_EW_01_LABEL_CODE=29)
            h.seed(base)
            for signal, expected in ((1, None), (2, 'RADAR LOCK'), (3, 'RWR LAUNCH')):
                h.seed({'F22_RWR_ALERT': signal})
                for text in ('RADAR LOCK', 'RWR LAUNCH'):
                    self.assertEqual(bool(showing(h, graph, text)), text == expected, kind)
            for failure in ({'F22_DEF_OV_CURRENT': 0}, {'F22_RWR_READY': 0},
                            {'F22_RWR_POWER': 0}, {'F22_EW_01_COAST': 1}):
                h.seed(base)
                h.seed(failure)
                self.assertFalse(showing(h, graph, 'RWR LAUNCH'), (kind, failure))
            for record in graph.values():
                if record.formats:
                    for _, fmt in record.formats.items():
                        self.assertNotIn('%s', fmt)

    def test_warning_bearing_uses_relative_rf_and_does_not_invent_range(self):
        h = rwr_host()
        for bearing in (0, math.pi/2, math.pi, -math.pi/2):
            native_contact(h, 2, bearing=bearing)
            self.assertEqual(h.get('F22_DEF_OV_01_RANGED'), 0)
            self.assertEqual(h.get('F22_DEF_OV_01_SIGNAL'), 2)
            radius = math.hypot(h.get('F22_DEF_OV_01_X'), h.get('F22_DEF_OV_01_Y'))
            self.assertAlmostEqual(h.get('F22_DEF_OV_01_X')/radius, -math.sin(bearing))
            self.assertAlmostEqual(h.get('F22_DEF_OV_01_Y')/radius, math.cos(bearing))
        h.seed({'MAIN_POWER': 0})
        h.update()
        self.assertEqual(h.get('F22_DEF_OV_01_SIGNAL'), 0)
        self.assertEqual(h.get('F22_DEF_OV_COUNT'), 0)

    def test_hud_distinguishes_rf_and_optical_warnings_and_honours_repeater_toggle(self):
        h = rwr_host()
        graph = hud_page(h)
        for signal, expected in ((1, None), (2, 'RADAR LOCK'), (3, 'RWR LAUNCH')):
            native_contact(h, signal)
            for text in ('RADAR LOCK', 'RWR LAUNCH'):
                self.assertEqual(bool(showing(h, graph, text)), text == expected)
        self.assertFalse(showing(h, graph, 'MISSILE'))
        h.seed({'F22_MWS_BLINK': 1})
        self.assertTrue(showing(h, graph, 'MISSILE'))
        self.assertTrue(showing(h, graph, 'RWR LAUNCH'))
        h.seed({'F22_RWR_HUD_ENABLED': 0})
        self.assertFalse(showing(h, graph, 'RWR LAUNCH'))
        self.assertTrue(showing(h, graph, 'MISSILE'))
        h.seed({'F22_RWR_HUD_ENABLED': 1, 'F22_DEF_OV_CURRENT': 0})
        self.assertFalse(showing(h, graph, 'RWR LAUNCH'))


if __name__ == '__main__':
    unittest.main()
