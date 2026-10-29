"""R-RAD-001/002/011/019: actual owned reports, scalar health and elapsed input.

Independent requirements and host ports; no retired assertion/fixture imports.
Synthetic parameter packets verify software contracts, not DCS detection physics.
"""
import math
import unittest
from host import Host


def observation(h, source=84, degrees=50, stamp=10):
    angle = math.radians(degrees)
    return h.lua.table_from(dict(native_id=source, measurement_source=2,
        range=20000, az=angle, el=0, age=10-stamp, observed=stamp,
        north=20000*math.cos(angle), altitude=5000, east=20000*math.sin(angle),
        vn=50, vu=0, ve=0, velocity_valid=True, association_valid=True,
        filter_valid=True, iff=-1))


def system_host():
    h = Host()
    h.sensor('getSelfCoordinates', (0, 5000, 0))
    for name in ('getHeading', 'getPitch', 'getRoll'):
        h.sensor(name, 0)
    h.load('Systems/Radar_System.lua')
    h.env.post_initialize()
    h.seed(dict(MAIN_POWER=1, HUD_MODE=2, F22_SOI=2,
        F22_MFD_LAYOUT_READY=1, F22_PMFD_FORMAT=1, F22_AESA_DRIVER_READY=1,
        EFM_POWER_OWNER=1, EFM_PHYSICAL_VALID=1, EFM_PHYSICAL_GENERATION=1,
        EFM_PHYSICAL_CLOCK_KIND=1, EFM_MISSION_POWER_AVAILABLE=1,
        F22_ELECTRICAL_VALID=1, EFM_ENVIRONMENT_VALID=1,
        EFM_EQUIPMENT_TEMP_C=20, EFM_THERMAL_FAULT=0,
        F22_AESA_ARRAY_KNOWN=1, F22_AESA_ARRAY_HEALTH=1,
        EFM_HUD_VALID=1, EFM_HUD_VN=100, EFM_HUD_VU=0, EFM_HUD_VE=0))
    return h


def current_frame(h, now, sequence=2, source=42, degrees=0):
    h.state.time = now
    h.seed(dict(F22_AP_CLOCK=now, EFM_PHYSICAL_STAMP=now,
        F22_AESA_READY=1, F22_AESA_SEQUENCE=sequence,
        F22_AESA_TIME=now, F22_AESA_GENERATION=1))
    angle = math.radians(degrees)
    values = dict(VALID=1, ID=source, TIME=now, N=20000*math.cos(angle),
        U=5000, E=20000*math.sin(angle), VN=50, VU=0, VE=0,
        ASSOCIATION_VALID=1, FILTER_VALID=1, VELOCITY_VALID=1,
        VELOCITY_SIGMA_MPS=2, RANGE_SIGMA_M=10, HITS=3)
    h.seed({'F22A_01_'+key: value for key, value in values.items()})


def selected_host():
    h = system_host()
    current_frame(h, 10)
    h.env.SetCommand(10602, 1)  # TWS through saved command routing.
    h.update()
    current_frame(h, 10.1, 4)
    h.update()
    h.env.SetCommand(10618, 1)  # NEXT TRACK selects an actual admitted file.
    h.update()
    return h


