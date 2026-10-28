"""Native request/readback divergence, reconnect and invalid data handling."""
from test_display_startup import runtime
lua=runtime()
lua.execute('''
local now=0;local actual=false;local blocked=false;local available=true;local broken=false
local count=120;local sets=0
function get_model_time()return now end
local native={
 drop_chaff=function()end,drop_flare=function()end,
 get_chaff_count=function()if broken then error('native receiver restarting')end;return count end,
 get_flare_count=function()return 120 end,
 get_ECM_status=function()return actual end,
 set_ECM_status=function(self,value)sets=sets+1;if not blocked then actual=value end end}
function GetDevice()if available then return native end end
local function p(k,v)get_param_handle(k):set(v)end
local function g(k)return get_param_handle(k):get()end
dofile(SCRIPT_ROOT..'Systems/EW_System.lua');post_initialize();p('MAIN_POWER',1);update()
blocked=true;SetCommand(11116,1);SetCommand(11116,0);update()
assert(g('F22_ECM_REQUESTED')==1 and g('F22_ECM_ACTIVE')==0 and g('F22_ECM_PENDING')==1)
local calls=sets
for i=1,30 do update()end
assert(sets==calls,'paused model time retried the same request repeatedly')
now=.4;update();assert(sets==calls,'retry rate unbounded')
blocked=false;now=.6;update()
assert(actual and g('F22_ECM_PENDING')==0 and g('F22_ECM_ACTIVE')==1)
-- Rearm/native reset changed actual state behind the cached switch request.
actual=false;now=.7;update();assert(g('F22_ECM_ACTIVE')==0 and g('F22_ECM_PENDING')==1)
now=1.2;update();assert(actual and g('F22_ECM_PENDING')==0)
-- API failure clears validity; old cartridge counts do not remain authoritative.
broken=true;now=1.3;update()
assert(g('F22_EW_BACKEND_READY')==0 and g('F22_CM_INVENTORY_VALID')==0 and g('F22_CHAFF_COUNT')==0)
broken=false;now=1.4;update();assert(g('F22_CM_INVENTORY_VALID')==1 and g('F22_CHAFF_COUNT')==120)
for _,bad in ipairs({0/0,math.huge,-1,1.5})do
 count=bad;now=now+.05;update();assert(g('F22_CM_INVENTORY_VALID')==0)
end
count=120;now=2;update()
-- Pilot can explicitly cancel request during outage; reconnect must respect it.
available=false;SetCommand(11116,1);SetCommand(11116,0);update()
assert(g('F22_ECM_REQUESTED')==0 and g('F22_EW_BACKEND_READY')==0)
available=true;now=2.1;update();assert(not actual)
-- Explicit ON during a temporary outage survives as intent, never actual status.
available=false;SetCommand(11116,1);SetCommand(11116,0);update()
assert(g('F22_ECM_REQUESTED')==1 and g('F22_ECM_ACTIVE')==0 and g('F22_ECM_PENDING')==1)
available=true;now=2.2;update();assert(actual)
p('MAIN_POWER',0);now=2.3;update();assert(not actual and g('F22_ECM_REQUESTED')==0)
p('MAIN_POWER',1);SetCommand(11116,1);SetCommand(11116,0);now=3;update();assert(actual)
now=0;update();assert(not actual and g('F22_ECM_REQUESTED')==0,'rewind retained ECM emission request')
''')
print('EW backend: actual/readback pending state, bounded retries, rearm/reset, invalid inventories, outage intent and power/rewind PASS')
