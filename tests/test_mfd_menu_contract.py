"""Bottom-center labels, real bezel routing, range direction and receiver validity."""
from pathlib import Path
root=Path(__file__).resolve().parents[1]
fixture=root/'tests/test_display_startup.py';ns={'__file__':str(fixture)}
exec(compile(fixture.read_text().split('\nfor page in ',1)[0],str(fixture),'exec'),ns)
for folder in ['MFD_LEFT','MFD_CENTER','MFD_RIGHT','PMFD_CENTER']:
 for file in sorted((root/'Cockpit/Scripts'/folder).glob('*.lua')):
  if not any(k in file.name for k in ('page','format','overview','detail')):continue
  lua=ns['runtime']();lua.execute("dofile(SCRIPT_ROOT..'"+folder+'/'+file.name+"')")
  for index in range(1,len(lua.globals().elements)+1):
   e=lua.globals().elements[index]
   if e['value'] in ('MENU','RTN'):
    assert abs(e['init_pos'][1])<.001 and e['init_pos'][2]<-.8,(folder,file.name,e['value'],'return control moved away from bottom center')
print('Native element graphs: all MFD MENU/RTN labels are at bottom center PASS')

lua=ns['runtime']()
lua.execute(r'''
function get_aircraft_property()return 1 end
function get_mission_route()return {}end
package.preload.terrain=function()return {GetHeight=function()return 0 end,convertMetersToLatLon=function()return 41,42 end}end
local function p(k,v)get_param_handle(k):set(v)end
local function g(k)return get_param_handle(k):get()end
dofile(SCRIPT_ROOT..'Systems/Navigation_System.lua');post_initialize();local nc,nu=SetCommand,update
dofile(SCRIPT_ROOT..'Systems/MFD_System.lua');post_initialize();local mc,mu=SetCommand,update
local sent={}
function dispatch_action(d,c,v)sent[#sent+1]={d,c,v};if d==devices.NAV_SYSTEM then nc(c,v)end end
local function tick()nu();mu()end
local function key(base,b)mc(base+b,devices.MFD_SYSTEM+.375);mc(base+b,devices.MFD_SYSTEM+.25);tick()end
p('MAIN_POWER',1);tick()
for _,panel in ipairs({{10060,'LMFD_PAGE'},{10090,'RMFD_PAGE'},{10110,'CMFD_PAGE'}})do
 local base,param=panel[1],panel[2]
 for _,selection in ipairs({{1,9},{2,8},{3,5},{4,7},{5,4},{6,1},{7,2},{8,3},{9,6}})do
  key(base,13);assert(g(param)==0,'bottom-center MENU failed to open selector')
  key(base,selection[1]);assert(g(param)==selection[2],'selector did not open the selected page')
  key(base,13);assert(g(param)==0)
  key(base,12);assert(g(param)==selection[2],'RTN did not restore the previous page')
 end
 key(base,13);key(base,6);key(base,1);assert(g(param)==1,'blank ENG key changed the format')
end
mc(10823,1);tick();local before=g('F22_NAV_SCALE_NM')
key(10110,15);assert(g('F22_NAV_SCALE_NM')<before,'RNG- increased numerical range')
key(10110,14);assert(g('F22_NAV_SCALE_NM')==before,'RNG+ failed to increase numerical range')
key(10110,11);key(10110,3);sent={};key(10110,7)
assert(sent[#sent][1]==devices.FLIGHT_GUIDANCE and sent[#sent][2]==10936,'TCN DATA MODE lost its separate control')
''')
print('Actual MFD/NAV owners: bottom-center MENU/return, blank old MENU, range signs and separate TCN MODE PASS')

lua=ns['runtime']()
lua.execute(r'''
local function p(k,v)get_param_handle(k):set(v)end
dofile(SCRIPT_ROOT..'MFD_LEFT/hsi_page.lua')
local lookup={};for _,e in ipairs(elements)do lookup[e.name]=e end
local function visible(e)
 for _,c in ipairs(e.controllers or {})do
  if c[1]=='parameter_in_range'or c[1]=='opacity_using_parameter'then
   local v=get_param_handle(e.element_params[c[2]+1]):get()
   if c[1]=='parameter_in_range'and(v<c[3]or v>c[4])or c[1]=='opacity_using_parameter'and v<=0 then return false end
  end
 end
 return not e.parent_element or visible(lookup[e.parent_element])
end
local function shown(text)for _,e in ipairs(elements)do if e.value==text and visible(e)then return true end end;return false end
p('MFD_OPACITY',1);p('LMFD_HSI_PAGE',1);p('LMFD_HSI_PAGE_DATA',2)
assert(shown('BRG ---')and shown('DME ---')and not shown('BRG INVALID'))
p('F22_TCN_MODE',2);assert(shown('BRG INVALID')and shown('DME INVALID'))
p('F22_TCN_BRG_VALID',1);p('F22_TCN_RANGE_VALID',1);p('F22_TCN_MODE',2)
assert(not shown('BRG INVALID')and not shown('DME INVALID')and not shown('BRG ---'))
p('LMFD_HSI_PAGE_DATA',3);assert(shown('LOC INVALID')and shown('GS INVALID'))
p('F22_ILS_LOC_VALID',1);p('F22_ILS_GS_VALID',1)
assert(shown('LOC')and shown('GS')and not shown('LOC INVALID')and not shown('GS INVALID'))
''')
print('Actual NAV native visibility: valid, invalid and OFF cues remain distinct PASS')
