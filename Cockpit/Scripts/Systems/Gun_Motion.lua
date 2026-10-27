-- GPL-3.0-or-later. Estimate rotation of velocity rather than lagging world acceleration.
-- Match the owned radar's bounded lock/update envelope, not cockpit tick rate.
local M={maximum_interval=.5}
local function finite(v)return type(v)=='number'and v==v and math.abs(v)<1e8 end
local function norm(v)return math.sqrt(v[1]^2+v[2]^2+v[3]^2)end
local function cross(a,b)return{a[2]*b[3]-a[3]*b[2],a[3]*b[1]-a[1]*b[3],a[1]*b[2]-a[2]*b[1]}end
function M.new()
 local self={}
 function self:reset()self.t=nil;self.v=nil;self.omega=nil;self.tangent=nil;self.a=nil end
 function self:update(t,v)
  if not finite(t)or not v or not finite(v[1])or not finite(v[2])or not finite(v[3])then self:reset();return end
  if self.t==t then return self.a end
  local previous=self.v;local dt=self.t and t-self.t or 0
  self.t=t;self.v={v[1],v[2],v[3]}
  if not previous or dt<=0 or dt>M.maximum_interval then
   self.omega,self.tangent,self.a=nil,nil,nil
   return
  end
  local speed,prior=norm(v),norm(previous);if speed>1500 or prior>1500 then self:reset();return end
  local c=cross(previous,v);local length=norm(c);local omega={0,0,0}
  local dot=previous[1]*v[1]+previous[2]*v[2]+previous[3]*v[3]
  if length>1e-8 then local gain=math.atan2(length,dot)/(dt*length);for k=1,3 do omega[k]=c[k]*gain end end
  local tangent=(speed-prior)/dt;local alpha=1-math.exp(-dt/.12)
  if not self.omega then self.omega=omega;self.tangent=tangent
  else for k=1,3 do self.omega[k]=self.omega[k]+alpha*(omega[k]-self.omega[k])end;self.tangent=self.tangent+alpha*(tangent-self.tangent)end
  local a=cross(self.omega,v)
  if speed>1e-6 then for k=1,3 do a[k]=a[k]+self.tangent*v[k]/speed end end
  if norm(a)>150 then self:reset();return end
  self.a=a;return a
 end
 return self
end
return M
