"""Exercise bounded optical memory and actual passive/CM/ECM failure recovery."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
fixture = ROOT / 'tests/test_display_startup.py'
ns = {'__file__': str(fixture)}
exec(compile(fixture.read_text().split('\nfor page in ', 1)[0], str(fixture), 'exec'), ns)

lua = ns['runtime']()
lua.execute(r'''
local M=dofile(SCRIPT_ROOT..'Systems/MWS_Computer.lua');local r=M.new()
local contacts,slots,tracks=r.contacts,r.slots,r.tracks
local storage={};for i=1,M.capacity do storage[i]=slots[i]end
local observations={}
for i=1,17 do observations[i]={source=i,time=10,az=.1,el=0,threat=true}end
r:update(10,observations,true)
assert(#r.contacts==16 and r.input_truncated and not r.tracks[17],'ingress exceeded the fixed16 contract')
local function bounded()
 local count=0;for _ in pairs(r.tracks)do count=count+1 end
 assert(count<=16 and #r.contacts<=16 and r.contacts==contacts and r.slots==slots and r.tracks==tracks)
 for i=1,16 do assert(r.slots[i]==storage[i],'memory replacement allocated a new retained track')end
end
-- Frozen time cannot grow retained memory even when all sixteen IDs change.
for round=1,200 do
 for i=1,16 do observations[i].source=round*16+i end
 r:update(10,observations,true);bounded();assert(r.overflow)
end
assert(r.evictions>0)
r:update(10.6,{},true);bounded()
assert(#r.contacts==16 and r.contacts[1].coast and r.contacts[1].age>.59)
r:update(13.1,{},true);assert(#r.contacts==0 and next(r.tracks)==nil)
local o={source=42,time=14,az=0,el=0,threat=true}
r:update(14,{o},true);assert(r.tracks[42])
o.threat=false;o.time=13.9;r:update(14,{o},true);assert(r.tracks[42],'older non-threat retracted a newer observation')
o.time=14;r:update(14,{o},true);assert(not r.tracks[42])
o.threat=true;o.time=15;r:update(15,{o},true)
r:update(14,{},true);assert(#r.contacts==0,'epoch rewind retained future warning memory')
r:update(15,{o},true);r:update(15,{o},false);assert(#r.contacts==0)
for _,value in ipairs({0/0,math.huge,-1})do r:update(value,{o},true);assert(#r.contacts==0)end
bounded()
''')
print('MWS memory: fixed16 ingress/retained slots, frozen-time replacement, source-time retraction, '
      'coast/expiry, reset and reused storage PASS')

lua = ns['runtime']()
lua.execute(r'''
local now=100;function get_model_time()return now end
local function p(n,v)get_param_handle(n):set(v)end
local function g(n)return get_param_handle(n):get()end
local sounds={}
function create_sound_host()return {create_sound=function(_,name)
 local s={playing=false};sounds[name]=s
 function s:update()end;function s:is_playing()return self.playing and 1 or 0 end
 function s:play_continue()self.playing=true end;function s:play_once()self.playing=true end
 function s:stop()self.playing=false end;return s
end}end
local native={set_power=function(self,on)self.power=on end}
function GetDevice()return native end
for name,value in pairs({MAIN_POWER=1,RADAR_PWR=0,EFM_POWER_OWNER=1,EFM_PHYSICAL_VALID=1,
 EFM_PHYSICAL_GENERATION=1,EFM_PHYSICAL_STAMP=5,EFM_PHYSICAL_CLOCK_KIND=1,F22_AP_CLOCK=5,
 F22_ELECTRICAL_VALID=1,EFM_MISSION_POWER_AVAILABLE=0})do p(name,value)end
dofile(SCRIPT_ROOT..'Systems/MWS_System.lua');post_initialize();local mws=update
dofile(SCRIPT_ROOT..'Systems/RWR_System.lua');post_initialize();local rwr=update
local function optical(time)
 p('F22_MWS_NATIVE_READY',1);p('F22_MWS_NATIVE_TIME',now)
 for key,value in pairs({VALID=1,THREAT=1,SOURCE=900,TIME=time,AZ=.2,EL=0})do p('F22_MWS_NATIVE_01_'..key,value)end
end
for key,value in pairs({SOURCE=700,TIME=0,AZIMUTH=.3,ELEVATION=0,SIGNAL=3,PRIORITY=1,
 GENERAL_TYPE=1,UNIT_TYPE='27'})do p('RWR_CONTACT_01_'..key,value)end
optical(now);mws();rwr()
assert(g('F22_MWS_ALERT')==1 and g('F22_MWS_FRESH_COUNT')==1 and g('F22_RWR_ALERT')==3)
assert(native.power and g('F22_RWR_AUDIO_LOOP')==0,'qualified passive warnings depended on radar/mission power')
assert(sounds['Aircrafts/F-22A/MWS/approach'].playing)
-- Freeze the MWS owner while it holds priority1. The consumer must expire it.
now=100.2;rwr()
assert(g('F22_MWS_AUDIO_PRIORITY')==1 and g('F22_RWR_AUDIO_LOOP')==3,
 'frozen optical playback flag muted fresh RF launch warnings indefinitely')
now=100.6;optical(100);mws()
assert(g('F22_MWS_COUNT')==1 and g('F22_MWS_COAST')==1 and g('F22_MWS_FRESH_COUNT')==0)
assert(g('F22_MWS_ALERT')==0 and g('F22_MWS_BLINK')==0 and g('F22_MWS_AUDIO_PRIORITY')==0
 and not sounds['Aircrafts/F-22A/MWS/approach'].playing,'coast memory sounded a current inbound warning')
p('EFM_PHYSICAL_VALID',0);optical(now);mws();rwr()
assert(g('F22_MWS_POWER')==0 and g('F22_MWS_ALERT')==0 and g('F22_MWS_COUNT')==0
 and g('F22_RWR_POWER')==0 and g('F22_RWR_AUDIO_LOOP')==0 and not native.power)
p('EFM_POWER_OWNER',0);mws();rwr();assert(g('F22_RWR_POWER')==0,'owner loss revived legacy supply')
p('EFM_POWER_OWNER',1);p('EFM_PHYSICAL_VALID',1);p('F22_MWS_NATIVE_01_TIME',100);mws();rwr()
assert(g('F22_MWS_ALERT')==0,'restoration refreshed old optical evidence')
now=100.7;optical(now);mws();assert(g('F22_MWS_ALERT')==1)
p('F22_MWS_NATIVE_TIME','100.7');mws();assert(g('F22_MWS_READY')==0,'text timestamp was coerced into a valid sample')
''')
print('Actual MWS/RWR: independent passive supply, current warning versus coast, frozen playback '
      'lease expiry, invalid owner and fresh recovery PASS')

ui = ns['runtime']()
ui.execute('dofile(SCRIPT_ROOT.."HUD/page.lua")')
elements = {e['name']: e for _, e in ui.globals().elements.items()}
memory = elements['HUD_MWS_MEMORY']
assert memory['parent_element'] != 'HUD_MWS_WARNING'
assert list(memory['element_params'].values()) == ['HUD_POWER', 'F22_MWS_COAST', 'F22_MWS_POWER']
print('HUD MWS: coast memory has independent power/coast gates and does not inherit fresh blink PASS')

lua = ns['runtime']()
lua.execute(r'''
local now=100;function get_model_time()return now end
local function p(n,v)get_param_handle(n):set(v)end
local function g(n)return get_param_handle(n):get()end
local chaff,flare,ecm=100,100,false
local native={get_chaff_count=function()return chaff end,get_flare_count=function()return flare end,
 drop_chaff=function(_,count)chaff=chaff-count end,drop_flare=function(_,count)flare=flare-count end,
 get_ECM_status=function()return ecm and 1 or 0 end,set_ECM_status=function(_,value)ecm=value end}
function GetDevice()return native end
for name,value in pairs({MAIN_POWER=1,EFM_POWER_OWNER=1,EFM_PHYSICAL_VALID=1,
 EFM_PHYSICAL_GENERATION=1,EFM_PHYSICAL_STAMP=5,EFM_PHYSICAL_CLOCK_KIND=1,F22_AP_CLOCK=5,
 F22_ELECTRICAL_VALID=1,EFM_MISSION_POWER_AVAILABLE=0})do p(name,value)end
dofile(SCRIPT_ROOT..'Systems/EW_System.lua');post_initialize();update()
local function command(c)SetCommand(c,1);SetCommand(c,0)end
assert(g('EFM_POWER_OWNER')==1 and g('MAIN_POWER')==1 and g('F22_AP_CLOCK')==5,
 'post_initialize overwrote physical producer handles')
command(10840);assert(flare==99 and g('F22_CM_READY')==1,'APU-qualified low-load CM action unavailable')
command(10842);update();assert(not ecm and g('F22_ECM_POWER_AVAILABLE')==0 and g('F22_ECM_CONTROL_READY')==0)
p('EFM_MISSION_POWER_AVAILABLE',1);update();assert(not ecm,'mission-power restoration replayed unavailable ECM press')
command(10842);update();assert(ecm and g('F22_ECM_HOST_VALID')==1)
-- Optional ECM remains usable when a cartridge method is absent, and CM
-- remains usable with no ECM readback. These are independent capabilities.
local drop=native.drop_flare;native.drop_flare=nil;update()
assert(g('F22_CM_INVENTORY_VALID')==0 and g('F22_ECM_HOST_VALID')==1 and ecm)
native.drop_flare=drop;local read_ecm=native.get_ECM_status;native.get_ECM_status=nil;update()
command(10841);assert(chaff==99 and g('F22_CM_INVENTORY_VALID')==1 and g('F22_ECM_HOST_VALID')==0)
native.get_ECM_status=read_ecm
command(11100);update();local before_chaff,before_flare=chaff,flare
p('EFM_PHYSICAL_VALID',0);update()
assert(not ecm and g('F22_CM_READY')==0 and g('F22_CM_PROGRAM_RUNNING')==0 and g('F22_ECM_REQUESTED')==0)
SetCommand(10840,1);p('EFM_PHYSICAL_VALID',1);SetCommand(10840,1);update()
assert(chaff==before_chaff and flare==before_flare,'unavailable held press dispensed on restoration')
SetCommand(10840,0);command(10840);assert(flare==before_flare-1)
p('EFM_POWER_OWNER',0);command(10841);assert(chaff==before_chaff,'owned invalid frame revived legacy single dispense')
p('EFM_POWER_OWNER',1);update()
-- Self-test begins at the input's actual time, even with no intervening tick.
now=200;command(11109);now=200.1;update();assert(g('F22_CM_SELF_TEST')==1 and g('F22_CM_READY')==0)
now=201.1;update();assert(g('F22_CM_SELF_TEST')==0 and g('F22_CM_READY')==1)
command(11100);now=0/0;update()
assert(g('F22_CM_CLOCK_VALID')==0 and g('F22_CM_READY')==0 and g('F22_CM_PROGRAM_RUNNING')==0)
now=202;update();assert(g('F22_CM_PROGRAM_RUNNING')==0,'clock recovery replayed revoked program')
command(10842);update();assert(ecm)
p('EFM_PHYSICAL_GENERATION',2);update();assert(not ecm and g('F22_ECM_REQUESTED')==0)
p('EFM_MISSION_POWER_AVAILABLE',2);update()
assert(g('F22_EW_SUPPLY_VALID')==1 and g('F22_CM_READY')==1 and g('F22_ECM_POWER_VALID')==0)
post_initialize();assert(g('F22_CM_INVENTORY_VALID')==0 and g('F22_ECM_HOST_VALID')==0
 and g('EFM_POWER_OWNER')==1 and g('EFM_PHYSICAL_GENERATION')==2)
''')
print('Actual CM/ECM: electrical versus mission supply, independent APIs, owned-frame failure, '
      'held input/recovery, input-time test, clock/generation reset and provider preservation PASS')
