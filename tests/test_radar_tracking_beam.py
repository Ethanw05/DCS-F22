"""Owned measured tracking LOS and search recovery across ACM return patterns."""
from radar_test_runtime import owned_runtime
for command in (10605,10604,10622):
 l=owned_runtime();l.globals().PATTERN=command
 l.execute("""
f.lock(42);f.command(PATTERN,1)
for _,east in ipairs({2400,-3200,800})do
 f.pose.pitch=.3;f.pose.roll=1.1
 f.measure(42,6000,4000,east);f.tick()
 assert(f.get('F22_RADAR_STT_VALID')==1 and f.get('F22_RADAR_COVERAGE_VALID')==1)
 assert(f.get('F22_STT_PE')==east and f.get('F22_STT_PN')==6000)
 assert(f.get('F22_RADAR_COVERAGE_CENTER_ROT')==0)
 assert(f.get('F22_RADAR_COVERAGE_ROT')==math.rad(60) and f.get('F22_ACM_MODE')==0)
end
f.tick(.6)
assert(f.get('F22_RADAR_STT_VALID')==0)
assert(f.get('F22_RADAR_COVERAGE_VALID')==1,'owned track loss did not resume search')
""")
print('Owned tracking LOS: moving measurements in pitch/bank, retained ACM return, stale withdrawal and resumed search PASS')
