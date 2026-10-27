"""Actual radar owner withdraws support for stopped producer and A/G SIL."""
from radar_test_runtime import owned_runtime
from pathlib import Path
import sys
lua=owned_runtime()
lua.execute("""
f.measure(42);f.tick();f.measure(42);f.tick()
assert(f.get('F22_RADAR_SUPPORT_ENABLED')==1 and f.get('F22_SUPPORT_01_ID')==42)
f.now=f.now+.6;f.update() -- producer heartbeat frozen; driver remains ready
assert(f.get('F22_RADAR_BACKEND_READY')==1 and f.get('RADAR_PWR')==1)
assert(f.get('F22_RADAR_SUPPORT_ENABLED')==0,'stopped producer retained support authority')
f.measure(42);f.tick()
assert(f.get('F22_RADAR_SUPPORT_ENABLED')==1)
f.put('HUD_MODE',7);f.put('F22_AG_RADAR_NATIVE_READY',1);f.tick()
assert(f.get('F22_RADAR_SUPPORT_ENABLED')==1)
f.command(10638,1);f.tick()
assert(f.get('F22_AG_SILENT')==1 and f.get('F22_AESA_CONTROL_EMIT')==0)
assert(f.get('F22_RADAR_SUPPORT_ENABLED')==0,'SIL retained support authority')
f.command(10638,1);f.tick()
assert(f.get('F22_AG_SILENT')==0 and f.get('F22_RADAR_SUPPORT_ENABLED')==1)
""")
print('AESA support authority: live/frozen producer, live driver, AG SIL and recovery PASS')

# The integrated weapons consumer has a stricter support-list contract than
# this isolated radar branch. Pass that checkout to exercise the actual chain.
if len(sys.argv)>1:
    lua.globals().consumer_path=(Path(sys.argv[1])/'Cockpit/Scripts').resolve().as_posix()+'/'
    lua.execute("""
local saved_path=LockOn_Options.script_path
LockOn_Options.script_path=consumer_path
dofile(consumer_path..'Systems/Engagement_System.lua');post_initialize()
local engagement=update
LockOn_Options.script_path=saved_path
f.put('HUD_MODE',2);f.measure(42);f.tick()
f.put('F22_RADAR_WEAPON_TARGET_ID',42)
for k,v in pairs({SEQUENCE=1,ID=1001,TARGET=42,MODE=2,TIME=f.now,ALIVE=1,LIFETIME=60,STATE_SOURCE=1})do
 f.put('F22_SHOT_01_'..k,v)
end
f.put('F22_LAUNCH_SEQUENCE',1);engagement()
assert(f.get('F22_MSL_01_SUPPORT_STATE')==1,'live emitting radar lost actual support chain')
f.now=f.now+.6;f.update();engagement()
assert(f.get('F22_SUPPORT_01_ID')==42 and f.get('F22_MSL_01_SUPPORT_STATE')~=1,
 'retained current target ID granted support after producer stopped')
f.measure(42);f.tick();engagement()
assert(f.get('F22_MSL_01_SUPPORT_STATE')==1)
f.put('HUD_MODE',7);f.put('F22_AG_RADAR_NATIVE_READY',1);f.tick()
f.command(10638,1);f.tick();engagement()
assert(f.get('F22_MSL_01_SUPPORT_STATE')~=1,'retained ID granted support in AG SIL')
""")
    print('Integrated Engagement: current ID cannot grant support in stopped-producer or SIL state PASS')
