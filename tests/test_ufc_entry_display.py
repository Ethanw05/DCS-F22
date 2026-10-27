"""Typed digits stay in the separate, full-size UFC scratchpad aperture."""
from cockpit_fixture import runtime

lua = runtime()
lua.execute(r'''
local now=10;function get_model_time()return now end
local native={get_station_info=function(_,i)return {count=i==4 and 3 or 0,
 CLSID='{F22-MK83-TRAINING}',weapon={level1=4,level2=5,level3=9,level4=32}}end,
 select_station=function()end,get_chaff_count=function()return 120 end,get_flare_count=function()return 120 end}
function GetDevice()return native end
local function put(k,v)get_param_handle(k):set(v)end
local function get(k)return get_param_handle(k):get()end
dofile(SCRIPT_ROOT..'Systems/Weapon_System.lua');post_initialize();local wc,wu=SetCommand,update
dofile(SCRIPT_ROOT..'Systems/ICP_System.lua');post_initialize();local ic,iu=SetCommand,update
function dispatch_action(d,c,v)if d==devices.WEAPON_SYSTEM then wc(c,v)end end
local function tick()now=now+.02;wu();iu()end
local function key(c)ic(c,devices.ICP_SYSTEM+.375);ic(c,devices.ICP_SYSTEM+.25);tick()end
put('MAIN_POWER',1);put('F22_SMS_PROGRAM_PAGE',1);put('HUD_MODE',1)
wc(10800,1);for i=1,20 do tick()end
key(10989);key(3008);key(3027);key(3018)
assert(get('F22_UFC_SCRATCH')=='02_'and get('F22_UFC_ROW_1')=='QTY 1'and get('F22_SMS_QUANTITY')==1,
 'draft must be visible without replacing accepted readback')
key(3012);assert(get('F22_SMS_QUANTITY')==1,'unselected blank option committed quantity')
key(3008);key(3027);key(3018);key(3008)
assert(get('F22_SMS_QUANTITY')==2 and get('F22_UFC_ROW_1')=='QTY 2')
key(3010);key(3021);key(3027);key(3027)
assert(get('F22_UFC_SCRATCH')=='500_'and get('F22_SMS_SPACING_FT')==200)
local declared={};for k in pairs(handles)do declared[k]=true end
dofile(SCRIPT_ROOT..'ICP/page_1.lua')
local named={};for _,e in ipairs(elements)do assert(not named[e.name]);named[e.name]=e end
local scratch=assert(named.F22_UFC_SCRATCH)
assert(scratch.init_pos[1]<-1.6 and math.abs(scratch.init_pos[2]-1.2)<.01 and scratch.stringdefs[1]>=.005)
assert(scratch.element_params[1]=='F22_UFC_SCRATCH'and declared.F22_UFC_SCRATCH)
assert(scratch.controllers[1][1]=='text_using_parameter'and scratch.parent_element=='F22_UFC_ROOT')
for i=1,5 do
 local e=assert(named['F22_UFC_ROW_'..i]);assert(declared[e.element_params[1]])
 assert(e.init_pos[1]>-1.6 and e.stringdefs[1]>=.0043)
 assert(math.abs(e.init_pos[2]-(1.8-i*.6))<.01 and e.parent_element=='F22_UFC_ROOT')
end
key(3026);assert(get('F22_UFC_SCRATCH')=='_'and get('F22_UFC_SELECTED')==3)
key(3028);assert(get('F22_UFC_SCRATCH')=='_'and get('F22_UFC_PAGE')=='STORES')
put('MAIN_POWER',0);iu();assert(get('F22_UFC_VISIBLE')==0 and get('F22_UFC_SELECTED')==0)
''')
print('UFC draft/readback, leading zeros, same-option commit, native scratchpad aperture and CLR/UNDO/power PASS')
