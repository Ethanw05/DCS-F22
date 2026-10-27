"""Actual voice/MWS/RWR owners recover from sticky status and a frozen voice owner."""
import contextlib,io
with contextlib.redirect_stdout(io.StringIO()):
 from test_display_startup import runtime
lua=runtime()
lua.execute('''
local now=10;local altitude=200;local sounds={};local cuts=0
function get_model_time()return now end
function get_base_data()return setmetatable({
 getSelfCoordinates=function()return 0,altitude,0 end,getRoll=function()return 0 end,
 getHeading=function()return 0 end,getIndicatedAirSpeed=function()return 200 end,
 getVerticalAcceleration=function()return 1 end},{__index=function()return function()return 0 end end})end
package.preload.terrain=function()return {GetHeight=function()return 0 end}end
function create_sound_host(host)return {create_sound=function(_,path)
 local s={playing=false,ending=-1};sounds[path]=s
 function s:update()end
 function s:is_playing()
  if path:find('/Warnings/',1,true)then return self.playing end -- sticky after sample completion
  return self.playing and 1 or 0 -- numeric native status must not treat zero as playing
 end
 function s:play_once()self.playing=true;self.ending=now+1.850952381 end
 function s:play_continue()self.playing=true end
 function s:stop()if self.ending>now then cuts=cuts+1 end;self.playing=false end
 return s
end}end
native={set_power=function()end};function GetDevice()return native end
local function p(k,v)get_param_handle(k):set(v)end
local function g(k)return get_param_handle(k):get()end
dofile(SCRIPT_ROOT..'Systems/Pilot_Warning_System.lua');post_initialize();local voice=update
dofile(SCRIPT_ROOT..'Systems/MWS_System.lua');post_initialize();local mws=update
dofile(SCRIPT_ROOT..'Systems/RWR_System.lua');post_initialize();local rwr=update
p('MAIN_POWER',1);p('EFM_HUD_VALID',1);p('EFM_GROUND_VALID',1);p('EFM_HUD_VN',200);p('EFM_HUD_VU',-120)
voice();assert(g('F22_PILOT_AUDIO_PRIORITY')==3)
local deadline=g('F22_PILOT_AUDIO_UNTIL');assert(deadline>now and deadline-now<3)
local function sensors()
 p('F22_MWS_NATIVE_READY',1);p('F22_MWS_NATIVE_TIME',now)
 for k,v in pairs({VALID=1,THREAT=1,SOURCE=900,TIME=now,AZ=.5,EL=0})do p('F22_MWS_NATIVE_01_'..k,v)end
 for k,v in pairs({SOURCE=700,TIME=0,AZIMUTH=.3,ELEVATION=0,SIGNAL=3,PRIORITY=1,GENERAL_TYPE=1,UNIT_TYPE='27'})do p('RWR_CONTACT_01_'..k,v)end
end
sensors();mws();assert(g('F22_MWS_ALERT')==1 and g('F22_MWS_AUDIO_PRIORITY')==0)
-- Do not update the pilot owner: stale priority=3 must expire at its consumer.
now=deadline+.05;sensors();mws()
assert(g('F22_PILOT_AUDIO_PRIORITY')==3 and g('F22_MWS_AUDIO_PRIORITY')==1,'frozen voice priority permanently muted detected missile')
assert(sounds['Aircrafts/F-22A/MWS/approach'].playing,'numeric-zero status prevented missile tone from starting')
p('F22_MWS_NATIVE_READY',0);mws();rwr()
assert(g('F22_RWR_ALERT')==3 and g('F22_RWR_AUDIO_LOOP')==3,'expired voice lease still suppressed RWR launch tone')
assert(sounds['Aircrafts/F-22A/RWR/launch'].playing,'numeric-zero status prevented RWR launch tone from starting')
-- Resume voice owner: its stale true source is stopped after the real recording,
-- and a clear threat cannot keep the slot occupied. No audible sample is cut.
altitude=2000;p('EFM_HUD_VU',120);voice()
assert(g('F22_PILOT_AUDIO_PRIORITY')==0 and g('F22_PILOT_AUDIO_UNTIL')==0 and cuts==0)
local gate=dofile(SCRIPT_ROOT..'Systems/Warning_Audio_Gate.lua')
p('F22_PILOT_AUDIO_PRIORITY',3);p('F22_PILOT_AUDIO_UNTIL',now+1000)
assert(gate.priority(g,now)==0,'corrupt future lease muted all threats')
''')
print('Voice/MWS/RWR: actual urgent voice, full recording, sticky status, frozen producer lease expiry and audible missile/launch tones PASS')
