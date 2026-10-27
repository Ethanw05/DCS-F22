"""Actual cockpit-device inputs select ACM from HUD focus and reach native scan outputs."""
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
local radar_command,radar_update=SetCommand,update
dofile(SCRIPT_ROOT..'Systems/Combat_System.lua');post_initialize()
local combat_command,combat_update=SetCommand,update
function dispatch_action(device,command,value)
 actions[#actions+1]={command,value,device}
 if device==devices.RADAR_COMPUTER then radar_command(command,value)
 elseif device==devices.WEAPON_SYSTEM and command==10800 then put('HUD_MODE',value)end
end
put('MAIN_POWER',1);put('F22N_RADAR_MODE',1);put('F22_PMFD_PAGE',1);put('HUD_MODE',1)
local function tick()combat_update();radar_update()end
local function press(c)
 combat_command(c,16.375);combat_command(c,16.25);tick()
end
local function expect(pattern)
 assert(val('F22_RADAR_MODE_TEXT')==pattern,
  'HUD-focus scan request expected '..pattern..', got '..tostring(val('F22_RADAR_MODE_TEXT')))
end
tick()
'''

lua = namespace['runtime']()
lua.execute(SETUP + r'''
-- Recorded user sequence: select HUD, select GUN, press vertical / boresight.
press(10704);assert(val('F22_SOI')==1)
press(10728);expect('WIDE')
press(10702);expect('VACQ')
assert(math.abs(2*val('F22_AESA_CONTROL_HALF_AZ')-math.rad(10))<1e-8)
assert(math.abs(2*val('F22_AESA_CONTROL_HALF_EL')-math.rad(59))<1e-8)
press(10700);expect('BORE')
assert(math.abs(2*val('F22_AESA_CONTROL_HALF_AZ')-math.rad(3.3))<1e-8)
assert(math.abs(2*val('F22_AESA_CONTROL_HALF_EL')-math.rad(3.3))<1e-8)
press(10701);expect('WIDE')
-- The selected pattern stays selected through time and repeat weapon presses.
press(10702);for i=1,120 do tick()end;expect('VACQ')
press(10728);expect('VACQ')
press(10729);expect('RWS');press(10700);expect('BORE')
press(10728);expect('VACQ');press(10729);expect('BORE')
press(10721);expect('RWS')
''')
print('HUD-focus ACM: encoded physical inputs, actual owners, native scan volumes, persistence and weapon-state restore PASS')

lua = namespace['runtime']()
lua.execute(SETUP + r'''
press(10704);press(10728)
local p='F22N_RADAR_CONTACT_01_'
put(p..'RANGE',700);put(p..'TIME',0);tick();tick()
assert(val('F22_RADAR_STT_VALID')==1)
local start=#actions;press(10702)
assert(val('F22_RADAR_STT_VALID')==1 and val('F22_ACM_MODE')==0)
for i=start+1,#actions do assert(actions[i][1]~=509 and actions[i][1]~=510)end
put(p..'TIME',-1);for i=1,12 do tick()end;expect('VACQ')
put(p..'ELEVATION',math.rad(30));put(p..'TIME',0);tick();expect('ACQ')
put(p..'TIME',-1);press(10700);expect('BORE')
''')
print('HUD-focus ACM: owned measured STT retained, post-loss return and in-progress acquisition switched PASS')

lua = namespace['runtime']()
lua.execute(SETUP + r'''
-- Reported flight: BORE stayed selected after focus moved to the left NAV
-- display. Physical TMS down/right were received but produced no radar request.
press(10704);press(10728);press(10700);expect('BORE')
put('F22_MFD_LAYOUT_READY',1);put('F22_LMFD_FORMAT',7)
press(10707);assert(val('F22_SOI')==3)
press(10702);expect('VACQ')
press(10701);expect('WIDE')
-- GUN/SRM acquisition controls belong to the selected weapon, regardless of
-- where the pilot last touched a bezel. Scope cursor controls remain local.
local fields={[2]='F22_PMFD_FORMAT',[3]='F22_LMFD_FORMAT',[4]='F22_RMFD_FORMAT',[5]='F22_CMFD_FORMAT'}
for _,weapon in ipairs({10728,10729})do
 press(weapon)
 for focus=2,5 do
  for _,page in ipairs({0,7,13,6,8,9,10,11,12})do
   put(fields[focus],page);combat_command(10742,focus);tick()
   press(10700);expect('BORE')
   assert(math.abs(2*val('F22_AESA_CONTROL_HALF_AZ')-math.rad(3.3))<1e-8)
   press(10702);expect('VACQ')
   assert(math.abs(2*val('F22_AESA_CONTROL_HALF_EL')-math.rad(59))<1e-8)
   press(10701);expect('WIDE')
   local start=#actions;press(10733);press(10726)
   assert(#actions==start,'unfocused cursor/range action reached radar')
  end
 end
end
''')
print('GUN/SRM ACM: reported left-NAV focus sequence and 72 non-radar display contexts reach native BORE/VACQ/WIDE; cursor/range remain local PASS')

lua = namespace['runtime']()
lua.execute(SETUP + r'''
press(10704);press(10728);press(10702);expect('VACQ')
-- Weapon acquisition remains available after selecting a head-down page;
-- scope designation and range changes still require the radar's focus.
for _,focus in ipairs({10707,10705})do
 press(focus);local start=#actions
 press(10700);press(10702);press(10701)
 assert(#actions>start,'a head-down page disabled weapon acquisition')
 expect('WIDE')
 start=#actions;press(10733);press(10726)
 assert(#actions==start,'head-down system page sent scope designation/range')
end
press(10704);press(10730);expect('RWS')
local start=#actions;press(10700);press(10702);assert(#actions==start,'HUD focus altered BVR radar')
-- A/G HUD mark/clear commands retain their existing owner.
press(10732);start=#actions;press(10700);press(10702)
local mark,clear=0,0
for i=start+1,#actions do
 if actions[i][1]==10810 then mark=mark+1 elseif actions[i][1]==10811 then clear=clear+1 end
end
assert(mark==1 and clear==1)
''')
print('ACM weapon controls remain available across focus changes; scope/BVR guards and A/G HUD designation unchanged PASS')

lua = namespace['runtime']()
lua.execute(SETUP + r'''
local rows={};log={INFO=1,write=function(name,level,row)rows[#rows+1]={name,row}end}
press(10704);press(10728);press(10702);expect('VACQ')
local received,dispatched,applied=false,false,false
for _,row in ipairs(rows)do
 if row[1]=='F22_HOTAS' and row[2]:find('tms_down value=16.375',1,true)
  and row[2]:find('decoded=1.000 mode=5 soi=1',1,true)then received=true end
 if row[1]=='F22_RADAR_REQUEST' and row[2]:find('action=vertical hud=5 soi=1 native=1',1,true)then dispatched=true end
 if row[1]=='F22_RADAR' and row[2]:find('mode=VACQ',1,true)then applied=true end
end
assert(received and dispatched and applied,'received/dispatched/applied diagnostics incomplete')
''')
print('HUD-focus ACM: logs distinguish received input, dispatched request and applied radar pattern PASS')
