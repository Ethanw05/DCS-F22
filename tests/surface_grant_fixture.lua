-- Explicit completed array-job producer for surface controller replays.
return function(sensor,put)
 local actual=sensor.update;local sequence=0
 function sensor:update(pose,now,...)
  sequence=sequence+1
  put('F22_AESA_SURFACE_SERVICE',1);put('F22_AESA_SURFACE_SEQUENCE',sequence)
  -- Explicit16-cell synthetic volume; native grid geometry is tested in C++.
  put('F22_AESA_SURFACE_SEARCH',1);put('F22_AESA_SURFACE_CELLS',16)
  put('F22_AESA_SURFACE_AZ',math.sin(sequence*.3)*.5)
  put('F22_AESA_SEQUENCE',sequence*2);put('F22_AESA_READY',1);put('F22_AESA_GENERATION',1);put('F22_AESA_TIME',now)
  put('F22_AESA_SURFACE_DISCOVERY_SEQUENCE',sequence);put('F22_AESA_SURFACE_DISCOVERY_WORK',sequence/16)
  return actual(self,pose,now,...)
 end
end
