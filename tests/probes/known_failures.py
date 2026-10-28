"""Actual-owner pre-fix observations derived from VS-003/004 and F-INT-003.

Defects are recorded explicitly; this module never grants aircraft acceptance.
"""
import json
import subprocess
from host import Host


def physical(now):
    return {'EFM_POWER_OWNER': 1, 'EFM_PHYSICAL_VALID': 1,
            'EFM_PHYSICAL_GENERATION': 1, 'EFM_PHYSICAL_STAMP': now,
            'EFM_PHYSICAL_CLOCK_KIND': 1, 'F22_AP_CLOCK': now, 'MAIN_POWER': 1}


def stopped_altitude():
    h = Host()
    for name, value in {'getAngleOfSlide': 0, 'getVerticalAcceleration': 1,
                        'getAngleOfAttack': 0, 'getVerticalVelocity': 0}.items():
        h.sensor(name, value)
    h.load('Systems/HUD_Flight_Data.lua')
    h.seed(physical(10))
    h.seed({'F22_ALT_SELECTION': 0, 'F22_ALT_BARO_VALID': 1,
            'F22_ALT_BARO_FT': 3000, 'F22_ALT_BARO_STAMP': 10,
            'F22_ALT_SNAPSHOT_SCHEMA':1,'F22_ALT_SNAPSHOT_SEQUENCE':2,
            'F22_ALT_SNAPSHOT_GENERATION':1,'F22_ALT_SNAPSHOT_CLOCK_KIND':2,
            'F22_ALT_SNAPSHOT_TIME':10,'F22_ALT_SNAPSHOT_SELECTION':0})
    h.state.time = 10
    h.update()
    initial = h.get('HUD_ALT_VALID')
    h.seed(physical(20))
    h.state.time = 20
    h.update()
    observed = h.get('HUD_ALT_VALID')
    return dict(id='F-NAV-001',initial_valid=initial,expected_valid=0,
                actual_valid=observed,altitude_ft=h.get('HUD_ALT_FT'),
                status='known_failure' if initial == 1 and observed == 1 else
                'resolved' if initial == 1 and observed == 0 else 'changed_requires_review')


def competing_page():
    h = Host()
    for name, value in {'getTrueAirSpeed': 150, 'getIndicatedAirSpeed': 120,
                        'getVerticalAcceleration': 1, 'getAngleOfSlide': 0,
                        'getRateOfYaw': 0, 'getRateOfRoll': 0, 'getRateOfPitch': 0,
                        'getAngleOfAttack': 0, 'getVerticalVelocity': 0,
                        'getPitch': 0, 'getRoll': 0, 'getHeading': 0,
                        'getBarometricAltitude': 1000, 'getMachNumber': 0.5,
                        'getRadarAltitude': 900, 'getTotalFuelWeight': 5000}.items():
        h.sensor(name, value)
    h.env.get_cockpit_draw_argument_value = lambda _: 0
    h.env.get_aircraft_draw_argument_value = lambda _: 0
    h.env.set_aircraft_draw_argument_value = lambda *args: None
    h.env.print_message_to_user = lambda *args: None
    h.load('Systems/Avionics.lua')
    h.execute("routing=dofile(LockOn_Options.script_path..'Systems/Display_Routing.lua'); controller=dofile(LockOn_Options.script_path..'Systems/MFD_Controller.lua').new(get_param_handle,function() end,function() end)")
    h.seed(physical(10))
    h.seed({'BATTERY_POWER': 1,'APU_RPM_STATE': 2})
    h.execute('controller:update(true);controller:select(1,routing.pages.eng)')
    before = h.get('LMFD_ENG_PAGE')
    h.update()
    after = h.get('LMFD_ENG_PAGE')
    h.execute('controller:update(true)')
    restored = h.get('LMFD_ENG_PAGE')
    return dict(id='F-NAV-002',expected_sequence=[1,1,1],actual_sequence=[before,after,restored],
                status='known_failure' if [before,after,restored] == [1,0,1] else
                'resolved' if [before,after,restored] == [1,1,1] else 'changed_requires_review')


def native_read(executable):
    result = subprocess.run([str(executable),'--failed-read'], capture_output=True,
                            text=True, timeout=15)
    if result.returncode != 0:
        raise RuntimeError(result.stderr or result.stdout)
    data = json.loads(result.stdout)
    data.update(id='F-INT-003',status='known_failure' if data['exposed_value'] == 7
                else 'changed_requires_review',expected='failed conversion cannot be a successful value')
    return data
