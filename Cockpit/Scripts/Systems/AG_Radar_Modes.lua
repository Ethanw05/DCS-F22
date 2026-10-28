-- GPL-3.0-or-later. Ground radar control/geometry contract; no scene enumeration.
-- Mode tables and EXP geometry follow the recorded Hornet reference. The
-- discrete-scale fit margin is a mod policy, not a recovered APG-77 LAR.
local M={nm=1852}
local function clamp(v,a,b)return math.max(a,math.min(b,v))end
local function wrap(a)return (a+math.pi)%(2*math.pi)-math.pi end
M.wrap=wrap
function M.search(mode)return mode==2 or mode==3 or mode==4 or mode==5 end
function M.sea(mode)return mode==4 or mode==5 end
function M.ranging(mode)return mode==6 or mode==7 end
function M.ranges(mode)
 if mode==2 or mode==3 then return {5,10,20,40}end
 if M.sea(mode)then return {5,10,20,40,80}end
 if mode==6 then return {5,10}end
 if mode==7 then return {5}end
 return {5,10,20,40,80,160}
end
function M.range_step(mode,current,direction)
 local ranges=M.ranges(mode);local index=1
 for i,r in ipairs(ranges)do if current>=r then index=i end end
 return ranges[clamp(index+direction,1,#ranges)]
end
function M.fit_range(mode,distance)
 local ranges=M.ranges(mode)
 -- Keep the target within the inner 80% of the selected search scale. This
 -- is explicit mod policy until the full native MPD autorange is recovered.
 for _,r in ipairs(ranges)do if distance<=r*M.nm*.8 then return r end end
 return ranges[#ranges]
end
function M.new()
 return {silent=false,active=false,active_end=nil,fast=false,fan=true,gain=5,
  antenna=0,data=false,declutter=false,expansion=0,pending=0,patch=nil,
  sweep=0,units=0,direction=1}
end
function M.advance(c, enabled, granted, cells)
 if not enabled or not granted then return false end
 if type(cells)~='number' or cells~=cells or cells<1 or cells>8192 or cells%1~=0 then return false end
 -- Collection advances only when the owned AESA completes a surface dwell.
 -- It is a finite image job count; electronic pointing has no traverse time.
 local increment=1/cells
 local next_units=c.units+increment
 local complete=c.active and c.active_end and next_units>=c.active_end
 if complete then next_units=c.active_end end
 c.units=next_units;c.sweep=next_units%1;c.direction=1
 return complete
end
function M.exp_geometry(pose,point,level)
 if not pose or not point or level<1 or level>3 then return end
 local dn,de=point.north-pose.north,point.east-pose.east
 local distance=math.sqrt(dn*dn+de*de)
 if distance<100 then return end
 local fov=level==1 and math.rad(45)or level==2 and math.rad(12.6)or math.atan(2315/distance)
 local maximum=(level==3 and 30 or 40)*M.nm
 local center=math.min(distance,maximum/(1+math.tan(fov/2)))
 local heading=math.atan2(de,dn)
 local span=2*center*math.tan(fov/2)
 return {north=pose.north,altitude=pose.altitude,east=pose.east,heading=heading,
  center=center,span=span,fov=math.deg(fov),level=level,
  az=wrap(heading-pose.heading),elevation=math.atan2(point.altitude-pose.altitude,distance),
  qualified=distance<=maximum and math.abs(wrap(heading-pose.heading))<=math.rad(60)}
end
function M.project(point,view)
 local dn,de=point.north-view.north,point.east-view.east
 local f=dn*math.cos(view.heading)+de*math.sin(view.heading)
 local r=-dn*math.sin(view.heading)+de*math.cos(view.heading)
 return r/view.span*1.65,(f-view.center)/view.span*1.52
end
function M.point(view,x,y,terrain)
 local f=view.center+y/1.52*view.span;local r=x/1.65*view.span
 local n=view.north+f*math.cos(view.heading)-r*math.sin(view.heading)
 local e=view.east+f*math.sin(view.heading)+r*math.cos(view.heading)
 local ok,u=pcall(terrain.GetHeight,n,e)
 if ok and type(u)=='number'and u==u then return {north=n,altitude=u,east=e}end
end
return M
