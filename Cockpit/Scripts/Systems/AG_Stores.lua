-- GPL-3.0-or-later. Store programs advance only on observed native releases.
local caps=dofile(LockOn_Options.script_path..'Systems/Store_Capabilities.lua')
local M={labels=caps.labels,short_labels=caps.short_labels,
 limits={quantity=8,interval_min_ms=50,interval_max_ms=2000,spacing_min_ft=10,spacing_max_ft=9999}}
function M.new()return setmetatable({groups={},profiles={},profile_indices={},targets={},inventory_expectations={},target_sequence=0,selected=nil,program=nil}, {__index=M})end
function M:group()for _,g in ipairs(self.groups)do if g.key==self.selected then return g end end end
function M:profile_index()return self.profile_indices[self.selected or ''] or 1 end
function M:profile()
 local key=(self.selected or '')..':'..self:profile_index();local p=self.profiles[key]
 if not p then local g=self:group();p={mode=g and g.guided and 3 or 2,quantity=1,interval=.2,interval_mode=g and g.guided and 0 or 1,spacing_ft=200,pair=1};self.profiles[key]=p end
 return p
end
function M:refresh(infos)
 local groups,by={},{ };self.infos=infos
 for station,target in pairs(self.targets)do local info=infos[station];if info and (caps.key(info)~=target.key or (info.count or 0)<=0)then self.targets[station]=nil end end
 for i=0,10 do local g=caps.describe(infos[i])
  if g and g.kind==7 then
   local existing=by[g.key]
   if not existing then g.index=#groups+1;g.count=0;g.stations={};groups[#groups+1]=g;by[g.key]=g;existing=g end
   existing.count=existing.count+infos[i].count;existing.stations[#existing.stations+1]=i
  end
 end
 self.groups=groups
 if not by[self.selected] and not self.program then self.selected=groups[1] and groups[1].key or nil end
end
function M:ready_count()
 local g=self:group();if not g or not g.supported then return 0 end
 local count=0
 for _,station in ipairs(g.stations)do
  local actual=(self.infos[station]or {}).count or 0
  if self:station_ready(station)then count=count+actual end
 end
 return count
end
function M:select(index)if self.groups[index]then self:cancel();self.selected=self.groups[index].key;return true end end
function M:step(direction)
 if #self.groups==0 then return end
 local g=self:group();self:select(((g and g.index or 1)-1+direction)%#self.groups+1)
end
function M:edit(action)
 self:cancel();local p,g=self:profile(),self:group()
 if action=='less'then p.quantity=math.max(p.pair,p.quantity-p.pair)
 elseif action=='more'then p.quantity=math.min(8,g and g.count or 1,p.quantity+p.pair)
 elseif action=='interval'then p.interval_mode=0;p.interval=p.interval==.1 and .2 or p.interval==.2 and .5 or p.interval==.5 and 1 or .1
 elseif action=='profile'then self.profile_indices[self.selected or '']=self:profile_index()==1 and 2 or 1
 elseif action=='unit'then p.interval_mode=1-p.interval_mode
 elseif action=='pair'then p.pair=p.pair==1 and 2 or 1;p.quantity=math.max(p.pair,math.floor(p.quantity/p.pair)*p.pair)end
end
function M:start(now,target,live_point)
 if self.entry or self.pending or self.program then return false end
 local p,g=self:profile(),self:group()
 if not g or not g.supported or p.quantity>self:ready_count()or p.quantity%p.pair~=0 then return false end
 self.failed=false;self.pending=nil
 local targets={};for _,station in ipairs(g.stations)do local assigned=self:target(station);if assigned then targets[station]=assigned end end
 self.program={key=g.key,remaining=p.quantity,quantity=p.quantity,interval=p.interval,interval_mode=p.interval_mode,spacing=p.spacing_ft*.3048,pair=p.pair,pulse_remaining=p.pair,next=now,target=target,last=now,targets=targets}
 if live_point then self.program.live_target={n=live_point.n,u=live_point.u,e=live_point.e,sequence=live_point.sequence}end
 return true
end
function M:target(station)
 local target=self.targets[station];local info=self.infos and self.infos[station]
 if target and info and caps.key(info)==target.key and (info.count or 0)>0 then return target end
end
function M:capture_target(station,point)
 local info=self.infos and self.infos[station];local cap=caps.describe(info)
 if not cap or not cap.guided or not cap.bomb or not point then return false end
 for _,axis in ipairs({'n','u','e'})do local v=point[axis];if type(v)~='number'or v~=v or math.abs(v)>1e7 then return false end end
 if point.u< -1000 or point.u>=20000 then return false end
 self:cancel();self.target_sequence=self.target_sequence+1
 self.targets[station]={n=point.n,u=point.u,e=point.e,key=cap.key,sequence=self.target_sequence}
 return true
end
function M:clear_target(station)self:cancel();self.targets[station]=nil end
function M:due(now,impact)
 local p=self.program
 if not p or now<p.last then self:cancel();return false end
 p.last=now
 if self.pending or now+1e-9<p.next then return false end
 if p.interval_mode==1 and p.last_impact and p.pulse_remaining==p.pair then
  if not impact or not impact.n or not impact.e then return false end
  local dn,de=impact.n-p.last_impact.n,impact.e-p.last_impact.e
  return dn*p.axis_n+de*p.axis_e>=p.spacing and math.abs(de*p.axis_n-dn*p.axis_e)<=math.max(15,p.spacing*.25)
 end
 return true
end
function M:released(now,impact)
 local p=self.program;if not p then return true end
 p.remaining=p.remaining-1;p.pulse_remaining=p.pulse_remaining-1
 if p.pulse_remaining<=0 then
  p.pulse_remaining=p.pair;p.next=now+(p.interval_mode==0 and p.interval or .02)
  if impact then p.last_impact={n=impact.n,e=impact.e};local speed=math.sqrt((impact.vn or 0)^2+(impact.ve or 0)^2);if speed>1 then p.axis_n=impact.vn/speed;p.axis_e=impact.ve/speed else p.axis_n,p.axis_e=1,0 end end
 else p.next=now end
 if p.remaining<=0 then self.program=nil;return true end
 return false
end
function M:request(station,info,now,impact,sequence)
 if not self.program or self.pending or not info or not self:station_ready(station)then return false end
 self.pending={station=station,count=info.count,key=caps.key(info),type4=(info.weapon or {}).level4 or 0,time=now,impact=impact,sequence=sequence or 0}
 return true
end
function M:station_ready(station)
 local expectation=self.inventory_expectations[station]
 if not expectation then return true end
 local info=self.infos and self.infos[station]
 if info and (caps.key(info)~=expectation.key or (info.count or 0)<=expectation.count)then self.inventory_expectations[station]=nil;return true end
 return false
end
function M:acknowledge(infos,now,shot)
 local q=self.pending;if not q then return nil end
 if now<q.time or now-q.time>.8 then self:fail_request();return false,false,q end
 local info=infos[q.station];local same=info and caps.key(info)==q.key
 local inventory=(same and (info.count or 0)<q.count) or (info and (info.count or 0)==0)
 local native=shot and shot.sequence>q.sequence and shot.id>0 and shot.station==q.station and shot.mode==7 and shot.type4==q.type4 and shot.time>=q.time-.02 and shot.time<=now+.02 and shot.time<=q.time+.8
 if inventory or native then
  -- A shot may be published before the payload count changes. Quarantine
  -- that station so its delayed decrement cannot acknowledge a second shot.
  if native and not inventory then self.inventory_expectations[q.station]={key=q.key,count=q.count-1}end
  q.evidence=native and 2 or 1;q.native_id=native and shot.id or 0;q.native_sequence=native and shot.sequence or 0;q.native_time=native and shot.time or 0
  self.pending=nil;return true,self:released(now,q.impact),q
 end
 return nil
end
function M:unconfirmed()
 local g=self:group()
 for _,station in ipairs(g and g.stations or {})do local q=self.inventory_expectations[station];if q and q.unconfirmed and not self:station_ready(station)then return true end end
 return false
end
function M:retain_unconfirmed()
 local q=self.pending
 if q then self.inventory_expectations[q.station]={key=q.key,count=q.count-1,unconfirmed=true}end
end
function M:fail_request()self:retain_unconfirmed();self.pending=nil;self.program=nil;self.failed=true end
function M:begin_entry(field)
 self:cancel();if not self:group()then return end
 self.entry={field=field,key=self.selected,profile=self:profile_index(),buffer='',error=0}
end
function M:digit(value)
 local e=self.entry
 if e and value>=0 and value<=9 and value==math.floor(value)then
  local maximum=(e.field==1 or e.field==4 or e.field==5)and 2 or 5
  if #e.buffer<maximum then e.buffer=e.buffer..value;e.error=0 else e.error=4 end
 end
end
function M:backspace()if self.entry then self.entry.buffer=self.entry.buffer:sub(1,-2);self.entry.error=0 end end
function M:commit()
 local e,g=self.entry,self:group()
 if not e or not g or e.key~=self.selected or e.profile~=self:profile_index()then self.entry=nil;return false end
 if e.error==4 then return false end
 local v=tonumber(e.buffer);if not v then e.error=3;return false end
 local p=self:profile()
 if e.field==1 or e.field==4 then
  local quantity=e.field==4 and v*p.pair or v
  if quantity<1 or quantity>M.limits.quantity or quantity>g.count or quantity%p.pair~=0 then e.error=1;return false end
  p.quantity=quantity
 elseif e.field==2 then
  if v<M.limits.interval_min_ms or v>M.limits.interval_max_ms then e.error=2;return false end
  p.interval=v/1000;p.interval_mode=0
 elseif e.field==5 then
  if (v~=1 and v~=2) or p.quantity%v~=0 or v>g.count then e.error=6;return false end
  p.pair=v
 elseif e.field==3 then
  if v<M.limits.spacing_min_ft or v>M.limits.spacing_max_ft then e.error=5;return false end
  p.spacing_ft=v;p.interval_mode=1
 else return false end
 self.entry=nil;return true
end
function M:entry_error_text()
 local e=self.entry;if not e or e.error==0 then return ''end
 local g,p=self:group(),self:profile()
 if e.error==1 then
  local quantity=(tonumber(e.buffer)or 0)*(e.field==4 and p.pair or 1)
  local maximum=math.min(M.limits.quantity,g and g.count or 0)
  if quantity>=1 and quantity<=maximum and quantity%p.pair~=0 then return 'QTY MULT OF '..p.pair end
  return 'QTY 1-'..maximum
 elseif e.error==2 then return string.format('INT %d-%d MS',M.limits.interval_min_ms,M.limits.interval_max_ms)
 elseif e.error==3 then return 'ENTER VALUE'
 elseif e.error==4 then return (e.field==1 or e.field==4 or e.field==5)and'MAX 2 DIGITS'or'MAX 5 DIGITS'
 elseif e.error==5 then return string.format('INT %d-%d FT',M.limits.spacing_min_ft,M.limits.spacing_max_ft)
 elseif e.error==6 then return p.quantity%2~=0 and 'MULT 1 FOR ODD QTY'or'MULT 1 OR 2'end
 return 'CHECK VALUE'
end
function M:cancel(keep_failure)self:retain_unconfirmed();self.program=nil;self.pending=nil;self.entry=nil;if not keep_failure then self.failed=false end end
return M
