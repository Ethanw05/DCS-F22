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

lua=scope['runtime']()
lua.execute(r'''
local function get(k)return get_param_handle(k):get()end
local function put(k,v)get_param_handle(k):set(v)end
function get_cockpit_draw_argument_value(index)return index==117 and 1 or 0 end
put('HYD_LIGHT',1);put('OIL_LIGHT',1);put('L_GEN_OUT',1);put('F22_PILOT_WARNING_VALID',1)
dofile(SCRIPT_ROOT..'Systems/Avionics.lua');post_initialize();update()
assert(get('CAUTION_LIGHT')==0,'missing fault registry was replaced by aggregate/animation caution')
put('F22_FAULT_REGISTRY_READY',1);put('F22_MASTER_ATTENTION',1);update();assert(get('CAUTION_LIGHT')==1)
put('F22_MASTER_ATTENTION',0);update();assert(get('CAUTION_LIGHT')==0,'aggregate flags defeated registry ACK')
put('F22_FAULT_REGISTRY_READY',0);update();assert(get('CAUTION_LIGHT')==0,'withdrawn registry revived aggregate caution')
''')
print('Master caution uses the fault registry from startup and preserves its acknowledgement authority PASS')
lua=scope['runtime']()
lua.execute(r'''
local hosts=0
function get_model_time()return 0 end
function create_sound_host()hosts=hosts+1;return {create_sound=function()return{update=function()end,
 play_once=function()end,is_playing=function()return false end,stop=function()end}end}end
get_param_handle('MAIN_POWER'):set(1)
dofile(SCRIPT_ROOT..'Systems/Pilot_Warning_System.lua');post_initialize();SetCommand(11001,1);update()
assert(hosts==0 and get_param_handle('F22_PILOT_TEST_ACTIVE'):get()==0,
 'loose main power admitted warning/audio control without physical ownership')
''')
print('Warning power and command authority require the current physical producer from startup PASS')

lua=scope['runtime']()
lua.execute(r'''
local P=dofile(SCRIPT_ROOT..'Systems/Pilot_Warnings.lua')
local policy=P.new()
local s={now=0,powered=true,valid=false,ground=false,airborne=true,fcs_valid=true,fcs_fault=true,caution=true}
policy:update(s,nil);s.now=3
assert(policy:update(s,nil).text=='' and policy.faults.unknown==8,
 'aggregate flags bypassed the explicit fault catalogue')
s.conditions={};for i=1,8 do s.conditions[i]={valid=true,active=false}end
s.conditions[1].active=true;s.fcs_valid=false;s.fcs_fault=false;policy:update(s,nil);s.now=3.6
assert(policy:update(s,nil).event=='flight_controls','current FCS occurrence depended on obsolete loose flags')
s.conditions[1]={valid=true};s.now=4;policy:update(s,nil)
assert(not policy.faults.records[1].valid,'missing active flag became a healthy fault reading')
s.conditions=42;s.now=5
assert(policy:update(s,nil).text=='' and policy.faults.unknown==8,'malformed catalogue acquired fault authority')
local phase=P.new();s.conditions={};for i=1,8 do s.conditions[i]={valid=true,active=false}end
s.conditions[1].active=true;s.airborne=nil;s.now=6;phase:update(s,nil);s.now=6.6
assert(phase:update(s,nil).text~='FLIGHT CONTROLS','unknown contact was assumed airborne for FCS speech')
s.airborne=true;s.now=7;phase:update(s,nil);s.now=7.6
assert(phase:update(s,nil).event=='flight_controls','current airborne phase did not restore FCS speech')

''')
print('Policy requires typed per-identity conditions; loose aggregate flags cannot create warning authority PASS')
