"""Audit regressions: producer failure, IFF scope, focus, emissions and identity.

The sensor boundary is synthetic; real Lua producers and consumers run together.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
fixture = ROOT / 'tests/test_display_startup.py'
namespace = {'__file__': str(fixture)}
exec(compile(fixture.read_text().split('\nfor page in ', 1)[0], str(fixture), 'exec'), namespace)
runtime = namespace['runtime']

lua = runtime()
lua.execute(r'''
local now=1;function get_model_time()return now end
native={set_power=function()end};function GetDevice()return native end
local function put(n,v)get_param_handle(n):set(v)end
local function val(n)return get_param_handle(n):get()end
dofile(SCRIPT_ROOT..'Systems/Radar_System.lua');post_initialize()
local radar_update,radar_command=update,SetCommand
dofile(SCRIPT_ROOT..'Systems/Radar_Data_Bridge.lua');post_initialize()
local bridge_update=update
put('MAIN_POWER',1);put('HUD_MODE',2);put('F22N_RADAR_MODE',3)
put('EFM_HUD_VALID',1);put('EFM_HUD_VN',200)
put('F22_STT_MOTION_VALID',1);put('F22_STT_ID',123)
put('F22_STT_PN',5000);put('F22_STT_PU',0);put('F22_STT_PE',0)
put('F22_STT_VN',100);put('F22_STT_VU',0);put('F22_STT_VE',0)
put('F22N_RADAR_STT_RANGE',5000);put('F22N_RADAR_STT_AZIMUTH',0);put('F22N_RADAR_STT_ELEVATION',0)
radar_command(10602,1)
local function tick(fresh)
 now=now+.05;if fresh then put('F22_STT_TIME',now)end
 radar_update();bridge_update()
end
for i=1,60 do tick(true);assert(val('HUD_AA_TARGET_VALID')==1,'stationary fresh STT rejected')end
assert(val('F22_RADAR_STT_VALID')==1 and val('HUD_GUN_TARGET_VALID')==1)
assert(val('HUD_AA_CLOSURE_VALID')==1 and math.abs(val('HUD_AA_TGT_CLOSURE_KTS')-194.3844492)<.01)
-- Identical geometry remains valid only while the independent timestamp advances.
for i=1,13 do tick(false)end
assert(val('F22_RADAR_STT_VALID')==0 and val('HUD_AA_TARGET_VALID')==0 and val('HUD_GUN_TARGET_VALID')==0)
assert(val('HUD_TD_VALID')==0 and val('HUD_AA_CLOSURE_VALID')==0,'stale target left live cues')
tick(true);assert(val('HUD_AA_TARGET_VALID')==1)
-- Freeze the Lua producer while the native sensor itself remains alive.
for i=1,13 do now=now+.05;put('F22_STT_TIME',now);bridge_update()end
assert(val('HUD_AA_TARGET_VALID')==0,'HUD renewed a frozen producer snapshot')
tick(true);put('F22_STT_MOTION_VALID',0);bridge_update()
assert(val('HUD_AA_TARGET_VALID')==0,'native invalidation ignored between owner updates')
put('F22_STT_MOTION_VALID',1);tick(true)
put('F22_STT_ID',456);bridge_update()
assert(val('HUD_AA_TARGET_VALID')==0,'new native identity reused previous target snapshot')
tick(true);assert(val('HUD_AA_TARGET_VALID')==1)
now=0;bridge_update();assert(val('HUD_AA_TARGET_VALID')==0,'future timestamp survived restart')
tick(true);put('MAIN_POWER',0);radar_update();bridge_update()
assert(val('F22_RADAR_STT_VALID')==0 and val('HUD_TD_VALID')==0)
''')
print('STT: stationary fresh measurements, frozen native/Lua producers, invalidation, ID change, rewind and power PASS')

lua = runtime()
lua.execute(r'''
local m=dofile(SCRIPT_ROOT..'Systems/Radar_IFF.lua')
local s=m.new();s:update(10,true)
assert(s:enabled(),'automatic identification default lost')
s:request('interrogate_los',10,math.rad(20),math.rad(5))
assert(s:reply(1,10.1,math.rad(20),math.rad(5))==1)
assert(s:reply(1,10.1,math.rad(-20),math.rad(5))==-1,'LOS interrogation accepted another sector')
assert(s:reply(1,9.9,math.rad(20),math.rad(5))==-1,'manual request reused a pre-request reply')
s:request('interrogate',10.2,0,0)
assert(s:reply(1,10.3,math.rad(-20),0)==1,'wide interrogation remained LOS gated')
assert(s:reply(0,10.3,0,0)==-1 and s:reply(2,10.3,0,0)==-1,'native coalition became combat ID')
s:toggle_auto();s:update(20,true);assert(not s:enabled(),'expired manual request stayed on')
s:request('interrogate_los',20,0,0);assert(s:enabled())
s:update(20.1,false);assert(not s:enabled(),'power loss retained an interrogation')
s:update(1,true);assert(not s:enabled(),'rewind restored an old manual request')
''')
print('IFF: automatic setting, distinct wide/LOS requests, request time, unknown classification and expiry PASS')

lua = runtime()
lua.execute(r'''
local now=10;function get_model_time()return now end
native={set_power=function()end};function GetDevice()return native end
local function put(n,v)get_param_handle(n):set(v)end
local function val(n)return get_param_handle(n):get()end
dofile(SCRIPT_ROOT..'Systems/Radar_System.lua');post_initialize()
put('MAIN_POWER',1);put('F22N_RADAR_MODE',1);SetCommand(10602,1);SetCommand(10631,1)
put('F22_RADAR_OBSERVATIONS_READY',1);put('F22_RADAR_OBSERVATION_COUNT',2)
for i,a in ipairs({0,math.rad(20)})do
 local p=string.format('F22O_%02d_',i)
 for k,v in pairs({ID=500+i,AGE=0,NORTH=10000*math.cos(a),ALTITUDE=0,EAST=10000*math.sin(a),VN=0,VU=0,VE=0,IFF=1})do put(p..k,v)end
end
update();assert(val('F22_RADAR_IFF_ON')==0 and val('F22_SCOPE_01_AFFILIATION')==-1)
SetCommand(10625,1);now=10.1;update()
local friendly,unknown=0,0
for i=1,2 do local a=val(string.format('F22_SCOPE_%02d_AFFILIATION',i))
 if a==1 then friendly=friendly+1 elseif a==-1 then unknown=unknown+1 end
end
assert(friendly==1 and unknown==1,'LOS scope not applied by actual observation producer')
SetCommand(10619,1);now=10.2;update()
assert(val('F22_SCOPE_01_AFFILIATION')==1 and val('F22_SCOPE_02_AFFILIATION')==1)
now=20;update();assert(val('F22_RADAR_IFF_ON')==0 and val('F22_RADAR_IFF_REQUEST')==0)
''')
print('IFF owner integration: automatic OFF, isolated LOS reply, wide reply and native interrogator expiry PASS')

lua = runtime()
lua.execute(r'''
local events={}
local s=dofile(SCRIPT_ROOT..'Systems/Combat_Logic.lua').new(function(n,v)events[#events+1]=n end)
local c={ground=false,locked=false,selected=false}
local function press(n)s:input(n,1,c);s:input(n,0,c)end
press('dms_up');events={};press('tdc');press('tms_up');press('expand')
assert(s.soi==1 and #events==0,'HUD focus still controlled radar')
press('dms_right');events={};press('tdc');assert(s.soi==4 and #events==0)
press('dms_down');assert(s.soi==2)
events={};press('tdc');assert(#events==1 and events[1]=='designate')
s:input('tms_right',1,c);press('dms_up');events={};s:update(2,c);s:input('tms_right',0,c)
assert(#events==0,'deferred radar action survived a focus change')
for _,name in ipairs({'srm','ag','gun'})do
 events={};press(name)
 for _,event in ipairs(events)do assert(event~='radar_operate','weapon selection forces emissions')end
end
''')
print('HOTAS: actual focus routing, deferred-action cancellation and passive weapon selection PASS')

lua = runtime()
lua.execute(r'''
native={set_power=function()end};function GetDevice()return native end
local function put(n,v)get_param_handle(n):set(v)end
local function val(n)return get_param_handle(n):get()end
dofile(SCRIPT_ROOT..'Systems/Radar_System.lua');post_initialize()
put('MAIN_POWER',1);put('F22N_RADAR_MODE',1)
SetCommand(10602,1);update();assert(val('RADAR_PWR')==1)
SetCommand(10600,1);update();assert(val('RADAR_PWR')==0)
for _,cmd in ipairs({10626,10627,10604,10605,10622,10601,10602,10606})do
 SetCommand(cmd,1);update();assert(val('RADAR_PWR')==0,'mode selection overrode explicit emission inhibit')
end
assert(val('F22_RADAR_EMISSION_INHIBIT')==1)
SetCommand(10600,1);update();assert(val('RADAR_PWR')==1 and val('F22_RADAR_EMISSION_INHIBIT')==0)
put('F22_RADAR_OBSERVATIONS_READY',1);put('F22_RADAR_OBSERVATION_COUNT',1)
for k,v in pairs({ID=123,AGE=0,NORTH=5000,ALTITUDE=0,EAST=0,VN=0,VU=0,VE=0,IFF=0})do put('F22O_01_'..k,v)end
put('F22_EW_01_SOURCE',123);put('F22_EW_01_AGE',0);put('F22_EW_01_SIGNAL',1)
update();assert(val('F22_SCOPE_01_AFFILIATION')==0,'detected simulator foe classification was discarded')
put('F22_SOI',1);local x=val('F22_RADAR_CURSOR_X');SetCommand(10620,1)
for i=1,10 do update()end
assert(val('F22_RADAR_CURSOR_X')==x,'slew axis bypassed sensor focus')
put('F22_SOI',2);SetCommand(10620,1);update()
assert(val('F22_RADAR_CURSOR_X')~=x,'radar focus did not restore slew')
''')
print('Radar owner: persistent emission inhibit, deliberate re-enable, honest unknown ID and slew focus PASS')
