"""R-FLT-002/006/008: actual indications/adapters never become physical owners."""
import math
import unittest
from host import Host


def frame(host):
    host.seed({'EFM_POWER_OWNER': 1, 'EFM_PHYSICAL_VALID': 1,
               'EFM_PHYSICAL_GENERATION': 41, 'EFM_PHYSICAL_STAMP': 5,
               'EFM_PHYSICAL_CLOCK_KIND': 1, 'F22_AP_CLOCK': 5})


def engine_samples(host):
    frame(host)
    host.seed({'EFM_ENGINE_INDICATION_SCHEMA': 1, 'EFM_ENGINE_VALID': 1,
               'EFM_VEHICLE_VALID': 1, 'EFM_ENGINE_CONTROL_SCHEMA': 1})
    for side, rpm in [('LEFT', 70), ('RIGHT', 80)]:
        host.seed({f'EFM_ENGINE_{side}_RPM_PCT': rpm,
                   f'EFM_ENGINE_{side}_TEMP_C': 650,
                   f'EFM_ENGINE_{side}_OIL_PSI': 150,
                   f'EFM_ENGINE_{side}_NOZZLE_PCT': 40,
                   f'EFM_ENGINE_{side}_FLOW_KG_S': .5,
                   f'EFM_HYD_{side}_PSI': 2000})
    for side in ['L', 'R']:
        host.seed({f'EFM_{side}_ENGINE_PHASE': 4, f'EFM_{side}_START_FAULT': 0,
                   f'EFM_{side}_START_REJECTION': 0, f'EFM_{side}_ENGINE_CONTROL': 0,
                   f'EFM_{side}_PURGE_S': 0, f'EFM_{side}_CONTROL_AVAILABLE': 1,
                   f'EFM_{side}_AUG_AVAILABLE': 1, f'EFM_{side}_STARTER_ENGAGED': 0,
                   f'EFM_{side}_FUEL_VALVE': 1, f'EFM_{side}_STARTER_SELECTED': 0,
                   f'EFM_{side}_FUEL_SELECTED': 1, f'EFM_{side}_IGNITION_SELECTED': 0,
                   f'EFM_{side}_START_RESET_READY': 0})


