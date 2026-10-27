"""TSD composition uses NAV measurements and passive unit directions only."""
from test_display_startup import runtime
lua=runtime()
lua.execute('''
local TSD=dofile(SCRIPT_ROOT..'Systems/Tactical_Situation.lua')
local Frames=dofile(SCRIPT_ROOT..'Systems/Gun_Frames.lua')
local v={F22_RADAR_RANGE_NM=20,F22_NAV_SOURCE=0,F22_NAV_VALID=1,F22_NAV_OWN_VALID=1,
 F22_NAV_STEER_VALID=1,F22_NAV_STEER_STAMP=5,F22_NAV_SCALE_NM=40,F22_NAV_COMPASS_ROT=0,
 F22_NAV_TARGET_N=10*1852,F22_NAV_TARGET_E=5*1852,F22_NAV_OWN_N=0,F22_NAV_OWN_E=0,HUD_WP_INDEX=3,
 F22_NAV_LEG_01_VALID=1,F22_NAV_LEG_01_X1=-.1,F22_NAV_LEG_01_Y1=.1,
 F22_NAV_LEG_01_X2=.1,F22_NAV_LEG_01_Y2=.2}
local h,p,r=0,0,0
local sensors={getHeading=function()return -h end,getPitch=function()return p end,getRoll=function()return r end}
local function get(k)return v[k]or 0 end
local function put(k,x)v[k]=x end
local t=TSD.new(get,put,sensors)
local rf={source=100,signal=2,az=.2,el=0,age=0,selected=true,observations={
 rf={time=5,az=.2,el=0}}}
t:update(5,{rf},true)
assert(v.F22_TSD_NAV_VALID==1 and v.F22_TSD_NAV_ID==3)
assert(math.abs(v.F22_TSD_NAV_X-1.45*.25)<1e-10)
assert(math.abs(v.F22_TSD_NAV_Y-(-.66+1.45*.5))<1e-10)
assert(v.F22_TSD_NAV_LEG_01_VALID==1)
local x,y=v.F22_TSD_BEARING_01_X,v.F22_TSD_BEARING_01_Y
assert(math.abs(math.sqrt(x*x+(y+.66)^2)-.20)<1e-10,'passive bearing acquired a map range')
v.F22_RADAR_RANGE_NM=80;t:update(5,{rf},true)
assert(v.F22_TSD_BEARING_01_X==x and v.F22_TSD_BEARING_01_Y==y,'passive ring scales with range')
assert(math.abs(v.F22_TSD_NAV_X-1.45/16)<1e-10)
-- Stabilized heading-up passive direction remains fixed across ownship bank
-- and pitch when its genuine current body observation is transformed back.
h=.4;p=.6;r=1.2
local frame=Frames.from_pose({heading=h,pitch=p,roll=r})
local body=Frames.body(frame,{1,0,0})
rf.observations.rf.az=math.atan2(body[3],body[1])
rf.observations.rf.el=math.atan2(body[2],math.sqrt(body[1]^2+body[3]^2))
t:update(5,{rf},true)
assert(math.abs(v.F22_TSD_BEARING_01_X+.20*math.sin(h))<1e-10)
assert(math.abs(v.F22_TSD_BEARING_01_Y-(-.66+.20*math.cos(h)))<1e-10)
-- Existing on-map radar source suppresses a second passive symbol.
v.F22_SCOPE_01_VALID=1;v.F22_SCOPE_01_SOURCE=100;t:update(5,{rf},true)
assert(v.F22_TSD_BEARING_01_VALID==0 and v.F22_TSD_SELECTED_RF==1)
v.F22_SCOPE_01_COAST=1;t:update(5,{rf},true)
assert(v.F22_TSD_BEARING_01_VALID==1,'coasting radar ghost hid a current passive direction')
v.F22_SCOPE_01_COAST=0
v.F22_SCOPE_01_VALID=0
t:update(5.6,{rf},true);assert(v.F22_TSD_NAV_VALID==0 and v.F22_TSD_NAV_LEG_01_VALID==0,'frozen NAV stays fresh')
v.F22_NAV_STEER_STAMP=5.6;v.F22_NAV_SOURCE=1;t:update(5.6,{rf},true)
assert(v.F22_TSD_NAV_VALID==0,'TACAN source reuses stale mission target')
v.F22_NAV_SOURCE=0;t:command(10915);t:update(5.6,{rf},true);assert(v.F22_TSD_NAV_VALID==0)
t:command(10916);t:update(5.6,{rf},true);assert(v.F22_TSD_BEARING_01_VALID==0)
t:reset();v.F22_AG_RADAR_PAGE=1;t:update(5.6,{rf},true)
assert(v.F22_TSD_VALID==0 and v.F22_TSD_NAV_VALID==0 and v.F22_TSD_BEARING_01_VALID==0,'TSD leaks into A/G')
t:update(5.6,{rf},false);assert(v.F22_TSD_VALID==0)
''')
print('TSD: common-source passive ring, heading/pitch/bank stabilization, real NAV scale/age/source gates, dedup, layers and A/G exclusion PASS')
lua=runtime()
lua.execute('''
local now,heading=0,0
function get_model_time()return now end
function get_base_data()return {getHeading=function()return -heading end,
 getPitch=function()return 0 end,getRoll=function()return 0 end}end
local function put(k,x)get_param_handle(k):set(x)end
local function get(k)return get_param_handle(k):get()end
dofile(SCRIPT_ROOT..'Systems/MWS_System.lua');post_initialize()
put('MAIN_POWER',1);put('F22_MWS_NATIVE_READY',1)
for k,v in pairs({VALID=1,THREAT=1,SOURCE=9,TIME=0,AZ=0,EL=0})do put('F22_MWS_NATIVE_01_'..k,v)end
update()
-- Fresh sensor publications, but no new sighting: maintain and rotate the
-- remembered world direction without modifying the raw receiver track.
put('F22_MWS_NATIVE_01_VALID',0)
for tick=1,24 do
 now=tick*.05;heading=now*math.pi/2;put('F22_MWS_NATIVE_TIME',now);update()
 assert(math.abs(get('F22_MWS_01_AZ')+heading)<1e-10,'optical memory double-rotated or stayed body-fixed')
end
assert(get('F22_MWS_COAST')==1)
''')
print('Actual optical owner: 108-degree ownship turn preserves raw measurement and correctly rotates warning memory PASS')
