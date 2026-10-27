-- Synthetic publication for HUD consumer-only tests. Radar producer and
-- producer-failure integration tests supply the actual native world snapshot.
local now=0
if type(get_model_time)~='function'then function get_model_time()return now end end
function publish_test_stt(range,az,el,iff)
 now=now+.05
 local values={F22N_RADAR_MODE=3,F22_STT_MOTION_VALID=1,F22_STT_ID=9001,
  F22_STT_TIME=get_model_time(),F22_RADAR_STT_VALID=1,F22_RADAR_STT_SOURCE_ID=9001,
  F22_RADAR_STT_TIME=get_model_time(),F22_RADAR_STT_RANGE=range,
  F22_RADAR_STT_AZIMUTH=az,F22_RADAR_STT_ELEVATION=el,F22_RADAR_STT_IFF=iff==1 and 1 or -1}
 for name,value in pairs(values)do get_param_handle(name):set(value)end
end
