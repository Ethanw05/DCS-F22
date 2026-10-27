"""Protect the native adapter/device graph while new overhaul devices are added.

Several qualified common-DCS adapters address specific device slots. New devices
may be appended, but shifting an existing slot can bind a different native object.
This exercises the real Lua registration graph; it does not run the native host.
"""
from pathlib import Path
import contextlib
import io
import runpy

ROOT = Path(__file__).resolve().parents[1]
with contextlib.redirect_stdout(io.StringIO()):
    runtime = runpy.run_path(str(ROOT / 'tests/test_display_startup.py'))['runtime']

lua = runtime()
lua.execute('dofile(SCRIPT_ROOT.."device_init.lua")')
g = lua.globals()

# These slots are dereferenced by qualified native adapters, not arbitrary UI IDs.
native_contract = {
    'RADAR_NATIVE': (13, 'avLuaDevice'),
    'WEAPON_NATIVE': (15, 'avSimpleWeaponSystem'),
    'ILS_NATIVE': (24, 'avILS'),
    'NAV_POWER_NATIVE': (26, 'avSimpleElectricSystem'),
}
for name, (slot, native_class) in native_contract.items():
    assert g.devices[name] == slot, (name, g.devices[name], slot)
    creator = g.creators[slot]
    # RADAR_NATIVE can deliberately be disabled through Radar_Config.lua.
    if name == 'RADAR_NATIVE' and creator is None:
        continue
    assert creator is not None, (name, 'native service not registered')
    assert creator[1] == native_class, (name, creator[1], native_class)

device_ids = list(g.devices.values())
assert len(device_ids) == len(set(device_ids)), 'two device names share one slot'
for slot, creator in g.creators.items():
    assert slot in device_ids, ('creator has no declared device slot', slot)
    assert Path(creator[2]).is_file(), ('registered implementation is missing', creator[2])

print('Overhaul device graph: native 13/15/24/26 contracts, unique slots and existing registered implementations PASS')
