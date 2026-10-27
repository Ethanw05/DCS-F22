-- GPL-3.0-or-later. Deliberately simplified navigation estimate, not recovered F-22 INS.
-- Truth velocity remains the sensor approximation. Report an explicit uncertainty
-- budget instead of claiming ideal dead reckoning has real INS accuracy or adding
-- arbitrary position noise. Aiding correction is slew-limited to avoid route jumps.
local M={}
local function finite(v)return type(v)=='number'and v==v and math.abs(v)<1e9 end
function M.new()return setmetatable({valid=false,error=15,heading_error=.1},{__index=M})end
function M:update(s)
 local now=s.now
 if not finite(now)then self.valid=false;return end
 local dt=self.clock and now-self.clock or 0;self.clock=now
 if not s.powered then self.valid=false;return end
 if not(finite(s.n)and finite(s.e)and finite(s.alt))then self.valid=false;return end
 if not s.enabled then
  self.n,self.e,self.alt=s.n,s.e,s.alt;self.error=0;self.heading_error=0;self.valid=true;self.aiding=true
  return self.n,self.e,self.alt
 end
 if not s.aligned then self.valid=false;self.n=nil;return end
 if dt<0 or dt>2 then self.n=nil;self.valid=false end
 if s.aided then
  if not self.n or not self.valid then self.n,self.e,self.alt=s.n,s.e,s.alt;self.correcting=false
  elseif self.aiding and not self.correcting then self.n,self.e,self.alt=s.n,s.e,s.alt
  else
   self.correcting=true
   local dn,de,da=s.n-self.n,s.e-self.e,s.alt-self.alt
   -- Predicted inertial motion before the correction; do not trail normal flight.
   if s.velocity_valid and finite(s.vn)and finite(s.ve)and finite(s.vu)then
    self.n=self.n+s.vn*dt;self.e=self.e+s.ve*dt;self.alt=self.alt+s.vu*dt
    dn,de,da=s.n-self.n,s.e-self.e,s.alt-self.alt
   end
   local d=math.sqrt(dn*dn+de*de+da*da);local f=d>0 and math.min(1,50*dt/d)or 1
   self.n=self.n+dn*f;self.e=self.e+de*f;self.alt=self.alt+da*f
  end
  local residual=math.sqrt((self.n-s.n)^2+(self.e-s.e)^2+(self.alt-s.alt)^2)
  self.error=math.max(15,residual);if residual<=15 then self.correcting=false end
  self.heading_error=.1;self.valid=true;self.aiding=true
 else
  self.aiding=false
  if not self.n or not self.valid or not s.velocity_valid or not(finite(s.vn)and finite(s.ve)and finite(s.vu))then self.valid=false;return end
  self.n=self.n+s.vn*dt;self.e=self.e+s.ve*dt;self.alt=self.alt+s.vu*dt
  -- Own illustrative budget: 1 NM/hour position, .05 degrees/min heading, bounded.
  self.error=math.min(18520,self.error+1852/3600*dt)
  self.heading_error=math.min(5,self.heading_error+.05/60*dt)
 end
 return self.n,self.e,self.alt
end
return M
