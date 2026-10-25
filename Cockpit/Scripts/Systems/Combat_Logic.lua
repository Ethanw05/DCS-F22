-- GPL-3.0-or-later. Contextual inputs, no sensor or weapon simulation here.
local M={}
function M.new(emit)
 local s={mode=1,last_aa=2,dogfight=false,saved=1,soi=2,held={},clock=0,acm_pattern="wide"}
 function s:set_mode(mode)
  self.mode=mode
  if mode==2 or mode==3 or mode==5 then self.last_aa=mode end
  -- A mode change must not erase the physical down latch. DCS can repeat
  -- down events; only the matching release permits another press.
  for _,h in pairs(self.held) do h.done=true end
  emit('weapon_mode',mode)
  if mode~=1 then emit('radar_operate');emit('radar_page') end
  -- Change the return search even during STT; the radar owner preserves lock.
  if mode==2 then emit('bvr') end
 end
 function s:act(n,long,c)
  local acm=self.mode==5 or self.mode==3
  if n=='tdc' then emit('designate')
  elseif n=='tms_up' then
   if acm then self.acm_pattern='boresight';emit('boresight') else emit('designate') end
  elseif n=='tms_down' then
   if acm then self.acm_pattern='vertical';emit('vertical') else emit('undesignate') end
  elseif n=='tms_right' then
   if acm then self.acm_pattern='wide';emit('wide')
   elseif long then emit('toggle') else emit('next_track') end
  elseif n=='tms_left' then emit(long and 'interrogate_los' or 'interrogate')
  elseif n=='dms_up' then self.soi=1
  elseif n=='dms_down' then self.soi=self.soi==2 and 3 or 2;emit('radar_page')
  elseif n=='dms_left' then self.soi=3;emit('left_page')
  elseif n=='dms_right' then self.soi=4;emit('right_page')
  elseif n=='cms_up' then emit('defense_program',1)
  elseif n=='cms_left' then emit('defense_program',2)
  elseif n=='cms_push' then emit('defense_program',3)
  elseif n=='cms_right' then emit('defense_consent',0)
  elseif n=='cms_down' then emit('defense_consent',1)
  elseif n=='expand' then emit('expand')
  elseif n=='coverage' then emit(long and 'vertical_span' or 'azimuth')
  elseif n=='missile_step' then
   if c.ground then emit('nws') elseif long then emit('station_step')
   else emit('undesignate') end
  elseif n=='paddle' then emit('autopilot_off')
  elseif n=='dogfight' then
   if self.dogfight then self.dogfight=false;self:set_mode(self.saved)
   else self.saved=self.mode;self.dogfight=true;self:set_mode(5)
    if not c.locked then emit(self.acm_pattern) end
   end
  elseif n=='weapon_select' then
   if self.dogfight then self:set_mode(self.mode==5 and 3 or 5)
   else self:set_mode(self.mode==2 and 3 or self.mode==3 and 5 or 2) end
   if self.mode~=2 and not c.locked then emit(self.acm_pattern) end
  elseif n=='aa' then
   self.dogfight=false
   if self.mode==2 or self.mode==3 or self.mode==5 then self:set_mode(1)
   else self:set_mode(self.last_aa);if self.mode~=2 and not c.locked then emit(self.acm_pattern) end end
  elseif n=='ag' then self.dogfight=false;self:set_mode(self.mode==7 and 1 or 7)
  elseif n=='nav' then self.dogfight=false;self:set_mode(1)
  elseif n=='gun' or n=='srm' or n=='mrm' then
   self.dogfight=false;self:set_mode(({gun=5,srm=3,mrm=2})[n])
   if n~='mrm' and not c.locked then emit(self.acm_pattern) end
  elseif n=='cage' then emit('cage')
  elseif n=='arm' then emit('arm')
  elseif n=='radar_power' then emit('power')
  elseif n=='range_up' or n=='range_down' then emit(n) end
 end
 local delayed={tms_right=true,tms_left=true,coverage=true,missile_step=true}
 function s:input(n,v,c)
  if n=='trigger_first' or n=='trigger_second' or n=='pickle' then
   emit(n,v>0 and 1 or 0);return
  end
  if v>0 then
   if self.held[n] then return end
   self.held[n]={start=self.clock,done=false,context=c}
   self.held[n].delayed=delayed[n] and not (n=='tms_right' and (self.mode==5 or self.mode==3))
   if not self.held[n].delayed then self:act(n,false,c) end
  else
   local h=self.held[n];self.held[n]=nil
   if h and h.delayed and not h.done then self:act(n,false,c) end
  end
 end
 function s:update(dt,c)
  self.clock=self.clock+dt
  for n,h in pairs(self.held) do
   local threshold=n=='tms_right' and 1 or .5
   if h.delayed and not h.done and self.clock-h.start>=threshold then
    h.done=true;self:act(n,true,c)
   end
  end
 end
 return s
end
return M
