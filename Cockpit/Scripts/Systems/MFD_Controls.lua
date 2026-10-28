-- GPL-3.0-or-later. Labels and actions share one contract.
local R=dofile(LockOn_Options.script_path..'Systems/Display_Routing.lua')
local P=R.pages
local caps=dofile(LockOn_Options.script_path..'Systems/Store_Capabilities.lua')
local nav=dofile(LockOn_Options.script_path..'Systems/Nav_Display_Controls.lua')
local defensive=dofile(LockOn_Options.script_path..'Systems/Defensive_Controls.lua')
local M={}
local function row(label,action,value)return {label=label,action=action,value=value}end
function M.for_page(page,view,get)
 local c={[13]=row('MENU','menu')}
 if page==P.menu then
  c[13]=row('MENU','none');c[13].selected=true;c[12]=row('RTN','return')
  for b,destination in ipairs(R.order)do c[b]=row(R.names[destination],'page',destination)end
 elseif page==P.nav then
  for b,a in pairs(nav.for_page(view))do c[b]=a end
 elseif page==P.stores then
  local aa=get('HUD_MODE')>=2 and get('HUD_MODE')<=6
  if view>0 then c[12]=row('RTN','view',0)end
  if view==4 then
   if not aa and get('HUD_AG_SUBMODE')~=1 then
    for button,mode in ipairs({{3,'AUTO'},{2,'CCIP'}})do
     if get('F22_SMS_MODE_AVAILABLE_'..mode[1])>.5 then
      c[button]={label=mode[2],device='WEAPON_SYSTEM',command=10806+mode[1],home=true,
       selected=get('HUD_AG_SUBMODE')==mode[1]}
     end
    end
   end
  elseif view==2 then
   if get('WoW')>.5 then c[10]=row('GND OVR','ground_override')end
  elseif view==3 then
   c[12]=row('RTN','view',0)
   c[14]={label='PP SLOT',device='WEAPON_SYSTEM',command=11121}
   c[15]={label='STN STEP',device='WEAPON_SYSTEM',command=10804}
   c[16]={label='TGT SET',device='WEAPON_SYSTEM',command=10987}
   c[17]={label='TGT CLR',device='WEAPON_SYSTEM',command=10988}
  elseif view==1 then
   c[12]=row('DONE','stores_edit',0)
   for _,spec in ipairs({{14,'QTY',10048},{15,'MULT',10049},{16,'INTVL',10050},{17,'UNITS',10051}})do
    c[spec[1]]={label=spec[2],device='ICP_SYSTEM',command=spec[3]}
   end
   c[18]={label='ENTER',device='ICP_SYSTEM',command=10994}
   c[19]={label='CLEAR',device='ICP_SYSTEM',command=3026}
  else
   c[10]=row('DOORS','view',2)
   if aa then c[18]={label='STEP',device='WEAPON_SYSTEM',command=10804}
   else
    for b=1,5 do
     local p='F22_SMS_STORE_'..b..'_';local code=get(p..'LABEL');local index=get(p..'INDEX')
     if index>0 and caps.short_labels[code]then
      c[b]={label=caps.short_labels[code],device='WEAPON_SYSTEM',command=10981,value=index,selected=get(p..'SELECTED')>.5}
     end
    end
    if get('HUD_MODE')==7 then
     c[20]={label='GUN',device='WEAPON_SYSTEM',command=10807,selected=get('HUD_AG_SUBMODE')==1}
    end
    if get('HUD_AG_SUBMODE')~=1 and (get('F22_SMS_MODE_AVAILABLE_2')>.5 or get('F22_SMS_MODE_AVAILABLE_3')>.5)then
     c[6]=row('MODES','view',4)
    end
    if get('HUD_AG_SUBMODE')~=1 and get('F22_SMS_LABEL')>0 then
     c[7]={label='PROFILE',device='WEAPON_SYSTEM',command=10982}
     c[8]=row('EDIT','stores_edit',1)
     c[11]=row('TARGET','view',3)
    end
   end
  end
 elseif page==P.tsd then
  local ag=get('HUD_MODE')==7
  local function radar(b,label,command)c[b]={label=label,device='RADAR_COMPUTER',command=command}end
  radar(15,'RNG-',10608);radar(14,'RNG+',10607);radar(6,'EMIT',10600)
  radar(20,string.format('AZ %.0f',get(ag and 'F22_AG_RADAR_WIDTH_DEG'or'F22_RADAR_SEARCH_WIDTH_DEG')),10616)
  radar(16,'CNTR',10617)
  if not ag then c[11]=row('DONOR','view',6)end
  if not ag and view==6 then
   c[6]={label='NEXT',device='RWR_SYSTEM',command=11140}
   c[7]={label='PREV',device='RWR_SYSTEM',command=11141}
   c[8]={label='FOLLOW',device='RWR_SYSTEM',command=11144}
   c[9]={label='REJECT',device='RWR_SYSTEM',command=11142}
   if get('F22_DONOR_HANDOFF_AVAILABLE')==1 then
    c[10]={label='CUE',device='RWR_SYSTEM',command=11143,selected=get('F22_RADAR_DONOR_STATUS')>0}
   end
   c[12]=row('RTN','view',0)
   return c
  end
  if ag and get('F22_AG_GAIN_INDEX')>=1 then
   -- Current ground-radar controls, arranged on the common physical bezel.
   if get('F22_AG_RANGE_AVAILABLE')<.5 then c[14]=nil;c[15]=nil;c[20]=nil end
   radar(7,'SIL',10638);c[7].selected=get('F22_AG_SILENT')>.5
   if get('F22_AG_ACTIVE_AVAILABLE')>.5 then radar(8,'ACTIVE',10639)end
   radar(9,'FRZ',10623);c[9].selected=get('F22_AG_VIDEO_FROZEN')>.5
   radar(10,'RSET',10645)
   if view==3 then
    c[12]=row('RTN','view',0)
    for b,spec in ipairs({{'MAP',10601},{'GMT',10602},{'SEA',10649},{'TA',10650},{'AGR',10651}})do radar(b,spec[1],spec[2]);c[b].home=true end
   else
    if get('F22_AG_EXPANSION')>0 then radar(1,'MAP',10601)
    else c[1]=row(({'MAP','GMT','GMTT','SEA','SEAT','TA','AGR'})[get('F22_AG_MODE')]or'MODE','view',3)end
    if get('F22_AG_INTL_AVAILABLE')>.5 then radar(2,'INTL',10619)
    elseif get('F22_AG_EXP1_AVAILABLE')>.5 then radar(2,'EXP1',10646)end
    if get('F22_AG_OPTIONS_AVAILABLE')>.5 then radar(3,'EXP2',10647);radar(4,'EXP3',10648)end
    for button,level in pairs({[2]=1,[3]=2,[4]=3})do
     if c[button]and c[button].label=='EXP'..level then c[button].selected=get('F22_AG_EXPANSION')==level end
    end
    if get('F22_AG_BEAM_AVAILABLE')>.5 then radar(5,get('F22_AG_VIDEO_FAN')>.5 and'FAN'or'PEN',10644)end
    if view==2 then
     c[12]=row('RTN','view',0);radar(18,'GAIN+',10641);radar(17,'GAIN-',10642);radar(16,'DCLTR',10652)
    else
     c[11]=row('DATA','view',2);radar(18,'EL UP',10614);radar(17,'EL DN',10615)
     if get('F22_AG_FAST_AVAILABLE')>.5 then
      radar(19,'FAST',10643);c[19].selected=get('F22_AG_FAST')>.5
     elseif get('F22_AG_INTL_AVAILABLE')>.5 and get('F22_AG_EXP1_AVAILABLE')>.5 then
      radar(19,'EXP1',10646)
     end
    end
   end
  elseif ag then
   radar(1,'MAP',10601);radar(2,'GMT',10602);radar(3,'DESIG',10606);radar(4,'CLEAR',10609);radar(5,'INTL',10619)
   radar(19,'FRZ',10623);radar(18,'GAIN+',10614);radar(17,'GAIN-',10615)
  elseif view==1 then
   c[12]=row('RTN','view',0)
   for b,spec in ipairs({{'BORE',10605},{'VACQ',10604},{'WIDE',10622},{'RWS',10601},{'TWS',10602}})do radar(b,spec[1],spec[2]);c[b].home=true end
  else
   radar(1,'PRI',10606);radar(2,'SEC',10628);radar(3,'SWAP',10629);radar(4,'CLR2',10630);radar(5,'IFF',10619)
   radar(7,'RWS/TWS',10603);c[8]=row('ACM','view',1)
   c[9]={label='NAV',device='RWR_SYSTEM',command=10915,selected=get('F22_TSD_NAV_LAYER')>.5}
   radar(19,string.format('HT %.0f',get('F22_RADAR_SEARCH_HEIGHT_DEG')),10623)
   radar(18,'EL UP',10614);radar(17,'EL DN',10615)
  end
 elseif page==P.checks then
  for button,label in ipairs({'START','TAXI','T/O','LAND','STOP'})do c[button]=row(label,'view',button-1)end
  c[6]=row('FAULTS','view',5)
  if view>=5 then
   c[7]={label='NEXT',device='PILOT_WARNING_SYSTEM',command=11005}
   c[8]={label='PREV',device='PILOT_WARNING_SYSTEM',command=11006}
   c[9]={label='ACK',device='PILOT_WARNING_SYSTEM',command=11000}
   c[10]=row('REF','view',6)
   if view==6 then c[12]=row('RTN','view',5)end
  end
 elseif page==P.def then
  return defensive.for_page(view,get)
 end
 return c
end
return M
