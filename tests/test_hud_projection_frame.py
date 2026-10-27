"""Cross-cue physical origin and off-axis focal-plane projection regression.

These native-element checks prove math/wiring, not real optical/VR alignment.
"""
from pathlib import Path
import contextlib,io
ROOT=Path(__file__).resolve().parents[1]
fixture=ROOT/'tests/test_display_startup.py';ns={'__file__':str(fixture)}
exec(compile(fixture.read_text().split('\nfor page in ',1)[0],str(fixture),'exec'),ns)
sim=ns['runtime']()
sim.execute('''
local optics=dofile(SCRIPT_ROOT..'HUD/optics.lua')
local projection=dofile(SCRIPT_ROOT..'Systems/HUD_Projection.lua')
local forward,down=optics.distance_factor[1],optics.distance_factor[2]
local planar_az,planar_el=math.atan(.12),math.atan(-.08)
local polar_el=math.atan2(-.08,math.sqrt(1+.12*.12))
local x,y=projection.planar(planar_az,planar_el)
assert(math.abs(x-.12)<1e-12 and math.abs(y+.08)<1e-12)
local px,py=projection.polar(planar_az,polar_el)
assert(math.abs(px-x)<1e-12 and math.abs(py-y)<1e-12,'polar/planar elevation confused')
assert(not projection.polar(math.pi,0),'rear seeker ray reflected into forward HUD')
assert(not projection.polar(math.pi/2,0))
assert(not projection.planar(0/0,0) and not projection.planar(0,math.huge))

dofile(SCRIPT_ROOT..'HUD/page.lua')
local named={};for _,e in ipairs(elements)do named[e.name]=e end
local values={}
local function position(name)
 local e=assert(named[name],name);local ax,ay=0,0
 if e.parent_element then ax,ay=position(e.parent_element)end
 local p=e.init_pos or {0,0,0};ax=ax+p[1]*GetScale();ay=ay+p[2]*GetScale()
 for _,c in ipairs(e.controllers or {})do
  if c[1]=='move_left_right_using_parameter' then ax=ax+(values[e.element_params[c[2]+1]]or 0)*c[3]
  elseif c[1]=='move_up_down_using_parameter' then ay=ay+(values[e.element_params[c[2]+1]]or 0)*c[3]end
 end
 return ax,ay
end
local roots={'HUD_ATTITUDE_ROLL','HUD_FPM','HUD_NAV_STEERING','HUD_NAV_OFFSCREEN',
 'HUD_IR_NATIVE_3','HUD_GUN_NATIVE','HUD_RADAR_TD','HUD_SECONDARY_TD','HUD_TARGET_LOCATOR',
 'HUD_GUN_FUNNEL','HUD_GUN_MANEUVER','HUD_AG_MARKER','HUD_AG_CCIP_PIPPER','HUD_ACM_VOLUME_1'}
for _,name in ipairs(roots)do
 local rx,ry=position(name)
 assert(math.abs(rx)<1e-9 and math.abs(down+ry)<1e-9,
  name..' forward ray differs from common physical FRL')
end
-- Plane translations must use exact slopes at finite off-axis directions.
for _,prefix in ipairs({'HUD_FPM','HUD_IR_SEEKER','HUD_GUN_NATIVE','HUD_AG_TGT','HUD_AG_CCIP'})do
 values[prefix..'_X_SLOPE']=x;values[prefix..'_Y_SLOPE']=y
end
values.HUD_WP_X=x;values.HUD_WP_Y=y;values.HUD_TD_X=x;values.HUD_TD_Y=y
for _,name in ipairs({'HUD_FPM','HUD_NAV_STEERING','HUD_IR_NATIVE_3','HUD_GUN_NATIVE','HUD_RADAR_TD','HUD_AG_MARKER','HUD_AG_CCIP_PIPPER'})do
 local rx,ry=position(name)
 assert(math.abs(rx-forward*x)<1e-9 and math.abs(down+ry-forward*y)<1e-9,
  name..' consumes angular units as linear matrix translation')
end

-- Exercise real flight and ground-designation producers, not hand-seeded
-- display values alone. Their old angular contracts remain unchanged.
function get_base_data()return setmetatable({
 getSelfCoordinates=function()return 0,1000,0 end,
 getHeading=function()return 0 end,getPitch=function()return 0 end,getRoll=function()return 0 end,
},{__index=function()return function()return 0 end end})end
local function put(k,v)get_param_handle(k):set(v)end
local function get(k)return get_param_handle(k):get()end
put('EFM_HUD_VALID',1);put('EFM_HUD_VN',100);put('EFM_HUD_VE',12);put('EFM_HUD_VU',-8)
dofile(SCRIPT_ROOT..'Systems/HUD_Flight_Data.lua');update=dofile(SCRIPT_ROOT..'../../tests/reference_frame_fixture.lua')():wrap(update);post_initialize();update()
assert(math.abs(get('HUD_FPM_X_RAD')-planar_az)<1e-12)
assert(math.abs(get('HUD_FPM_X_SLOPE')-x)<1e-12 and math.abs(get('HUD_FPM_Y_SLOPE')-y)<1e-12)
package.preload.terrain=function()return {GetHeight=function()return 200 end}end
put('MAIN_POWER',1);put('HUD_MODE',7)
dofile(SCRIPT_ROOT..'Systems/AG_Mark_System.lua');post_initialize()
put('F22_AG_DESIGNATION_SEQUENCE',1);put('F22_AG_DESIGNATION_VALID',1)
put('F22_AG_DESIGNATION_NORTH',10000);put('F22_AG_DESIGNATION_ALTITUDE',200);put('F22_AG_DESIGNATION_EAST',1200);update()
assert(math.abs(get('HUD_AG_TGT_AZ_RAD')-planar_az)<1e-12)
assert(math.abs(get('HUD_AG_TGT_X_SLOPE')-x)<1e-12 and math.abs(get('HUD_AG_TGT_Y_SLOPE')-y)<1e-12)

local ag_clock=10;local queued=false
function get_model_time()return ag_clock end
function dispatch_action(_,c)
 if c==10851 then queued=true end
end
local function native_frame()
 assert(queued);queued=false
 put('F22_AG_BOMB_NATIVE_VALID',1);put('F22_AG_BOMB_RESULT_TIME',10)
 put('F22_AG_BOMB_RESPONSE_SEQUENCE',get('F22_AG_BOMB_REQUEST_SEQUENCE'))
 put('F22_AG_BOMB_RESPONSE_SCHEMA',2);put('F22_AG_BOMB_RESPONSE_REQUEST_TIME',get('F22_AG_BOMB_REQUEST_TIME'))
 for _,key in ipairs({'STATION','TYPE3','TYPE4'})do put('F22_AG_BOMB_RESPONSE_'..key,get('F22_AG_BOMB_REQUEST_'..key))end
 put('F22_AG_BOMB_IMPACT_N',10000);put('F22_AG_BOMB_IMPACT_U',200);put('F22_AG_BOMB_IMPACT_E',1200);put('F22_AG_BOMB_FALL_TIME',10)
end
-- Guided point isolates physical projection from terrain interpolation,
-- which is covered by the independent queued/ridge/valley owner regression.
put('HUD_AG_SUBMODE',3);put('F22_AG_GUIDED_SELECTED',1);put('F22_AG_BOMB_SELECTED',1);put('F22_AG_WEAPON_TYPE3',36);put('F22_AG_WEAPON_TYPE4',32);put('F22_WEAPON_STATION',4);put('BAY_C_ARG',1)
put('F22_AG_BOMB_ASYNC_SUPPORTED',2);put('HUD_AG_TARGET_VALID',1)
dofile(SCRIPT_ROOT..'Systems/AG_Ballistic_Computer.lua');post_initialize();update()
assert(get('F22_AG_SOLUTION_VALID')==0);native_frame();ag_clock=10.05;update()
assert(get('F22_AG_SOLUTION_VALID')==1)
assert(math.abs(get('HUD_AG_CCIP_AZ_RAD')-planar_az)<1e-12)
assert(math.abs(get('HUD_AG_CCIP_X_SLOPE')-x)<1e-12 and math.abs(get('HUD_AG_CCIP_Y_SLOPE')-y)<1e-12)
assert(math.abs(get('HUD_AG_DIL_X1')-x)<1e-12 and math.abs(get('HUD_AG_DIL_Y1')-y-optics.frl_elevation)<1e-12)
-- Dynamic bomb-fall line endpoint must coincide with its pipper exactly.
local dil=named.HUD_AG_BOMB_FALL_LINE
local c=dil.controllers[2]
local lx=get(dil.element_params[c[3]+1])*c[5]
local ly=get(dil.element_params[c[4]+1])*c[6]
local rx,ry=position('HUD_AG_CCIP_PIPPER')
assert(math.abs(lx-rx)<1e-9 and math.abs(ly-ry)<1e-9,'fall line misses CCIP pipper')
''')
print('HUD physical frame: 14 common FRL origins, finite polar/planar rays, rear-ray rejection, actual FPM/AG producers and exact fall-line/pipper coincidence PASS')
