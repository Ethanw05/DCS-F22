-- GPL-3.0-or-later. Desired pressure and warning floors; EFM static-pressure altimeter owns barometry.
dofile(LockOn_Options.script_path..'devices.lua')
local dev,base=GetSelf(),get_base_data()
local decode=dofile(LockOn_Options.script_path..'Systems/Input_Value.lua')
local settings=dofile(LockOn_Options.script_path..'Systems/Altitude_Settings.lua').new()
local handles={}
local function h(k)if not handles[k]then handles[k]=get_param_handle(k)end return handles[k]end
local function get(k)return h(k):get()end
local function put(k,v)h(k):set(v)end
local physical=dofile(LockOn_Options.script_path..'Systems/Physical_Snapshot.lua').new(get,
 {'MAIN_POWER','F22_ESSENTIAL_POWER','EFM_HUD_VALID'})
local function power(essential)
 local key=essential and 'F22_ESSENTIAL_POWER'or'MAIN_POWER'
 return physical.valid and physical.values[key]==1
end
for _,k in ipairs({'MAIN_POWER','EFM_HUD_VALID','F22_ALTIMETER_NATIVE_READY','F22_ALTIMETER_NATIVE_VALID',
 'F22_ALTIMETER_RESULT_TIME','F22_ALT_ACTUAL_PRESSURE_MMHG','F22_ALT_NATIVE_BARO_M',
 'F22_ALT_PRESSURE_MMHG','F22_ALT_PRESSURE_REQUEST_VALID','F22_ALT_PRESSURE_REQUEST_TIME',
 'F22_ALT_UNITS','F22_ALT_STD','F22_ALT_BARO_FLOOR','F22_ALT_RADAR_FLOOR',
 'F22_ALT_RADAR_STAMP','F22_ALT_BARO_STAMP','F22_ALT_RADAR_REASON','F22_ALT_BARO_REASON',
 'F22_ALT_DISPLAY_TEXT','F22_ALT_BARO_VALID','F22_ALT_RADAR_VALID','F22_ALT_BARO_FT','F22_ALT_RADAR_FT'})do h(k)end
put('F22_ALT_DISPLAY_TEXT','BARO 29.92 INHG')
local adopted=false
local previous_pressure_text
local function finite(v)return type(v)=='number'and v==v and math.abs(v)<1e8 end
local function publish()
 put('F22_ALT_PRESSURE_MMHG',settings:pressure());put('F22_ALT_STD',settings.standard and 1 or 0)
 local pressure_text=settings:pressure_text()..(settings.standard and ' STD' or '')
 if pressure_text~=previous_pressure_text then
  previous_pressure_text=pressure_text
  local now=type(get_model_time)=='function'and get_model_time()or 0
  put('F22_ALT_CONFIRM_UNTIL',now+5)
 end
 put('F22_ALT_DISPLAY_TEXT',pressure_text)
 put('F22_ALT_UNITS',settings.units);put('F22_ALT_BARO_FLOOR',settings.baro_floor)
 put('F22_ALT_RADAR_FLOOR',settings.radar_floor)
 put('F22_ALT_SELECTION',settings.display);put('F22_ALT_MINIMA_FT',settings.minima)
 put('F22_ALT_MINIMA_SOURCE',settings.minima_source)
 put('F22_RECOVERY_INTENT',settings.recovery)
end
function post_initialize()
 put('F22_ENTRY_ALT_ACTIVE',0)
 settings=dofile(LockOn_Options.script_path..'Systems/Altitude_Settings.lua').new();adopted=false
 previous_pressure_text=nil
 put('F22_ALT_PRESSURE_REQUEST_VALID',0);put('F22_ALT_BARO_VALID',0);put('F22_ALT_RADAR_VALID',0);publish()
end
for c=11020,11029 do dev:listen_command(c)end
dev:listen_command(11036)
local function apply_command(c,v)
 physical:update()
 if not power(false)or not finite(v)then return end
 if c==11036 then
  if v>=0 and v<=2 and v%1==0 then settings.recovery=v;publish()end
  return
 end
 if c>=11024 and c<=11029 then
  if c==11024 and v>=650 and v<=820 then settings.qnh=v;settings.saved_qnh=v;settings.standard=false;adopted=true
  elseif c==11025 and v>=0 and v<=25000 and v%1==0 then settings.baro_floor=v
  elseif c==11026 and v>=0 and v<=5000 and v%1==0 then settings.radar_floor=v
  elseif c==11027 and v>=0 and v<=2 and v%1==0 then settings.display=v
  elseif c==11028 and v>=0 and v<=25000 and v%1==0 then settings.minima=v
  elseif c==11029 and (v==0 or v==1)then settings.minima_source=v end
 else
  if decode(v,devices.ALTITUDE_SYSTEM)<=.5 then return end
  if c==11020 then settings:toggle_standard();adopted=true
  elseif c==11023 then settings.units=1-settings.units
  elseif c==11021 or c==11022 then settings.field=1;settings:adjust(c==11021 and 1 or -1);adopted=true end
 end
 publish()
