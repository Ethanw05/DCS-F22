-- GPL-3.0-or-later. Warthog/STECS routing with a single master-mode owner.
dofile(LockOn_Options.script_path..'devices.lua')
local input_value=dofile(LockOn_Options.script_path..'Systems/Input_Value.lua')
local commands=dofile(LockOn_Options.script_path..'Systems/Combat_Commands.lua')
local radar=dofile(LockOn_Options.script_path..'Systems/Radar_Commands.lua')
local dev=GetSelf();local dt=.02;make_default_activity(dt)
local handles={};local function h(n) if not handles[n] then handles[n]=get_param_handle(n) end;return handles[n] end
local function get(n) return h(n):get() end
local function put(n,v) h(n):set(v) end
local by_id={};for n,id in pairs(commands) do by_id[id]=n;dev:listen_command(id) end
local function send(id,c,v) dispatch_action(id,c,v or 1) end
local bursts=0;local next_burst=0;local burst_program=1;local clock=0
local function emit(n,v)
 if n=='weapon_mode' then send(devices.WEAPON_SYSTEM,10800,v)
 elseif n=='trigger_first' then send(devices.WEAPON_SYSTEM,10801,v)
 elseif n=='trigger_second' then send(devices.WEAPON_SYSTEM,10802,v)
 elseif n=='pickle' then send(devices.WEAPON_SYSTEM,10803,v)
 elseif n=='radar_operate' then send(devices.RADAR_COMPUTER,radar.operate)
 elseif n=='radar_page' then send(devices.PMFD_SYSTEM,10005)
 elseif n=='left_page' then send(devices.MFD_SYSTEM,10820)
 elseif n=='right_page' then send(devices.MFD_SYSTEM,10821)
 elseif n=='arm' then send(devices.WEAPON_SYSTEM,10008)
 elseif n=='station_step' then send(devices.WEAPON_SYSTEM,10804)
 elseif n=='cage' then send(devices.WEAPON_SYSTEM,10805)
 elseif n=='nws' then dispatch_action(nil,562,1)
 elseif n=='autopilot_off' then dispatch_action(nil,408,1)
 elseif n=='defense_program' then
  bursts=v==3 and 6 or v==2 and 2 or 4;burst_program=v;next_burst=clock
 elseif n=='defense_consent' then
  -- No automatic threat responder is claimed. Consent is stored, not automatic release.
  put('F22_CM_CONSENT',v)
 elseif n=='expand' then send(devices.RADAR_COMPUTER,10624)
 elseif n=='interrogate_los' then send(devices.RADAR_COMPUTER,10625)
 elseif radar[n] then send(devices.RADAR_COMPUTER,radar[n]) end
end
local logic=dofile(LockOn_Options.script_path..'Systems/Combat_Logic.lua').new(emit)
local function context()
 return {locked=get('F22_RADAR_STT_VALID')>.5,selected=get('F22_RADAR_SELECTED_VALID')>.5,
  ground=get('WoW')>.5}
end
function post_initialize()
 put('F22_SOI',2);put('F22_CM_CONSENT',0);put('F22_CM_AUTO_AVAILABLE',0)
end
function SetCommand(c,v)
 local n=by_id[c];if n then
  if log and log.write then log.write('F22_HOTAS',log.INFO,n..' value='..tostring(v)) end
  logic:input(n,input_value(v,devices.COMBAT_SYSTEM),context())
 end
end
function update()
 clock=clock+dt
 -- Mirror keyboard/cockpit mode changes without re-emitting them.
 local mode=get('HUD_MODE')
 if mode>=1 and mode<=7 and mode~=logic.mode then
  logic.mode=mode
  if mode==2 or mode==3 or mode==5 then logic.last_aa=mode end
 end
 if get('MAIN_POWER')>.5 then logic:update(dt,context())
 else
  logic.held={};bursts=0
  emit('trigger_first',0);emit('trigger_second',0);emit('pickle',0)
 end
 put('F22_SOI',logic.soi);put('F22_DOGFIGHT',logic.dogfight and 1 or 0)
 if bursts>0 and clock>=next_burst and get('MAIN_POWER')>.5 then
  local ok,native=pcall(GetDevice,devices.WEAPON_NATIVE)
  if ok and native and type(native.drop_chaff)=='function' then
   -- Simple manual programs; native device owns actual cartridge counts.
   pcall(function()
    if burst_program~=2 then native:drop_chaff() end
    native:drop_flare()
   end)
  end
  bursts=bursts-1;next_burst=clock+.25
 end
end
need_to_be_closed=false
