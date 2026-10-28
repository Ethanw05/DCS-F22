-- Explicit completed array-job producer for surface controller replays.
return function(sensor,put)
 local actual=sensor.update;local sequence=0
 function sensor:update(...)
  sequence=sequence+1
  put('F22_AESA_SURFACE_SERVICE',1);put('F22_AESA_SURFACE_SEQUENCE',sequence)
  -- Explicit16-cell synthetic volume; native grid geometry is tested in C++.
  put('F22_AESA_SURFACE_SEARCH',1);put('F22_AESA_SURFACE_CELLS',16)
  put('F22_AESA_SURFACE_AZ',math.sin(sequence*.3)*.5)
  return actual(self,...)
 end
end
