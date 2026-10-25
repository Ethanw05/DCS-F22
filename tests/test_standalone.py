"""Loader and device graph regression; native module-absence tests are separate."""
from pathlib import Path
import re
from lupa.lua51 import LuaRuntime
from test_display_startup import runtime

ROOT = Path(__file__).resolve().parents[1]
lua = LuaRuntime(unpack_returned_tuples=True)
lua.globals().current_mod_path = ROOT.as_posix()
lua.globals().path_exists = lambda path: Path(path).is_file()
lua.execute('''
function _(s) return s end
function declare_plugin(id, config) plugin_id=id;plugin_config=config end
function dofile(path) assert(path_exists(path),path);suspension={};ViewSettings={};SnapViews={} end
function make_view_settings(...) end
function make_flyable(name,cockpit,fm,comm) flyable={name,cockpit,fm,comm} end
function plugin_done() done=true end
function mount_vfs_model_path(...) end
function mount_vfs_sound_path(...) end
function mount_vfs_liveries_path(...) end
function mount_vfs_texture_path(...) end
''')
lua.execute((ROOT / 'entry.lua').read_text(encoding='utf-8-sig'))
g = lua.globals()
assert g.done and g.flyable[1] == 'F-22A'
assert g.flyable[2] == ROOT.as_posix() + '/Cockpit/Scripts/'
assert g.flyable[3][2].lower() == 'f22.dll'
assert g.flyable[4] == ROOT.as_posix() + '/comm.lua'
assert list(g.plugin_config.binaries.values()) == ['F22']
assert g.plugin_config.requiredModules is None

cockpit = runtime()
cockpit.execute('dofile(SCRIPT_ROOT.."device_init.lua")')
c = cockpit.globals()
for name, native_class in [('RADAR_NATIVE','avSimpleRadar'),
                           ('WEAPON_NATIVE','avSimpleWeaponSystem'),
                           ('RWR_NATIVE','avSimpleRWR'),
                           ('NAV_SYSTEM','avLuaDevice'),
                           ('EW_SYSTEM','avLuaDevice'),
                           ('MWS_NATIVE','avMLWS'),('MWS_SYSTEM','avLuaDevice')]:
    registration = c.creators[c.devices[name]]
    assert registration[1] == native_class
    assert Path(registration[2]).is_file()

# The common simulator libraries are expected; aircraft-specific avionics must
# never be introduced as a hidden adapter prerequisite.
allowed = {'CockpitBase.dll', 'Weapons.dll', 'WeaponsBase.dll', 'World.dll'}
for source in (ROOT / 'EFM/source').glob('Native*.cpp'):
    modules = re.findall(r'(?:GetModuleHandle|LoadLibrary)(?:W|A)?\(L?"([^"]+)"', source.read_text())
    assert set(modules) <= allowed, (source.name, modules)
print('Standalone loader, own cockpit/device graph and common-library adapter boundary PASS')
