-- GPL-3.0-or-later. Hornet SMS/UFC option-select workflow, adapted to the ICP.
-- Reference: ED Hornet guide pp304-306 and installed MPD/STORES.lua UFC option.
-- MFD UFC opens this selected-program numeric editor.
local M={}
function M.new(get,put,send,c)
 local s={open=false,field=0,key=nil,profile=nil}
 put('ICP_STORES_MENU',0)
 for _,name in ipairs({'TITLE','ENTRY','ROW_1','ROW_2','ROW_3','ROW_4','ROW_5'})do put('ICP_STORES_'..name,'')end
 local digits={[c.N0]=0};for i=1,9 do digits[c.N1+i-1]=i end
 local options={[c.OP1]=1,[10048]=1,[c.OP2]=2,[10049]=2,[c.OP3]=3,[10050]=3,[c.OP4]=4,[10051]=4,[c.OP5]=5,[10052]=5}
 function s:available()
  local mode=get('HUD_MODE')
  return get('MAIN_POWER')>.5 and (mode==1 or mode==7)
   and get('F22_SMS_PROGRAM_PAGE')>.5 and get('F22_SMS_LABEL')>0 and get('HUD_AG_SUBMODE')~=1
 end
 function s:close()
  if self.open then send(10980,1)end
  self.open=false;self.field=0
 end
 function s:handle(command)
  if command==10989 then
   if self.open then self:close()
   elseif self:available()then
    send(10980,1);self.open=true;self.field=0;self.key=get('F22_SMS_SELECTED_INDEX');self.profile=get('F22_SMS_PROFILE')
   end
   return true
  end
  if not self.open then return false end
  if not self:available()then self:close();return false end
  if digits[command]~=nil then if self.field>=1 and self.field<=3 then send(10977,digits[command])end;return true end
  if command==c.CLR then send(10978,1);return true end
  if command==c.UNDO then self:close();return true end
  local option=options[command]
  if option then
   if option<=3 then
    self.field=option
    send(option==1 and 10975 or option==2 and 10990 or get('F22_SMS_INTERVAL_MODE')>.5 and 10985 or 10976,1)
   elseif option==4 then send(10980,1);send(10983,1);self.field=0
   else send(10979,1)end
   return true
  end
  -- Selecting another ICP page gives it ownership immediately.
  self:close();return false
 end
 function s:update()
  if self.open and (not self:available()or self.key~=get('F22_SMS_SELECTED_INDEX')or self.profile~=get('F22_SMS_PROFILE'))then self:close()end
  put('ICP_STORES_MENU',self.open and 1 or 0)
  if not self.open then return false end
  local spacing=get('F22_SMS_INTERVAL_MODE')>.5
  local error=get('F22_SMS_ENTRY_ERROR');local length=get('F22_SMS_ENTRY_LENGTH')
  local entry=length>0 and string.format('%0'..length..'d',get('F22_SMS_ENTRY_VALUE'))or'----'
  local editing=get('F22_SMS_ENTRY_FIELD')>0
  local function value(field,key)
   return editing and self.field==field and entry or string.format('%.0f',get(key))
  end
  local error_text=get('F22_SMS_ENTRY_ERROR_TEXT')
  if type(error_text)~='string'or error_text==''then error_text='CHECK VALUE'end
  local labels={'QTY '..value(1,'F22_SMS_QUANTITY'),'MULT '..value(2,'F22_SMS_PAIR'),
   'INT '..value(3,spacing and 'F22_SMS_SPACING_FT'or'F22_SMS_INTERVAL_MS')..(spacing and ' FT'or' MS'),
   spacing and 'UNIT FT'or'UNIT MS',error>0 and error_text or'ENTR'}
  for i,label in ipairs(labels)do put('ICP_STORES_ROW_'..i,(self.field==i and ':'or' ')..label)end
  put('ICP_STORES_TITLE',string.format('%s  P%.0f',get('F22_SMS_MODE_TEXT'),get('F22_SMS_PROFILE')))
  put('ICP_STORES_ENTRY',error>0 and error_text or(editing and entry or''))
  return true
 end
 return s
end
return M
