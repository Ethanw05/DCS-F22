"""Rendered focal-plane channels must exist when native HUD states bind."""
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
fixture=ROOT/'tests/test_display_startup.py'
ns={'__file__':str(fixture)}
exec(compile(fixture.read_text().split('\nfor page in ',1)[0],str(fixture),'exec'),ns)
lua=ns['runtime']()
lua.execute(r'''
for _,owner in ipairs({'Weapon_System','Gun_System','HUD_Flight_Data','AG_Mark_System','AG_Ballistic_Computer'})do
 dofile(SCRIPT_ROOT..'Systems/'..owner..'.lua')
end
local declared={};for name in pairs(handles)do declared[name]=true end
dofile(SCRIPT_ROOT..'HUD/page.lua')
local used={}
for _,element in ipairs(elements)do
 for _,parameter in ipairs(element.element_params or {})do
  if parameter:find('_X_SLOPE',1,true)or parameter:find('_Y_SLOPE',1,true)or parameter:find('_PLANE_',1,true)then used[parameter]=true end
 end
end
local count,missing=0,{}
for parameter in pairs(used)do count=count+1;if not declared[parameter]then missing[#missing+1]=parameter end end
table.sort(missing)
assert(count>0,'native HUD no longer uses the reviewed projection contract')
assert(#missing==0,string.format('%d HUD plane parameters created after native binding; first: %s',#missing,table.concat(missing,', ',1,math.min(12,#missing))))
''')
print('Overhaul HUD binding: FPM/IR/gun/AG/funnel/maneuver projection channels initialized before native indicators PASS')
