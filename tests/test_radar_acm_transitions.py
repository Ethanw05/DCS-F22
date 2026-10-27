"""ACM patterns, fresh confirmation, electronic priorities and high-slot contacts."""
from radar_test_runtime import owned_runtime
for command in (10622,10604,10605):
    l=owned_runtime();l.globals().PATTERN=command
    l.execute("""
f.command(PATTERN,1);f.measure(42,700);f.tick()
assert(f.get('F22_RADAR_MODE_TEXT')=='ACQ' and f.get('F22_RADAR_STT_VALID')==0)
f.tick();f.measure(42,650);f.tick()
assert(f.get('F22_RADAR_STT_VALID')==1)
assert(f.get('F22_AESA_CONTROL_HALF_AZ')>math.rad(50),'ACM lock confined background search')
assert(f.get('F22_AESA_CONTROL_RANGE')==80*1852)
f.measure(42,600,3000,20);f.tick()
assert(math.abs(f.get('F22_RADAR_STT_RANGE')-math.sqrt(600^2+20^2))<.001)
f.command(10604,1);f.tick();assert(f.get('F22_RADAR_STT_VALID')==1)
f.command(10609,1);f.alive=false;f.tick()
assert(f.get('F22_RADAR_STT_VALID')==0)
assert(#actions==0)
""")
l=owned_runtime();l.execute("""
f.command(10605,1)
f.slots[42]=40;f.measure(42,500);f.tick()
assert(f.get('F22_AESA_PRIORITY_01')==42 and f.get('F22_RADAR_DRAWN_COUNT')==1)
f.tick(2);assert(f.get('F22_RADAR_STT_VALID')==0,'old cache auto-confirmed acquisition')
""")
print('Owned ACM: wide/vertical/bore, measured confirmation/motion, retained return pattern, stale exclusion and slot40 PASS')
l=owned_runtime();l.execute("""
-- DCS may deliver the legacy SRM key before the shared HUD role publication.
f.command(108,1);f.put('HUD_MODE',3);f.tick()
assert(f.get('F22_ACM_MODE')==1,'late SRM role change erased explicit BORE request')
local r=dofile(SCRIPT_ROOT..'Systems/Radar_Computer.lua').new()
local missile=r:scope_range(8000,40000)
assert(missile>40000 and missile<80000,'missile scope excluded RMAX')
assert(r:scope_range(8000,40010)==missile,'small envelope variation changed zoom')
local gun=r:scope_range(700,nil)
assert(gun<5000,'gun zoom inherited missile envelope scale')
""")
