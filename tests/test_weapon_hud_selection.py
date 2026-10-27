"""Mixed-load selection/counting through the real controller and HUD bindings."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
fixture=ROOT/'tests/test_display_startup.py';ns={'__file__':str(fixture)}
exec(compile(fixture.read_text().split('\nfor page in ',1)[0],str(fixture),'exec'),ns)
lua=ns['runtime']()
lua.execute(r'''
local caps=dofile(SCRIPT_ROOT..'Systems/Store_Capabilities.lua')
local models={
 {'{C8E06185-7CD6-4C90-959F-044679E90751}','AIM-120B'},
 {'{40EF17B7-F508-45de-8566-6FFECC0C1AB8}','AIM-120C'},
 {'{AIM-120C-7}','AIM-120C7'},{'{LAU_115_2xAIM-120C-7}','AIM-120C7'},
 {'{AIM-120C-8}','AIM-120C8'},{'{LAU_115_2xAIM-120C-8}','AIM-120C8'},
 {'{AIM-120D-3}','AIM-120D3'},{'{LAU_115_2xAIM-120D-3}','AIM-120D3'},
 {'{AIM-260A}','AIM-260A'},{'{LAU_115_2xAIM-260A}','AIM-260A'},
 {'{MAKO_A2A_C}','MAKO A/A'},
 {'{6CEB49FC-DED8-4DED-B053-E1F033FF72D3}','AIM-9M'},
 {'{5CE2FF2A-645A-4197-B48D-8720AC69394F}','AIM-9X'},
 {'{AIM9X-BLKII}','AIM-9X II'},{'{LAU_115_2xAIM9X-II}','AIM-9X II'}}
for _,m in ipairs(models)do
 local cap=caps.describe({CLSID=m[1],count=1,weapon={level1=4,level2=4,level3=7,level4=900}})
 assert(cap.hud==m[2]and cap.supported,m[1]..' missing model identity')
end
local function store(id,count,type4,bomb)
 return {CLSID=id,count=count,weapon={level1=4,level2=bomb and 5 or 4,level3=bomb and 36 or 7,level4=type4}}
end
payload={
 [0]=store('{6CEB49FC-DED8-4DED-B053-E1F033FF72D3}',1,22),
 [10]=store('{AIM9X-BLKII}',1,7000),
 [2]=store('{AIM-120C-7}',1,7001),[8]=store('{LAU_115_2xAIM-120C-7}',2,7001),
 [3]=store('{AIM-260A}',1,7002),
 [5]=store('{C8E06185-7CD6-4C90-959F-044679E90751}',1,24),
 [7]=store('{40EF17B7-F508-45de-8566-6FFECC0C1AB8}',1,106),
 [4]=store('{GBU_32_V_2B}',2,292,true)}
local chosen=-1
native={get_station_info=function(_,i)return payload[i]or {count=0}end,
 select_station=function(_,i)chosen=i end,get_chaff_count=function()return 120 end,get_flare_count=function()return 120 end}
function GetDevice()return native end
function get_aircraft_property()return 1 end
local function p(n,v)get_param_handle(n):set(v)end
local function g(n)return get_param_handle(n):get()end
dofile(SCRIPT_ROOT..'Systems/Weapon_System.lua');post_initialize();p('MAIN_POWER',1)
SetCommand(10800,2);update()
assert(chosen==2 and g('F22_WEAPON_NAME')=='AIM-120C7' and g('F22_WEAPON_COUNT')==3)
assert(g('F22_WEAPON_CATEGORY_COUNT')==6)
for _,expected in ipairs({{'AIM-260A',1},{'AIM-120B',1},{'AIM-120C',1},{'AIM-120C7',3}})do
 SetCommand(10804,1)
 assert(g('F22_WEAPON_NAME')==expected[1]and g('F22_WEAPON_COUNT')==expected[2],'stepped weapon lost its own inventory')
end
SetCommand(10800,3);update();assert(g('F22_WEAPON_NAME')=='AIM-9M'and g('F22_WEAPON_COUNT')==1)
SetCommand(10804,1);assert(g('F22_WEAPON_NAME')=='AIM-9X II'and g('F22_WEAPON_COUNT')==1)
SetCommand(10800,7);update();assert(g('F22_WEAPON_NAME')=='GBU-32 JDAM'and g('F22_WEAPON_COUNT')==2)
SetCommand(10800,5);update();assert(g('F22_WEAPON_NAME')=='GUN'and g('F22_WEAPON_COUNT')==0)
for _,i in ipairs({2,3,5,7,8})do payload[i].count=0 end
SetCommand(10800,2);update();assert(g('F22_WEAPON_NAME')=='NO MRM'and g('F22_WEAPON_COUNT')==0 and g('F22_WEAPON_SELECTED_VALID')==0)
dofile(SCRIPT_ROOT..'HUD/page.lua')
local bound=0
for _,e in ipairs(elements)do
 assert(e.value~='AIM-120'and e.value~='AIM-9','fixed missile model label remains')
 if(e.element_params or {})[1]=='F22_WEAPON_NAME'then bound=bound+1;assert(e.formats[1]=='%s')end
end
assert(bound==5,'MRM, three IR contexts and A/G must all bind selected identity')
''')
print('Weapon HUD: all registered A/A models, mixed loads, paired racks, exact-model counts, station steps, A/G, gun and empty inventory PASS')
