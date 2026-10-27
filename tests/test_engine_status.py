"""Engine indications consume actual coherent physical states and never drive them."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
fixture = ROOT/'tests/test_display_startup.py'
scope = {'__file__': str(fixture)}
exec(compile(fixture.read_text().split('\nfor page in ', 1)[0], str(fixture), 'exec'), scope)
lua = scope['runtime']()
lua.execute(r'''
local function set(k,v)get_param_handle(k):set(v)end
local function get(k)return get_param_handle(k):get()end
local status=dofile(SCRIPT_ROOT..'Systems/Engine_Status.lua').new(get_param_handle)
status:update();assert(get('F22_ENGINE_L_STATUS_VALID')==0)
set('EFM_POWER_OWNER',1);set('EFM_PHYSICAL_VALID',1);set('EFM_PHYSICAL_GENERATION',1)
set('EFM_PHYSICAL_STAMP',10);set('EFM_PHYSICAL_CLOCK_KIND',1);set('F22_AP_CLOCK',10)
set('EFM_ENGINE_CONTROL_SCHEMA',1)
for _,side in ipairs({'L','R'})do
 set('EFM_'..side..'_ENGINE_PHASE',1);set('EFM_'..side..'_STARTER_SELECTED',1)
 set('EFM_'..side..'_STARTER_ENGAGED',1);set('EFM_'..side..'_CONTROL_AVAILABLE',1)
 set('EFM_'..side..'_AUG_AVAILABLE',1)
end
status:update();assert(get('F22_ENGINE_L_STATUS')=='L DRY CRANK')
assert(get('F22_ENGINE_R_CONTROL')=='CONTROL OK')
set('EFM_L_START_FAULT',1);set('EFM_L_PURGE_S',4.99);status:update()
assert(get('F22_ENGINE_L_STATUS')=='L NO LIGHT PURGE 5S')
set('EFM_L_PURGE_S',0);set('EFM_L_START_RESET_READY',1);status:update()
assert(get('F22_ENGINE_L_STATUS')=='L NO LIGHT RESET READY')
set('EFM_L_START_FAULT',0);set('EFM_L_START_RESET_READY',0)
set('EFM_L_ENGINE_PHASE',4);set('EFM_L_ENGINE_CONTROL',1);set('EFM_L_AUG_AVAILABLE',0)
status:update();assert(get('F22_ENGINE_L_STATUS')=='L RUN')
assert(get('F22_ENGINE_L_CONTROL')=='CONTROL DEGRADED')
set('EFM_L_FUEL_VALVE',1);set('EFM_L_FUEL_SELECTED',0);status:update()
assert(get('F22_ENGINE_L_STATUS_VALID')==0 and get('F22_ENGINE_R_STATUS_VALID')==1)
set('EFM_L_FUEL_SELECTED',1);set('EFM_PHYSICAL_STAMP',9);status:update()
assert(get('F22_ENGINE_L_STATUS')=='L UNKNOWN')
set('EFM_POWER_OWNER',0);status:update()
assert(get('F22_ENGINE_L_STATUS_VALID')==0,'old native data revived after owner loss')
set('EFM_POWER_OWNER',1);set('EFM_PHYSICAL_GENERATION',2)
set('EFM_PHYSICAL_STAMP',0);set('F22_AP_CLOCK',0);status:update()
assert(get('F22_ENGINE_L_STATUS')=='L RUN')
set('EFM_L_ENGINE_CONTROL',2);set('EFM_L_CONTROL_AVAILABLE',0);set('EFM_L_START_FAULT',4)
status:update();assert(get('F22_ENGINE_L_CONTROL')=='CONTROL LOST')
assert(get('EFM_L_START_FAULT')==4 and get('EFM_L_FUEL_SELECTED')==1,'consumer changed physical state')
set('EFM_ENGINE_CONTROL_SCHEMA',2);status:update()
assert(get('F22_ENGINE_L_STATUS_VALID')==0)
''')
print('Engine workflow indications: dry/run/fault/purge/reset/control, coherent epochs and no writes to physics PASS')
faults = re.findall(r'\{"(f22_[^"]+)", Signal::',
                   (ROOT/'EFM/source/VehicleFaults.h').read_text(encoding='utf-8'))
registration = (ROOT/'F-22A.lua').read_text(encoding='utf-8-sig')
for fault in faults:
    assert len(fault) < 32
    entries = re.findall(r"\{\s*id\s*=\s*'" + re.escape(fault) + r"'[^\n]+", registration)
    assert len(entries) == 1 and 'enable = false' in entries[0], fault
print(f'All {len(faults)} bounded physical fault IDs are registered once and disabled by default PASS')
