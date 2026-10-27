"""Master-mode context must agree between visible Stores labels and active controls."""
from test_display_startup import runtime
lua=runtime()
lua.execute('''
function get_aircraft_property()return 1 end
dofile(SCRIPT_ROOT..'Systems/MFD_System.lua');post_initialize()
local command,tick=SetCommand,update
get_param_handle('MAIN_POWER'):set(1);get_param_handle('MFD_OPACITY'):set(1)
get_param_handle('HUD_MODE'):set(2);get_param_handle('HUD_AG_SUBMODE'):set(2)
get_param_handle('F22_WEAPON_NAME'):set('AIM-120C7');get_param_handle('F22_WEAPON_COUNT'):set(3)
get_param_handle('F22_WEAPON_KIND'):set(2);tick()
assert(get_param_handle('F22_SMS_AA_CONTEXT'):get()==1 and get_param_handle('F22_SMS_PROGRAM_PAGE'):get()==0)
dofile(SCRIPT_ROOT..'MFD_LEFT/bay_page.lua')
local byname={};for _,e in ipairs(elements)do byname[e.name]=e end
local function visible(e)
 if e.parent_element and not visible(byname[e.parent_element])then return false end
 for _,c in ipairs(e.controllers or {})do
  local p=e.element_params and e.element_params[c[2]+1];local v=p and get_param_handle(p):get()
  if c[1]=='parameter_in_range'and(v<c[3]or v>c[4])or c[1]=='opacity_using_parameter'and v<=0 then return false end
 end
 return true
end
local function shown(text)
 for _,e in ipairs(elements)do if e.value==text and visible(e)then return true end end
 return false
end
assert(shown('A/A')and shown('STEP')and shown('DOORS')and shown('MENU'))
assert(not shown('CCIP')and not shown('AUTO')and not shown('UFC')and not shown('PROG'))
actions={};command(10078,1);command(10078,0)
local steps=0;for _,a in ipairs(actions)do if a[1]==10804 then steps=steps+1 end end
assert(steps==1,'A/A STEP did not reach actual weapon selection once')
for _,b in ipairs({1,2,3,4,5,6,7,8,9,10,12,14,15,16,17})do
 actions={};command(10060+b,1);command(10060+b,0)
 for _,a in ipairs(actions)do assert(a[1]==10742,'blank A/A key reached an A/G program')end
end
get_param_handle('HUD_MODE'):set(7);tick()
assert(get_param_handle('F22_SMS_AA_CONTEXT'):get()==0 and shown('CCIP')and shown('PROG'))
get_param_handle('HUD_MODE'):set(1);tick();assert(shown('PROG'),'NAV lost A/G preparation')
''')
print('Actual Stores master-mode context: A/A selection/count/STEP, blank strike controls and retained NAV/A/G programming PASS')
