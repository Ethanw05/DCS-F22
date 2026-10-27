"""Weapon changes restore radar state without carrying GUN ACM into other modes."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
fixture = ROOT / 'tests/test_display_startup.py'
namespace = {'__file__': str(fixture)}
exec(compile(fixture.read_text().split('\nfor page in ', 1)[0], str(fixture), 'exec'), namespace)

SETUP = r'''
native={set_power=function()end};function GetDevice()return native end
local function put(n,v)get_param_handle(n):set(v)end
local function val(n)return get_param_handle(n):get()end
dofile(SCRIPT_ROOT..'Systems/Radar_System.lua')
dofile(SCRIPT_ROOT..'../../tests/radar_body_fixture.lua');post_initialize()
put('MAIN_POWER',1);put('F22N_RADAR_MODE',1);put('HUD_MODE',1);update()
local function mode(n)put('HUD_MODE',n);update()end
local function expect(name)
 assert(val('F22_RADAR_MODE_TEXT')==name,
  'expected '..name..', got '..tostring(val('F22_RADAR_MODE_TEXT')))
end
'''

lua = namespace['runtime']()
lua.execute(SETUP + r'''
-- User flight sequence: GUN -> SRM -> NAV -> MRM -> GUN -> NAV.
mode(5);SetCommand(10622,1);update();expect('WIDE')
mode(3);expect('RWS')
mode(1);expect('RWS')
mode(2);expect('RWS')
mode(5);expect('WIDE')
mode(1);expect('RWS')
-- Remember deliberate SRM and GUN patterns separately, not one shared value.
mode(3);SetCommand(10604,1);update();expect('VACQ')
mode(5);expect('WIDE');SetCommand(10605,1);update();expect('BORE')
mode(3);expect('VACQ')
mode(1);expect('RWS')
mode(5);expect('BORE')
-- Search preference and search volume survive the temporary GUN override.
mode(2);SetCommand(10602,1);SetCommand(10616,1);SetCommand(10614,1);update()
expect('TWS');local range=val('F22_RADAR_RANGE_NM')
local width=val('F22_RADAR_SEARCH_WIDTH_DEG');local el=val('F22_RADAR_EL_DEG')
mode(5);mode(2);expect('TWS')
assert(val('F22_RADAR_RANGE_NM')==range)
assert(val('F22_RADAR_SEARCH_WIDTH_DEG')==width and val('F22_RADAR_EL_DEG')==el)
-- Repeated selection / ordinary updates must not overwrite a manual pattern.
mode(5);SetCommand(10604,1);update();mode(5);expect('VACQ')
-- Radar OFF stays OFF through weapon changes; only its pattern state changes.
SetCommand(10600,1);update()
for _,n in ipairs({3,1,2,5,1})do mode(n);assert(val('RADAR_PWR')==0)end
assert(val('F22_RADAR_EMISSION_INHIBIT')==1)
''')
print('Radar weapon state: flight sequence, separate ACM memory, search settings, repeated selection and emission inhibit PASS')

lua = namespace['runtime']()
lua.execute(SETUP + r'''
-- The actual mode owner must not reapply a shared WIDE after radar restoration.
local radar_command,radar_update=SetCommand,update
local commands=dofile(SCRIPT_ROOT..'Systems/Radar_Commands.lua')
local logic=dofile(SCRIPT_ROOT..'Systems/Combat_Logic.lua').new(function(n,v)
 if n=='weapon_mode' then put('HUD_MODE',v)
 elseif commands[n]then radar_command(commands[n],1)end
end)
local c={locked=false,ground=false,primary_page=1}
local function press(n)
 logic:input(n,1,c);logic:input(n,0,c);radar_update()
end
press('gun');expect('WIDE');press('tms_up');radar_update();expect('BORE')
press('srm');expect('RWS');press('tms_down');radar_update();expect('VACQ')
press('gun');expect('BORE');press('srm');expect('VACQ')
press('aa');expect('RWS');press('aa');expect('VACQ')
press('mrm');expect('RWS');press('dogfight');expect('BORE')
press('dogfight');expect('RWS')
press('weapon_select');expect('VACQ');press('weapon_select');expect('BORE')
press('weapon_select');expect('RWS')
''')
print('Radar weapon state: actual mode owner, direct selection, A/A toggle, dogfight restore and weapon cycle PASS')

from radar_test_runtime import owned_runtime
lua=owned_runtime()
lua.execute("""
f.put('HUD_MODE',5);f.measure(42,700);f.tick()
assert(f.get('F22_RADAR_MODE_TEXT')=='ACQ')
f.put('HUD_MODE',3);f.tick()
assert(f.get('F22_RADAR_STT_VALID')==0 and f.get('F22_AESA_CONTROL_TARGET')==0)
f.lock(42);f.command(10602,1)
f.put('HUD_MODE',2);f.tick()
assert(f.get('F22_RADAR_STT_VALID')==1 and f.get('F22_ACM_MODE')==0)
f.tick(.6);assert(f.get('F22_RADAR_STT_VALID')==0)
assert(f.get('F22_RADAR_MODE_TEXT')=='TWS')
assert(#actions==0,'weapon switch dispatched a mechanical acquisition/unlock')
""")
print('Owned weapon transitions: unfinished acquisition cancelled, measured lock retained and post-loss search restored PASS')
