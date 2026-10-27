"""Electrical reserve and brake transport, exercising the cockpit owner."""
from test_display_startup import runtime
sim=runtime()
sim.execute('''
local Electrical = dofile(SCRIPT_ROOT..'Systems/Electrical_Computer.lua')
local a,b=Electrical.new(),Electrical.new()
for i=1,2400 do a:update(1,true,false,false,false) end
for i=1,24000 do b:update(.1,true,false,false,false) end
assert(math.abs(a.soc-b.soc)<1e-10)
assert(a.battery==0 and a.essential==0 and a.volts==0)
a:update(120,true,true,false,false)
assert(a.battery==1 and a.essential==1 and a.volts==28 and a.soc>0)
a:update(1,true,false,false,true)
assert(a.battery==0 and a.essential==0)
local c=Electrical.new(); c:update(100,true,false,true,false)
assert(c.soc < .8 and c.soc > .7)

dofile(SCRIPT_ROOT..'Systems/Engine_System.lua'); post_initialize()
get_param_handle('EFM_ENGINE_VALID'):set(1)
get_param_handle('EFM_ENGINE_LEFT_RPM_PCT'):set(67)
get_param_handle('EFM_ENGINE_RIGHT_RPM_PCT'):set(67)
update()
assert(handles.MAIN_POWER:get()==1 and handles.BATTERY_POWER:get()==1)
get_param_handle('L_GEN_FAILURE'):set(1); update()
assert(handles.L_GEN_POWER:get()==0 and handles.MAIN_POWER:get()==1)
get_param_handle('R_GEN_FAILURE'):set(1); update()
assert(handles.MAIN_POWER:get()==0 and handles.F22_ESSENTIAL_POWER:get()==1)
get_param_handle('BATTERY_FAILURE'):set(1); update()
assert(handles.BATTERY_POWER:get()==0 and handles.F22_ESSENTIAL_POWER:get()==0)
get_param_handle('GROUND_POWER'):set(1); update()
assert(handles.MAIN_POWER:get()==1 and handles.F22_ESSENTIAL_POWER:get()==1)

SetCommand(10056,-.5);SetCommand(10057,.6);actions={};update()
local l,r
for _,a in ipairs(actions) do
    assert(a[1]~=74 and a[1]~=75,'independent axes collapsed to common brake')
    if a[1]==10540 then l=a[2] elseif a[1]==10541 then r=a[2] end
end
assert(math.abs(l-.25)<1e-12 and math.abs(r-.8)<1e-12)
SetCommand(10056,-1);actions={};update()
for _,a in ipairs(actions) do if a[1]==10540 then assert(a[2]==0) elseif a[1]==10541 then assert(math.abs(a[2]-.8)<1e-12) end end
''')
print('Vehicle electrical: finite reserve, recharge, generator/battery failure and restoration; proportional brake transport PASS')