class RadarSourceContract(unittest.TestCase):
    def test_search_request_and_owned_admission_agree(self):
        h = Host()
        c = h.load('Systems/Radar_Computer.lua').new()
        c.power, c.clock = True, 10
        c.command(c, 'tws')
        first = observation(h, source=42, degrees=0)
        c.update(c, 0, h.lua.table_from([first]), 1, True)
        c.command(c, 'next_track')
        plan = c.search_plan(c, h.lua.table())
        h.env.computer, h.env.plan = c, plan
        h.execute("adapter=dofile(LockOn_Options.script_path..'Systems/AESA_Control.lua').new("
            "function(k) return get_param_handle(k):get() end,"
            "function(k,v) get_param_handle(k):set(v) end);"
            "adapter:publish(10,computer,1,true,false,plan)")
        self.assertAlmostEqual(h.get('F22_AESA_CONTROL_HALF_AZ'), math.pi/3, places=12)
        self.assertAlmostEqual(plan.half_az, math.pi/3, places=12)
        for degrees in (0, 30, -30, 50, -50, 55, -55, 60, -60):
            self.assertTrue(c.inside(c, observation(h, degrees=degrees)), degrees)
        for degrees in (60.0001, -60.0001):
            self.assertFalse(c.inside(c, observation(h, degrees=degrees)), degrees)
        c.azimuth = 15
        self.assertTrue(c.inside(c, observation(h)))  # Already sensed before pilot edit.

    def test_report_limits_and_explicit_retained_source_exception(self):
        h = Host()
        c = h.load('Systems/Radar_Computer.lua').new()
        c.power, c.clock = True, 10
        for field, bad in [('age', -1), ('age', 21), ('range', 39),
                           ('az', float('nan')), ('el', float('inf')),
                           ('north', 'bad'), ('east', float('nan'))]:
            o = observation(h)
            o[field] = bad
            self.assertFalse(c.inside(c, o), (field, bad))
        c.update(c, 0, h.lua.table_from([observation(h)]), 1, True)
        retained = observation(h, degrees=80)
        self.assertTrue(c.inside(c, retained))  # Geometry changes cannot unsense same source.
        retained.north = float('nan')
        self.assertFalse(c.inside(c, retained))
        retained.north = 0
        retained.age = 21
        self.assertFalse(c.inside(c, retained))

    def test_support_depends_on_measured_age_and_association(self):
        h = Host()
        c = h.load('Systems/Radar_Computer.lua').new()
        c.power, c.clock = True, 10
        c.command(c, 'tws')
        for stamp in (10, 10.1):
            o = observation(h, source=42, degrees=0, stamp=stamp)
            o.age = 0
            c.clock = stamp
            c.update(c, 0, h.lua.table_from([o]), 1, True)
        c.command(c, 'next_track')
        plan = c.search_plan(c, h.lua.table_from([42, 42, 99]))
        self.assertEqual(plan.support_count, 2)
        self.assertEqual(plan.support_overdue, 1)
        self.assertIsNone(plan.uncovered)
        c.clock = 16.1001
        self.assertEqual(c.search_plan(c, h.lua.table_from([42])).support_overdue, 1)
        c.clock = 10.1
        c.tracks[c.selected].association_valid = False
        self.assertFalse(c.supportable(c, c.tracks[c.selected]))

    def test_full_system_controls_reports_and_tactical_consumer(self):
        h = selected_host()
        current_frame(h, 10.2, 6, source=84, degrees=50)
        # Keep both native-owned files in the same complete source snapshot.
        h.seed({f'F22A_02_{key}': h.get(f'F22A_01_{key}') for key in
            ('VALID','ID','TIME','N','U','E','VN','VU','VE','ASSOCIATION_VALID',
             'FILTER_VALID','VELOCITY_VALID','VELOCITY_SIGMA_MPS','RANGE_SIGMA_M','HITS')})
        current_frame(h, 10.2, 6)
        h.update()
        sources = {h.get(f'F22_RADAR_TACTICAL_{i:02}_SOURCE') for i in (1, 2)}
        self.assertEqual(sources, {42, 84})
        self.assertEqual(h.get('F22_RADAR_SEARCH_REQUEST_VALID'), 1)
        self.assertAlmostEqual(h.get('F22_AESA_CONTROL_HALF_AZ'), math.pi/3, places=12)
        h.seed({'F22_AESA_SEQUENCE': 7})
        h.update()
        self.assertEqual(h.get('F22_RADAR_OBSERVATION_BACKEND_READY'), 0)
        h = system_host()
        current_frame(h, 10)
        h.execute("local get=get_param_handle; get_param_handle=function(k) "
            "local handle=get(k); if k=='F22A_01_N' then return {get=function() "
            "get('F22_AESA_GENERATION'):set(2); return handle:get() end, set=handle.set} end; "
            "return handle end")
        h.update()
        self.assertEqual(h.get('F22_RADAR_OBSERVATION_BACKEND_READY'), 0)
        h.seed({'F22_AESA_SEQUENCE': 8, 'F22_AESA_GENERATION': 2})
        h.update()
        self.assertEqual(h.get('F22_RADAR_OBSERVATION_BACKEND_READY'), 1)
        h.seed({'HUD_MODE': 7})
        h.update()
        self.assertEqual(h.get('F22_RADAR_SEARCH_REQUEST_VALID'), 0)

    def test_selected_closure_rejects_each_invalid_component_and_recovers(self):
        h = selected_host()
        self.assertEqual(h.get('F22_RADAR_SELECTED_CLOSURE_VALID'), 1)
        self.assertAlmostEqual(h.get('F22_RADAR_SELECTED_CLOSURE_KTS'), 50*1.943844492, places=6)
        for component in ('VN', 'VU', 'VE'):
            for bad in (float('nan'), float('inf'), -float('inf'), 'bad', None):
                with self.subTest(component=component, bad=bad):
                    h.seed({'EFM_HUD_'+component: bad})
                    h.update()
                    self.assertEqual(h.get('F22_RADAR_SELECTED_CLOSURE_VALID'), 0)
                    self.assertEqual(h.get('F22_RADAR_SELECTED_CLOSURE_KTS'), 0)
                    self.assertEqual(h.get('F22_RADAR_SELECTED_VALID'), 1)
                    h.seed({'EFM_HUD_'+component: 100 if component == 'VN' else 0})
                    h.update()
                    self.assertEqual(h.get('F22_RADAR_SELECTED_CLOSURE_VALID'), 1)
        h.seed({'EFM_HUD_VN': 50})
        h.update()
        self.assertEqual(h.get('F22_RADAR_SELECTED_CLOSURE_VALID'), 1)
        self.assertEqual(h.get('F22_RADAR_SELECTED_CLOSURE_KTS'), 0)

    def test_closure_vector_frame_and_near_zero_domain(self):
        h = Host()
        module = h.load('Systems/Radar_Closure.lua')
        pose = h.lua.table_from(dict(north=0,altitude=0,east=0))
        track = h.lua.table_from(dict(north=300,altitude=400,east=0,vn=1,vu=2,ve=3,
            observed=10,velocity_valid=True))
        own = h.lua.table_from(dict(vn=11,vu=22,ve=33))
        self.assertAlmostEqual(module.relative(track,pose,own,10), 22*1.943844492, places=8)
        track.north, track.altitude = 0, 0
        self.assertIsNone(module.relative(track,pose,own,10))
        track.north = 40
        self.assertIsNone(module.relative(track,pose,own,10))
        track.north = 41
        self.assertIsNotNone(module.relative(track,pose,own,10))
        self.assertIsNone(module.relative(track,pose,own,9))

    def test_invalid_stt_never_falls_back_to_selected_closure(self):
        h = selected_host()
        h.env.SetCommand(10632, 1)
        h.update()
        current_frame(h, 10.2, 6)
        h.update()
        self.assertEqual(h.get('F22N_RADAR_MODE'), 3)
        self.assertEqual(h.get('F22_RADAR_STT_CLOSURE_VALID'), 1)
        current_frame(h, 10.3, 8)
        h.seed({'F22A_01_N': 30})  # Current lock observation is outside range domain.
        h.update()
        self.assertEqual(h.get('F22_RADAR_STT_VALID'), 0)
        self.assertEqual(h.get('F22_RADAR_SELECTED_CLOSURE_VALID'), 0)

    def test_cursor_uses_elapsed_clock_and_command_does_not_consume_it(self):
        results=[]
        for frequency in (30, 60, 240):
            h = system_host()
            current_frame(h, 10)
            h.update()
            h.env.SetCommand(10620, .5)
            for i in range(1, frequency+1):
                current_frame(h, 10+i/frequency, 2+2*i)
                if i == frequency//2:
                    h.env.SetCommand(10621, 0)  # Unrelated command synchronizes model time.
                h.update()
            results.append(h.get('F22_RADAR_CURSOR_X'))
        for value in results:
            self.assertAlmostEqual(value, 1.45*.2, delta=1e-6)

    def test_cursor_pause_jitter_and_loss_require_new_input(self):
        h = system_host()
        current_frame(h, 10)
        h.update()
        h.env.SetCommand(10620, .5)
        h.update()
        self.assertEqual(h.get('F22_RADAR_CURSOR_X'), 0)
        now = 10
        for step in (.01, .03, .005, .055, .1):
            now += step
            current_frame(h, now)
            h.update()
        self.assertAlmostEqual(h.get('F22_RADAR_CURSOR_X'), 1.45*.04, delta=1e-6)
        # Focus/page and power loss cancel held intent, including regain.
        for field, bad, restored in [('F22_SOI', 3, 2),
                                     ('F22_PMFD_FORMAT', 7, 1), ('MAIN_POWER', 0, 1)]:
            h.env.SetCommand(10620, .5)
            h.seed({field: bad})
            now += .01
            current_frame(h, now)
            h.update()
            before = h.get('F22_RADAR_CURSOR_X')
            h.seed({field: restored})
            now += .01
            current_frame(h, now)
            h.update()
            self.assertEqual(h.get('F22_RADAR_CURSOR_X'), before)
        h.env.SetCommand(10620, .5)
        current_frame(h, now+1)  # Unbounded elapsed gap cancels, never catches up.
        h.update()
        before = h.get('F22_RADAR_CURSOR_X')
        current_frame(h, now+1.01)
        h.update()
        self.assertEqual(h.get('F22_RADAR_CURSOR_X'), before)
        current_frame(h, 1)  # Rollback also withdraws held consent.
        h.update()
        self.assertEqual(h.get('F22_RADAR_CURSOR_X'), before)

    def test_surface_cursor_has_same_elapsed_policy(self):
        endpoints=[]
        for frequency in (30, 60, 240):
            h = Host()
            model = h.load('Systems/AG_Radar_Computer.lua').new()
            model.slew_x, model.slew_y = .5, .2
            for _ in range(frequency):
                model.slew(model, 1/frequency)
            endpoints.append((model.cursor_az, model.cursor_fraction))
            model.slew(model, 0)
            self.assertAlmostEqual(model.cursor_az, .225, delta=1e-6)
            model.slew(model, float('nan'))
            model.slew(model, .1)
            self.assertAlmostEqual(model.cursor_az, .225, delta=1e-6)
        for angle, fraction in endpoints:
            self.assertAlmostEqual(angle, .225, delta=1e-6)
            self.assertAlmostEqual(fraction, .56, delta=1e-6)

    def test_invalid_command_clock_cannot_restore_held_axis_on_recovery(self):
        h = system_host()
        current_frame(h, 10)
        h.update()
        original = h.env.get_model_time
        h.env.get_model_time = h.lua.eval('function() return 0/0 end')
        h.env.SetCommand(10620, .5)
        h.env.get_model_time = original
        current_frame(h, 10.1)
        h.update()
        current_frame(h, 10.2)
        h.update()
        self.assertEqual(h.get('F22_RADAR_CURSOR_X'), 0)

    def test_native_snapshot_rejects_future_stale_torn_and_bad_generation(self):
        for field, bad in [('F22_AESA_TIME', 11), ('F22_AESA_TIME', 9),
                           ('F22_AESA_GENERATION', 0), ('F22_AESA_SEQUENCE', 3)]:
            h = system_host()
            current_frame(h, 10)
            h.seed({field: bad})
            h.update()
            self.assertEqual(h.get('F22_RADAR_OBSERVATION_BACKEND_READY'), 0, field)
        h = system_host()
        current_frame(h, 10)
        h.execute("local get=get_param_handle; get_param_handle=function(k) "
            "local handle=get(k); if k=='F22A_01_N' then return {get=function() "
            "get('F22_AESA_SEQUENCE'):set(4); return handle:get() end, set=handle.set} end; "
            "return handle end")
        h.update()
        self.assertEqual(h.get('F22_RADAR_OBSERVATION_BACKEND_READY'), 0)

    def test_retired_noise_packets_cannot_publish_overlay_or_target(self):
        h = Host()
        h.seed({'F22_AG_RETURN_TIME': 10, 'F22_AG_RETURN_COUNT': 1,
                'F22G_1_N': 1000, 'F22G_1_U': 0, 'F22G_1_E': 0,
                'F22G_1_TIME': 10, 'F22G_1_RCS': 100})
        h.execute("ground=dofile(LockOn_Options.script_path..'Systems/AG_Radar_System.lua').new("
            "function(k) return get_param_handle(k):get() end,"
            "function(k,v) get_param_handle(k):set(v) end,function() end)")
        h.execute('ground:update(nil,10,0,false,false)')
        self.assertIsNone(h.get('F22_AG_MAP_1_VALID'))
        self.assertEqual(h.get('F22_AG_TRACK_VALID'), 0)
        h.execute("ground.model.sequence=9; ground.track_sequence=7;"
            "get_param_handle('F22_AG_DESIGNATION_VALID'):set(1);"
            "ground:update(nil,1,0,false,false)")
        self.assertEqual(h.get('F22_AG_DESIGNATION_VALID'), 0)
        self.assertEqual(h.get('F22_AG_DESIGNATION_SEQUENCE'), 0)
        self.assertGreater(h.get('F22_AG_TRACK_REQUEST_SEQUENCE'), 7)


if __name__ == '__main__':
    unittest.main()
