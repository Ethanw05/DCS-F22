"""Write-only DCS fixture without running the startup test on import."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
source = ROOT / 'tests/test_display_startup.py'
scope = {'__file__': str(source)}
exec(compile(source.read_text(encoding='utf-8').split('\nfor page in ', 1)[0],
             str(source), 'exec'), scope)
runtime = scope['runtime']


def power_frame(lua, *, battery, main, left=0, right=0, apu=0, spool=0,
                generation=1, stamp=10):
    """Declare a physical-provider sample; this fixture does not integrate power."""
    fields = {
        'EFM_POWER_OWNER': 1, 'EFM_PHYSICAL_VALID': 1,
        'EFM_PHYSICAL_GENERATION': generation, 'EFM_PHYSICAL_STAMP': stamp,
        'EFM_PHYSICAL_CLOCK_KIND': 1, 'F22_AP_CLOCK': stamp,
        'F22_ELECTRICAL_VALID': 1, 'BATTERY_POWER': battery, 'MAIN_POWER': main,
        'L_GEN_POWER': left, 'R_GEN_POWER': right, 'APU_POWER': apu,
        'APU_RPM_STATE': spool, 'EFM_APU_AUTO_SHUTDOWN': 0,
    }
    for key, value in fields.items():
        handle = lua.globals().get_param_handle(key)
        handle.set(handle, value)


def engine_frame(lua, *, left, right, generation=1, stamp=10):
    """A complete declared indication sample from the physical provider."""
    fields = {
        'EFM_POWER_OWNER': 1, 'EFM_PHYSICAL_VALID': 1,
        'EFM_PHYSICAL_GENERATION': generation, 'EFM_PHYSICAL_STAMP': stamp,
        'EFM_PHYSICAL_CLOCK_KIND': 1, 'F22_AP_CLOCK': stamp,
        'EFM_ENGINE_VALID': 1, 'EFM_VEHICLE_VALID': 1,
        'EFM_ENGINE_INDICATION_SCHEMA': 1,
    }
    for name, sample in (('LEFT', left), ('RIGHT', right)):
        for metric, suffix in (('rpm', 'RPM_PCT'), ('temperature', 'TEMP_C'),
                               ('oil', 'OIL_PSI'), ('nozzle', 'NOZZLE_PCT'),
                               ('flow', 'FLOW_KG_S')):
            fields[f'EFM_ENGINE_{name}_{suffix}'] = sample[metric]
        fields[f'EFM_HYD_{name}_PSI'] = sample['hydraulic']
    for key, value in fields.items():
        handle = lua.globals().get_param_handle(key)
        handle.set(handle, value)
