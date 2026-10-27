"""Real guidance Lua: heading wrap, CDI, true/magnetic, radio loss and ICP routing."""
from test_display_startup import runtime
sim=runtime()
sim.execute("""
local nav=dofile(SCRIPT_ROOT..'Systems/Nav_Computer.lua')
local guidance=dofile(SCRIPT_ROOT..'Systems/Nav_Guidance.lua')
function get(k)return get_param_handle(k):get()end
function put(k,v)get_param_handle(k):set(v)end
local own={x=0,y=1852,alt=3000,heading=math.rad(359),gs=200}
local route=nav.new({{x=0,y=0,alt=3000},{x=18520,y=0,alt=3000}})
local s=nav.solution(route,own)
put('MAIN_POWER',1);put('F22_AP_HEADING',1);put('F22_AP_CLOCK',42)
guidance(get,put,own,s)
assert(math.abs(get('HUD_HDG_BUG_DEG')-2)<1e-8,'short path across north')
assert(get('HUD_NAV_BUG_DEG')<0 and get('F22_NAV_STEER_VALID')==1)
assert(get('F22_NAV_CDI')<0 and get('F22_NAV_STEER_TRACK')>math.pi,'right of northbound leg steers left')
assert(get('F22_NAV_STEER_STAMP')==42)
put('F22_NAV_REFERENCE',1);put('F22_MAG_VALID',1);put('F22_MAG_DECL',math.rad(10))
guidance(get,put,own,s);assert(get('F22_NAV_HEADING_TEXT')=='349M')
assert(math.abs(get('HUD_HDG_BUG_DEG')-2)<1e-8,'relative bug unaffected by reference')
put('F22_NAV_SOURCE',1);put('F22_TCN_MODE',2);put('F22_TCN_BRG_VALID',1);put('F22_TCN_BRG_MAG',math.rad(20))
put('F22_TCN_RANGE_VALID',1);put('F22_TCN_RANGE_M',18520);put('F22_TCN_TUNE_TEXT','TCN 001X T/R')
guidance(get,put,own,nil);assert(get('F22_NAV_BRG_TEXT')=='BRG 020M' and get('HUD_NAV_BUG_EDGE')==1)
assert(get('F22_NAV_STEER_VALID')==1)
put('F22_MAG_VALID',0);guidance(get,put,own,nil);assert(get('F22_NAV_STEER_VALID')==0,'missing magnetic conversion inhibits coupling')
put('F22_NAV_SOURCE',0);put('F22_INS_MODEL_ENABLED',1);put('F22_INS_READY',0)
guidance(get,put,own,s);assert(get('F22_NAV_STEER_VALID')==0 and get('HUD_NAV_BUG_VALID')==0)
guidance(get,put,nil,nil);assert(get('HUD_HDG_BUG_VALID')==0)
""")
sim=runtime()
sim.execute("""
dofile(SCRIPT_ROOT..'Systems/Flight_Guidance.lua');post_initialize()
function get(k)return get_param_handle(k):get()end
function put(k,v)get_param_handle(k):set(v)end
put('MAIN_POWER',1);function dispatch_action(d,c,v)actions[#actions+1]={d,c,v}end
SetCommand(10950,25.375);SetCommand(10950,25.25)
assert(#actions==1 and actions[1][2]==11600,'one native AP command per physical press')
assert(get('F22_ILS_FREQ_KHZ')==110300)
for i=1,200 do SetCommand(10937,1)end;assert(get('F22_ILS_FREQ_KHZ')==111950)
for i=1,200 do SetCommand(10938,1)end;assert(get('F22_ILS_FREQ_KHZ')==108100)
for i=1,200 do SetCommand(10934,1)end;assert(get('F22_TCN_CHANNEL')==1)
SetCommand(10953,1);assert(actions[#actions][2]==11603)
put('MAIN_POWER',0);SetCommand(10962,1);assert(actions[#actions][2]==11612)
""")
sim=runtime()
sim.execute("""
local guidance=dofile(SCRIPT_ROOT..'Systems/Nav_Guidance.lua')
local function get(k)return get_param_handle(k):get()end
local function put(k,v)get_param_handle(k):set(v)end
put('MAIN_POWER',1);put('HUD_MODE',1);put('F22_NAV_SOURCE',2);put('F22_ILS_LOC_VALID',1);put('F22_ILS_LOC',.6*math.rad(1.25))
put('F22_ILS_GS_VALID',0);put('F22_ILS_GS',.6*math.rad(.35));put('F22_ILS_TUNE_TEXT','ILS 110.30')
guidance(get,put,{heading=0,x=0,y=0,alt=1000,gs=130},nil)
assert(get('HUD_ILS_LOC_VALID')==1 and get('HUD_ILS_GS_VALID')==0 and math.abs(get('HUD_ILS_LOC')-.5)<1e-9)
assert(math.abs(get('HUD_ILS_GS')+.5)<1e-9,'positive receiver GS error means high: fly-down bar')
assert(get('F22_NAV_STEER_VALID')==0,'ILS advisory cannot silently engage waypoint autopilot')
put('F22_NAV_SOURCE',1);put('HUD_LANDING_CONFIG',1);put('HUD_MODE',7)
put('F22_ILS_GS_VALID',1);guidance(get,put,nil,nil)
assert(get('HUD_ILS_LOC_VALID')==1 and get('HUD_ILS_GS_VALID')==1,'valid landing reception lost under TCN/A-G or unavailable IRS position')
put('HUD_LANDING_CONFIG',0);guidance(get,put,nil,nil)
assert(get('HUD_ILS_DISPLAY_ENABLE')==0 and get('HUD_ILS_LOC_VALID')==0,'approach bars leaked into gear-up combat')
put('HUD_LANDING_CONFIG',1);put('F22_ILS_LOC_VALID',0);put('F22_ILS_GS_VALID',0);guidance(get,put,nil,nil)
assert(get('HUD_ILS_LOC_VALID')==0 and get('HUD_ILS_GS_VALID')==0)
put('F22_ILS_LOC_VALID',1);put('F22_ILS_GS_VALID',1);put('MAIN_POWER',0);guidance(get,put,nil,nil)
assert(get('HUD_ILS_DISPLAY_ENABLE')==0 and get('HUD_ILS_LOC_VALID')==0 and get('HUD_ILS_GS_VALID')==0)
""")
sim=runtime()
sim.execute("""
own={n=0,e=0,alt=3000}
function get_base_data()return {getSelfCoordinates=function()return own.n,own.alt,own.e end,
getHeading=function()return 0 end,getPitch=function()return 0 end,getRoll=function()return 0 end}end
function get_mission_route()return {{x=0,y=0,alt=3000},{x=10000,y=0,alt=3000}}end
dofile(SCRIPT_ROOT..'Systems/Navigation_System.lua');post_initialize()
local function p(k,v)get_param_handle(k):set(v)end
local function g(k)return get_param_handle(k):get()end
p('MAIN_POWER',1);p('HUD_GS_VALID',1);p('HUD_GS_MPS',100)
p('F22_INS_MODEL_ENABLED',1);p('F22_INS_READY',1);p('F22_GPS_AID',1);p('F22_AP_CLOCK',1);update()
p('F22_GPS_AID',0);p('EFM_HUD_VALID',1);p('EFM_HUD_VN',100);p('F22_AP_CLOCK',2)
own.n=1000;update()
assert(math.abs(g('HUD_WP_RANGE_NM')-9900/1852)<1e-6,'GPS off integrates velocity, ignores truth position jump')
p('F22_GPS_AID',1);p('F22_AP_CLOCK',2.1);update()
assert(g('HUD_WP_RANGE_NM')>9000/1852 and g('HUD_WP_RANGE_NM')<9900/1852,'GPS restoration corrects with bounded slew')
assert(g('F22_INS_POSITION_UNCERTAINTY_M')>15)
p('F22_GPS_AID',0);p('EFM_HUD_VALID',0);p('F22_AP_CLOCK',2.05);update()
assert(g('F22_NAV_STEER_VALID')==0,'lost inertial velocity inhibits coupling')
""")
print('Guidance math, stale/lost signal inhibition, source reference and physical AP input edges PASS')
sim=runtime()
sim.execute('''
local guidance=dofile(SCRIPT_ROOT..'Systems/Nav_Guidance.lua')
local function g(n)return get_param_handle(n):get()end
local function p(n,v)get_param_handle(n):set(v)end
p('MAIN_POWER',1);p('HUD_MODE',1);p('HUD_FPM_VALID',1);p('EFM_HUD_VALID',1);p('EFM_HUD_VN',100)
local own={x=0,y=0,alt=1000,heading=0,gs=100}
local s={bearing=math.rad(4),distance=18520,waypoint={id=2}}
guidance(g,p,own,s)
assert(g('HUD_NAV_STEER_VALID')==1 and math.abs(g('HUD_NAV_STEER_ERROR')-math.rad(4))<1e-9,'normal waypoint required OBS to show steering')
s.bearing=math.rad(-15);guidance(g,p,own,s)
assert(math.abs(g('HUD_NAV_STEER_ERROR')+math.rad(8))<1e-9 and math.abs(g('HUD_NAV_STEER_MAG_DEG')-15)<1e-9)
p('HUD_FPM_VALID',0);guidance(g,p,own,s);assert(g('HUD_NAV_STEER_VALID')==0)
p('HUD_FPM_VALID',1);p('F22_NAV_SOURCE',1);p('F22_TCN_MODE',2);p('F22_TCN_BRG_VALID',1);p('F22_MAG_VALID',1);p('F22_TCN_BRG_MAG',math.rad(3))
guidance(g,p,own,nil);assert(g('HUD_NAV_STEER_VALID')==1,'TACAN steering unavailable')
p('F22_TCN_BRG_VALID',0);guidance(g,p,own,nil);assert(g('HUD_NAV_STEER_VALID')==0,'lost TACAN kept an old cue')
''')
print('Hornet NAV cue: normal WPT without OBS, caged steering error, TACAN, FPM validity and lost receiver PASS')