end
local transaction=dofile(LockOn_Options.script_path..'Systems/Entry_Transaction.lua').channel('ALT',get,put)
dev:listen_command(11800)
function SetCommand(command,value)
 if command~=11800 then apply_command(command,value);return end
 local requested,wanted=transaction:take(value)
 if not requested then return end
 physical:update()
 local key=({[11024]='F22_ALT_PRESSURE_MMHG',[11025]='F22_ALT_BARO_FLOOR',[11026]='F22_ALT_RADAR_FLOOR',
  [11027]='F22_ALT_SELECTION',[11028]='F22_ALT_MINIMA_FT',[11029]='F22_ALT_MINIMA_SOURCE',
  [11036]='F22_RECOVERY_INTENT'})[requested]
 if not key or not power(false)then transaction:finish(value,false);return end
 apply_command(requested,wanted)
 transaction:finish(value,math.abs(get(key)-wanted)<.02,get(key))
end
function update()
 physical:update()
 local now=type(get_model_time)=='function'and get_model_time()or 0
 local age=now-get('F22_ALTIMETER_RESULT_TIME')
 local native=get('F22_ALTIMETER_NATIVE_READY')>.5 and get('F22_ALTIMETER_NATIVE_VALID')>.5 and age>=-.01 and age<=.2
 if native and not adopted then
  local q=get('F22_ALT_ACTUAL_PRESSURE_MMHG')
  if finite(q)and q>=650 and q<=820 then settings.qnh=q;settings.saved_qnh=q;adopted=true end
 end
 local powered=power(false)
 put('F22_ALT_PRESSURE_REQUEST_TIME',now);put('F22_ALT_PRESSURE_REQUEST_VALID',powered and adopted and 1 or 0);publish()
 if not powered then put('F22_ENTRY_ALT_ACTIVE',0)end
 local baro=get('F22_ALT_NATIVE_BARO_M')*3.280839895
 put('F22_ALT_BARO_VALID',powered and native and finite(baro)and 1 or 0)
 put('F22_ALT_BARO_STAMP',get('F22_ALTIMETER_RESULT_TIME'))
 put('F22_ALT_BARO_REASON',not powered and 1 or not native and 2 or not finite(baro)and 3 or 0)
 if native and finite(baro)then put('F22_ALT_BARO_FT',baro)end
 local standby=get('F22_ALT_STANDBY_NATIVE_M')*3.280839895
 local standby_age=now-get('F22_ALT_STANDBY_NATIVE_STAMP')
 local standby_valid=get('F22_ALT_STANDBY_NATIVE_VALID')==1 and standby_age>=-.01 and standby_age<=.2
  and finite(standby)
 -- The generic standby pressure sensor is independent of primary ADC failure.
 -- A display still needs usable DC; no specific F-22 pneumatic control is claimed.
 local standby_power=power(true)
 put('F22_ALT_STANDBY_VALID',standby_power and standby_valid and 1 or 0)
 put('F22_ALT_STANDBY_REASON',not standby_power and 1 or not standby_valid and 2 or 0)
 put('F22_ALT_STANDBY_STAMP',get('F22_ALT_STANDBY_NATIVE_STAMP'))
 if standby_valid then put('F22_ALT_STANDBY_FT',standby)end
 local ok,radar=pcall(base.getRadarAltitude)
 local valid=powered and physical.values.EFM_HUD_VALID==1 and ok and finite(radar)and radar>=0 and radar<20000
 put('F22_ALT_RADAR_VALID',valid and 1 or 0)
 put('F22_ALT_RADAR_REASON',not powered and 1 or not ok and 2 or not valid and 3 or 0)
 if valid then put('F22_ALT_RADAR_FT',radar*3.280839895);put('F22_ALT_RADAR_STAMP',now)end
end
make_default_activity(.05)
need_to_be_closed=false
