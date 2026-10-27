"""Execute actual ICP routing: ALT settings never command AP; entries transactional."""
from test_display_startup import runtime
lua=runtime()
lua.execute('''
function dispatch_action(d,c,v)actions[#actions+1]={d,c,v}end
dofile(SCRIPT_ROOT..'Systems/ICP_System.lua');post_initialize()
local function g(n)return get_param_handle(n):get()end
local function p(n,v)get_param_handle(n):set(v)end
local function tap(c)SetCommand(c,7.375);SetCommand(c,7.25)end
local function type_number(s)for d in s:gmatch('.')do tap(d=='0'and 3027 or 3016+tonumber(d))end end
p('MAIN_POWER',1);p('F22_ALT_PRESSURE_MMHG',760)
tap(3005);update();assert(g('ICP_FLIGHT_MENU')==4 and #actions==0,'ALT must not engage/open AP')
tap(3009);type_number('1500');assert(#actions==0,'entry must not mutate before accepted')
tap(3012);assert(actions[1][1]==devices.ALTITUDE_SYSTEM and actions[1][2]==11025 and actions[1][3]==1500)
tap(3011);local before=#actions;tap(3008);type_number('299');tap(3012)
assert(#actions==before,'reject malformed pressure')
tap(3028);type_number('2992');tap(3012)
assert(actions[#actions][2]==11024 and math.abs(actions[#actions][3]-759.968)<.001)
tap(3013);update();assert(g('ICP_FLIGHT_MENU')==5)
tap(3011);assert(actions[#actions][1]==devices.PILOT_WARNING_SYSTEM and actions[#actions][2]==11001)
before=#actions;tap(3015);update();assert(g('ICP_FLIGHT_MENU')==1 and #actions==before,'AP opens without engaging')
tap(3011);assert(actions[#actions][1]==devices.FLIGHT_GUIDANCE and actions[#actions][2]==10954)
for i=1,1200 do update()end;assert(g('ICP_FLIGHT_MENU')==1,'AP page must not time out during use')
tap(3013);update();assert(g('ICP_FLIGHT_MENU')==2)
tap(3009);type_number('7000');tap(3012);assert(actions[#actions][2]==11011 and actions[#actions][3]==7000)
tap(3011);tap(3010);tap(3026);type_number('1500');tap(3012)
assert(actions[#actions][2]==11012 and actions[#actions][3]==-1500,'negative vertical-speed target')
p('F22_NAV_REFERENCE',1);p('F22_MAG_VALID',1);p('F22_MAG_DECL',math.rad(10))
tap(3011);tap(3008);type_number('359');tap(3012);assert(actions[#actions][2]==11010 and math.abs(actions[#actions][3]-9)<1e-8)
tap(3011);tap(3012);before=#actions;type_number('080');tap(3012)
assert(actions[#actions][2]==11014 and actions[#actions][3]==.8,'Mach hundredths entry')
assert(#actions==before+1,'editing target must not engage autothrottle')
tap(3003);update();assert(g('ICP_FLIGHT_MENU')==0 and g('ICP_CNI_MENU')==1,'NAV exits flight page into CNI')
tap(3005);update();assert(g('ICP_FLIGHT_MENU')==4 and g('ICP_CNI_MENU')==0,'ALT exits CNI cleanly')
for reason=0,5 do p('F22_AP_REASON',reason);p('F22_AP_AT',1);tap(3015);update();if g('ICP_FLIGHT_MENU')==0 then tap(3015);update()end;assert(#g('ICP_FLIGHT_TITLE')<=30,'header must fit physical aperture')end
p('MAIN_POWER',0);update();assert(g('ICP_FLIGHT_MENU')==0)
''')
print('ICP AP/ALT: distinct keys, persistent menus, explicit row actions, target/pressure validation, cancel, CNI handoff and power PASS')
