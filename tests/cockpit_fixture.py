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