class FlightOwners(unittest.TestCase):
    def test_actual_mainpanel_has_three_independent_lamp_bindings(self):
        h = Host()
        h.env.LoRegisterPanelControls = lambda: h.lua.table()
        h.env.CreateGauge = h.env.CreateElement
        h.load('mainpanel_init.lua')
        for variable, channel, argument in [('N_GEAR', 'N_GEAR_LIGHT', 723),
                                            ('L_GEAR', 'L_GEAR_LIGHT', 724),
                                            ('R_GEAR', 'R_GEAR_LIGHT', 725)]:
            declaration = h.state.elements[h.env[variable]]
            self.assertEqual(declaration.parameter_name, channel)
            self.assertEqual(declaration.arg_number, argument)

    def test_indications_preserve_valid_zero_and_isolate_bad_fields(self):
        h = Host()
        engine_samples(h)
        h.execute("indications=dofile(LockOn_Options.script_path..'Systems/Engine_Indications.lua').new(get_param_handle)")
        h.execute('indications:update()')
        self.assertEqual(h.get('RPM_L'), 70)
        self.assertAlmostEqual(h.get('L_FF_VALUE'), .5 * 3600 / .45359237, delta=.01)
        h.seed({'EFM_ENGINE_LEFT_OIL_PSI': math.nan})
        h.execute('indications:update()')
        self.assertEqual(h.get('F22_ENGINE_L_OIL_VALID'), 0)
        self.assertEqual(h.get('F22_ENGINE_L_RPM_VALID'), 1)
        self.assertEqual(h.get('F22_ENGINE_R_OIL_VALID'), 1)
        h.seed({'EFM_ENGINE_LEFT_OIL_PSI': 0})
        h.execute('indications:update()')
        self.assertEqual(h.get('F22_ENGINE_L_OIL_VALID'), 1)
        self.assertEqual(h.get('OIL_L'), 0)
        h.seed({'EFM_PHYSICAL_VALID': 0})
        h.execute('indications:update()')
        self.assertEqual(h.get('F22_ENGINE_R_RPM_VALID'), 0)

    def test_workflow_status_withdraws_stale_and_recovers_current_generation(self):
        h = Host()
        engine_samples(h)
        h.execute("status=dofile(LockOn_Options.script_path..'Systems/Engine_Status.lua').new(get_param_handle);status.update()")
        self.assertEqual(h.get('F22_ENGINE_L_STATUS'), 'L RUN')
        h.seed({'EFM_L_START_FAULT': 1, 'EFM_L_FUEL_VALVE': 0,
                'EFM_L_FUEL_SELECTED': 0, 'EFM_L_PURGE_S': 3.2})
        h.execute('status.update()')
        self.assertIn('PURGE 4S', h.get('F22_ENGINE_L_STATUS'))
        h.seed({'F22_AP_CLOCK': 6})
        h.execute('status.update()')
        self.assertEqual(h.get('F22_ENGINE_L_STATUS_VALID'), 0)
        self.assertEqual(h.get('F22_ENGINE_L_STATUS'), 'L UNKNOWN')
        engine_samples(h)
        h.seed({'EFM_PHYSICAL_GENERATION': 42})
        h.execute('status.update()')
        self.assertEqual(h.get('F22_ENGINE_L_STATUS'), 'L RUN')

    def test_power_requests_do_not_create_measured_supply_or_drain_second_battery(self):
        h = Host()
        h.execute("power=dofile(LockOn_Options.script_path..'Systems/Vehicle_Power_Adapter.lua').new()")
        h.execute('result=power:update(1,1,1,1)')
        self.assertFalse(h.env.result)
        self.assertIsNone(h.env.power.apu_rpm)
        self.assertEqual(h.get('F22_APU_REQUEST'), 1)
        frame(h)
        h.seed({'F22_ELECTRICAL_VALID': 1, 'APU_RPM_STATE': 0,
                'APU_POWER': 0, 'L_GEN_POWER': 0, 'R_GEN_POWER': 0,
                'MAIN_POWER': 0, 'EFM_APU_AUTO_SHUTDOWN': 0, 'F22_BATTERY_SOC': .3})
        h.execute('for i=1,200 do assert(power:update(1,1,1,1)) end')
        self.assertEqual(h.get('F22_BATTERY_SOC'), .3)
        self.assertEqual(h.env.power.apu_rpm, 0)
        self.assertEqual(h.env.power.main, 0)
        h.seed({'APU_RPM_STATE': 'ready'})
        h.execute('result=power:update(1,1,1,1)')
        self.assertFalse(h.env.result)
        self.assertIsNone(h.env.power.main)

    def test_actual_engine_device_preserves_measured_reserve_and_native_bindings(self):
        h = Host()
        h.execute('''
            function get_cockpit_draw_argument_value(_) return 0 end
            function get_aircraft_draw_argument_value(_) return 0 end
            function set_aircraft_draw_argument_value(_,_) end
            function get_clickable_element_reference(_) return nil end
            function create_sound_host(...)
                return {create_sound=function(_,name)
                    return {is_playing=function() return false end,stop=function() end,
                        play_once=function() end,play_continue=function() end,
                        update=function() end,set_pitch=function() end,set_gain=function() end,
                        set_lowpass=function() end}
                end}
            end
        ''')
        h.load('Systems/Engine_System.lua')
        h.env.post_initialize()
        engine_samples(h)
        h.seed({'F22_ELECTRICAL_VALID': 1, 'APU_RPM_STATE': 0,
                'APU_POWER': 0, 'L_GEN_POWER': 0, 'R_GEN_POWER': 0,
                'MAIN_POWER': 0, 'EFM_APU_AUTO_SHUTDOWN': 0, 'F22_BATTERY_SOC': .4})
        for _ in range(10):
            h.update()
        self.assertEqual(h.get('F22_BATTERY_SOC'), .4)
        commands = [h.state.actions[i].command for i in range(1, len(h.state.actions) + 1)]
        self.assertIn(10540, commands)
        self.assertIn(10541, commands)
        self.assertEqual(h.get('F22_APU_REQUEST'), 0)
