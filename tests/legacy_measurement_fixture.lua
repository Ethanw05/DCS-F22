-- Test-only migration of archived world-report inputs into the owned mailbox.
-- Production has no legacy observation fallback. This does not model sensing.
local actual=update
local clock=0
local fallback_clock
if type(get_model_time)~="function" then fallback_clock=function()return clock end;get_model_time=fallback_clock end
local function get(n)return get_param_handle(n):get()end
local function put(n,v)get_param_handle(n):set(v)end
function update()
 clock=type(get_model_time)=='function' and get_model_time~=fallback_clock and get_model_time() or clock+.05
 put('F22_AESA_DRIVER_READY',1);put('F22_AESA_READY',get('F22_RADAR_OBSERVATIONS_READY'))
 put('F22_AESA_TIME',clock);put('F22_AESA_SEQUENCE',4)
 put('F22_AESA_GENERATION',1)
 put('F22_TWS_GUIDANCE_BACKEND_READY',1)
 for i=1,64 do
  local p=string.format('F22O_%02d_',i);local q=string.format('F22A_%02d_',i)
  local valid=i<=get('F22_RADAR_OBSERVATION_COUNT') and get(p..'ID')>0
  put(q..'VALID',valid and 1 or 0)
  if valid then
   for k,v in pairs({ID=get(p..'ID'),TIME=clock-get(p..'AGE'),N=get(p..'NORTH'),
    U=get(p..'ALTITUDE'),E=get(p..'EAST'),VN=get(p..'VN'),VU=get(p..'VU'),VE=get(p..'VE'),
    ASSOCIATION_VALID=1,VELOCITY_VALID=1,HITS=2,RANGE_SIGMA_M=30,ANGLE_SIGMA_RAD=.001,
    FILTER_VALID=1,POSITION_SIGMA_M=20,VELOCITY_SIGMA_MPS=10})do put(q..k,v)end
  end
 end
 return actual()
end
