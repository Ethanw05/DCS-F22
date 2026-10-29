"""P-RAD-007: actual request owner, explicit provider no-go, no identity emulator."""
import math
import re
import unittest

from host import Host, ROOT
from test_radar_source_contract import system_host, current_frame
from test_radar_pilot_presentation import page_host, visible, array


def iff_host():
    h = Host()
    h.sensor('getSelfCoordinates', (0, 5000, 0))
    for name in ('getHeading', 'getPitch', 'getRoll'):
        h.sensor(name, 0)
    h.execute("""
        iff_attempts={}
        local load=dofile
        function dofile(path)
            local module=load(path)
            if string.sub(path,-16)=='IFF_Provider.lua' then
                local create=module.new
                function module.new()
                    local p=create()
                    local request=p.request
                    function p:request(intent)
                        local copy={}
                        for k,v in pairs(intent)do copy[k]=v end
                        local accepted,reason=request(self,intent)
                        copy.accepted,copy.reason=accepted,reason
                        iff_attempts[#iff_attempts+1]=copy
                        return accepted,reason
                    end
                    return p
                end
            end
            return module
        end
    """)
    h.load('Systems/Radar_System.lua')
    h.env.post_initialize()
    h.seed(dict(MAIN_POWER=1, HUD_MODE=2, F22_SOI=2,
                F22_MFD_LAYOUT_READY=1, F22_PMFD_FORMAT=1))
    h.state.time = 10
    h.update()
    return h


def attempts(h):
    return [h.env.iff_attempts[i] for i in range(1, len(h.env.iff_attempts)+1)]


