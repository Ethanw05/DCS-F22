"""Audio events follow stable emitters, real RF revisits, warning priority and mute."""
from pathlib import Path
from lupa.lua51 import LuaRuntime
import wave,math
root=Path(__file__).resolve().parents[1]
lua=LuaRuntime(unpack_returned_tuples=True)
lua.globals().MODULE=str(root/'Cockpit/Scripts/Systems/RWR_Audio.lua')
lua.execute('''
local m=dofile(MODULE)
local function c(id,age,signal) return {source=id,age=age or 0,signal=signal or 1} end
local a=m.new()
assert(a:update(.05,{c(1)},true,false,1).event=='new_contact')
-- A changing slot order or identification never creates a new emitter.
assert(a:update(.05,{c(1,.05)},true,false,1).event==nil)
assert(a:update(.05,{c(1,.1),c(2)},true,false,1).event==nil,'dense new returns should aggregate')
assert(a:update(.05,{c(2,.05),c(1,.15)},true,false,1).event==nil)
-- Age advances: the previous RF observation is stale, not another ping.
for i=1,25 do assert(a:update(.05,{c(1,.15+i*.05),c(2,.05+i*.05)},true,false,1).event==nil) end
assert(a:update(.05,{c(1,0),c(2,1.4)},true,false,1).event=='ping')
-- Two sources on one sweep produce one ping, with a rate limit.
assert(a:update(.05,{c(1,.05),c(2,0)},true,false,1).event==nil)
-- Missile warning suppresses lock and all lower-priority event sounds.
local v=a:update(.05,{c(1,0,2),c(2,0,3),c(3)},true,false,3)
assert(v.loop=='launch' and v.event==nil)
v=a:update(.05,{c(1,0,2),c(2,.05,1),c(3,.05)},true,false,2)
assert(v.loop=='lock' and v.event==nil)
-- A one-frame native export gap must not announce a contact lost.
assert(a:update(.05,{},true,false,0).event==nil)
assert(a:update(.05,{c(1),c(2),c(3)},true,false,1).event==nil)
local lost=0
for i=1,14 do local e=a:update(.05,{c(1,i*.05),c(3,i*.05)},true,false,1).event;if e=='contact_lost' then lost=lost+1 end end
assert(lost==1,'loss must produce one event after the receiver expires a source')
-- Muting still consumes identity changes; unmuting has no backlog.
assert(a:update(.05,{c(5)},true,true,1).event==nil)
assert(a:update(.05,{c(5,.05)},true,false,1).event==nil)
assert(a:update(.05,{c(5,0,3)},true,true,3).loop==nil)
assert(a:update(.05,{c(5,0,3)},true,false,3).loop=='launch')
assert(a:update(.05,{},false,false,0).event==nil)
assert(a:update(.05,{c(5)},true,false,1).event=='new_contact')
-- A persistent early-warning radar must not beep at every routine sweep.
a=m.new()
local ewr=c(7);ewr.label='EWR'
assert(a:update(.05,{ewr},true,false,1).event=='new_contact')
for i=1,120 do
 ewr.age=(i*.05)%3
 assert(a:update(.05,{ewr},true,false,1).event==nil)
end
ewr.signal=2
assert(a:update(.05,{ewr},true,false,2).loop=='lock')
ewr.signal=3
assert(a:update(.05,{ewr},true,false,3).loop=='launch')
''')
print('RWR audio: five distinct states; stable source IDs; RF revisit pings; loss debounce; missile priority; mute/power OK')
for name in ['ping','new_contact','contact_lost','lock','launch']:
    with wave.open(str(root/'Sounds/Effects/Aircrafts/F-22A/RWR'/f'{name}.wav')) as w:
        assert w.getnchannels()==1 and w.getsampwidth()==2 and w.getframerate()==24000
        assert .1<=w.getnframes()/w.getframerate()<=.7
    sdef=(root/'Sounds/sdef/Aircrafts/F-22A/RWR'/f'{name}.sdef').read_text()
    assert f'Effects/Aircrafts/F-22A/RWR/{name}' in sdef
print('Original PCM cue assets and DCS sound definitions validated')
