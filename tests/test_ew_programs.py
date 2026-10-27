"""Execute saved/draft banks, physical HOTAS routing and actual CM callbacks."""
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
fixture = ROOT / 'tests/test_display_startup.py'
ns = {'__file__': str(fixture)}
exec(compile(fixture.read_text().split('\nfor page in ', 1)[0], str(fixture), 'exec'), ns)
lua = ns['runtime']()
lua.execute(r'''
local P=dofile(SCRIPT_ROOT..'Systems/EW_Programs.lua')
local banks=P.new()
local first=banks:capture(1)
banks:command(10911);banks:command(10913);banks:command(10914)
assert(banks.dirty and banks:capture(1).chaff==1 and first.chaff==1)
assert(banks:command(11103) and banks:capture(1).chaff==2)
assert(banks:capture(1).interval==.5 and banks:capture(1).repetitions==5)
banks:command(10911);banks:command(11104)
assert(not banks.dirty and banks.draft.chaff==2)
banks.draft.chaff=0;banks.draft.flare=0
assert(not banks:command(11103) and banks.error and banks:capture(1).chaff==2)
for _,bad in ipairs({0/0,math.huge,-1,1.5})do
 banks.draft.chaff=bad;assert(not banks:command(11103))
end
banks:command(10910)
assert(banks.selected==2 and banks.normal==1 and banks.direct==2 and not banks.dirty)
banks:command(11105);banks:command(11106)
assert(banks.normal==2 and banks.direct==3)

local now,chaff,flare,blocked=10,40,40,false
local ecmbroken=false
function get_model_time()return now end
local native={
 get_chaff_count=function()return chaff end,get_flare_count=function()return flare end,
 drop_chaff=function(_,n)if not blocked then chaff=chaff-n end end,
 drop_flare=function(_,n)if not blocked then flare=flare-n end end,
 get_ECM_status=function()if ecmbroken then error('no ECM')end;return false end,
 set_ECM_status=function()end}
function GetDevice()return native end
local function p(k,v)get_param_handle(k):set(v)end
local function g(k)return get_param_handle(k):get()end
p('MAIN_POWER',1)
dofile(SCRIPT_ROOT..'Systems/EW_System.lua');post_initialize()
local ew_command,ew_update=SetCommand,update
local function command(c)ew_command(c,1);ew_command(c,0)end
local function tick(n)for _=1,n or 1 do now=now+.05;ew_update()end end
tick()
-- Edit selection cannot silently select the normal bank; SAVE is explicit.
command(10910);command(10912)
assert(g('F22_CM_PROGRAM_SELECTED')==2 and g('F22_CM_NORMAL_BANK')==1)
assert(g('F22_CM_PROGRAM_2_FLARE')==1 and g('F22_CM_DRAFT_DIRTY')==1)
command(11100);tick(2)
assert(g('F22_CM_RUNNING_BANK')==1 and chaff==39 and flare==39)
command(11103);tick(30)
assert(chaff==36 and flare==36 and g('F22_CM_STATUS')==3)
assert(g('F22_CM_COMPLETED_SEQUENCE')==1)
command(11105);command(11100);tick(20)
assert(chaff==36 and flare==32,'normal bank ignored committed selection')
assert(g('F22_CM_LAST_BANK')==2 and g('F22_CM_STATUS')==3)
-- Direct uses its declared bank without changing normal or edit selection.
command(11106);command(11101);tick(2)
assert(g('F22_CM_RUNNING_BANK')==3 and g('F22_CM_NORMAL_BANK')==2)
local running=g('F22_CM_BURSTS_REMAINING')
command(11100)
assert(g('F22_CM_REJECTION')==9 and g('F22_CM_BURSTS_REMAINING')==running)
command(11113);local before=chaff;tick(40)
assert(chaff==before and g('F22_CM_PROGRAM_RUNNING')==0)
-- A category exhausting cannot falsely complete a mixed program.
chaff=1;flare=30;command(11102);tick(15)
assert(g('F22_CM_STATUS')==4 and g('F22_CM_COMPLETED_SEQUENCE')==2)
chaff=0;flare=0;command(11100);tick()
assert(g('F22_CM_STATUS')==5 and g('F22_CM_PROGRAM_RUNNING')==0)
-- CM inventory is independent from a missing/broken optional ECM service.
chaff=40;flare=40;ecmbroken=true;tick()
assert(g('F22_CM_READY')==1 and g('F22_ECM_HOST_VALID')==0)
command(11100);tick(2);p('MAIN_POWER',0);tick();before=flare
p('MAIN_POWER',1);tick(40)
assert(flare==before and g('F22_CM_PROGRAM_RUNNING')==0)
-- SEMI requires new per-event consent and snapshots the saved event bank.
command(11107);command(11110);tick(10)
assert(g('F22_CM_MODE')==2 and g('F22_CM_AWAITING_CONSENT')==1 and flare==before)
command(11105);command(11111);tick(25)
assert(g('F22_CM_LAST_BANK')==2 and g('F22_CM_CONSENT')==0)
command(11110);command(11112);command(11111);tick(10)
assert(g('F22_CM_PROGRAM_RUNNING')==0 and g('F22_CM_AWAITING_CONSENT')==0)
-- AUTO only runs after authorization; revocation does not queue old events.
command(11107);before=chaff;command(11110);tick(10);assert(chaff==before)
command(11111);command(11110);tick(2);assert(g('F22_CM_AUTHORIZED')==1)
command(11112);before=chaff;tick(40);assert(chaff==before)
command(11111);tick(20);assert(chaff==before)
-- OFF/STBY/test/failure revoke and never resume; presets survive power/refill.
command(11108);assert(g('F22_CM_SYSTEM')==0 and g('F22_CM_READY')==0)
command(11100);tick();assert(g('F22_CM_PROGRAM_RUNNING')==0)
command(11108);tick();assert(g('F22_CM_SYSTEM')==1 and g('F22_CM_READY')==0)
command(11108);tick();command(11109);tick(10)
assert(g('F22_CM_SELF_TEST')==1 and g('F22_CM_READY')==0)
tick(12);assert(g('F22_CM_READY')==1)
-- A successful API call with no observed decrement is a failed transaction.
blocked=true;command(11100);tick(20)
assert(g('F22_CM_STATUS')==8 and g('F22_CM_UNCONFIRMED')==1)
command(11100);assert(g('F22_CM_REJECTION')==9)
chaff=100;flare=100;blocked=false;tick()
command(11100);tick(2);assert(g('F22_CM_PROGRAM_RUNNING')==1)
command(11113);tick()
-- Preserve saved HOTAS bindings; Combat dispatches to the sole EW owner.
dofile(SCRIPT_ROOT..'Systems/Combat_System.lua');post_initialize()
local combat_command=SetCommand
function dispatch_action(device,c,v)if device==devices.EW_SYSTEM then ew_command(c,v)end end
combat_command(10708,1);combat_command(10708,0);tick(2)
assert(g('F22_CM_RUNNING_BANK')==g('F22_CM_NORMAL_BANK'))
''')
print('EW programs: saved/draft selection, actual effects, partial/empty, consent, power, test, quarantine and HOTAS PASS')
