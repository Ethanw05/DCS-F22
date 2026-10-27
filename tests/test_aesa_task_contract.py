"""Actual AESA controller requests track service by acquisition/weapon role."""
from radar_test_runtime import owned_runtime

lua = owned_runtime()
lua.execute('''
f.measure(42);f.tick();f.measure(42);f.tick()
f.lock(42)
assert(f.get('F22_AESA_CONTROL_FC_TARGET')==42)
assert(f.get('F22_AESA_CONTROL_GUN_TRACK')==0)
f.put('HUD_MODE',5);f.tick()
assert(f.get('F22_RADAR_STT_VALID')==1)
assert(f.get('F22_AESA_CONTROL_FC_TARGET')==42 and f.get('F22_AESA_CONTROL_GUN_TRACK')==1)
f.put('HUD_MODE',2);f.tick()
assert(f.get('F22_AESA_CONTROL_FC_TARGET')==42 and f.get('F22_AESA_CONTROL_GUN_TRACK')==0)
f.put('HUD_MODE',7);f.tick()
assert(f.get('F22_AESA_CONTROL_FC_TARGET')==0 and f.get('F22_AESA_CONTROL_GUN_TRACK')==0)
f.put('MAIN_POWER',0);f.put('HUD_MODE',2);f.tick()
assert(f.get('F22_AESA_REQUEST')==0 and f.get('F22_AESA_CONTROL_FC_TARGET')==0)
''')
print('Owned AESA task roles: acquisition/STT, gun, surface and power loss reach coherent current controls PASS')
