"""Actual combined input and HUD consume the physical NWS selection."""
from cockpit_fixture import runtime

lua=runtime()
lua.execute('''
local function p(n,v)get_param_handle(n):set(v)end
local function g(n)return get_param_handle(n):get()end
local frame=dofile(SCRIPT_ROOT..'../../tests/physical_frame_fixture.lua')({
 MAIN_POWER=1,EFM_GROUND_VALID=1,EFM_WEIGHT_ON_WHEELS=1,EFM_NWS_SELECTED=1,
 EFM_GEAR_DOWN_LOCKED=1,EFM_GEAR_UP_LOCKED=0,EFM_GEAR_UNSAFE=0})
frame:publish(10);p('WoW',1)
events={}
function dispatch_action(device,command,value)
 events[#events+1]={command=command,value=value,device=device}
 if command==11701 then frame.values.EFM_NWS_SELECTED=value;frame:publish(10)end
end
dofile(SCRIPT_ROOT..'Systems/Combat_System.lua');post_initialize()
local combat_input,combat_update=SetCommand,update
combat_input(10714,16.375)
assert(#events==1 and events[1].command==11701 and events[1].value==0,'NWS did not reach physical owner on press')
for _=1,40 do combat_input(10714,16.375);combat_update()end
combat_input(10714,16.25);combat_input(10714,16.25)
assert(#events==1,'hold/release repeated the NWS toggle')
combat_input(10714,1);combat_input(10714,0)
assert(#events==2 and events[2].value==1)
frame.values.EFM_GROUND_VALID=0;frame:publish(10)
combat_input(10714,1);combat_input(10714,0);assert(#events==2,'unknown contact changed steering')
frame.values.EFM_GROUND_VALID=1;frame.values.EFM_WEIGHT_ON_WHEELS=0
frame:publish(10);p('WoW',0)
combat_input(10714,1);combat_input(10714,0)
assert(#events==5 and events[3].command==10609 and events[4].command==10842
 and events[4].value==1 and events[5].command==10842 and events[5].value==0,
 'airborne tap did not clear radar and navigation designations')
combat_input(10714,1);for _=1,30 do combat_update()end;combat_input(10714,0)
assert(#events==6 and events[6].command==10804,'airborne hold did not step once')
combat_input(10714,1);p('WoW',1);combat_input(10714,0)
assert(#events==6,'landing during an airborne press toggled NWS')

dofile(SCRIPT_ROOT..'Systems/HUD_Flight_Data.lua');post_initialize()
local hud_update=update
local function check(expected)
 frame:publish(10);hud_update();assert(g('HUD_NWS_ACTIVE')==expected,'NWS HUD gate incorrect')
end
frame.values.EFM_WEIGHT_ON_WHEELS=1;check(1)
frame.values.EFM_NWS_SELECTED=0;check(0)
frame.values.EFM_NWS_SELECTED=1;frame.values.EFM_WEIGHT_ON_WHEELS=0;check(0)
frame.values.EFM_WEIGHT_ON_WHEELS=1;frame.values.EFM_GEAR_DOWN_LOCKED=0;check(0)
frame.values.EFM_GEAR_DOWN_LOCKED=1;frame.values.EFM_GEAR_UNSAFE=1;check(0)
frame.values.EFM_GEAR_UNSAFE=0;frame.values.EFM_GROUND_VALID=0;check(0)
frame.values.EFM_GROUND_VALID=1;frame.values.MAIN_POWER=0;check(0)
frame.values.MAIN_POWER=1;check(1)
p('F22_AP_CLOCK',11);hud_update();assert(g('HUD_NWS_ACTIVE')==0,'stale NWS state stayed displayed')
post_initialize();assert(g('HUD_NWS_ACTIVE')==0)
''')
for scale in (.00055,.001):
    lua=runtime()
    lua.globals().native_scale=scale
    lua.execute('function GetScale()return native_scale end;dofile(SCRIPT_ROOT.."HUD/page.lua")')
    elements={e['name']:e for _,e in lua.globals().elements.items()}
    root=elements['HUD_NWS_STATUS']
    assert root['element_params'][1]=='HUD_NWS_ACTIVE'
    labels=[e for e in elements.values() if e['value']=='NWS']
    assert len(labels)==1 and labels[0]['parent_element']=='HUD_NWS_STATUS'
    assert labels[0]['element_params'][1]=='HUD_POWER'
print('Combined NWS/undesignate: physical owner, immediate/repeat/release/hold/transition gates; fresh HUD selection and native declaration PASS')
