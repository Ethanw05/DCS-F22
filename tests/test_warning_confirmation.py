"""Accepted audio calls without playback status cannot acknowledge real events."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
fixture = ROOT / 'tests/test_display_startup.py'
scope = {'__file__': str(fixture)}
exec(compile(fixture.read_text().split('\nfor page in ', 1)[0], str(fixture), 'exec'), scope)
lua = scope['runtime']()
lua.execute(r'''
local now=0;local status=false;local requests=0
function get_model_time()return now end
function create_sound_host()return {create_sound=function()
 local source={ending=-1}
 function source:update()end
 function source:play_once()self.ending=now+1.14;requests=requests+1 end
 function source:is_playing()if not status then error('unavailable status')end;return now<self.ending end
 function source:stop()self.ending=-1 end
 return source
end}end
local function put(k,v)get_param_handle(k):set(v)end
local function get(k)return get_param_handle(k):get()end
dofile(SCRIPT_ROOT..'Systems/Pilot_Warning_System.lua');post_initialize()
put('MAIN_POWER',1);put('EFM_FCS_INTEGRITY_VALID',1);put('EFM_FCS_DAMAGED',1)
local function advance(seconds)for i=1,math.ceil(seconds/.05)do now=now+.05;update()end end
advance(.8)
assert(requests==1 and get('F22_PILOT_AUDIO_INFERRED')==1)
assert(get('F22_PILOT_AUDIO_STATUS_VALID')==0 and get('F22_PILOT_AUDIO_PRIORITY')==0)
advance(2);assert(requests>=2,'unconfirmed call falsely marked the real warning delivered')
status=true;advance(.1)
assert(get('F22_PILOT_AUDIO_STATUS_VALID')==1 and get('F22_PILOT_AUDIO_PRIORITY')==1)
local confirmed=requests;advance(3)
assert(requests==confirmed,'confirmed real event ignored its repeat policy')
''')
print('Audio status failure: bounded inferred slot, no false delivery, confirmed recovery and repeat accounting PASS')