class RadarIFFConsumer(unittest.TestCase):
    def assert_unavailable(self, h, requested=None):
        self.assertEqual(h.get('F22_RADAR_IFF_ON'), 0)
        self.assertEqual(h.get('F22N_IFF_INTERROGATOR_STATUS'), 0)
        self.assertEqual(h.get('F22_RADAR_IFF_UNAVAILABLE'), 1)
        self.assertEqual(h.get('F22_RADAR_IFF_PROVIDER_READY'), 1)
        self.assertEqual(h.get('F22_RADAR_IFF_REASON'), 1)
        if requested is not None:
            self.assertEqual(h.get('F22_RADAR_IFF_REQUESTED'), requested)
        self.assertEqual(len(h.state.actions), 0)

    def test_auto_intent_routes_once_per_activation_without_claiming_on(self):
        h = iff_host()
        self.assert_unavailable(h, 1)
        self.assertEqual(h.get('F22_RADAR_IFF_AUTO'), 1)
        self.assertEqual([v.kind for v in attempts(h)], ['auto'])
        for stamp in (10, 10.001, 10.09, 11):
            h.state.time = stamp
            h.update()
        self.assertEqual(len(attempts(h)), 1)  # No invented waveform/cadence.
        for value, enabled in ((14.375, 0), (14.25, 0), (14.375, 1)):
            h.env.SetCommand(10631, value)
            self.assertEqual(h.get('F22_RADAR_IFF_AUTO'), enabled)
            self.assert_unavailable(h, enabled)
        self.assertEqual([v.kind for v in attempts(h)], ['auto', 'auto'])
        self.assertTrue(all(v.accepted is False and v.reason == 'HOST_UNQUALIFIED'
                            for v in attempts(h)))

    def test_saved_manual_and_los_commands_keep_eight_second_intent(self):
        commands = Host().load('Systems/Radar_Commands.lua')
        for name, number in (('interrogate', 10619), ('interrogate_los', 10625), ('iff_auto', 10631)):
            self.assertEqual(commands[name], number)
        for kind in ('keyboard', 'joystick'):
            content = re.sub(r'\s+', '', (ROOT/'Input/F-22A'/kind/'default.lua').read_text())
            for number in (10619, 10631):
                self.assertIn(f'down={number},value_down=1,cockpit_device_id=14', content)
        for role in (2, 7):
            h = iff_host()
            h.seed({'HUD_MODE': role})
            h.env.SetCommand(10631, 14.375)  # AUTO off, explicit mode only.
            requested = ((10625, 2, 'interrogate_los'),) if role == 7 else (
                (10619, 1, 'interrogate'), (10625, 2, 'interrogate_los'))
            for command, mode, kind in requested:
                before = len(attempts(h))
                h.env.SetCommand(command, 14.375)
                self.assertEqual(len(attempts(h)), before+1)
                self.assertEqual(attempts(h)[-1].kind, kind)
                self.assertEqual(attempts(h)[-1].time, h.state.time)
                self.assertEqual(h.get('F22_RADAR_IFF_REQUEST'), mode)
                self.assertAlmostEqual(h.get('F22_RADAR_IFF_REMAINING'), 8)
                h.env.SetCommand(command, 14.25)
                self.assertEqual(len(attempts(h)), before+1)
                start = h.state.time
                for elapsed in (0, .1, 3.7, 8):
                    h.state.time = start+elapsed
                    h.update()
                    self.assertEqual(h.get('F22_RADAR_IFF_REQUEST'), mode)
                    self.assertAlmostEqual(h.get('F22_RADAR_IFF_REMAINING'), 8-elapsed)
                    self.assert_unavailable(h, 1)
                h.state.time = start+8.0001
                h.update()
                self.assertEqual(h.get('F22_RADAR_IFF_REQUEST'), 0)
                self.assert_unavailable(h, 0)

    def test_los_attempt_retains_actual_selected_measured_direction(self):
        h = iff_host()
        h.seed(dict(F22_AESA_DRIVER_READY=1, EFM_POWER_OWNER=1, EFM_PHYSICAL_VALID=1,
                    EFM_PHYSICAL_GENERATION=1, EFM_PHYSICAL_CLOCK_KIND=1,
                    EFM_MISSION_POWER_AVAILABLE=1, F22_ELECTRICAL_VALID=1,
                    EFM_ENVIRONMENT_VALID=1, EFM_EQUIPMENT_TEMP_C=20, EFM_THERMAL_FAULT=0,
                    F22_AESA_ARRAY_KNOWN=1, F22_AESA_ARRAY_HEALTH=1))
        h.env.SetCommand(10602, 1)
        for stamp, sequence in ((10, 2), (10.1, 4)):
            current_frame(h, stamp, sequence, degrees=30)
            h.seed({'F22A_01_U': 6000})
            h.update()
        h.env.SetCommand(10618, 1)
        h.update()
        self.assertEqual(h.get('F22_RADAR_SELECTED_VALID'), 1)
        h.env.SetCommand(10625, 1)
        request = attempts(h)[-1]
        self.assertEqual(request.kind, 'interrogate_los')
        self.assertAlmostEqual(request.az, math.pi/6, delta=1e-10)
        self.assertAlmostEqual(request.el, math.atan2(1000, 20000), delta=1e-10)
        self.assertEqual(request.time, 10.1)
        self.assertFalse(request.accepted)
        self.assert_unavailable(h, 1)

    def test_power_and_clock_retire_manual_requests_without_replay(self):
        for failure in ('power', 'rewind', 'missing', 'nan', 'infinite', 'negative'):
            h = iff_host()
            h.env.SetCommand(10631, 1)
            h.env.SetCommand(10625, 1)
            before = len(attempts(h))
            if failure == 'power':
                h.seed({'MAIN_POWER': 0})
            elif failure == 'rewind':
                h.state.time = 2
            elif failure == 'missing':
                h.env.get_model_time = None
            else:
                h.state.time = {'nan': float('nan'), 'infinite': float('inf'), 'negative': -1}[failure]
            h.update()
            self.assertEqual(h.get('F22_RADAR_IFF_REQUEST'), 0, failure)
            self.assert_unavailable(h, 0)
            h.seed({'MAIN_POWER': 1})
            h.state.time = 10.1
            h.env.get_model_time = h.lua.eval('function() return 10.1 end')
            h.update()
            self.assertEqual(len(attempts(h)), before, failure)
            self.assertEqual(h.get('F22_RADAR_IFF_REQUEST'), 0)
            h.env.SetCommand(10619, 1)
            self.assertEqual(attempts(h)[-1].kind, 'interrogate')
            self.assert_unavailable(h, 1)

    def test_reset_and_invalid_saved_values_preserve_auto_choice(self):
        h = iff_host()
        h.env.SetCommand(10631, 1)
        h.env.SetCommand(10619, 1)
        before = len(attempts(h))
        for command in (10619, 10625, 10631):
            for value in (0, -1, float('nan'), float('inf'), 'invalid'):
                h.env.SetCommand(command, value)
        self.assertEqual(len(attempts(h)), before)
        self.assertEqual(h.get('F22_RADAR_IFF_AUTO'), 0)
        h.env.post_initialize()
        self.assertEqual(h.get('F22_RADAR_IFF_REQUEST'), 0)
        self.assertEqual(h.get('F22_RADAR_IFF_AUTO'), 0)
        self.assert_unavailable(h, 0)
        h.update()
        self.assertEqual(len(attempts(h)), before)

    def test_module_rejects_provider_failure_and_unreviewed_available_backend(self):
        h = Host()
        state = h.load('Systems/Radar_IFF.lua').new()
        h.env.iff = state
        real_sample, real_request = state.provider.sample, state.provider.request
        for body in ("error('provider failed')", "return nil", "return {schema=2}",
                     "return {schema=1,provider_ready=true,available=true,status='READY',identity=1}"):
            state.provider.sample = h.lua.eval('function() '+body+' end')
            state.update(state, 10, True)
            self.assertFalse(state.enabled(state))
            self.assertFalse(state.available)
            self.assertFalse(state.provider_ready)
            self.assertEqual(state.identity, -1)
            self.assertFalse(state.identity_known)
        state.provider.sample = real_sample
        state.provider.request = h.lua.eval("function() return true,'ACCEPTED' end")
        accepted, _ = state.request(state, 'interrogate', 10, .2, -.1)
        self.assertFalse(accepted)
        self.assertFalse(state.provider_ready)
        state.provider.request = real_request
        state.update(state, 10.1, True)
        self.assertTrue(state.provider_ready)
        self.assertEqual(state.status, 'HOST_UNQUALIFIED')
        self.assertFalse(state.enabled(state))
        self.assertIsNone(state.reply)
        for args in (('bad', 10, 0, 0), ('interrogate', -1, 0, 0),
                     ('interrogate_los', float('nan'), 0, 0), ('interrogate', 10, float('inf'), 0)):
            self.assertFalse(state.request(state, *args))

    def test_no_response_or_simulated_responder_cannot_invent_affiliation(self):
        h = system_host()
        h.seed(dict(F22_IFF_RESPONDER_SIMULATED=1, F22_IFF_RESPONDER_HOST_READY=0,
                    F22_IFF_RESPONDER_READY=1, F22_IFF_REPLY_SEQUENCE=999,
                    F22_IFF_REPLY_RECENT=1, F22_IFF_REPLY_TIME=10,
                    F22N_RADAR_STT_FRIENDLY=1, F22N_RADAR_STT_IFF=0))
        current_frame(h, 10)
        h.update()
        h.env.SetCommand(10619, 1)
        current_frame(h, 10.1, 4)
        h.update()
        self.assert_unavailable(h, 1)
        self.assertEqual(h.get('F22_RADAR_TACTICAL_01_FRIENDLY'), 0)
        self.assertEqual(h.get('F22_RADAR_TACTICAL_01_HOSTILE'), 0)
        self.assertEqual(h.get('F22_RADAR_TACTICAL_01_IDENTITY_KNOWN'), 0)
        self.assertEqual(h.get('F22_RADAR_STT_IFF'), -1)

    def test_independent_fusion_friendly_protection_survives_unavailable_iff(self):
        h = Host()
        iff = h.load('Systems/Radar_IFF.lua').new()
        store = h.load('Systems/Tactical_Tracks.lua').new()
        h.env.store = store
        h.execute("""
            store:update(10,{radar={sequence=2,time=10,epoch=1,contacts={{
                source=42,age=0,az=0,el=0,range=20000,n=20000,u=5000,e=0,
                measurement_source=2,friendly=true,identity_known=true,identity_time=9.8,
                vn=0,vu=0,ve=0,velocity_valid=true}}}},true)
        """)
        first = next(iter(store.contacts.values()))
        self.assertTrue(first.friendly_protected)
        self.assertEqual(first.identity_evidence.radar.time, 9.8)
        iff.update(iff, 10, True)
        iff.request(iff, 'interrogate_los', 10, 0, 0)
        store.update(store, 10.1, h.lua.table(), True)
        retained = next(iter(store.contacts.values()))
        self.assertTrue(retained.friendly_protected)
        self.assertFalse(retained.identity_conflict)
        self.assertEqual(retained.identity_evidence.radar.time, 9.8)
        self.assertEqual(iff.identity, -1)
        self.assertFalse(iff.enabled(iff))

    def test_current_pmfd_uses_write_only_port_and_static_unavailable_gate(self):
        source = (ROOT/'Cockpit/Scripts/PMFD_CENTER/radar_format.lua').read_text(encoding='utf-8-sig')
        for aspect in (1, .7):
            h, baseline = page_host(aspect=aspect)
            h.execute(source)('IFF_PAGE', 'IFF_', 'IFF_DETAIL')
            records = {record.name: record for _, record in h.state.elements.items()
                       if record.added and record.name and record.name.startswith('IFF_')}
            labels = [name for name, record in records.items() if record.value == 'IFF UNAV']
            self.assertEqual(len(labels), 1)
            label = records[labels[0]]
            self.assertEqual(array(label.formats), [])
            self.assertAlmostEqual(label.init_pos[1], .79*.82*min(1, aspect))
            self.assertAlmostEqual(label.init_pos[2], .875*.82*min(1, aspect))
            h.seed(dict(MFD_OPACITY=1, IFF_PAGE=1, F22_AG_RADAR_PAGE=0,
                        F22_RADAR_IFF_REQUESTED=1, F22_RADAR_IFF_UNAVAILABLE=1))
            self.assertTrue(visible(h, records, labels[0]))
            for field in ('F22_RADAR_IFF_REQUESTED', 'F22_RADAR_IFF_UNAVAILABLE', 'IFF_PAGE'):
                h.seed({field: 0})
                self.assertFalse(visible(h, records, labels[0]))
                h.seed({field: 1})
            h.seed({'F22_AG_RADAR_PAGE': 1})
            self.assertFalse(visible(h, records, labels[0]))


if __name__ == '__main__':
    unittest.main()
