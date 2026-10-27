"""Owned STT/HUD producer freshness, IFF boundaries, focus and emission intent."""
from radar_test_runtime import owned_runtime, ns
runtime=ns['runtime']
lua=owned_runtime()
lua.execute("""
f.lock(42)
dofile(SCRIPT_ROOT..'Systems/Radar_Data_Bridge.lua');post_initialize();local bridge=update
bridge();assert(f.get('HUD_AA_TARGET_VALID')==1 and f.get('HUD_GUN_TARGET_VALID')==1)
f.tick(.6);bridge()
assert(f.get('F22_RADAR_STT_VALID')==0 and f.get('HUD_AA_TARGET_VALID')==0 and f.get('HUD_GUN_TARGET_VALID')==0)
f.lock(42);bridge();assert(f.get('HUD_AA_TARGET_VALID')==1)
-- Fresh private aliases cannot renew a frozen radar owner's publication.
f.now=f.now+.6;f.put('F22_STT_TIME',f.now);bridge()
assert(f.get('HUD_AA_TARGET_VALID')==0)
f.tick();f.put('MAIN_POWER',0);f.tick();bridge()
assert(f.get('HUD_TD_VALID')==0)
""")
print('Owned STT/HUD: independent measurements, stopped owner, stale native aliases and power withdrawal PASS')
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

lua=owned_runtime()
lua.execute("""
f.command(10600,1);f.tick();assert(f.get('RADAR_PWR')==0)
for _,cmd in ipairs({10626,10627,10604,10605,10622,10601,10602,10606})do
 f.command(cmd,1);f.tick();assert(f.get('RADAR_PWR')==0)
end
f.command(10600,1);f.tick();assert(f.get('RADAR_PWR')==1)
f.measure(123,5000);f.tick()
assert(f.get('F22_SCOPE_01_AFFILIATION')==-1)
f.put('F22_SOI',1);local x=f.get('F22_RADAR_CURSOR_X');f.command(10620,1)
for i=1,10 do f.tick()end
assert(f.get('F22_RADAR_CURSOR_X')==x)
f.put('F22_SOI',2);f.command(10620,1);f.tick()
assert(f.get('F22_RADAR_CURSOR_X')~=x)
""")
print('Owned radar: persistent emission intent, unknown ID and focused slew PASS')
