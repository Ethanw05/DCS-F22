-- GPL-3.0-or-later. Desired pressure and warning floors; EFM static-pressure altimeter owns barometry.
dofile(LockOn_Options.script_path..'devices.lua')
local dev,base=GetSelf(),get_base_data()
local decode=dofile(LockOn_Options.script_path..'Systems/Input_Value.lua')
local settings=dofile(LockOn_Options.script_path..'Systems/Altitude_Settings.lua').new()
local handles={}
local function h(k)if not handles[k]then handles[k]=get_param_handle(k)end return handles[k]end
local function get(k)return h(k):get()end
local function put(k,v)h(k):set(v)end
for _,k in ipairs({'MAIN_POWER','EFM_HUD_VALID','F22_ALTIMETER_NATIVE_READY','F22_ALTIMETER_NATIVE_VALID',
 'F22_ALTIMETER_RESULT_TIME','F22_ALT_ACTUAL_PRESSURE_MMHG','F22_ALT_NATIVE_BARO_M',
 'F22_ALT_PRESSURE_MMHG','F22_ALT_PRESSURE_REQUEST_VALID','F22_ALT_PRESSURE_REQUEST_TIME',
 'F22_ALT_UNITS','F22_ALT_STD','F22_ALT_BARO_FLOOR','F22_ALT_RADAR_FLOOR',
 'F22_ALT_DISPLAY_TEXT','F22_ALT_BARO_VALID','F22_ALT_RADAR_VALID','F22_ALT_BARO_FT','F22_ALT_RADAR_FT'})do h(k)end
put('F22_ALT_DISPLAY_TEXT','BARO 29.92 INHG')
local adopted=false
local function finite(v)return type(v)=='number'and v==v and math.abs(v)<1e8 end
local function publish()
 put('F22_ALT_PRESSURE_MMHG',settings:pressure());put('F22_ALT_STD',settings.standard and 1 or 0)
 put('F22_ALT_DISPLAY_TEXT',settings:pressure_text()..(settings.standard and ' STD' or ''))
 put('F22_ALT_UNITS',settings.units);put('F22_ALT_BARO_FLOOR',settings.baro_floor)
 put('F22_ALT_RADAR_FLOOR',settings.radar_floor)
end
function post_initialize()
 settings=dofile(LockOn_Options.script_path..'Systems/Altitude_Settings.lua').new();adopted=false
 put('F22_ALT_PRESSURE_REQUEST_VALID',0);put('F22_ALT_BARO_VALID',0);put('F22_ALT_RADAR_VALID',0);publish()
end
for c=11020,11026 do dev:listen_command(c)end
function SetCommand(c,v)
 if get('MAIN_POWER')<.5 or not finite(v)then return end
 if c>=11024 and c<=11026 then
  if c==11024 and v>=650 and v<=820 then settings.qnh=v;settings.saved_qnh=v;settings.standard=false;adopted=true
  elseif c==11025 and v>=0 and v<=25000 and v%1==0 then settings.baro_floor=v
  elseif c==11026 and v>=0 and v<=5000 and v%1==0 then settings.radar_floor=v end
 else
  if decode(v,devices.ALTITUDE_SYSTEM)<=.5 then return end
  if c==11020 then settings:toggle_standard();adopted=true
  elseif c==11023 then settings.units=1-settings.units
  elseif c==11021 or c==11022 then settings.field=1;settings:adjust(c==11021 and 1 or -1);adopted=true end
 end
 publish()
end
function update()
 local now=type(get_model_time)=='function'and get_model_time()or 0
 local age=now-get('F22_ALTIMETER_RESULT_TIME')
 local native=get('F22_ALTIMETER_NATIVE_READY')>.5 and get('F22_ALTIMETER_NATIVE_VALID')>.5 and age>=-.01 and age<=.2
 if native and not adopted then
  local q=get('F22_ALT_ACTUAL_PRESSURE_MMHG')
  if finite(q)and q>=650 and q<=820 then settings.qnh=q;settings.saved_qnh=q;adopted=true end
 end
 put('F22_ALT_PRESSURE_REQUEST_TIME',now);put('F22_ALT_PRESSURE_REQUEST_VALID',adopted and 1 or 0);publish()
 local powered=get('MAIN_POWER')>.5
 local baro=get('F22_ALT_NATIVE_BARO_M')*3.280839895
 put('F22_ALT_BARO_VALID',powered and native and finite(baro)and 1 or 0)
 if native and finite(baro)then put('F22_ALT_BARO_FT',baro)end
 local ok,radar=pcall(base.getRadarAltitude)
 local valid=powered and get('EFM_HUD_VALID')>.5 and ok and finite(radar)and radar>=0 and radar<20000
 put('F22_ALT_RADAR_VALID',valid and 1 or 0)
 if valid then put('F22_ALT_RADAR_FT',radar*3.280839895)end
end
make_default_activity(.05)
need_to_be_closed=false
