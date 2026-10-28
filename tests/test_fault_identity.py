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
lua = scope['runtime']()
lua.execute(r'''
local now=10
function get_model_time()return now end
function get_base_data()return setmetatable({getSelfCoordinates=function()return 0,1000,0 end},
 {__index=function()return function()return 0 end end})end
function get_aircraft_draw_argument_value()return 0 end
local function get(k)return get_param_handle(k):get()end
local function put(k,v)get_param_handle(k):set(v)end
put('MAIN_POWER',1);put('EFM_VEHICLE_VALID',1);put('L_GEN_OUT',1)
for key,value in pairs({EFM_POWER_OWNER=1,EFM_PHYSICAL_VALID=1,
 EFM_PHYSICAL_GENERATION=1,EFM_PHYSICAL_CLOCK_KIND=1,F22_ELECTRICAL_VALID=1,
 L_GEN_POWER=0,R_GEN_POWER=1,EFM_FCS_INTEGRITY_VALID=1,EFM_FCS_DAMAGED=0,
 EFM_HYD_LEFT_PSI=4000,EFM_HYD_RIGHT_PSI=4000,EFM_ENGINE_VALID=1,
 EFM_ENGINE_LEFT_OIL_PSI=200,EFM_ENGINE_RIGHT_OIL_PSI=200})do put(key,value)end
dofile(SCRIPT_ROOT..'Systems/Pilot_Warning_System.lua');post_initialize()
local warning_update=update
function update()
 put('F22_AP_CLOCK',now);put('EFM_PHYSICAL_STAMP',now)
 put('EFM_PHYSICAL_GENERATION',get('EFM_PHYSICAL_GENERATION')+1)
 warning_update()
end
update()
assert(get('F22_FAULT_GEN_L_OCCURRENCE')==1)
SetCommand(11000,1);now=11;update();assert(get('F22_FAULT_UNACK_COUNT')==0)
put('MAIN_POWER',0);now=12;update();now=13;update()
assert(get('F22_FAULT_GEN_L_OCCURRENCE')==1,'power loss erased fault history')
-- Physical sensing is independent of display power. Add a new real source
-- occurrence to verify that a held ACK cannot acknowledge it on restoration.
put('EFM_HYD_RIGHT_PSI',0)
put('MAIN_POWER',1);now=14;update();SetCommand(11000,1);update()
assert(get('F22_FAULT_UNACK_COUNT')>0,'held ACK re-fired after power restore')
SetCommand(11000,0);SetCommand(11000,1);update();assert(get('F22_FAULT_UNACK_COUNT')==0)
post_initialize()
now=15;update();assert(get('F22_FAULT_GEN_L_OCCURRENCE')==1,'fresh mission retained prior occurrence sequence')
''')
print('Actual alert owner: fault history and physical ACK latch survive power loss; deliberate release/repress and mission reset PASS')
