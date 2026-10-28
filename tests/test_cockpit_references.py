"""Native element graphs and read-only reference ownership on all four panels."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
fixture = ROOT / 'tests/test_display_startup.py'
scope = {'__file__': str(fixture)}
exec(compile(fixture.read_text().split('\nfor page in ', 1)[0], str(fixture), 'exec'), scope)
lua = scope['runtime']()
lua.execute(r'''
local function get(key)return get_param_handle(key):get()end
local function put(key,value)get_param_handle(key):set(value)end
local reference=dofile(SCRIPT_ROOT..'Systems/Cockpit_References.lua').new(get,put)
reference.update()
assert(get('F22_REFERENCE_MASS')=='WEIGHT --' and get('F22_REFERENCE_TRIM')=='TAIL --')
put('EFM_MASS_VALID',1);put('EFM_MASS_KG',10000);put('EFM_TRIM_VALID',1)
put('EFM_TRIM_LEFT_DEG',2);put('EFM_TRIM_RIGHT_DEG',-1)
put('EFM_VEHICLE_VALID',1);put('EFM_INTERNAL_FUEL_KG',1000);put('EFM_EXTERNAL_FUEL_KG',0)
reference.update();assert(get('F22_REFERENCE_MASS')=='WEIGHT --','loose mass acquired reference authority')
local physical=dofile(SCRIPT_ROOT..'../../tests/physical_frame_fixture.lua')({F22_ESSENTIAL_POWER=1})
physical:publish(get('F22_AP_CLOCK'));reference.update()
assert(get('F22_REFERENCE_MASS')=='WEIGHT 22046 LB')
assert(get('F22_REFERENCE_TRIM')=='TAIL L 2.0 R -1.0 DEG')
assert(get('EFM_INTERNAL_FUEL_KG')==1000,'opening a reference changed physical fuel')
put('EFM_MASS_VALID',0);reference.update();assert(get('F22_REFERENCE_MASS')=='WEIGHT --')
local routing=dofile(SCRIPT_ROOT..'Systems/Display_Routing.lua')
local controls=dofile(SCRIPT_ROOT..'Systems/MFD_Controls.lua')
for _,panel in ipairs(routing.panels)do
 dofile(SCRIPT_ROOT..'MFD_COMMON/checklist_page.lua')(panel..'_CHECKLIST_PAGE')
 for view=0,4 do
  local buttons=controls.for_page(routing.pages.checks,view,get)
  assert(buttons[view+1].value==view and buttons[6].value==5)
  assert(buttons[13].action=='menu','reference lost its MENU return')
 end
 local detail=controls.for_page(routing.pages.checks,6,get)
 assert(detail[12].value==5 and detail[7].command==11005 and detail[9].command==11000)
end
local names={}
for _,element in ipairs(elements)do
 assert(not names[element.name],'duplicate native reference element name');names[element.name]=true
 if element.kind=='ceStringSLine' then
  assert(element.init_pos[1]>=-.95 and element.init_pos[1]<=.95)
  assert(element.init_pos[2]>=-.8 and element.init_pos[2]<=.8)
 end
end
for _,element in ipairs(elements)do
 if element.parent_element then assert(names[element.parent_element],'missing native parent')end
end
''')
print('Start/taxi/takeoff/landing/shutdown/fault references: four native graphs, returns, validity and read-only values PASS')
