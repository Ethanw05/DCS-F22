"""A longer replacement recording must not be cut by the old playback timer."""
import contextlib
import io
import wave
from pathlib import Path

with contextlib.redirect_stdout(io.StringIO()):
    from test_display_startup import runtime

root = Path(__file__).resolve().parents[1]
durations = {}
for name in ('terrain', 'pull_up', 'roll_right', 'roll_left'):
    with wave.open(str(root / f'Sounds/Effects/Aircrafts/F-22A/Warnings/{name}.wav'), 'rb') as clip:
        assert (clip.getnchannels(), clip.getsampwidth(), clip.getframerate()) == (1, 2, 44100)
        durations[name] = clip.getnframes() / clip.getframerate()

lua = runtime()
lua.globals().CLIP_SECONDS = durations['pull_up']
lua.execute('''
local now=10
function get_model_time()return now end
function get_base_data()return {}end
local sounding=false
function create_sound_host()return {create_sound=function(_,name)return {
 update=function()end,play_once=function()sounding=true end,
 stop=function()sounding=false end,is_playing=function()return sounding end
}end}end
dofile(SCRIPT_ROOT..'Systems/Pilot_Warning_System.lua');post_initialize()
local function p(n,v)get_param_handle(n):set(v)end
local function v(n)return get_param_handle(n):get()end
p('MAIN_POWER',1);p('EFM_WEIGHT_ON_WHEELS',1)
SetCommand(11001,1);SetCommand(11001,0);update()
assert(v('F22_PILOT_AUDIO_PLAYING')==1)
now=10+CLIP_SECONDS-.02;update()
assert(sounding and v('F22_PILOT_AUDIO_PLAYING')==1,'replacement PULL UP was cut before its last sample')
now=10+CLIP_SECONDS+.4;update()
assert(not sounding and v('F22_PILOT_AUDIO_PLAYING')==0,'stale true source status retained the voice slot past its complete recording')
sounding=false;now=now+.05;update()
assert(v('F22_PILOT_AUDIO_PLAYING')==0 and v('F22_PILOT_AUDIO_PRIORITY')==0,'natural completion did not release voice slot')
''')
print('User warning voices: PCM asset contract and actual owner full-clip playback timing PASS')
