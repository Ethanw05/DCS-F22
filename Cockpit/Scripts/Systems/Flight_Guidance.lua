-- GPL-3.0-or-later. Cockpit controls; actual AFCS state is published by the EFM.
local dev=GetSelf()
dofile(LockOn_Options.script_path..'devices.lua')
local decode=dofile(LockOn_Options.script_path..'Systems/Input_Value.lua')
make_default_activity(.05)
local handles={}
local function h(k)if not handles[k]then handles[k]=get_param_handle(k)end return handles[k]end
local function get(k)return h(k):get()end
local function set(k,v)h(k):set(v)end
for _,k in ipairs({'F22_AP_ACTIVE','F22_AP_ROLL_MODE','F22_AP_PITCH_MODE','F22_AP_AT','F22_AP_MACH_HOLD',
 'F22_AP_HEADING','F22_AP_ALT','F22_AP_VS','F22_AP_SPEED','F22_AP_MACH','F22_AP_REASON','F22_AP_OVERRIDE','F22_AP_READY','F22_AP_CLOCK',
 'F22_NAV_CONFIG_PATH','F22_AP_STATUS_TEXT','F22_AP_HDG_TEXT','F22_AP_ALT_TEXT','F22_AP_SPEED_TEXT','F22_AP_VS_TEXT',
 'F22_TCN_CHANNEL','F22_TCN_BAND','F22_TCN_MODE','F22_ILS_FREQ_KHZ','F22_NAV_SOURCE','F22_NAV_REFERENCE','F22_NAV_OBS','F22_NAV_COURSE',
 'F22_NAV_CRS_TEXT','F22_NAV_SOURCE_TEXT','F22_TCN_TUNE_TEXT','F22_ILS_TUNE_TEXT','F22_INS_READY','F22_INS_MODEL_ENABLED','F22_INS_STATUS_TEXT','F22_GPS_AID'})do h(k)end
for _,key in ipairs({'F22_AP_STATUS_TEXT','F22_AP_HDG_TEXT','F22_AP_ALT_TEXT','F22_AP_SPEED_TEXT','F22_AP_VS_TEXT',
 'F22_NAV_CRS_TEXT','F22_NAV_SOURCE_TEXT','F22_TCN_TUNE_TEXT','F22_ILS_TUNE_TEXT','F22_INS_STATUS_TEXT'})do set(key,'')end
local light_control=dofile(LockOn_Options.script_path..'Systems/External_Light_Control.lua').new(
 get_cockpit_draw_argument_value,function(owner,command,value)
  local device=GetDevice(devices[owner])
  if device and type(device.performClickableAction)=='function' then
   device:performClickableAction(command,value,false)
  end
 end)
