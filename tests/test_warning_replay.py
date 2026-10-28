"""All recorded voices remain playable after the first one, including source/start failures."""
import contextlib,io,wave
from pathlib import Path
with contextlib.redirect_stdout(io.StringIO()):
    from test_display_startup import runtime
root=Path(__file__).resolve().parents[1]
durations={}
for name in ['pull_up','roll_left','roll_right','altitude','flight_controls','caution','terrain']:
    with wave.open(str(root/f'Sounds/Effects/Aircrafts/F-22A/Warnings/{name}.wav'),'rb')as w:
        durations[name]=w.getnframes()/w.getframerate()

for scenario in ['normal','create_error','create_nil','start_error','silent_start',
                 'delayed_start','numeric_status','unavailable_status','sticky_status']:
    lua=runtime();lua.globals().SCENARIO=scenario;lua.globals().DURATIONS=lua.table_from(durations)
    lua.execute('''
local now=0;local sounds={};local created={};local attempts={};local events={};local cuts=0
function get_model_time()return now end
function get_base_data()return {}end
function create_sound_host()return {create_sound=function(_,path)
 local name=path:match('([^/]+)$');created[name]=(created[name]or 0)+1
 if name=='roll_left'and created[name]==1 then
  if SCENARIO=='create_error'then error('transient source creation failure')end
  if SCENARIO=='create_nil'then return nil end
 end
 local s={ending=-1,beginning=-1}
 function s:update()end
 function s:is_playing()
  if SCENARIO=='unavailable_status'then error('status API unavailable')end
  if SCENARIO=='sticky_status'then return self.sticky or false end
  local active=now>=self.beginning and now<self.ending
  if SCENARIO=='numeric_status'then return active and 1 or 0 end
  return active
 end
 function s:stop()if now>=self.beginning and now<self.ending then cuts=cuts+1 end;self.ending=-1;self.sticky=false end
 function s:play_once()
  attempts[name]=(attempts[name]or 0)+1
  if name=='roll_left'and attempts[name]==1 then
   if SCENARIO=='start_error'then error('transient playback failure')end
   if SCENARIO=='silent_start'then return end
  end
  for _,other in pairs(sounds)do assert(now>=other.ending,'overlapping voices')end
  self.beginning=now+(SCENARIO=='delayed_start'and .1 or 0)
  self.sticky=true
  self.ending=self.beginning+DURATIONS[name];events[#events+1]=name
 end
 sounds[name]=s;return s
end}end
local function g(k)return get_param_handle(k):get()end
dofile(SCRIPT_ROOT..'Systems/Pilot_Warning_System.lua');local physical=dofile(SCRIPT_ROOT..'../../tests/warning_physical_fixture.lua')();update=physical:wrap(update);SetCommand=physical:wrap(SetCommand);post_initialize()
get_param_handle('MAIN_POWER'):set(1);get_param_handle('EFM_WEIGHT_ON_WHEELS'):set(1)
local expected={'pull_up','roll_left','roll_right','altitude','flight_controls','caution','terrain'}
-- Run the entire actual owner's test twice, reusing every sound source.
for pass=1,2 do
 SetCommand(11001,1);SetCommand(11001,0)
 for i=1,650 do now=now+.05;update()end
 assert(g('F22_PILOT_TEST_ACTIVE')==0,'voice test never completed')
 assert(#events==pass*#expected,'later clips were skipped after the first successful voice: '..SCENARIO)
 for i=1,#events do assert(events[i]==expected[(i-1)%#expected+1],'voice order changed or failed clip was skipped')end
 assert(g('F22_PILOT_AUDIO_PLAYING')==0 and g('F22_PILOT_AUDIO_PRIORITY')==0,'completed voice left its slot occupied')
end
assert(cuts==0,'natural sequence cut a sounding clip')
''')
    print('All seven voices twice, scenario:',scenario,'PASS')

