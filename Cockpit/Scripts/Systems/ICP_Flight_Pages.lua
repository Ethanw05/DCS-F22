-- GPL-3.0-or-later. AP/ALT controls with explicit, isolated numeric transactions.
local M={}
local function finite(v)return type(v)=='number'and v==v and math.abs(v)<1e9 end
function M.new(get,put,send,c)
 local s={menu=0,field=0,buffer='',status='',editing=false}
 for _,key in ipairs({'ICP_FLIGHT_TITLE','ICP_FLIGHT_ENTRY','ICP_FLIGHT_STATUS',
  'ICP_FLIGHT_ROW_1','ICP_FLIGHT_ROW_2','ICP_FLIGHT_ROW_3','ICP_FLIGHT_ROW_4','ICP_FLIGHT_ROW_5'})do put(key,'')end
 put('ICP_FLIGHT_MENU',0);put('ICP_FLIGHT_FIELD',0)
 local options={[c.OP1]=1,[c.OP2]=2,[c.OP3]=3,[c.OP4]=4,[c.OP5]=5,
  [10048]=1,[10049]=2,[10050]=3,[10051]=4,[10052]=5}
 local digits={[c.N0]=0};for i=1,9 do digits[c.N1+i-1]=i end
 local function output(device,command,value)send(device,command,value or 1)end
 function s:cancel()self.buffer='';self.status='';self.editing=false;self.field=0 end
 function s:close()self:cancel();self.menu=0 end
 function s:open(menu)self:cancel();self.menu=menu end
 function s:choose(field)self:cancel();self.field=field;self.editing=true end
 function s:commit()
  if not self.editing or self.buffer==''then return true end
  local v=tonumber(self.buffer);local id,device=0,c.guidance
  if not finite(v)then self.status='ENTER DIGITS';return false end
  if self.menu==2 then
   if self.field==1 then
    if v>=0 and v<360 and v%1==0 then
     if get('F22_NAV_REFERENCE')>.5 and get('F22_MAG_VALID')>.5 then v=(v+math.deg(get('F22_MAG_DECL')))%360 end;id=11010
    else self.status='HDG 000-359'end
   elseif self.field==2 then if v>=0 and v<=65000 then id=11011 else self.status='ALT 0-65000 FT'end
   elseif self.field==3 then if math.abs(v)<=6000 then id=11012 else self.status='VS -6000 TO 6000'end
   elseif self.field==4 then if v>=160 and v<=700 then id=11013 else self.status='CAS 160-700 KT'end
   elseif self.field==5 then v=v/100;if v>=.2 and v<=2 then id=11014 else self.status='MACH 0.20-2.00'end end
  elseif self.menu==3 and self.field==5 then
   if v>=200 and v<=5000 then id=11015 else self.status='RALT 200-5000 FT'end
  elseif self.menu==4 then
   local t=dofile(LockOn_Options.script_path..'Systems/Altitude_Settings.lua').new()
   t.units=get('F22_ALT_UNITS');t.field=self.field;t.buffer=self.buffer
   if not t:commit()then self.status=t.status:gsub(':','');return false end
   device=c.altitude
   if self.field==1 then id=11024;v=t.qnh elseif self.field==2 then id=11025;v=t.baro_floor elseif self.field==3 then id=11026;v=t.radar_floor end
  end
  if id==0 then if self.status==''then self.status='CHECK VALUE'end;return false end
  output(device,id,v);self.buffer='';self.status='SET';return true
 end
 function s:adjust(direction)
  -- Wheel increments never submit a typed draft as a side effect.
  if not self.editing or self.buffer~=''then return end
  if self.menu==2 then
   local commands={direction>0 and 10957 or 10956,direction>0 and 10959 or 10958,
    direction>0 and 10964 or 10963,direction>0 and 10966 or 10965}
   if self.field<=3 then output(c.guidance,commands[self.field])
   elseif self.field==4 then output(c.guidance,11013,math.max(160,math.min(700,get('F22_AP_SPEED')+direction*5)))
   elseif self.field==5 then output(c.guidance,11014,math.max(.2,math.min(2,get('F22_AP_MACH')+direction*.01)))end
  elseif self.menu==4 and self.field<=3 then
   if self.field==1 then output(c.altitude,direction>0 and 11021 or 11022)
   else local key=self.field==2 and 'F22_ALT_BARO_FLOOR'or'F22_ALT_RADAR_FLOOR'
    output(c.altitude,self.field==2 and 11025 or 11026,math.max(0,math.min(self.field==2 and 25000 or 5000,get(key)+direction*100)))end
  end
 end
 function s:handle(command)
  if command==c.AP or command==10047 or command==c.ALT or command==10045 then
   if get('MAIN_POWER')<.5 then self:close();return true end
   local ap=command==c.AP or command==10047
   local same=ap and self.menu>=1 and self.menu<=3 or not ap and self.menu>=4
   if same then self:close()else self:open(ap and 1 or 4)end;return true
  end
  if self.menu==0 then return false end
  if get('MAIN_POWER')<.5 then self:close();return true end
  if command==c.NAV or command==10043 or command==10054 or command==c.STP or command==10044 or command==c.HUD or command==10046
   or command==c.COM1 or command==c.COM2 or command==c.OTHR or command==10041 or command==10042 or command==10053 then self:close();return false end
  if command==c.UNDO then
   if self.buffer~=''then self.buffer='';self.status=''elseif self.editing then self:cancel()else self:close()end;return true
  end
  if command==c.CLR then
   if self.editing then
    if self.menu==2 and self.field==3 and self.buffer==''then self.buffer='-'else self.buffer=self.buffer:sub(1,-2)end
    self.status=''
   end;return true
  end
  if command==c.UP or command==c.DOWN then
   local first,last=self.menu<=3 and 1 or 4,self.menu<=3 and 3 or 5
   self:open((self.menu-first+(command==c.UP and 1 or -1))%(last-first+1)+first);return true
  end
  if command==c.WHEELUP or command==c.WHEELDOWN then self:adjust(command==c.WHEELUP and 1 or -1);return true end
  local digit=digits[command]
  if digit~=nil then
   if self.editing then if #self.buffer<6 then self.buffer=self.buffer..digit;self.status=''else self.status='MAX 6 DIGITS'end end
   return true
  end
  local row=options[command]
  if row then
   if self.editing then
    if row==4 then self:cancel()elseif row==5 then self:commit()end
   elseif self.menu==1 then output(c.guidance,({10950,10951,10953,10954,10955})[row])
   elseif self.menu==2 then self:choose(row)
   elseif self.menu==3 then if row<=4 then output(c.guidance,({10960,10969,10952,10968})[row])else self:choose(5)end
   elseif self.menu==4 then if row<=3 then self:choose(row)else output(c.altitude,row==4 and 11023 or 11020)end
   elseif self.menu==5 and row>=3 then output(c.warnings,({[3]=11004,[4]=11001,[5]=11000})[row])end
   return true
  end
  return true
 end
 function s:update()
  if get('MAIN_POWER')<.5 then self:close()end
  put('ICP_FLIGHT_MENU',self.menu);put('ICP_FLIGHT_FIELD',self.editing and 1 or 0)
  local titles={'AP1/3 MODES','AP2/3 TARGETS','AP3/3 MORE','ALT1/2 SETTINGS','ALT2/2 STATUS'}
  put('ICP_FLIGHT_TITLE',titles[self.menu]or'')
  local active=get('F22_AP_ACTIVE')>.5
  local function mark(text,condition)return text..(condition and ' (A)'or'')end
  local t=dofile(LockOn_Options.script_path..'Systems/Altitude_Settings.lua').new();t.qnh=get('F22_ALT_PRESSURE_MMHG');t.units=get('F22_ALT_UNITS')
  local targets={get('F22_AP_HDG_TEXT'),get('F22_AP_ALT_TEXT')..' FT',get('F22_AP_VS_TEXT')..' FPM',
   string.format('CAS %.0f KT',get('F22_AP_SPEED')),string.format('MACH %.2f',get('F22_AP_MACH'))}
  local settings={t:pressure_text(),string.format('MSL FLOOR %.0f FT',get('F22_ALT_BARO_FLOOR')),
   string.format('AGL FLOOR %.0f FT',get('F22_ALT_RADAR_FLOOR')),get('F22_ALT_UNITS')>.5 and 'UNIT HPA'or'UNIT INHG',get('F22_ALT_STD')>.5 and 'QNH'or'STD'}
  local rows={}
  if self.menu==1 then rows={mark('ALT HOLD',active and get('F22_AP_PITCH_MODE')==2),mark('ATT HOLD',active and get('F22_AP_PITCH_MODE')==1),
   'AP / AT OFF',mark('HDG SEL',active and get('F22_AP_ROLL_MODE')==2),mark('NAV',active and get('F22_AP_ROLL_MODE')==3)}
  elseif self.menu==2 then rows=targets
  elseif self.menu==3 then rows={mark('RALT HOLD',active and get('F22_AP_PITCH_MODE')==3),mark('VS HOLD',active and get('F22_AP_PITCH_MODE')==4),
   mark('AT CAS',get('F22_AP_AT')>.5 and get('F22_AP_MACH_HOLD')<.5),mark('AT MACH',get('F22_AP_AT')>.5 and get('F22_AP_MACH_HOLD')>.5),string.format('RALT %.0f FT',get('F22_AP_RALT'))}
  elseif self.menu==4 then rows=settings
  elseif self.menu==5 then rows={get('F22_ALT_BARO_VALID')>.5 and string.format('BARO %.0f FT',get('F22_ALT_BARO_FT'))or'BARO NO DATA',
   get('F22_ALT_RADAR_VALID')>.5 and string.format('RADAR %.0f FT',get('F22_ALT_RADAR_FT'))or'RADAR NO DATA',get('F22_PILOT_AUDIO_MUTED')>.5 and'VOICE OFF'or'VOICE ON','VOICE TEST','ACK'}end
  if self.editing then
   local saved=self.menu==2 and targets[self.field]or self.menu==4 and settings[self.field]or string.format('RALT %.0f FT',get('F22_AP_RALT'))
   local label=self.menu==2 and ({'HDG','ALT','VS','CAS','MACH'})[self.field]or self.menu==4 and ({'BARO','MSL','AGL'})[self.field]or'RALT'
   local draft=self.buffer~=''and self.buffer or'----';local unit=''
   if self.menu==2 then
    unit=({'',' FT',' FPM',' KT',''})[self.field]
    if self.field==1 then unit=get('F22_NAV_REFERENCE')>.5 and get('F22_MAG_VALID')>.5 and'M'or'T'
    elseif self.field==5 and #self.buffer<=3 then
     local b=self.buffer..string.rep('-',3-#self.buffer);draft=b:sub(1,1)..'.'..b:sub(2,3)
    end
   elseif self.menu==4 then
    unit=self.field==1 and(get('F22_ALT_UNITS')>.5 and' HPA'or' INHG')or' FT'
    if self.field==1 and get('F22_ALT_UNITS')<.5 and #self.buffer<=4 then
     local b=self.buffer..string.rep('-',4-#self.buffer);draft=b:sub(1,2)..'.'..b:sub(3,4)
    end
   else unit=' FT'end
   rows={':'..label..' '..draft..unit,'SET '..saved,self.status,'RTN','ENTR'}
  end
  for i=1,5 do put('ICP_FLIGHT_ROW_'..i,rows[i]or'')end
  put('ICP_FLIGHT_ENTRY',self.buffer);put('ICP_FLIGHT_STATUS',self.status)
 end
 return s
end
return M
