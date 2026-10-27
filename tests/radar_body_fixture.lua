-- Synthetic body observations for offline control tests only.

local actual_update=update
local fixture_clock=0
if type(get_model_time)~='function' then
 function get_model_time()return fixture_clock end
end
function update()
 fixture_clock=fixture_clock+.05
 local pose={north=0,east=0,altitude=0,heading=0,pitch=0,roll=0}
 local sensor=get_base_data()
 pose.north,pose.altitude,pose.east=sensor.getSelfCoordinates()
 pose.heading=(2*math.pi-sensor.getHeading())%(2*math.pi)
 pose.pitch=sensor.getPitch();pose.roll=sensor.getRoll()
 local d=dofile(SCRIPT_ROOT..'Systems/Radar_Display.lua')
 -- Control/geometry tests simulate a live native STT producer. Failure tests
 -- must not use this helper: they freeze/invalidate the independent timestamp.
 local range=get_param_handle('F22N_RADAR_STT_RANGE'):get()
 local stt=get_param_handle('F22N_RADAR_MODE'):get()==3 and range>=40
 get_param_handle('F22_STT_MOTION_VALID'):set(stt and 1 or 0)
 if stt then
  local o={range=range,az=get_param_handle('F22N_RADAR_STT_AZIMUTH'):get(),
   el=get_param_handle('F22N_RADAR_STT_ELEVATION'):get()}
  d.world_observation(o,pose)
  for k,v in pairs({ID=9001,TIME=get_model_time(),PN=o.north,PU=o.altitude,PE=o.east,VN=0,VU=0,VE=0})do
   get_param_handle('F22_STT_'..k):set(v)
  end
 end
 get_param_handle('F22_RADAR_OBSERVATIONS_READY'):set(1)
 local count=0
 for i=1,64 do
  local p=string.format('F22N_RADAR_CONTACT_%02d_',i)
  local r=get_param_handle(p..'RANGE'):get();local age=get_param_handle(p..'TIME'):get()
  if r>=40 and age>=0 then
   local o={range=r,az=get_param_handle(p..'AZIMUTH'):get(),el=get_param_handle(p..'ELEVATION'):get()}
   d.world_observation(o,pose);count=count+1
   local q=string.format('F22O_%02d_',count)
   for k,v in pairs({NORTH=o.north,EAST=o.east,ALTITUDE=o.altitude,ID=1000+i,AGE=age,
    IFF=get_param_handle(p..'FRIENDLY'):get(),VN=get_param_handle(p..'VX'):get(),
    VU=get_param_handle(p..'VY'):get(),VE=get_param_handle(p..'VZ'):get()}) do get_param_handle(q..k):set(v) end
  end
 end
 get_param_handle('F22_RADAR_OBSERVATION_COUNT'):set(count)
 actual_update()
end