# A normal warning must remain pending if play_once returns without starting.
lua=runtime();lua.globals().DURATIONS=lua.table_from(durations)
lua.execute('''
local now=0;local sounds={};local events={};local first=true
function get_model_time()return now end
function get_base_data()return {getSelfCoordinates=function()return 0,3000,0 end,
 getRoll=function()return 0 end,getHeading=function()return 0 end,
 getIndicatedAirSpeed=function()return 200 end,getVerticalAcceleration=function()return 1 end}end
package.preload.terrain=function()return {GetHeight=function()return 0 end}end
function create_sound_host()return {create_sound=function(_,path)
 local name=path:match('([^/]+)$');local s={ending=-1}
 function s:update()end
 function s:is_playing()return now<self.ending end
 function s:stop()self.ending=-1 end
 function s:play_once()
  if name=='altitude'and first then first=false;return end
  for _,other in pairs(sounds)do assert(not other:is_playing())end
  self.ending=now+DURATIONS[name];events[#events+1]=name
 end
 sounds[name]=s;return s
end}end
local function p(k,v)get_param_handle(k):set(v)end
local function g(k)return get_param_handle(k):get()end
local function advance(seconds)for i=1,math.ceil(seconds/.05)do now=now+.05;update()end end
dofile(SCRIPT_ROOT..'Systems/Pilot_Warning_System.lua');post_initialize()
-- The physical producer supplies fault authority; display colors do not.
for key,value in pairs({EFM_POWER_OWNER=1,EFM_PHYSICAL_VALID=1,EFM_PHYSICAL_GENERATION=1,
 EFM_PHYSICAL_CLOCK_KIND=1,MAIN_POWER=1,EFM_HUD_VALID=1,EFM_GROUND_VALID=1,
 EFM_WEIGHT_ON_WHEELS=0,EFM_HUD_VN=200,EFM_HUD_VE=0,EFM_HUD_VU=0,
 EFM_GEAR_DOWN_LOCKED=0,EFM_GEAR_UP_LOCKED=1,EFM_GEAR_UNSAFE=0,
 EFM_AIRDATA_VALID=1,EFM_AIRDATA_HEALTH=0,EFM_AIRDATA_CAS_MPS=200,
 EFM_FCS_INTEGRITY_VALID=1,EFM_FCS_DAMAGED=0,F22_ELECTRICAL_VALID=1,
 L_GEN_POWER=1,R_GEN_POWER=1,EFM_HYD_LEFT_PSI=4000,EFM_HYD_RIGHT_PSI=4000,
 EFM_ENGINE_VALID=1,EFM_ENGINE_LEFT_OIL_PSI=200,EFM_ENGINE_RIGHT_OIL_PSI=200})do p(key,value)end
local warning_update=update
function update()
 p('EFM_PHYSICAL_STAMP',now);p('F22_AP_CLOCK',now);p('EFM_AIRDATA_STAMP',now)
 p('EFM_PHYSICAL_GENERATION',g('EFM_PHYSICAL_GENERATION')+1)
 warning_update()
end
p('F22_ALT_RADAR_VALID',1);p('F22_ALT_RADAR_FT',700);p('F22_ALT_RADAR_FLOOR',500);update()
p('F22_ALT_RADAR_FT',400);advance(2.5)
assert(events[1]=='altitude','silent initial start consumed the actual altitude crossing')
p('F22_ALT_RADAR_FT',700) -- Reset repeating radar-low before the independent FCS/caution sequence.
p('EFM_FCS_INTEGRITY_VALID',1);p('EFM_FCS_DAMAGED',1);advance(3)
assert(events[2]=='flight_controls','second real warning remained silent')
p('EFM_FCS_DAMAGED',0);p('F22_ALT_RADAR_FT',700);p('OIL_LIGHT',1);p('EFM_ENGINE_LEFT_OIL_PSI',50);advance(4)
assert(events[3]=='caution','third real warning remained silent')
p('OIL_LIGHT',0);p('EFM_ENGINE_LEFT_OIL_PSI',200);p('F22_ALT_RADAR_FT',400);advance(1.95)
assert(#events==4 and events[4]=='altitude','previously used source failed to replay')
assert(g('F22_PILOT_AUDIO_PLAYING')==0)
''')
print('Normal warnings: retry silent first start, altitude -> flight controls -> caution -> altitude replay PASS')
