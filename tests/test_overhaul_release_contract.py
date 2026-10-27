"""Independent release acknowledgement and failure-boundary contracts.

Execute the real stores model. Native launch calls are requests; only matching,
timely observed evidence may advance a captured program.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
fixture = ROOT / 'tests/test_display_startup.py'
ns = {'__file__': str(fixture)}
exec(compile(fixture.read_text().split('\nfor page in ', 1)[0], str(fixture), 'exec'), ns)
lua = ns['runtime']()
lua.execute(r'''
local Model=dofile(SCRIPT_ROOT..'Systems/AG_Stores.lua')
local function info(count)
 return {count=count,CLSID='{F22-MK83-TRAINING}',weapon={level1=4,level2=5,level3=9,level4=32}}
end
local function request()
 local m=Model.new();local load=info(2)
 m:refresh({[4]=load});m:profile().quantity=2;m:profile().interval_mode=0
 assert(m:start(100,7));assert(m:due(100))
 assert(m:request(4,load,100,{n=500,e=300,vn=200,ve=0},10))
 assert(not m:request(4,load,100,nil,10),'a second request replaced a pending release')
 assert(not m:due(100.005),'pending release allowed another launch')
 return m,load
end
local function shot()
 return {sequence=11,id=123,station=4,mode=7,type4=32,time=100.01}
end
-- Evidence is conjunctive: no single plausible field substitutes for identity.
for _,bad in ipairs({
 {'sequence',10},{'id',0},{'station',5},{'mode',2},{'type4',85},
 {'time',99.9},{'time',101}
})do
 local m,load=request();local event=shot();event[bad[1]]=bad[2]
 assert(m:acknowledge({[4]=load},100.1,event)==nil,'unrelated event advanced a program: '..bad[1])
 assert(m.program.remaining==2 and m.pending,'invalid evidence changed release ownership')
end
-- A native event is enough even when native station counts lag one update.
local m,load=request();local accepted,complete=m:acknowledge({[4]=load},100.1,shot())
assert(accepted and not complete and m.program.remaining==1)
assert(not m:due(100.29) and m:due(100.3),'acknowledged ripple did not retain interval')
assert(not m:station_ready(4),'native-only acknowledgement did not quarantine stale inventory')
assert(not m:request(4,load,100.3,{n=600,e=300,vn=200,ve=0},11),'stale station accepted another request')
assert(m:station_ready(6),'one delayed station blocked another station')
local decremented=info(1);m:refresh({[4]=decremented})
assert(m:station_ready(4),'matching inventory did not reconcile the prior release')
assert(m:request(4,decremented,100.3,{n=600,e=300,vn=200,ve=0},11))
assert(m:acknowledge({[4]=decremented},100.31,shot())==nil,'the same shot acknowledged a second request')
-- A station count decrease has no action identity. It cannot acknowledge a shot.
local empty=info(0)
assert(m:acknowledge({[4]=empty},100.32,nil)==nil)
local second=shot();second.sequence=12;second.time=100.31;second.id=124
accepted,complete=m:acknowledge({[4]=empty},100.32,second)
assert(accepted and complete and not m.program and not m.pending)
assert(m:acknowledge({[4]=empty},100.33,shot())==nil,'completed request acknowledged twice')
-- Clock discontinuities and late polling terminate consent before count evidence.
for _,observation in ipairs({99.99,100.801})do
 local t,unchanged=request();local reduced=info(1)
 accepted,complete=t:acknowledge({[4]=reduced},observation,shot())
 assert(accepted==false and complete==false and t.failed,'invalid time accepted release evidence')
 assert(not t.program and not t.pending and not t:due(observation+1),'failed transaction retained consent')
end
local t,unchanged=request();local frozen=t.pending
t:fail_request()
assert(t.failed and not t.pending and not t.program and frozen.time==100,'explicit failure altered request identity')
-- Cancelling consent cannot remove a still-outstanding native/count reconciliation.
t,unchanged=request();assert(t:acknowledge({[4]=unchanged},100.1,shot()))
t:cancel();assert(not t:station_ready(4),'cancel discarded native/count reconciliation')
assert(not t:start(101),'new consent reused unreconciled inventory')
t:refresh({[4]=info(1)});assert(t:station_ready(4))
-- A cancelled dispatched request remains physically unresolved too. Its delayed
-- decrement must be reconciled before a later request captures a new baseline.
t,unchanged=request();t:cancel()
assert(not t:station_ready(4) and not t:start(100.1),'cancelled unconfirmed request lost its inventory barrier')
t:refresh({[4]=info(1)});t:profile().quantity=1
assert(t:station_ready(4) and t:start(101))
assert(t:request(4,t.infos[4],101,nil,11))
assert(t:acknowledge({[4]=info(1)},101.1,shot())==nil,'prior cancelled release acknowledged a newer request')
local failed,original=request();failed:fail_request()
assert(not failed:station_ready(4) and not failed:start(101),'timeout/failure discarded unknown physical request')
-- An edit cancels the release transaction before changing the profile.
t,unchanged=request();t:begin_entry(2)
assert(not t.pending and not t.program and t.entry)
t:digit(2);t:digit(0);t:digit(0);assert(t:commit() and t:profile().interval==.2)
assert(t:acknowledge({[4]=info(1)},100.1,shot())==nil,'cancelled program accepted a late acknowledgement')
''')
print('Overhaul release contract: actual launch identity, count-only rejection, time boundaries, quarantine and cancellation PASS')
