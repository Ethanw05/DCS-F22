"""Physical supply readback and independent brake transport in the cockpit."""
from cockpit_fixture import runtime, power_frame

sim = runtime()
sim.execute("dofile(SCRIPT_ROOT..'Systems/Engine_System.lua'); post_initialize(); update()")
assert sim.globals().handles.F22_BATTERY_REQUEST.value == 1
assert sim.globals().handles.MAIN_POWER.value == 0
# Finite battery/APU/generator physics is exercised in the owning C++ Power
# tests and actual DLL workflow, not a second electrical model in this device.
for supply in (
    dict(battery=1, main=1, left=1, right=1),
    dict(battery=1, main=1, left=0, right=1),
    dict(battery=1, main=1, left=1, right=0),
    dict(battery=1, main=0),
    dict(battery=0, main=0),
    dict(battery=0, main=1),  # external supply, no working battery
):
    power_frame(sim, **supply)
    sim.globals().update()
    for field, key in (('battery','BATTERY_POWER'), ('main','MAIN_POWER'),
                       ('left','L_GEN_POWER'), ('right','R_GEN_POWER')):
        assert sim.globals().get_param_handle(key).value == supply.get(field, 0)

sim.execute("""
SetCommand(10056,-.5); SetCommand(10057,.6); actions={}; update()
local l,r
for _,a in ipairs(actions) do
    assert(a[1]~=74 and a[1]~=75, 'independent axes collapsed to common brake')
    if a[1]==10540 then l=a[2] elseif a[1]==10541 then r=a[2] end
end
assert(math.abs(l-.25)<1e-12 and math.abs(r-.8)<1e-12)
SetCommand(10056,-1); actions={}; update()
for _,a in ipairs(actions) do
    if a[1]==10540 then assert(a[2]==0)
    elseif a[1]==10541 then assert(math.abs(a[2]-.8)<1e-12) end
end
""")
print('Physical electrical supply/readback and proportional independent brake transport PASS')
