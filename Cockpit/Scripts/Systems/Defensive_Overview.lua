-- GPL-3.0-or-later. Photo-inspired defensive picture from existing source-aware tracks.
local Frames=dofile(LockOn_Options.script_path..'Systems/Gun_Frames.lua')
local Bearings=dofile(LockOn_Options.script_path..'Systems/RWR_Bearings.lua')
local Geolocation=dofile(LockOn_Options.script_path..'Systems/EW_Geolocation.lua')
local Datalink=dofile(LockOn_Options.script_path..'Systems/Datalink_Tracks.lua')
local Proximity=dofile(LockOn_Options.script_path..'Systems/RWR_Proximity.lua')
local M={radius=.84}
local Labels=dofile(LockOn_Options.script_path..'Systems/RWR_Computer.lua')
local function contact_kind(t)
 if not t then return 0 end
 if t.label=='SAM' or t.label=='EWR'then return 2 end
 if t.label=='AAA'then return 3 end
 local rf=t.observations and t.observations.rf
 if rf and rf.general==3 then return 4 end
 if t.optical and not (t.observations and t.observations.radar)then return 5 end
 return 1
end
local function finite(v)return type(v)=='number'and v==v and math.abs(v)<1e9 end
function M.new(get,put,sensors)
 local s={}
 get("F22_DEF_OV_CURRENT") -- MFD-owned independent freshness gate; declare read binding only.
 function s:update(now,tracks,power,critical,selected)
  local frame=Bearings.frame(sensors)
  local valid=power and frame~=nil and finite(now)
  local heading=valid and -sensors.getHeading()or 0
  local own=valid and Geolocation.position(sensors)
  local range=get('F22_DEF_DISPLAY_RANGE_NM')
 if not finite(range)or range<1 then range=get('F22_RADAR_RANGE_NM')end
  local ranged=finite(range)and range>=1 and range<=320
  if not ranged then range=40 end
  local function warning(t)
   local o=t.observations or {};local rf,ir=o.rf,o.mws
   local rf_age=rf and finite(rf.time)and math.max(0,now-rf.time)or math.huge
   local ir_age=ir and finite(ir.time)and math.max(0,now-ir.time)or math.huge
   local signal=rf and (rf.signal or t.signal or 1)or 0
   local active_ir=ir_age<=.5
   local active_rf=rf_age<=(signal>1 and 3.5 or 6)
   return active_ir,active_rf and signal or 0,(rf~=nil or ir~=nil)and not active_ir and not active_rf
  end
  local visible,projected={},{}
  if valid then
   for _,t in ipairs(tracks or {})do
    if finite(t.az)and finite(t.el)and finite(t.age)and t.age>=0 and math.abs(t.el)<=math.pi/2+.001 and
      (not critical or select(1,warning(t))or select(2,warning(t))>1)then
     local ce=math.cos(t.el)
     local w=Frames.world(frame,{ce*math.cos(t.az),math.sin(t.el),ce*math.sin(t.az)})
     local onboard=finite(t.range)and t.range>=40
     local dl=not onboard and own and Datalink.position(t.datalink,now)or nil
     local dl_range
     if dl then
      w={dl.n-own.n,dl.u-own.u,dl.e-own.e};dl_range=math.sqrt(w[1]^2+w[2]^2+w[3]^2)
      if dl_range>=1 then for i=1,3 do w[i]=w[i]/dl_range end else dl=nil;dl_range=nil end
     end
     local geo=not onboard and not dl and Geolocation.relative(t.geolocation,now,own)or nil
     if geo then w={(geo.n-own.n)/geo.range,(geo.u-own.u)/geo.range,(geo.e-own.e)/geo.range}end
     local right=-w[1]*math.sin(heading)+w[3]*math.cos(heading)
     local forward=w[1]*math.cos(heading)+w[3]*math.sin(heading)
     local horizontal=math.sqrt(right*right+forward*forward)
     if horizontal>=1e-6 then
      projected[t]={right,forward,horizontal,geo,dl_range};visible[#visible+1]=t
     end
    end
   end
  end
  table.sort(visible,function(a,b)
   local function score(t)local ir,signal=warning(t);return (t.source==selected and 100 or 0)+(ir and 20 or 0)+signal*3 end
   if score(a)~=score(b)then return score(a)>score(b)end
   return a.source<b.source
  end)
  local proximity_count,position_count=0,0
  for i=1,16 do
   local t=visible[i];local p=string.format('F22_DEF_OV_%02d_',i)
   local x,y,rotation,radius,has_range,offscale,estimated=0,0,0,0,false,false,false
   local relative,link=false,0
   if t then
    local right,forward,horizontal,geo,dl_range=unpack(projected[t])
    local distance_m=finite(t.range)and t.range>=40 and t.range or dl_range
    has_range=ranged and distance_m~=nil
    link=has_range and dl_range and t.datalink.link or 0
    estimated=ranged and not has_range and geo~=nil
    local rf=t.observations and t.observations.rf
    local proximity=not has_range and not estimated and rf and Proximity.radius(rf.power,M.radius)
    relative=proximity~=nil and proximity~=false
    local distance=has_range and distance_m*horizontal/(range*1852)or estimated and geo.range*horizontal/(range*1852)or 1
    offscale=(has_range or estimated)and distance>1
    radius=proximity or M.radius*math.min(1,distance)
    x=radius*right/horizontal;y=radius*forward/horizontal
    rotation=-math.atan2(right,forward)
    if relative then proximity_count=proximity_count+1 end
    if has_range or estimated then position_count=position_count+1 end
   end
   put(p..'X',x);put(p..'Y',y);put(p..'ROT',rotation)
   put(p..'SOURCE',t and t.source or 0)
   put(p..'LABEL_CODE',Labels.label_code(t and t.label or 'U'))
   put(p..'KIND',contact_kind(t))
   put(p..'AFFILIATION',t and t.affiliation or -1)
   put(p..'IDENTITY_CONFLICT',t and t.identity_conflict and 1 or 0)
   local donor=t and t.datalink
   put(p..'DATALINK_OBSERVATION_KNOWN',donor and donor.observation_known and 1 or 0)
   put(p..'DATALINK_RECEIVE_AGE',donor and donor.received and math.max(0,now-donor.received)or 999)
   put(p..'SELECTED',t and t.source==selected and 1 or 0)
   put(p..'RANGED',t and has_range and 1 or 0)
   put(p..'PROXIMITY',relative and 1 or 0);put(p..'DATALINK',link)
   put(p..'GEO',estimated and 1 or 0)
   put(p..'OFFSCALE',offscale and 1 or 0)
   put(p..'OPTICAL',t and t.optical and 1 or 0)
   put(p..'RF',t and t.observations and t.observations.rf and 1 or 0)
   local ir,signal,coast=false,0,false
   if t then ir,signal,coast=warning(t)end
   put(p..'SIGNAL',signal)
   put(p..'MWS_CURRENT',ir and 1 or 0)
   put(p..'PULSE',Labels.pulse(now,ir and 3 or signal))
   put(p..'RF_CURRENT',signal>0 and 1 or 0)
   if donor and (donor.observation_known==false or now-donor.time>Datalink.coast)then coast=true end
   put(p..'COAST',coast and 1 or 0)
   put(p..'ALPHA',coast and .4 or 1)
   put(p..'ALERT',(ir or signal>=3)and 1 or 0)
   put(p..'VALID',t and 1 or 0)
  end
  put('F22_DEF_OV_RANGE_NM',range);put('F22_DEF_OV_RANGE_VALID',ranged and 1 or 0)
  put('F22_DEF_OV_PROXIMITY_COUNT',proximity_count);put('F22_DEF_OV_POSITION_COUNT',position_count)
  put('F22_DEF_OV_OVERFLOW',math.max(0,#visible-16))
  put('F22_DEF_OV_COUNT',math.min(16,#visible))
  put('F22_DEF_OV_TIME',finite(now)and now or 0)
  put('F22_DEF_OV_VALID',valid and 1 or 0)
 end
 s:update(0,{},false,false,nil)
 return s
end
return M
