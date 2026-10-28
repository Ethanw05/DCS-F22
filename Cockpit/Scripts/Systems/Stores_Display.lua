-- GPL-3.0-or-later. Bezel navigation only; weapon programs belong to Weapon_System.
local M={};M.__index=M
function M.new(param,send,page,override,hud)
 local self=setmetatable({param=param,send=send,page=page,override=override,hud=hud,visible=false,subpage=0},M)
 self:set(0);param('F22_SMS_PROGRAM_PAGE'):set(0);return self
end
function M:set(value)self.subpage=value;self.param('F22_SMS_UI_PAGE'):set(value)end
function M:cancel()self.send(10980,1)end
function M:update(visible)
 if self.visible and not visible then self:cancel();self:set(0)end
 if visible and self.param('HUD_AG_SUBMODE'):get()==1 and (self.subpage==1 or self.subpage==3)then self:cancel();self:set(0)end
 local mode=self.param('HUD_MODE'):get()
 local aa=mode>=2 and mode<=6
 self.visible=visible;self.param('F22_SMS_PROGRAM_PAGE'):set(visible and not aa and 1 or 0)
 if aa and self.subpage~=0 and self.subpage~=2 then self:cancel();self:set(0)end
end
function M:handle(button)
 if not self.visible then return false end
 local sub=self.subpage
 if button==13 then
  self:cancel();if sub~=0 then self:set(0)else self.page(0)end;return true
 end
 if sub==1 and button==18 then self:cancel();self.send(10804,1);return true end
 if sub==4 then
  local delivery=({[1]=3,[2]=2})[button]
  if self.param('HUD_AG_SUBMODE'):get()~=1 and delivery
   and self.param('F22_SMS_MODE_AVAILABLE_'..delivery):get()>.5 then
   self:cancel();self.send(10806+delivery,1);self:set(0)
  end
  return true
 elseif sub==2 then
  if button==10 then self.override()end
  return true
 end
 local mode=self.param('HUD_MODE'):get()
 if mode>=2 and mode<=6 then
  if button==18 then self.send(10804,1)
  elseif button==11 then self:cancel();self:set(2)end
  return true -- A/G program fields are not active in an A/A master mode.
 end
 if self.param('HUD_AG_SUBMODE'):get()==1 and (button==7 or button==8 or button==9 or button==10 or button==12 or button==14 or button==15 or button==16 or button==17)then return true end
 if button>=1 and button<=5 then
  local index=self.param('F22_SMS_STORE_'..button..'_INDEX'):get()
  if index>0 then self:cancel();self.send(10981,index)end
 elseif button==6 then
  local available=self.param('F22_SMS_MODE_AVAILABLE_2'):get()>.5
   or self.param('F22_SMS_MODE_AVAILABLE_3'):get()>.5
  if self.param('HUD_AG_SUBMODE'):get()~=1 and available then self:cancel();self:set(4)end
 elseif button==20 and mode==7 then self:cancel();self.send(10807,1)
 elseif button==7 then self:cancel();self.send(10982,1)
 elseif button==8 then
  if self.param('F22_SMS_LABEL'):get()>0 and self.hud then self.hud()end
 elseif button==11 then self:cancel();self:set(2)
 elseif button==12 and sub==0 then self:cancel();self:set(1)
 elseif sub==1 and button==16 then self:cancel();self.send(10987,1)
 elseif sub==1 and button==17 then self:cancel();self.send(10988,1)end
 return true -- blank keys never fall through to legacy bay commands
end
return M
