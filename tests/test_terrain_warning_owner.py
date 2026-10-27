"""Real predictor -> warning owner -> voice engine; no clip preemption or stale queue."""
from test_display_startup import runtime
lua=runtime()
lua.execute('''
local now=0;local altitude=1200;local bank=math.rad(80);local cas=200;local vu=-120
function get_model_time()return now end
function get_base_data()return {
 getSelfCoordinates=function()return 0,altitude,0 end,getRoll=function()return bank end,
 getHeading=function()return 0 end,getIndicatedAirSpeed=function()return cas end,
 getVerticalAcceleration=function()return 1 end}end
local traces=0
package.preload.terrain=function()return {GetHeight=function()return 0 end,
 isVisible=function(a,b,c,d,e,f)
  assert(type(a)=='number'and type(b)=='number'and type(c)=='number'and type(d)=='number'and type(e)=='number'and type(f)=='number')
  traces=traces+1;return true
 end}end
local sounds={};local events={};local cuts=0
function create_sound_host()return {create_sound=function(_,path)
 local name=path:match('([^/]+)$');local sound={ending=-1}
 function sound:update()end
 function sound:is_playing()return now<self.ending end
 function sound:play_once()
  for _,other in pairs(sounds)do assert(not other:is_playing(),'overlapping pilot voices')end
  local durations={pull_up=1.850952381,roll_left=1.418276644,roll_right=1.418276644}
  self.ending=now+(durations[name]or 2);events[#events+1]=name
 end
 function sound:stop()if self:is_playing()then cuts=cuts+1 end;self.ending=-1 end
 sounds[name]=sound;return sound
end}end
local function p(k,x)get_param_handle(k):set(x)end
local function g(k)return get_param_handle(k):get()end
dofile(SCRIPT_ROOT..'Systems/Pilot_Warning_System.lua');post_initialize()
p('MAIN_POWER',1);p('EFM_HUD_VALID',1);p('EFM_GROUND_VALID',1);p('EFM_HUD_VN',200);p('EFM_HUD_VU',vu)
-- Continuous descent gives each recovery path its real unsafe-onset timestamp.
local found=false
for i=0,60 do
 now=i*.2;altitude=1200-i*20;update()
 if #events>0 then found=true;break end
end
assert(found and events[1]=='roll_left','real continuous banked descent never issued ROLL LEFT')
assert(g('F22_TAWS_READY')==1 and g('F22_TAWS_TRACE_ACTIVE')==1 and traces>0)
assert(g('F22_TAWS_NO_ESCAPE')==1 and g('F22_TAWS_CUE_VALID')==1)
assert(g('F22_TAWS_CUE_ROT_RAD')>0,'vertical cue must remain horizon upright')
local ending=sounds.roll_left.ending
-- Change the live instruction twice within one utterance. The HUD changes now;
-- the voice finishes, then selects only the latest still-active directive.
now=now+.05;bank=0;altitude=80;update()
assert(g('F22_PILOT_WARNING_TEXT')=='PULL UP'and sounds.roll_left:is_playing()and #events==1)
now=now+.05;bank=-math.rad(80);update()
assert(g('F22_PILOT_WARNING_TEXT')=='ROLL RIGHT'and sounds.roll_left:is_playing()and #events==1)
assert(g('F22_TAWS_CUE_ROT_RAD')<0)
SetCommand(11000,1);SetCommand(11000,0);assert(sounds.roll_left:is_playing(),'ACK cut urgent recovery')
now=ending-.01;update();assert(#events==1 and sounds.roll_left:is_playing(),'timer cut the recording before its final sample')
now=ending+.01;update()
assert(#events==2 and events[2]=='roll_right'and sounds.roll_right:is_playing(),'latest directive did not get completed voice slot')
assert(cuts==0,'automatic recovery changes stopped a clip')
ending=sounds.roll_right.ending
-- Threat and sensor validity clear visual guidance without truncating speech.
now=now+.05;altitude=2000;vu=120;p('EFM_HUD_VU',vu);update()
assert(g('F22_TAWS_THREAT')==0 and g('F22_TAWS_CUE_VALID')==0 and sounds.roll_right:is_playing())
now=now+.05;cas=0;update()
assert(g('F22_TAWS_READY')==0 and sounds.roll_right:is_playing())
now=ending+.01;update();assert(#events==2 and g('F22_PILOT_AUDIO_PLAYING')==0 and cuts==0,'stale directive was queued after clearing')
-- User mute and electrical power remain intentional hard stops.
cas=200;altitude=80;vu=-120;p('EFM_HUD_VU',vu);now=now+.25;update();now=now+.25;update()
assert(g('F22_PILOT_AUDIO_PLAYING')==1)
SetCommand(11004,1);SetCommand(11004,0);now=now+.05;update()
assert(g('F22_TAWS_THREAT')==1 and g('F22_PILOT_AUDIO_PLAYING')==0 and cuts==1)
p('MAIN_POWER',0);update();assert(g('F22_TAWS_THREAT')==0 and g('F22_TAWS_CUE_VALID')==0)
''')
print('Terrain owner: real roll onset, live PULL/roll changes without cuts, full engine tail, latest-only handoff, cleared/stale sensing and explicit mute/power PASS')
