"""Equipment occurrence/acknowledgement survives independent navigation loss."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
fixture = ROOT / 'tests/test_display_startup.py'
scope = {'__file__': str(fixture)}
exec(compile(fixture.read_text().split('\nfor page in ', 1)[0], str(fixture), 'exec'), scope)
lua = scope['runtime']()
lua.execute(r'''
local Policy=dofile(SCRIPT_ROOT..'Systems/Pilot_Warnings.lua')
local conditions={};for i=1,8 do conditions[i]={valid=true,active=false}end
local policy=Policy.new()
local s={now=10,powered=true,valid=false,ground=true,conditions=conditions,fcs_valid=true}
conditions[2].active=true;policy:update(s,nil);s.now=12.1
assert(policy:update(s,nil).text=='CAUTION','navigation loss hid a valid equipment fault')
local generator=policy.faults.records[2]
assert(generator.active and generator.occurrence==1 and policy.faults.attention==1)
policy:acknowledge();assert(generator.active and generator.acknowledged==generator.occurrence)
s.now=13;conditions[4].active=true;policy:update(s,nil)
assert(policy.faults.active==2 and policy.faults.attention==1)
s.now=15.1;assert(policy:update(s,nil).event=='caution','new hydraulic fault inherited generator acknowledgement')
policy:acknowledge();conditions[4].active=false;s.now=16;policy:update(s,nil)
assert(policy.faults.records[4].cleared==16 and generator.active)
conditions[4].active=true;s.now=17;policy:update(s,nil)
assert(policy.faults.records[4].occurrence==3 and policy.faults.attention==1)
conditions[4].valid=false;s.now=18;policy:update(s,nil)
assert(policy.faults.unknown==1 and policy.faults.records[4].active,'unknown source was reported as repaired')
policy:acknowledge();conditions[4].valid=true;s.now=19;policy:update(s,nil)
assert(policy.faults.records[4].occurrence==4 and policy.faults.attention==1)
conditions[2].active=false;conditions[4].active=false;s.now=20;policy:update(s,nil)
assert(policy.faults.active==0 and policy.faults.records[2].cleared==20)
s.now=1;policy:update(s,nil);assert(policy.faults.occurrence==0,'mission time reversal retained old fault history')
''')
print('Fault identities: independent causes, new attention, ACK, recurrence, invalid source, history and reset PASS')
