"""Explicit source tuples for new navigation cases; no legacy test imports."""
from host import Host


def seed_physical(h, clock=2, generation=3):
    h.seed({'EFM_POWER_OWNER':1,'EFM_PHYSICAL_VALID':1,'EFM_PHYSICAL_GENERATION':generation,
            'EFM_PHYSICAL_STAMP':clock,'EFM_PHYSICAL_CLOCK_KIND':1,'F22_AP_CLOCK':clock,
            'MAIN_POWER':1,'BATTERY_POWER':1,'F22_ESSENTIAL_POWER':1,'EFM_HUD_VALID':1,
            'EFM_HUD_KINEMATICS_VALID':1,'EFM_HUD_VN':100,'EFM_HUD_VE':0,'EFM_HUD_VU':0,
            'EFM_GROUND_VALID':1,'EFM_WEIGHT_ON_WHEELS':0,'EFM_GEAR_UP_LOCKED':1,
            'EFM_GEAR_DOWN_LOCKED':0,'EFM_GEAR_UNSAFE':0,'EFM_AIRDATA_VALID':1,
            'EFM_AIRDATA_STAMP':clock,'EFM_AIRDATA_CAS_MPS':100,
            'EFM_AIRDATA_TAS_MPS':110,'EFM_AIRDATA_HEALTH':0})


def avionics_sensors(h):
    for name,value in {'getTrueAirSpeed':110,'getIndicatedAirSpeed':100,
                       'getVerticalAcceleration':1,'getAngleOfSlide':0,'getRateOfYaw':0,
                       'getRateOfRoll':0,'getRateOfPitch':0,'getAngleOfAttack':0,
                       'getVerticalVelocity':0,'getPitch':0,'getRoll':0,'getHeading':0,
                       'getBarometricAltitude':1000,'getMachNumber':.5,
                       'getRadarAltitude':600,'getTotalFuelWeight':5000}.items():
        h.sensor(name,value)
    h.sensor('getSelfCoordinates',(0,1000,0))
    h.env.get_cockpit_draw_argument_value=lambda _:0
    h.env.get_aircraft_draw_argument_value=lambda _:0
    h.env.set_aircraft_draw_argument_value=lambda *args:None
    h.env.print_message_to_user=lambda *args:None


def altitude_host():
    h=Host()
    avionics_sensors(h)
    seed_physical(h)
    h.state.time=10
    h.load('Systems/Altitude_System.lua')
    h.env.post_initialize()
    h.seed({'F22_ALTIMETER_NATIVE_READY':1,'F22_ALTIMETER_NATIVE_VALID':1,
            'F22_ALTIMETER_RESULT_TIME':10,'F22_ALT_ACTUAL_PRESSURE_MMHG':760,
            'F22_ALT_NATIVE_BARO_M':1000,'F22_ALT_STANDBY_NATIVE_M':900,
            'F22_ALT_STANDBY_NATIVE_STAMP':10,'F22_ALT_STANDBY_NATIVE_VALID':1})
    producer=h.env.update
    producer()
    return h,producer
