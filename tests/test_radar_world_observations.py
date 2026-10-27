"""World measurements are projected into the current body frame for acquisition."""
from radar_test_runtime import owned_runtime
l=owned_runtime()
l.execute("""
f.pose.north=1000;f.pose.altitude=5000;f.pose.east=2000
f.command(10604,1)
f.measure(123,13964,5000,2000);f.tick()
assert(f.get('F22_RADAR_MODE_TEXT')=='ACQ' and f.get('F22_AESA_PRIORITY_01')==123)
assert(f.get('F22_RADAR_DRAWN_COUNT')==1 and f.get('F22_RADAR_STT_VALID')==0)
f.tick();f.measure(123,13964,5000,2000);f.tick()
assert(f.get('F22_RADAR_STT_VALID')==1)
assert(math.abs(f.get('F22_RADAR_STT_RANGE')-12964)<.01)
assert(math.abs(f.get('F22_RADAR_STT_ELEVATION'))<1e-9)
f.alive=false;f.tick()
assert(f.get('F22_RADAR_STT_VALID')==0,'unavailable producer retained hard acquisition')
""")
print('Owned world snapshot: level VACQ, body geometry, new measurement confirmation and loss PASS')
