"""Owned radar geometry never promotes simulator coalition into combat ID."""
from radar_test_runtime import owned_runtime
lua=owned_runtime()
lua.execute("""
local receiver={set_power=function()end}
function GetDevice(id)assert(id==17);return receiver end
dofile(SCRIPT_ROOT..'Systems/RWR_System.lua');post_initialize();local rwr=update
f.measure(123,5000,3000,200);f.tick()
for k,v in pairs({SOURCE=123,TIME=0,AZIMUTH=-.04,ELEVATION=.1,SIGNAL=1,PRIORITY=1,GENERAL_TYPE=1,UNIT_TYPE='27'})do f.put('RWR_CONTACT_01_'..k,v)end
rwr()
assert(f.get('F22_SCOPE_01_AFFILIATION')==-1)
assert(f.get('F22_RADAR_TACTICAL_01_HOSTILE')==0 and f.get('F22_TACTICAL_01_AFFILIATION')==-1)
-- Retired simple-radar identity fields cannot classify an owned measurement.
f.put('F22O_01_IFF',0);f.put('F22N_RADAR_STT_FRIENDLY',1)
f.command(10619,1);f.measure(123,5000,3000,200);f.tick();rwr()
assert(f.get('F22_SCOPE_01_AFFILIATION')==-1 and f.get('F22_TACTICAL_01_AFFILIATION')==-1)
local iff=dofile(SCRIPT_ROOT..'Systems/Radar_IFF.lua').new();iff:update(10,true)
assert(iff:reply(0,10,0,0)==-1,'missing STT friendly response became hostile')
assert(iff:reply(0,10,0,0,true)==0,'explicit simulator identification was rejected')
iff:toggle_auto();assert(iff:reply(0,10,0,0,true)==-1,'disabled identification accepted new class')

""")
print('Owned radar combat ID: unknown without independent identification evidence, retired coalition fields ignored, exact-source RF correlation PASS')
