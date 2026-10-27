-- Synthetic measured body observations for controller/geometry replays only.
-- Legacy F22N_* names below are test inputs; production does not consume them.
-- The C++ sensor/ABI tests own detection, timing and noise coverage.
local actual_update=update
local fixture_clock=0
local display=dofile(SCRIPT_ROOT..'Systems/Radar_Display.lua')
local hits, stamps = {}, {}
if type(get_model_time)~='function' then
 function get_model_time()return fixture_clock end
end
local function set(n,v)get_param_handle(n):set(v)end
local function get(n)return get_param_handle(n):get()end
function update()
 fixture_clock=fixture_clock+.05
 local now=get_model_time()
 local sensor=get_base_data()
 local n,u,e=sensor.getSelfCoordinates()
 local pose={north=n,altitude=u,east=e,heading=(2*math.pi-sensor.getHeading())%(2*math.pi),
  pitch=sensor.getPitch(),roll=sensor.getRoll()}
 set('F22_AESA_DRIVER_READY',1);set('F22_AESA_READY',1)
 set('F22_AESA_SEQUENCE',4);set('F22_AESA_TIME',now)
 set('F22_AESA_GENERATION',1)
 for i=1,64 do
  local p=string.format('F22N_RADAR_CONTACT_%02d_',i)
  local q=string.format('F22A_%02d_',i)
  local range,age=get(p..'RANGE'),get(p..'TIME')
  local valid=range>=40 and age>=0
  set(q..'VALID',valid and 1 or 0)
  if valid then
   local o={range=range,az=get(p..'AZIMUTH'),el=get(p..'ELEVATION')}
   display.world_observation(o,pose)
   local stamp=now-age
   if not stamps[i] or stamp>stamps[i]+.01 then hits[i]=(hits[i]or 0)+1;stamps[i]=stamp end
   for k,v in pairs({ID=1000+i,TIME=stamp,N=o.north,U=o.altitude,E=o.east,
    VN=get(p..'VX'),VU=get(p..'VY'),VE=get(p..'VZ'),VELOCITY_VALID=1,
    HITS=hits[i],RANGE_SIGMA_M=30,ANGLE_SIGMA_RAD=.001,
    FILTER_VALID=1,POSITION_SIGMA_M=20,VELOCITY_SIGMA_MPS=10})do set(q..k,v)end
  end
 end
 actual_update()
end
