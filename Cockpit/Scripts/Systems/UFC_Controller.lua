-- GPL-3.0-or-later. One UFC page owner and one numeric-entry transaction.
local Nav=dofile(LockOn_Options.script_path..'Systems/Nav_Entry.lua')
local Transaction=dofile(LockOn_Options.script_path..'Systems/Entry_Transaction.lua')
local M={}
local function finite(v)return type(v)=='number'and v==v and math.abs(v)<1e9 end
function M.new(get,put,send,_sensors)
 local s={page='',entry=nil,pending=nil,status='',clock=0,point=nil}
 local channels={}
 for owner,lane in pairs({FLIGHT_GUIDANCE='GUIDANCE',ALTITUDE_SYSTEM='ALT',NAV_SYSTEM='NAV',WEAPON_SYSTEM='STORES'})do
  channels[owner]=Transaction.channel(lane,get,put)
 end
 local function trace(event,option,detail)
  if log and log.write then log.write('F22_UFC',log.INFO,event..' page='..s.page..' option='..tostring(option or 0)..' '..tostring(detail or ''))end
 end
 local function text(k,default)local v=get(k);return type(v)=='string'and v~=''and v or(default or'--')end
 local function number(label,value,commit,maximum,begin,on_digit,on_erase)
  return {label=label,kind='number',commit=commit,maximum=maximum or 6,begin=begin,digit=on_digit,erase=on_erase}
 end
 local function action(label,fn)return {label=label,kind='action',run=fn}end
 local function integer(b,lo,hi)local v=tonumber(b);if not finite(v)or v%1~=0 or v<lo or v>hi then return nil,'RANGE '..lo..'-'..hi end;return v end
 local function request(owner,c,v,read)
  return channels[owner]:submit(send,owner,c,v,read)
 end
 local function equal(k,v,tolerance)return function()return math.abs(get(k)-v)<(tolerance or .01)end end
 function s:cancel()
  if self.pending and self.pending.cancel then self.pending.cancel()end
  if self.page=='STORES'and(self.entry or self.pending)then send('WEAPON_SYSTEM',10980,1)end
  self.entry=nil;self.pending=nil;self.status=''
 end
 function s:load_point()
  self.point_wait=nil
  self.point=Nav.new(get('HUD_WP_INDEX'),get('F22_NAV_FIX_LAT'),get('F22_NAV_FIX_LON'),get('F22_NAV_FIX_ALT_FT'),get('F22_NAV_FIX_GEO_VALID')>.5)
  self.point_source=get('HUD_WP_INDEX')
  self.route_generation=get('F22_MISSION_ROUTE_GENERATION')
 end
 function s:open(page,force)
  local same=self.page==page;self:cancel();self.point_wait=nil;self.page=same and not force and''or page
  trace('OPEN')
  if self.page=='STPT'then self:load_point()end
  if self.page=='STORES'then self.store=get('F22_SMS_SELECTED_INDEX');self.profile=get('F22_SMS_PROFILE')end
  self:update(0)
 end
 function s:point_commit(field,buffer)
  local p=self.point;p.field=field;p.buffer=buffer
  local old=p.id
  if not p:accept()then return nil,p.error end
  if field==1 and p.id~=old then p.valid=false;p.lat_entered=false;p.lon_entered=false end
  if p:ready()then
   put('F22_NAV_EDIT_ID',p.id);put('F22_NAV_EDIT_LAT',p.lat);put('F22_NAV_EDIT_LON',p.lon);put('F22_NAV_EDIT_ALT_FT',p.alt)
   put('F22_ENTRY_NAV_ID',p.id);put('F22_ENTRY_NAV_LAT',p.lat)
   put('F22_ENTRY_NAV_LON',p.lon);put('F22_ENTRY_NAV_ALT_FT',p.alt)
   local id,lat,lon,alt=p.id,p.lat,p.lon,p.alt
   local pending,error=request('NAV_SYSTEM',10839,1,function()
    return get('F22_NAV_EDIT_ACK_ID')==id and math.abs(get('F22_NAV_EDIT_ACK_LAT')-lat)<1e-8
     and math.abs(get('F22_NAV_EDIT_ACK_LON')-lon)<1e-8 and math.abs(get('F22_NAV_EDIT_ACK_ALT_FT')-alt)<.01
   end)
   if pending then pending.accept=function()self.point_source=id;self.point.valid=true end end
   return pending,error
  else self.status='NEED LAT/LON'end
  return true
 end
 function s.ap_mode(_self,command)
  send('FLIGHT_GUIDANCE',command,1)
 end
 function s:rows()
  local page=self.page;local rows={}
  if page=='NAV'then
   rows[1]=number(string.format('TCN %03d',get('F22_TCN_CHANNEL')),get('F22_TCN_CHANNEL'),function(b)
    local v,e=integer(b,1,126);if not v then return nil,e end
    return request('FLIGHT_GUIDANCE',10946,v,equal('F22_TCN_CHANNEL',v))end,3)
   rows[2]=number(string.format('ILS %.2f',get('F22_ILS_FREQ_KHZ')/1000),0,function(b)
    local v=tonumber(b);if #b==5 then v=v and v*10 end
    if not v or(#b~=5 and #b~=6)or v<108100 or v>111950 or(v%200~=100 and v%200~=150)then return nil,'ILS FORMAT'end
    return request('FLIGHT_GUIDANCE',10947,v,equal('F22_ILS_FREQ_KHZ',v))end,6)
   rows[3]=number(text('F22_NAV_CRS_TEXT','CRS 000'),0,function(b)
    local v,e=integer(b,0,359);if not v then return nil,e end
    return request('FLIGHT_GUIDANCE',10949,v,equal('F22_NAV_COURSE',v))end,3)
   rows[4]=action(get('F22_TCN_BAND')>.5 and'BAND Y'or'BAND X',function()send('FLIGHT_GUIDANCE',10935,1)end)
   rows[5]=action('TCN '..(({'OFF','REC','T/R','A/A REC','A/A T/R'})[get('F22_TCN_MODE')+1]or'--'),function()send('FLIGHT_GUIDANCE',10936,1)end)
  elseif page=='NAV SETUP'then
   rows[1]=action(get('F22_NAV_REFERENCE')>.5 and'REF MAG'or'REF TRUE',function()send('FLIGHT_GUIDANCE',10939,1)end)
   rows[2]=action(get('F22_GPS_AID')>.5 and'GPS AID ON'or'GPS AID OFF',function()send('FLIGHT_GUIDANCE',10940,1)end)
   rows[3]=action('IRS ALIGN',function()send('FLIGHT_GUIDANCE',10942,1)end)
   rows[4]=action(text('F22_INS_STATUS_TEXT'),function()self:open('NAV QUALITY',true)end)
  elseif page=='NAV QUALITY'then
   local valid=get('F22_INS_ESTIMATE_VALID')>.5
   rows[1]={label=valid and'POSITION VALID'or'POSITION UNAVAILABLE',kind='read'}
   rows[2]={label=valid and string.format('POS UNC EST %.0f M',get('F22_INS_POSITION_UNCERTAINTY_M'))or'POS UNC --',kind='read'}
   rows[3]={label=valid and string.format('HDG UNC EST %.2f',get('F22_INS_HEADING_UNCERTAINTY_DEG'))or'HDG UNC --',kind='read'}
   local age=get('F22_INS_LAST_FIX_AGE')
   rows[4]={label=valid and age>=0 and string.format('LAST FIX %.0f MIN',age/60)or'LAST FIX --',kind='read'}
   rows[5]=action('RTN',function()self:open('NAV SETUP',true)end)
  elseif page=='HEADING'then
   rows[1]=number(text('F22_AP_HDG_TEXT','HDG ---'),0,function(b)
    local v,e=integer(b,0,359);if not v then return nil,e end
    if get('F22_NAV_REFERENCE')>.5 and get('F22_MAG_VALID')>.5 then v=(v+math.deg(get('F22_MAG_DECL')))%360 end
    return request('FLIGHT_GUIDANCE',11010,v,function()
     return math.abs((get('F22_AP_HEADING')-v+180)%360-180)<.1
    end)end,3)
  elseif page=='STPT'then
   local p=self.point
   local labels={string.format('WYPT %03d',p.id),'LAT '..Nav.coord(p.lat,true,p.south),'LON '..Nav.coord(p.lon,false,p.west),string.format('ELEV %.0f FT',p.alt)}
   if not p.valid and not p.lat_entered then labels[2]='LAT --'end
   if not p.valid and not p.lon_entered then labels[3]='LON --'end
   for i=1,4 do local field=i;rows[i]=number(labels[i],0,function(b)return self:point_commit(field,b)end,({3,7,8,6})[i])end
   if self.entry and self.entry.option==4 then
    rows[5]=action(p.below_sea and'ELEV NEG'or'ELEV POS',function()p.below_sea=not p.below_sea end)
   end
   if self.entry and(self.entry.option==2 or self.entry.option==3)then
    local latitude=self.entry.option==2
    rows[5]=action(latitude and(p.south and'HEMI S'or'HEMI N')or(p.west and'HEMI W'or'HEMI E'),function()
     if latitude then p.south=not p.south else p.west=not p.west end
    end)
   end
  elseif page=='ALT'then
   local hpa=get('F22_ALT_UNITS')>.5
   local pressure=get('F22_ALT_PRESSURE_MMHG')
   rows[1]=number(hpa and string.format('BARO %.0f HPA',pressure/.750061683)or string.format('BARO %.2f IN',pressure/25.4),0,function(b)
    local v=tonumber(b);local mm=v and v*(hpa and .750061683 or .254)
    if not mm or not hpa and #b~=4 or mm<650 or mm>820 then return nil,'BARO RANGE'end
    return request('ALTITUDE_SYSTEM',11024,mm,equal('F22_ALT_PRESSURE_MMHG',mm,.02))end,5)
   for i,spec in ipairs({{'MSL FLOOR','F22_ALT_BARO_FLOOR',11025,25000},{'AGL FLOOR','F22_ALT_RADAR_FLOOR',11026,5000}})do
    local d=spec;rows[i+1]=number(string.format('%s %.0f',d[1],get(d[2])),0,function(b)
     local v,e=integer(b,0,d[4]);if not v then return nil,e end
     return request('ALTITUDE_SYSTEM',d[3],v,equal(d[2],v))end,5)
   end
   rows[4]=action(hpa and'UNIT HPA'or'UNIT INHG',function()send('ALTITUDE_SYSTEM',11023,1)end)
   rows[5]=action(get('F22_ALT_STD')>.5 and'STD'or'QNH',function()send('ALTITUDE_SYSTEM',11020,1)end)
  elseif page=='AP'then
   local active=get('F22_AP_ACTIVE')>.5;local roll=get('F22_AP_ROLL_MODE');local pitch=get('F22_AP_PITCH_MODE')
   for i,d in ipairs({{'ATTH',10951,active and roll==1 and pitch==1},{'HSEL',10954,active and roll==2},
    {'BALT',10950,active and pitch==2},{'RALT',10960,active and pitch==3},{'NAV CPL',10955,active and roll==3}})do
    local item=d;rows[i]=action((item[3]and':'or'')..item[1],function()self:ap_mode(item[2])end)
   end
  elseif page=='STORES'then
   local spacing=get('F22_SMS_INTERVAL_MODE')>.5
   for i,d in ipairs({{'QTY','F22_SMS_QUANTITY',10975,2},{'MULT','F22_SMS_PAIR',10990,2},
    {spacing and'INT FT'or'INT MS',spacing and'F22_SMS_SPACING_FT'or'F22_SMS_INTERVAL_MS',spacing and 10985 or 10976,5}})do
    local item=d
    rows[i]=number(string.format('%s %.0f',item[1],get(item[2])),0,function()
     send('WEAPON_SYSTEM',10979,1)
     local wanted=tonumber(self.entry.buffer)
     return {read=function()return get('F22_SMS_ENTRY_FIELD')==0 and equal(item[2],wanted)()end,error=function()
      if get('F22_SMS_ENTRY_ERROR')>0 then return text('F22_SMS_ENTRY_ERROR_TEXT','CHECK VALUE')end
     end}
    end,item[4],function()send('WEAPON_SYSTEM',item[3],1)end,
     function(digit)send('WEAPON_SYSTEM',10977,digit)end,
     function()send('WEAPON_SYSTEM',10978,1)end)
   end
   rows[4]=action(spacing and'UNIT FT'or'UNIT MS',function()send('WEAPON_SYSTEM',10980,1);send('WEAPON_SYSTEM',10983,1)end)
  elseif page=='IFF'then
   rows[1]=action(get('F22_RADAR_IFF_AUTO')>.5 and'AUTO ON'or'AUTO OFF',function()send('RADAR_COMPUTER',10631,1)end)
   rows[2]=action('SCAN IFF',function()send('RADAR_COMPUTER',10619,1)end)
   rows[3]=action('LOS IFF',function()send('RADAR_COMPUTER',10625,1)end)
  elseif page=='OTHR'then
   rows[1]=action('AUDIO',function()self:open('AUDIO',true)end)
   rows[2]=action('KNEEBOARD',function()send(nil,1587,1)end)
   if get('WoW')>.5 then rows[3]=action('GROUND SERVICES',function()send(nil,1560,1)end)end
   rows[4]=action('COCKPIT PREFS',function()self:open('PREFS',true)end)
  elseif page=='AUDIO'then
   rows[1]=action(get('F22_PILOT_AUDIO_MUTED')>.5 and'VOICE OFF'or'VOICE ON',function()send('PILOT_WARNING_SYSTEM',11004,1)end)
   rows[2]=number(string.format('VOLUME %.0f',get('F22_PILOT_AUDIO_VOLUME')*100),0,function(b)
    local v,e=integer(b,0,100);if not v then return nil,e end
    if v%10~=0 then return nil,'STEP 10'end
    local difference=math.floor(v/10-get('F22_PILOT_AUDIO_VOLUME')*10+.5)
    for i=1,math.abs(difference)do send('PILOT_WARNING_SYSTEM',difference>0 and 11002 or 11003,1);send('PILOT_WARNING_SYSTEM',difference>0 and 11002 or 11003,0)end
    return {read=equal('F22_PILOT_AUDIO_VOLUME',v/100,.01)}end,3)
   rows[3]=action('VOICE TEST',function()send('PILOT_WARNING_SYSTEM',11001,1)end)
   rows[5]=action('RTN',function()self:open('OTHR',true)end)
  elseif page=='PREFS'then
   for i,label in ipairs({'CANOPY TINT','FLOOD COLOR','VISOR','PHOTO','WINDOW CLING'})do
    local index=i;rows[i]=action(label,function()if get('WoW')>.5 then send('PMFD_SYSTEM',11300+index,1)else self.status='GROUND ONLY'end end)
   end
  elseif page=='COM1'then rows[1]=action('COMMS MENU',function()send(nil,179,1)end)
  elseif page=='COM2'then self.status='RADIO 2 UNAVAILABLE'
  elseif page=='DVR'then self.status='DVR UNAVAILABLE'
  elseif page=='HUD'then self.status='USE DISPLAY CONTROLS'
  end
  return rows
 end
 function s:option(n)
  if self.pending then return end
  local row=self:rows()[n];if not row or row.kind=='read'then return end
  if row.kind=='number'then
   if self.entry and self.entry.option==n then
    if self.entry.buffer==''then return end
    trace('SUBMIT',n,self.entry.buffer)
    local result,error=row.commit(self.entry.buffer)
    if not result then self.entry.error=error or'CHECK VALUE';trace('REJECT',n,self.entry.error)
    elseif type(result)=='table'then self.pending=result;self.pending.started=self.clock
    else self.entry=nil;self.status=self.status~=''and self.status or'ENTERED';trace('ACCEPT',n)end
   else
    self:cancel();self.entry={option=n,buffer='',row=row,error=''}
    if row.begin then row.begin()end
   end
  else
   -- Hemisphere is an explicit modifier of the selected coordinate draft.
   local hemisphere=self.page=='STPT'and n==5 and self.entry~=nil
   if not hemisphere then self:cancel()end
   row.run()
  end
  self:update(0)
 end
 function s:digit(d)
  if self.pending or not self.entry then return end
  local e=self.entry
  if #e.buffer>=(e.row.maximum or 6)then e.error='MAX '..e.row.maximum..' DIGITS';return end
  e.buffer=e.buffer..d;e.error='';if e.row.digit then e.row.digit(d)end
  self:update(0)
 end
 function s:erase(all)
  if self.pending or not self.entry then return end
  local e=self.entry;local count=all and #e.buffer or math.min(1,#e.buffer)
  for i=1,count do if e.row.erase then e.row.erase()end end
  e.buffer=all and''or e.buffer:sub(1,-2);e.error='';self:update(0)
 end
 function s:page_step(direction)
  if self.entry or self.pending then return end
  if self.page=='NAV'or self.page=='NAV SETUP'then self:open(self.page=='NAV'and'NAV SETUP'or'NAV',true)end
 end
 function s:update(dt)
  self.clock=self.clock+(dt or .006)
  if get('MAIN_POWER')<.5 then self:cancel();self.page=''end
  if self.page=='STORES'and(get('F22_SMS_PROGRAM_PAGE')<.5 or get('F22_SMS_LABEL')<1 or get('HUD_AG_SUBMODE')==1
   or self.store~=get('F22_SMS_SELECTED_INDEX')or self.profile~=get('F22_SMS_PROFILE'))then self:cancel();self.page=''end
  if self.page=='STPT'and self.route_generation~=get('F22_MISSION_ROUTE_GENERATION')then
   self:cancel();self:load_point();self.status='ROUTE RELOADED'
  end
  if self.page=='STPT'and not self.entry and not self.pending and get('HUD_WP_INDEX')~=self.point_source
   and not(self.point and not self.point.valid)then self:load_point()end
  if self.pending then
   local p=self.pending;local error=p.error and p.error()
   if error then
    trace('REJECT',self.entry and self.entry.option,error)
    if p.cancel then p.cancel()end
    self.pending=nil
    if self.entry then self.entry.error=error end
   elseif p.read()then
    trace('ACCEPT',self.entry and self.entry.option)
    if p.accept then p.accept()end
    if p.cancel then p.cancel()end
    self.pending=nil;self.entry=nil;self.status='ENTERED'
   elseif self.clock-p.started>1 then
    trace('TIMEOUT',self.entry and self.entry.option)
    if p.cancel then p.cancel()end
    self.pending=nil
    if self.entry then self.entry.error='NO RESPONSE'end
   end
  end
  put('F22_UFC_VISIBLE',self.page~=''and 1 or 0);put('F22_UFC_SELECTED',self.entry and self.entry.option or 0)
  put('F22_UFC_PAGE',self.page)
  local title=self.page=='AP'and'AP: RMB ALL OFF'or self.page=='NAV'and'NAV 1/2'or self.page=='NAV SETUP'and'NAV SETUP 2/2'or self.page
  local rows=self:rows()
  put('F22_UFC_SCRATCH',self.entry and(self.entry.buffer~=''and self.entry.buffer..'_'or'_')or(self.status~=''and self.status or title))
  for i=1,5 do
   local label=rows[i]and rows[i].label or''
   if self.entry and self.entry.option==i and self.entry.error~=''then label=label..' ! '..self.entry.error end
   put('F22_UFC_ROW_'..i,label)
  end
  put('ICP_STORES_MENU',self.page=='STORES'and 1 or 0)
  put('ICP_NAV_MENU',self.page=='STPT'and 1 or 0);put('ICP_CNI_MENU',self.page=='NAV'and 1 or 0)
  put('ICP_FLIGHT_MENU',self.page=='AP'and 1 or self.page=='ALT'and 4 or 0)
  put('ICP_AP_MENU',0);put('ICP_HUD_MENU',0)
 end
 s:update(0);return s
end
return M
