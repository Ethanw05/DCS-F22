"""New tactical/defensive native fields must exist before indicators bind."""
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
fixture=ROOT/'tests/test_display_startup.py'
ns={'__file__':str(fixture)}
exec(compile(fixture.read_text().split('\nfor page in ',1)[0],str(fixture),'exec'),ns)
lua=ns['runtime']()
lua.execute(r'''
dofile(SCRIPT_ROOT..'Systems/RWR_System.lua')
dofile(SCRIPT_ROOT..'Systems/EW_System.lua')
local declared={};for name in pairs(handles)do declared[name]=true end
dofile(SCRIPT_ROOT..'MFD_RIGHT/rwr_page.lua')
dofile(SCRIPT_ROOT..'PMFD_CENTER/radar_page.lua')
local used={}
for _,element in ipairs(elements)do
 for _,parameter in ipairs(element.element_params or {})do
  if parameter:find('F22_DEFENSIVE_',1,true)==1 or parameter:find('F22_DEF_OV_',1,true)==1 or parameter:find('F22_TSD_',1,true)==1 or parameter:find('F22_CM_PROGRAM_',1,true)==1 then
   used[parameter]=true
  end
 end
end
local missing={};local count=0
for parameter in pairs(used)do count=count+1;if not declared[parameter]then missing[#missing+1]=parameter end end
table.sort(missing)
assert(count>0,'tactical formats do not consume their public producer fields')
assert(#missing==0,string.format('%d tactical parameters created after native binding; first: %s',#missing,table.concat(missing,', ',1,math.min(12,#missing))))
''')
print('Overhaul tactical binding: all Defensive/TSD/manual-CM fields declared by their owners during construction PASS')
