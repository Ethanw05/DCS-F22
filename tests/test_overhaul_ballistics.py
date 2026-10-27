"""Actual ballistic owner with DCS-style queued dispatch, not an inline fake.
Reproduces request1/response0 followed by response1/native time +1 ms.
"""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
fixture=ROOT/'tests/test_display_startup.py';ns={'__file__':str(fixture)}
exec(compile(fixture.read_text().split('\nfor page in ',1)[0],str(fixture),'exec'),ns)
lua=ns['runtime']()
lua.execute(r'''
local now=10;local own_n=0;local path_ready=true;local guided=false;local ridge=true;local valley=false
local native_offset=.001;local queued=0;local dropped=false;local mismatch=nil;local schema=2
function get_model_time()return now end
package.preload.terrain=function()return {GetHeight=function(n)
 if ridge and n>=450 and n<=650 then return 900 end
 if valley and n>=1500 then return -100 end
 return 0
end}end
function get_base_data()return {getSelfCoordinates=function()return own_n,1000,0 end,getHeading=function()return 0 end,getPitch=function()return -.2 end,getRoll=function()return 0 end}end
local function put(n,v)get_param_handle(n):set(v)end
local function val(n)return get_param_handle(n):get()end
function dispatch_action(_,c)if c==10851 then queued=queued+1 end end
local function native_frame()
 assert(queued<=1,'multiple queued native solves in one activity')
 if queued==0 then return end
 queued=0;put('F22_AG_BOMB_ASYNC_SUPPORTED',schema)
 if val('F22_AG_BOMB_REQUEST_VALID')<.5 or dropped then return end
 assert(val('F22_AG_BOMB_REQUEST_SCHEMA')==2)
 local stamp=val('F22_AG_BOMB_REQUEST_TIME')
 local origin=val('F22_AG_BOMB_REQUEST_N');local altitude=val('F22_AG_BOMB_REQUEST_U')
 local endpoint=guided and 5000 or origin+2000
 local level=val('F22_AG_BOMB_REQUEST_GROUND_LEVEL')
 put('F22_AG_BOMB_NATIVE_VALID',1);put('F22_AG_BOMB_RESULT_TIME',stamp+native_offset)
 put('F22_AG_BOMB_RESPONSE_SEQUENCE',val('F22_AG_BOMB_REQUEST_SEQUENCE'))
 put('F22_AG_BOMB_RESPONSE_SCHEMA',2);put('F22_AG_BOMB_RESPONSE_REQUEST_TIME',stamp)
 for _,key in ipairs({'STATION','TYPE3','TYPE4'})do put('F22_AG_BOMB_RESPONSE_'..key,val('F22_AG_BOMB_REQUEST_'..key))end
 put('F22_AG_BOMB_IMPACT_N',endpoint);put('F22_AG_BOMB_IMPACT_U',level);put('F22_AG_BOMB_IMPACT_E',0);put('F22_AG_BOMB_FALL_TIME',10)
 put('F22_AG_BOMB_TRAJECTORY_SUPPORTED',1);put('F22_AG_BOMB_TRAJECTORY_READY',path_ready and 1 or 0);put('F22_AG_BOMB_POINT_COUNT',17)
 for i=0,16 do local f=i/16;local values={origin+(endpoint-origin)*f,altitude+(level-altitude)*f,0,10*f}
  for j,axis in ipairs({'N','U','E','T'})do put(string.format('F22_AG_BOMB_%02d_%s',i,axis),values[j])end
 end
 if mismatch then put(mismatch,val(mismatch)+1)end
end
local function tick(delta)
 delta=delta or .05;now=now+delta;own_n=own_n+val('EFM_HUD_VN')*delta
 update();native_frame()
end
dofile(SCRIPT_ROOT..'Systems/AG_Ballistic_Computer.lua');post_initialize()
put('MAIN_POWER',1);put('HUD_MODE',7);put('HUD_AG_SUBMODE',2);put('EFM_HUD_VALID',1);put('F22_AG_BOMB_SELECTED',1)
put('F22_AG_WEAPON_TYPE3',9);put('F22_AG_WEAPON_TYPE4',32);put('F22_WEAPON_STATION',4);put('EFM_HUD_VN',200);put('BAY_C_ARG',0)
update();assert(val('F22_AG_BOMB_REQUEST_VALID')==0 and val('F22_AG_SOLUTION_VALID')==0,'schema handshake did not fail closed');native_frame()
tick();assert(val('F22_AG_SOLUTION_VALID')==0,'queued solve consumed before native frame')
local first_seq=val('F22_AG_BOMB_REQUEST_SEQUENCE');local first_origin=val('F22_AG_BOMB_REQUEST_N');local first_stamp=val('F22_AG_BOMB_REQUEST_TIME')
assert(math.abs(first_origin-100)<.001,'callback wait/closed-bay lead not predicted')
tick();assert(val('F22_AG_SOLUTION_VALID')==1 and val('F22_AG_TERRAIN_PATH_VALID')==1,'queued response not consumed')
assert(math.abs(val('F22_AG_SOLUTION_IMPACT_N')-450)<.01,'native endpoint skipped intervening ridge')
assert(val('F22_AG_SOLUTION_SEQUENCE')==first_seq and val('F22_AG_BOMB_REQUEST_SEQUENCE')==first_seq+1)
assert(math.abs(val('F22_AG_OWN_N')-first_origin)<.001 and math.abs(val('F22_AG_BOMB_REQUEST_N')-110)<.001,'next request overwrote consumed pose')
assert(math.abs(val('F22_AG_SOLUTION_TIME')-first_stamp)<.000001,'old measurement restamped at publication')
assert(math.abs(val('F22_AG_SOLUTION_PUBLICATION_TIME')-now)<.000001 and math.abs(val('F22_AG_SOLUTION_NATIVE_TIME')-first_stamp-.001)<.000001)
assert(math.abs(val('F22_AG_SOLUTION_MEASUREMENT_AGE_SEC')-.05)<.000001 and math.abs(val('F22_AG_SOLUTION_NATIVE_LATENCY_SEC')-.001)<.000001)
assert(val('F22_AG_BOMB_IMPACT_N')>2000 and math.abs(val('F22_AG_SOLUTION_IMPACT_N')-450)<.01,'raw result aliased published intersection')
put('EFM_HUD_VN',210);tick();local predicted=val('F22_AG_BOMB_REQUEST_N');local predicted_v=val('F22_AG_BOMB_REQUEST_VN')
tick();assert(math.abs(val('F22_AG_OWN_N')-predicted)<.001 and math.abs(val('F22_AG_RELEASE_VN')-predicted_v)<.001,'response lost bounded acceleration input')
put('BAY_C_ARG',.5);tick();assert(math.abs(val('F22_AG_BOMB_REQUEST_N')-(own_n+210*.2))<.001,'opening travel counted twice')
for _,name in ipairs({'F22_AG_BOMB_RESPONSE_STATION','F22_AG_BOMB_RESPONSE_TYPE3','F22_AG_BOMB_RESPONSE_TYPE4','F22_AG_BOMB_RESPONSE_SCHEMA','F22_AG_BOMB_RESPONSE_REQUEST_TIME'})do
 mismatch=name;tick();tick();assert(val('F22_AG_SOLUTION_VALID')==0,'mismatched response accepted: '..name)
end
mismatch=nil;native_offset=.02;tick();tick();assert(val('F22_AG_SOLUTION_VALID')==1,'processing latency conflated with future observation')
native_offset=.07;tick();tick();assert(val('F22_AG_SOLUTION_VALID')==0,'20ms future relative to observation accepted')
native_offset=-.03;tick();tick();assert(val('F22_AG_SOLUTION_VALID')==0,'native execution before request accepted')
native_offset=.001;tick();tick();assert(val('F22_AG_SOLUTION_VALID')==1)
put('F22_WEAPON_STATION',6);tick();assert(val('F22_AG_SOLUTION_VALID')==0,'changed station inherited pending solve')
tick();assert(val('F22_AG_SOLUTION_VALID')==1 and val('F22_AG_SOLUTION_STATION')==6)
-- Dropped results keep frozen input valid without issuing a newer identity.
dropped=true;tick();local waiting=val('F22_AG_BOMB_REQUEST_SEQUENCE');tick()
assert(val('F22_AG_SOLUTION_VALID')==0 and val('F22_AG_BOMB_REQUEST_SEQUENCE')==waiting and val('F22_AG_BOMB_REQUEST_VALID')==1)
tick();assert(val('F22_AG_BOMB_REQUEST_SEQUENCE')==waiting)
tick();assert(val('F22_AG_BOMB_REQUEST_SEQUENCE')==waiting+1 and val('F22_AG_SOLUTION_VALID')==0,'expired request restamped')
dropped=false;tick();tick();tick()
ridge=false;valley=true;put('BAY_C_ARG',1);put('F22_WEAPON_STATION',4);tick();tick()
assert(val('F22_AG_SOLUTION_VALID')==0,'unbracketed endpoint above valley accepted')
tick();assert(val('F22_AG_TERRAIN_PATH_VALID')==1 and val('F22_AG_SOLUTION_IMPACT_U')< -99.9,'queued terrain refinement failed')
path_ready=false;tick();tick();assert(val('F22_AG_SOLUTION_VALID')==0,'missing path used endpoint-only CCIP')
guided=true;valley=false;put('HUD_AG_SUBMODE',3);put('F22_AG_GUIDED_SELECTED',1);put('F22_AG_WEAPON_TYPE3',36)
put('F22_AG_DELIVERY_TARGET_SOURCE',2);put('F22_AG_DELIVERY_TARGET_VALID',1);put('F22_AG_DELIVERY_TARGET_SEQUENCE',1)
put('F22_AG_DELIVERY_TARGET_N',5500);put('F22_AG_DELIVERY_TARGET_U',0);put('F22_AG_DELIVERY_TARGET_E',500)
put('HUD_AG_TARGET_VALID',1);put('HUD_AG_MARK_NORTH',90000);tick();tick()
assert(val('F22_AG_LAR_ESTIMATED')==1 and val('F22_AG_LAR_READY')==1 and val('F22_AG_AUTO_RELEASE')==1,'stored target/estimated guided LAR not consumed')
put('F22_AG_DELIVERY_TARGET_N',5600);tick();assert(val('F22_AG_SOLUTION_VALID')==0,'changed target inherited pending solve')
tick();assert(val('F22_AG_SOLUTION_VALID')==1)
put('F22_AG_DELIVERY_TARGET_VALID',0);tick();assert(val('F22_AG_SOLUTION_VALID')==0 and val('F22_AG_AUTO_RELEASE')==0,'invalid stored target used live designation')
put('MAIN_POWER',0);tick();assert(val('F22_AG_BOMB_REQUEST_VALID')==0)
put('MAIN_POWER',1);put('F22_AG_DELIVERY_TARGET_VALID',1);tick();assert(val('F22_AG_SOLUTION_VALID')==0)
tick();now=now-.1;update();native_frame();assert(val('F22_AG_SOLUTION_VALID')==0,'model rewind reused old response')
guided=false;path_ready=true;put('HUD_AG_SUBMODE',2);put('F22_AG_GUIDED_SELECTED',0);put('F22_AG_WEAPON_TYPE3',9);put('BAY_C_ARG',0)
put('EFM_VEHICLE_VALID',1);put('EFM_ACTUATOR_AVAILABLE',0);tick()
assert(val('F22_AG_SOLUTION_VALID')==0 and val('F22_AG_BAY_PREDICTION_VALID')==0)
put('EFM_ACTUATOR_AVAILABLE',.5);tick();assert(math.abs(val('F22_AG_BOMB_REQUEST_N')-(own_n+210*.85))<.001,'partial authority delay forecast lost')
put('EFM_ACTUATOR_AVAILABLE',.1);tick();assert(val('F22_AG_SOLUTION_VALID')==0 and val('F22_AG_BOMB_REQUEST_VALID')==0)
put('BAY_C_ARG',1);put('EFM_ACTUATOR_AVAILABLE',0);tick();tick();assert(val('F22_AG_SOLUTION_VALID')==1 and val('F22_AG_SOLUTION_DELAY')==0)
-- Device recreation with retained native handles and identical clock/context
-- cannot repeat a completed transaction's sequence (ABA).
local old_response=val('F22_AG_BOMB_RESPONSE_SEQUENCE');local old_stamp=val('F22_AG_BOMB_RESPONSE_REQUEST_TIME')
post_initialize();now=old_stamp;update()
assert(val('F22_AG_BOMB_REQUEST_SEQUENCE')>old_response,'device reset reused a retained native identity')
now=now+.05;update();assert(val('F22_AG_SOLUTION_VALID')==0,'retained same-time response accepted after reset');native_frame()
tick();tick();assert(val('F22_AG_SOLUTION_VALID')==1)
''')
print('Overhaul ballistic queued owner: identity, source/native/publication clocks, stable pose/impact, callback forecast, achieved bay travel, ridge/valley terrain, stored targets, resets and physical supply PASS')
