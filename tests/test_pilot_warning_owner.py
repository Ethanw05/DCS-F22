"""Actual warning owner: complete clips, missile gating, mute/test/power."""
from test_display_startup import runtime
lua=runtime()
lua.execute('''
local time=10;function get_model_time()return time end
function get_base_data()return {getSelfCoordinates=function()return 0,3000,0 end,getRoll=function()return 0 end}end
package.preload.terrain=function()return {GetHeight=function()return 0 end}end
local active={};local plays=0
function create_sound_host()
 return {create_sound=function(self,name)return {update=function()end,
  play_once=function()active[name]=true;plays=plays+1 end,
  is_playing=function()return active[name]or false end,stop=function()active[name]=false end}end}
end
dofile(SCRIPT_ROOT..'Systems/Pilot_Warning_System.lua');post_initialize()
local function p(k,v)get_param_handle(k):set(v)end
local function g(k)return get_param_handle(k):get()end
local function tap(c)SetCommand(c,28.375);SetCommand(c,28.25)end
p('MAIN_POWER',1);p('EFM_HUD_VALID',1);p('EFM_GROUND_VALID',1);p('EFM_HUD_VN',200)
p('F22_ALT_RADAR_VALID',1);p('F22_ALT_RADAR_FT',700);p('F22_ALT_RADAR_FLOOR',500);update()
assert(plays==0 and g('F22_PILOT_AUDIO_READY')==1)
time=10.1;p('F22_ALT_RADAR_FT',450);update()
assert(plays==1 and g('F22_PILOT_AUDIO_PLAYING')==1 and g('F22_PILOT_AUDIO_PRIORITY')==1)
time=10.2;p('F22_MWS_ALERT',1);update()
assert(g('F22_PILOT_AUDIO_PLAYING')==1 and g('F22_PILOT_WARNING_VALID')==1,'missile change cut a sounding clip')
tap(11004);time=10.3;update();assert(g('F22_PILOT_AUDIO_MUTED')==1 and g('F22_PILOT_WARNING_VALID')==1)
p('EFM_WEIGHT_ON_WHEELS',1);p('F22_MWS_ALERT',0);tap(11004);tap(11001);time=11;update()
assert(g('F22_PILOT_WARNING_VALID')==0 and g('F22_PILOT_TEST_ACTIVE')==1 and g('F22_PILOT_AUDIO_PLAYING')==1)
tap(11001);time=11.1;update();assert(g('F22_PILOT_TEST_ACTIVE')==0 and g('F22_PILOT_AUDIO_PLAYING')==0)
tap(11001);time=12;update();assert(g('F22_PILOT_AUDIO_PLAYING')==1)
p('MAIN_POWER',0);time=12.1;update()
assert(g('F22_PILOT_AUDIO_PLAYING')==0 and g('F22_PILOT_AUDIO_PRIORITY')==0 and g('F22_PILOT_WARNING_VALID')==0)
p('MAIN_POWER',1);time=13;update();assert(g('F22_PILOT_TEST_ACTIVE')==0,'power restore must not resume test')
time=1;update();assert(g('F22_PILOT_TEST_ACTIVE')==0 and g('F22_PILOT_AUDIO_PRIORITY')==0)
''')
print('Pilot warning owner: actual sound readback, full clips during missile changes, visual retention under mute, test/cancel, power and rewind PASS')