for command=10505,10512 do dev:listen_command(command)end
for command=11905,11912 do dev:listen_command(command)end
local frequencies={}
for f=108100,111900,200 do frequencies[#frequencies+1]=f;frequencies[#frequencies+1]=f+50 end
local frequency_index=23 -- 110.30 MHz
local align=0;local last_time;local was_powered=false
local outage_since;local air_recovery=0;local manual_align=false;local previously_aligned=false
local names={[0]='OFF',[1]='REC',[2]='T/R',[3]='A/A REC',[4]='A/A T/R'}
function post_initialize()
 set('F22_NAV_CONFIG_PATH',LockOn_Options.script_path..'Systems/TACAN_Native.lua')
 set('F22_TCN_CHANNEL',1);set('F22_TCN_BAND',0);set('F22_TCN_MODE',2)
 set('F22_ILS_FREQ_KHZ',frequencies[frequency_index]);set('F22_NAV_SOURCE',0)
 set('F22_NAV_REFERENCE',0);set('F22_NAV_OBS',0);set('F22_NAV_COURSE',0)
 set('F22_INS_MODEL_ENABLED',1);set('F22_GPS_AID',1)
 local birth=LockOn_Options.init_conditions.birth_place
 align=birth=='GROUND_COLD' and 0 or 180
 previously_aligned=align>=180;outage_since=nil;air_recovery=0;manual_align=false;last_time=nil;was_powered=false
 set('F22_INS_READY',align>=180 and 1 or 0)
end
for c=10930,10949 do dev:listen_command(c)end
for c=10950,10969 do dev:listen_command(c)end
for c=11010,11016 do dev:listen_command(c)end
local function apply_command(command,value)
 if command==11016 and value>0 then dispatch_action(nil,11626,1);return end
 if command>=10505 and command<=10512 or command>=11905 and command<=11912 then
  if type(value)=='number' and decode(value,devices.FLIGHT_GUIDANCE)>0 then light_control:command(command)end
  return
 end
 if command>=11010 and command<=11015 then
  if type(value)=='number'and value==value and math.abs(value)<1e7 and get('MAIN_POWER')>.5 then
   dispatch_action(nil,11620+command-11010,value)
  end
  return
 end
 local changes_guidance = command>=10930 and command<=10938 or command>=10943 and command<=10949
 if changes_guidance and type(value)=='number' and value>0 then set('F22_NAV_STEER_VALID',0)end
 if command==10946 or command==10947 or command==10949 then
  if type(value)~='number'or value~=value or get('MAIN_POWER')<.5 then return end
  if command==10946 and value%1==0 and value>=1 and value<=126 then set('F22_TCN_CHANNEL',value)
  elseif command==10947 and value>=108100 and value<=111950 and (value%200==100 or value%200==150)then
   for i,f in ipairs(frequencies)do if f==value then frequency_index=i;set('F22_ILS_FREQ_KHZ',value);break end end
  elseif command==10949 and value>=0 and value<360 then set('F22_NAV_COURSE',value)end
  return
 end
 value=decode(value,devices.FLIGHT_GUIDANCE)
 -- The paddle release is a separate command and must work without main power.
 if command==10962 and value>0 then dispatch_action(nil,11612,1);return end
 if value<=0 then return end
 if command==10953 then dispatch_action(nil,11603,1);return end
 if get('MAIN_POWER')<.5 then return end
 if command>=10950 and command<=10969 then dispatch_action(nil,command+650,1);return end
 if command==10930 then set('F22_NAV_SOURCE',(get('F22_NAV_SOURCE')+1)%3)
 elseif command==10931 or command==10932 then set('F22_NAV_OBS',1);set('F22_NAV_COURSE',(get('F22_NAV_COURSE')+(command==10931 and 1 or -1))%360)
 elseif command==10933 or command==10934 then set('F22_TCN_CHANNEL',math.max(1,math.min(126,get('F22_TCN_CHANNEL')+(command==10933 and 1 or -1))))
 elseif command==10935 then set('F22_TCN_BAND',1-get('F22_TCN_BAND'))
 elseif command==10936 then set('F22_TCN_MODE',(get('F22_TCN_MODE')+1)%5)
 elseif command==10937 or command==10938 then frequency_index=math.max(1,math.min(#frequencies,frequency_index+(command==10937 and 1 or -1)));set('F22_ILS_FREQ_KHZ',frequencies[frequency_index])
 elseif command==10939 then set('F22_NAV_REFERENCE',1-get('F22_NAV_REFERENCE'))
 elseif command==10940 then set('F22_GPS_AID',1-get('F22_GPS_AID'))
 elseif command==10941 then set('F22_NAV_OBS',0)
 elseif command==10942 then align=0;manual_align=true;air_recovery=0;set('F22_INS_READY',0)
 elseif command==10943 then
  set('F22_NAV_SOURCE',0)
 elseif command==10944 then set('F22_NAV_SOURCE',1)
 elseif command==10945 then set('F22_NAV_SOURCE',2)
 elseif command==10948 then set('F22_NAV_OBS',1-get('F22_NAV_OBS'))
 end
end
local transaction=dofile(LockOn_Options.script_path..'Systems/Entry_Transaction.lua').channel('GUIDANCE',get,set)
dev:listen_command(11800)
function SetCommand(command,value)
 if command~=11800 then apply_command(command,value);return end
 local requested,wanted=transaction:take(value)
 if not requested then return end
 if get('MAIN_POWER')<.5 then transaction:finish(value,false);return end
 if requested>=11010 and requested<=11015 then
  dispatch_action(nil,11800,value)
  return
 end
 local key=({[10946]='F22_TCN_CHANNEL',[10947]='F22_ILS_FREQ_KHZ',[10949]='F22_NAV_COURSE'})[requested]
 if not key then transaction:finish(value,false);return end
 apply_command(requested,wanted)
 transaction:finish(value,math.abs(get(key)-wanted)<.01,get(key))
end
function update()
 local powered=get('MAIN_POWER')>.5
 local now=type(get_model_time)=='function' and get_model_time() or 0
 local delta=last_time and now-last_time or 0;last_time=now
 local dt=math.max(0,math.min(.2,delta))
 if delta<0 then align=0;manual_align=true;outage_since=nil;air_recovery=0 end
 if not powered then outage_since=outage_since or now
 else
  if outage_since then
   if now-outage_since>5 then align=0;air_recovery=0 end
   outage_since=nil
  end
  if align<180 then
   if get('EFM_GROUND_VALID')>.5 and get('EFM_WEIGHT_ON_WHEELS')>.5 and get('HUD_GS_VALID')>.5 and get('HUD_GS_MPS')<1 then
    align=align+dt;air_recovery=0
   elseif previously_aligned and not manual_align and get('F22_GPS_AID')>.5 and get('EFM_HUD_VALID')>.5 then
    -- Mod convenience: GPS-aided airborne recovery after extended power loss.
    align=0;air_recovery=air_recovery+dt;if air_recovery>=30 then align=180 end
   else align=0;air_recovery=0 end
  end
 end
 was_powered=powered
 if align>=180 then previously_aligned=true;manual_align=false end
 set('F22_INS_READY',powered and align>=180 and 1 or 0)
 local text=not powered and 'IRS OFF' or align<180 and (air_recovery>0 and string.format('GPS RECOVER %02d/30',air_recovery)or string.format('ALIGN %03d/180',align))
  or(get('F22_GPS_AID')>.5 and 'IRS/GPS SIM' or get('F22_INS_ESTIMATE_VALID')<.5 and 'IRS POSITION INVALID' or string.format('IRS COAST EST %.0f M',get('F22_INS_POSITION_UNCERTAINTY_M')))
 set('F22_INS_STATUS_TEXT',text)
 local pitch={[0]='OFF',[1]='ATT',[2]='ALT',[3]='RALT',[4]='V/S'}
 local roll={[0]='',[1]='ATT',[2]='HDG',[3]='NAV'}
 local active=get('F22_AP_ACTIVE')>.5
 local status=active and ('AP '..(roll[get('F22_AP_ROLL_MODE')] or '?')..' '..(pitch[get('F22_AP_PITCH_MODE')] or '?')) or 'AP OFF'
 if (get('F22_AP_OVERRIDE')>.5 or get('F22_AP_NAV_OVERRIDE')>.5) and active then status='AP OVERRIDE' end
 if get('F22_AP_AT')>.5 then status=status..(get('F22_AP_MACH_HOLD')>.5 and ' / MACH' or ' / A/T')end
 if get('F22_AP_REASON')>0 then
  local reason={[1]='ENGAGE INHIBIT',[2]='ENVELOPE / POWER',[3]='PILOT OVERRIDE',[4]='NAV LOST',
   [5]='VERTICAL SOURCE LOST',[6]='HEADING LOST'}
  status=status..' '..(reason[get('F22_AP_REASON')] or 'FAULT')
 end
 if get('F22_AT_REASON')>0 and get('F22_AP_CLOCK')<get('F22_AT_FEEDBACK_UNTIL')then status=status..' / A/T OFF'end
 if get('F22_AP_LIMITED')>.5 then status=status..' LIMIT'end
 set('F22_AP_STATUS_TEXT',status)
 local mag=get('F22_NAV_REFERENCE')>.5 and get('F22_MAG_VALID')>.5
 local d=mag and math.deg(get('F22_MAG_DECL')) or 0
 set('F22_AP_HDG_TEXT',string.format('HDG %03d%s',(get('F22_AP_HEADING')-d)%360,mag and 'M' or 'T'))
 set('F22_AP_ALT_TEXT',string.format('ALT %.0f',get('F22_AP_ALT')))
 set('F22_AP_VS_TEXT',string.format('V/S %+.0f',get('F22_AP_VS')))
 set('F22_AP_SPEED_TEXT',get('F22_AP_MACH_HOLD')>.5 and string.format('M %.2f',get('F22_AP_MACH')) or string.format('SPD %.0f',get('F22_AP_SPEED')))
 set('F22_TCN_TUNE_TEXT',string.format('TCN %03d%s %s',get('F22_TCN_CHANNEL'),get('F22_TCN_BAND')>.5 and 'Y' or 'X',names[get('F22_TCN_MODE')] or '?'))
 set('F22_ILS_TUNE_TEXT',string.format('ILS %.2f',get('F22_ILS_FREQ_KHZ')/1000))
 set('F22_NAV_SOURCE_TEXT',({'WPT','TCN','ILS'})[get('F22_NAV_SOURCE')+1] or 'WPT')
 set('F22_NAV_CRS_TEXT',string.format('CRS %03d%s',get('F22_NAV_COURSE'),mag and 'M' or 'T'))
end
need_to_be_closed=false
