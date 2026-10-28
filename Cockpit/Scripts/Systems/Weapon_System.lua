--[[
    Grinnelli Designs F-22A Raptor
    Copyright (C) 2024, Joseph Grinnelli

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see https://www.gnu.org/licenses.
--]]

local dev = GetSelf()
dofile(LockOn_Options.script_path.."devices.lua")
dofile(LockOn_Options.script_path.."command_defs.lua")

local warning_audio_gate=dofile(LockOn_Options.script_path..'Systems/Warning_Audio_Gate.lua')
local warning_audio_handles={}
for _,key in ipairs({'F22_PILOT_AUDIO_PRIORITY','F22_PILOT_AUDIO_UNTIL',
 'F22_MWS_AUDIO_PRIORITY','F22_MWS_AUDIO_UNTIL'})do
    warning_audio_handles[key]=get_param_handle(key)
end
local function warning_audio_value(key)return warning_audio_handles[key]:get()end
local function warning_audio_inhibit()
    local now=type(get_model_time)=='function' and get_model_time() or -1
    return warning_audio_gate.priority(warning_audio_value,now)>0 or warning_audio_gate.mws(warning_audio_value,now)
end

local update_time_step = 0.02
make_default_activity(update_time_step)

local sensor_data		= get_base_data()
local hud_projection=dofile(LockOn_Options.script_path.."Systems/HUD_Projection.lua")


	local parameters =
		{

			APU_POWER			= get_param_handle("APU_POWER"),
			BATTERY_POWER		= get_param_handle("BATTERY_POWER"),
			MAIN_POWER			= get_param_handle("MAIN_POWER"),
			BAY_OPTION			= get_param_handle("BAY_OPTION"),
			ARM_STATUS			= get_param_handle("ARM_STATUS"), -- ARM TEXT
			GROUND_ORIDE        = get_param_handle("GROUND_ORIDE"),
			ORIDE_X				= get_param_handle("ORIDE_X"),
			ORIDE_TEXT			= get_param_handle("ORIDE_TEXT"),
			BAY_L_ARG			= get_param_handle("BAY_L_ARG"),
			BAY_R_ARG			= get_param_handle("BAY_R_ARG"),
			BAY_C_ARG			= get_param_handle("BAY_C_ARG"),
			LMFD_PAGE           = get_param_handle("LMFD_PAGE"),
			BAY_STATION         = get_param_handle("BAY_STATION"),
			AIR_ORIDE			= get_param_handle("AIR_ORIDE"),
			MASTER_ARM			= get_param_handle("MASTER_ARM"),
			DOGFIGHT			= get_param_handle("DOGFIGHT"),
			HUD_MODE			= get_param_handle("HUD_MODE"),
            HUD_WEAPON = get_param_handle("HUD_WEAPON"),
            HUD_RADAR_REQUEST = get_param_handle("HUD_RADAR_REQUEST"),
            PMFD_RADAR_MODE = get_param_handle("PMFD_RADAR_SELECTION"),
            HUD_ARMED = get_param_handle("HUD_ARMED"),
            HUD_GUN_READY = get_param_handle("HUD_GUN_READY"),
            HUD_GUN_TRIGGER = get_param_handle("HUD_GUN_TRIGGER"),
            HUD_AG_SUBMODE = get_param_handle("HUD_AG_SUBMODE"),
			GROUND_POWER		= get_param_handle("GROUND_POWER"),
			WoW				    = get_param_handle("WoW"),
			DETENT				= get_param_handle("DETENT"),
			PICKLE				= get_param_handle("PICKLE"),

		}

--wep	
-- local PickleON 						= Keys.PlanePickleOn
-- local PickleOFF 						= Keys.PlanePickleOff
local PickleON 							= 350
local PickleOFF 						= 351
local PlaneFire							= 84--gun trigger on
local PlaneFireOff						= 85--gun trigger off
local PlaneChangeWeapon 				= Keys.PlaneChangeWeapon --D keybind
local PlaneModeCannon					= 113-- C Keybind
--modes
local PlaneModeNAV 						= Keys.PlaneModeNAV	--1						
local PlaneModeBVR 						= Keys.PlaneModeBVR	--2						
local PlaneModeVS 						= Keys.PlaneModeVS --3								
local PlaneModeBore 					= Keys.PlaneModeBore --4
local PlaneModeFI0 						= Keys.PlaneModeFI0 --6
local PlaneModeGround = Keys.PlaneModeGround --7, only a HUD request until A/G delivery is integrated
local PlaneRadarChangeMode = Keys.PlaneRadarChangeMode
local ChangeReleaseMode = Keys.ChangeReleaseMode
--rwr
-- local PlaneThreatWarnSoundVolumeDown 	= 409
-- local PlaneThreatWarnSoundVolumeUp 		= 410
--jettison
local PlaneJettisonWeapons = Keys.PlaneJettisonWeapons or Keys.PiCommandSelecterUplaneJettisonWeapons
local PlaneJettisonFuelTanks 			= Keys.PlaneJettisonFuelTanks


--local NextSteer			 				= Keys.PlaneChangeTarget --steer point up
--local PrevSteer 						= 1315 --steer point prev
--local PlaneWheelBrakeON 				= 74
--local PlaneWheelBrakeOff 				= Keys.PlaneWheelBrakeOff
--local PlaneAirRefuel 					= Keys.PlaneAirRefuel
--local PlaneFuelOn 						= Keys.PlaneFuelOn --fuel dump
--local AutoAttHold 					= 62
--local AutoAltHold 					= 389
--local AutoCancel 						= 408

-- local TEST			= 438
-- dev:listen_command(TEST)
dev:listen_command(PickleON)
dev:listen_command(PickleOFF)
dev:listen_command(PlaneFire)
dev:listen_command(PlaneFireOff)
dev:listen_command(PlaneChangeWeapon)
dev:listen_command(PlaneModeNAV)
dev:listen_command(PlaneModeBVR)
dev:listen_command(PlaneModeVS)
dev:listen_command(PlaneModeBore)
dev:listen_command(PlaneModeFI0)
dev:listen_command(PlaneModeCannon)
dev:listen_command(PlaneModeGround)
dev:listen_command(PlaneRadarChangeMode)
dev:listen_command(ChangeReleaseMode)
dev:listen_command(PlaneJettisonWeapons)
dev:listen_command(PlaneJettisonFuelTanks)
-- dev:listen_command(PlaneThreatWarnSoundVolumeDown)
-- dev:listen_command(PlaneThreatWarnSoundVolumeUp)
-- dev:listen_command(L_OSB_7)
-- dev:listen_command(10000)--Left Bay Select
-- dev:listen_command(10001)--Right Bay Select
-- dev:listen_command(10002)--Center Bay Select
-- dev:listen_command(10003)--All Bay Select
-- dev:listen_command(10004)--Step Select
dev:listen_command(10006)--Weapon Bay Air Override
dev:listen_command(10024)--Weapon Bay Air Override
dev:listen_command(10007)--Master Arm
dev:listen_command(10008)--Master Arm Toggle
dev:listen_command(10021)--First Detent
dev:listen_command(10022)--Second Detent
dev:listen_command(10026)--PICKLE

local master_arm_switch = device_commands.Button_1 --track mouse clicks
dev:listen_command(master_arm_switch)
local emer_jet = device_commands.Button_2 --track mouse clicks
dev:listen_command(emer_jet)

local weapon_release_state 	= 0 --track if you press weapon release
local master_arm_state		= 0 --track if master arm switch is ON
local mode_state 			= 1 --default NAV mode
--local ground_override		= 0
local dogfight_mode			= 0
local first_state		    = 0
local fire_z_weapons 		= 0
local trigger_input = dofile(LockOn_Options.script_path..'Systems/Weapon_Trigger_Input.lua').new(devices.WEAPON_SYSTEM)
local air_oride				= 0
local detent_pos			= 0
local pickle_pos			= 0
local hud_radar_request = 1 -- 1 RWS, 2 TWS request, 3 VS, 4 ACM, 5 FLOOD
local ag_submode = 2 -- 1 ground gun, 2 CCIP, 3 AUTO
local ccip_target = dofile(LockOn_Options.script_path .. 'Systems/AG_CCIP_Target.lua')
local function ground_parameter(name) return get_param_handle(name):get() end
local ag_first_selection=true
local ag_release_sequence=0
local ag_consent_target=nil
local equipment_held={}
local gun_command_active = false
local native_pickle_active = false
local release_baseline=0;local pickle_consumed=false
local prev_bay_selection = 2
local native_arm=true -- constructor default verified in CockpitBase; synchronized on first update
local native_ready=false
local caged=true
local previous_mode=1;local pointer_logged=false
local ir_audio=dofile(LockOn_Options.script_path..'Systems/IR_Audio.lua').new()
local ir_seeker_module=dofile(LockOn_Options.script_path..'Systems/IR_Seeker.lua')
local ir_seeker=ir_seeker_module.new(sensor_data,function(n)return get_param_handle(n):get()end)
local ir_feedback_outputs = {}
for _, name in ipairs({'OWNER', 'VALID', 'AVAILABLE', 'LOCK', 'CUE_VALID'}) do
    ir_feedback_outputs[name] = get_param_handle('F22_IR_FEEDBACK_'..name)
    ir_feedback_outputs[name]:set(0)
end
local function reset_ir_feedback()
    ir_seeker:reset()
    for _, handle in pairs(ir_feedback_outputs) do handle:set(0) end
    ir_feedback_outputs.OWNER:set(ir_seeker.feedback.owned and 1 or 0)
    get_param_handle('HUD_IR_SEEKER_AVAILABLE'):set(0)
    get_param_handle('HUD_IR_SEEKER_VALID'):set(0)
    local ok, message=pcall(ir_audio.update,ir_audio,false,0,0,0,0,false,false)
    get_param_handle('F22_IR_AUDIO_READY'):set(ok and 1 or 0)
    if not ok and log and log.write then log.write('F22_IR_AUDIO',log.ERROR,tostring(message)) end
end
local ag_stores=dofile(LockOn_Options.script_path..'Systems/AG_Stores.lua').new()
local physical_supply = dofile(LockOn_Options.script_path..'Systems/Weapon_Physical_State.lua').new()
local vehicle_stores = dofile(LockOn_Options.script_path..'Systems/Vehicle_Stores_Adapter.lua').new()
local vehicle_inventory_stamp = -1
physical_supply:update()
local physical_outputs = {}
for _, name in ipairs({'OWNER', 'VALID', 'GENERATION', 'STAMP'}) do
    physical_outputs[name] = get_param_handle('F22_SMS_PHYSICAL_'..name)
end
physical_outputs.MISSION = get_param_handle('F22_SMS_MISSION_POWER')
local ir_instance = {station=-2, store=-1, physical=-1, generation=0}
local function ir_instance_generation(station)
    local store = ag_stores:generation(station)
    if ir_instance.station ~= station or ir_instance.store ~= store
        or ir_instance.physical ~= physical_supply.generation then
        ir_instance.station = station
        ir_instance.store = store
        ir_instance.physical = physical_supply.generation
        -- Exhaustion withdraws the native configuration rather than reusing a token.
        ir_instance.generation = math.min(16777216, ir_instance.generation + 1)
    end
    return ir_instance.generation
end
local entry_transactions=dofile(LockOn_Options.script_path..'Systems/Entry_Transaction.lua').channel('STORES',
 function(name)return get_param_handle(name):get()end,
 function(name,value)get_param_handle(name):set(value)end)
local selected_station=-1
local ag_program_station=-1
local station_refresh=0
local last_native_diagnostic=nil
local diagnostic_clock=0;local next_diagnostic=0;local next_telemetry=0;local next_missile_diag=0
local function native_command(c) dispatch_action(devices.WEAPON_NATIVE,c,1) end
local function publish_control_state()
    parameters.MASTER_ARM:set(master_arm_state)
    physical_outputs.OWNER:set(physical_supply.owned and 1 or 0)
    physical_outputs.VALID:set(physical_supply.valid and 1 or 0)
    physical_outputs.MISSION:set(physical_supply.mission and 1 or 0)
    physical_outputs.GENERATION:set(physical_supply.generation)
    physical_outputs.STAMP:set(physical_supply.stamp)
    get_param_handle('F22_AG_RELEASE_CONSENT'):set(not ag_stores.servicing
        and mode_state==7 and master_arm_state==1
        and physical_supply.mission and parameters.WoW:get()<.5
        and weapon_release_state==1 and ag_stores.program~=nil and not pickle_consumed and 1 or 0)
end
publish_control_state()
for _,c in ipairs({10800,10801,10802,10803,10804,10805,10806}) do dev:listen_command(c) end
for _,c in ipairs({10807,10808,10809,10813})do dev:listen_command(c)end
local store_caps=dofile(LockOn_Options.script_path..'Systems/Store_Capabilities.lua')
local station_infos={}
for _,n in ipairs({'F22_WEAPON_NAME','F22_WEAPON_EMPTY_TEXT'})do get_param_handle(n):set('')end
for _,n in ipairs({'F22_WEAPON_COUNT','F22_WEAPON_CATEGORY_COUNT','F22_WEAPON_SELECTED_VALID','F22_WEAPON_KIND','F22_WEAPON_SUPPORTED'})do get_param_handle(n):set(0)end
local function store_kind(info)local cap=store_caps.describe(info);return cap and cap.kind end
for c=10970,10988 do dev:listen_command(c) end
dev:listen_command(10990) -- Front keypad MULT field.
for _,command in ipairs({11121,11800})do dev:listen_command(command)end
for _,event in ipairs({'WeaponRearmFirstStep','WeaponRearmComplete','UnlimitedWeaponStationRestore'})do
 dev:listen_event(event)
end
for _,n in ipairs({"F22_SMS_ENTRY_FIELD","F22_SMS_ENTRY_VALUE","F22_SMS_ENTRY_LENGTH","F22_SMS_ENTRY_ERROR"})do get_param_handle(n)end
get_param_handle('F22_SMS_ENTRY_ERROR_TEXT'):set('')
-- String handles must exist before native indicator states bind.
for _,n in ipairs({'F22_SMS_WEAPON_TEXT','F22_SMS_MODE_TEXT','F22_SMS_FUZE_TEXT','F22_SMS_STATUS_TEXT',
 'F22_SMS_AVAILABLE','F22_SMS_QUANTITY','F22_SMS_INTERVAL_MS','F22_SMS_REMAINING'})do get_param_handle(n)end
for i=1,5 do for _,suffix in ipairs({'LABEL','COUNT','SELECTED'})do get_param_handle('F22_SMS_STORE_'..i..'_'..suffix)end end
for _,n in ipairs({'F22_SMS_LABEL','F22_SMS_TYPE4','F22_SMS_STATUS'})do get_param_handle(n)end
for _,name in ipairs({'MISSION_SLOT','MISSION_MODE','SERVICE_ACTIVE','SERVICE_SEQUENCE',
 'TARGET_N','TARGET_U','TARGET_E'})do
 get_param_handle('F22_SMS_'..name)
end
for station=0,10 do
 local prefix=string.format('F22_SMS_STATION_%02d_',station)
 get_param_handle(prefix..'GENERATION');get_param_handle(prefix..'INVENTORY_VALID')
end
-- Native gun telemetry is read-only; declare its display bindings without resetting the producer.
get_param_handle('F22_GUN_AMMO_COUNT');get_param_handle('F22_GUN_AMMO_VALID')
get_param_handle('F22_AG_GUIDED_SELECTED')
local function target_station()
 local g=ag_stores:group()
 if mode_state==7 and selected_station>=0 then return selected_station end
 for _,station in ipairs(g and g.stations or {})do if station==ag_program_station then return station end end
 return g and g.stations[1]or -1
end
local function publish_delivery_target()
 local station=target_station();local p=ag_stores.program
 local stored=p and p.targets[station]or ag_stores:target(station)
 local assigned=stored~=nil;local target=stored or p and p.live_target
 local live_allowed=ag_stores:mission_mode(station)==1
 local valid=assigned or live_allowed and get_param_handle('HUD_AG_TARGET_VALID'):get()>.5
  and (not p or p.live_target~=nil)
 local guided_ccip=mode_state==7 and ag_submode==2 and ag_stores:group()and ag_stores:group().guided
 if guided_ccip then target=p and p.ccip_target;valid=target~=nil;assigned=false end
 local function put(n,v)get_param_handle('F22_AG_DELIVERY_TARGET_'..n):set(v)end
 put('VALID',valid and 1 or 0);put('SOURCE',valid and guided_ccip and 3 or assigned and 2 or valid and 1 or 0)
 put('N',target and target.n or get_param_handle('HUD_AG_MARK_NORTH'):get())
 put('U',target and target.u or get_param_handle('HUD_AG_MARK_ALT'):get())
 put('E',target and target.e or get_param_handle('HUD_AG_MARK_EAST'):get())
 put('SEQUENCE',target and target.sequence or get_param_handle('F22_AG_TARGET_SEQUENCE'):get())
 get_param_handle('F22_SMS_TARGET_STATION'):set(station)
 get_param_handle('F22_SMS_TARGET_STATION_DISPLAY'):set(station>=0 and station+1 or 0)
 get_param_handle('F22_SMS_TARGET_VALID'):set(valid and 1 or 0)
 get_param_handle('F22_SMS_TARGET_SOURCE'):set(assigned and 2 or valid and 1 or 0)
 get_param_handle('F22_SMS_MISSION_MODE'):set(ag_stores:mission_mode(station))
 get_param_handle('F22_SMS_TARGET_SEQUENCE'):set(target and target.sequence or get_param_handle('F22_AG_TARGET_SEQUENCE'):get())
 for _,axis in ipairs({'N','U','E'})do get_param_handle('F22_SMS_TARGET_'..axis):set(get_param_handle('F22_AG_DELIVERY_TARGET_'..axis):get())end
end
local function publish_stores()
 publish_delivery_target()
 local g,p=ag_stores:group(),ag_stores:profile()
 local entry=ag_stores.entry
 local function put(n,v)get_param_handle('F22_SMS_'..n):set(v)end
 put('ENTRY_FIELD',entry and entry.field or 0);put('ENTRY_VALUE',entry and tonumber(entry.buffer)or 0)
 put('ENTRY_LENGTH',entry and #entry.buffer or 0);put('ENTRY_ERROR',entry and entry.error or 0)
 put('ENTRY_ERROR_TEXT',ag_stores:entry_error_text())
 put('WEAPON_TEXT',g and string.sub(g.name,1,25)or 'NO A/G STORES')
 put('MODE_TEXT',ag_submode==1 and 'GUN' or p.mode==3 and 'AUTO' or 'CCIP')
 put('FUZE_TEXT','STORE DEFAULT')
 local status=(ag_stores.failed or ag_stores:unconfirmed())and 7 or ag_stores.pending and 6 or ag_stores.program and 1 or not g and 2
  or not g.supported and 8 or p.quantity>g.count and 3 or p.quantity%p.pair~=0 and 9
  or not store_caps.mode_available(g,p.mode)and 4 or 5
 local text={[1]='RELEASING',[2]='NO STORE',[3]='QTY EXCEEDS LOAD',[4]='MODE UNAVAILABLE',[5]='PROGRAM SET',[6]='RELEASE PENDING',[7]='RELEASE UNCONFIRMED',[8]='WPN UNAVAIL',[9]='CHECK PAIR QTY'}
 put('STATUS',status);put('STATUS_TEXT',text[status]);put('AVAILABLE',g and g.count or 0)
 put('READY_COUNT',ag_stores:ready_count());put('FUZE_PROGRAMMABLE',0);put('SELECTED_INDEX',g and g.index or 0);put('QUANTITY',p.quantity)
 put('INTERVAL_MS',p.interval*1000);put('INTERVAL_MODE',p.interval_mode);put('SPACING_FT',p.spacing_ft)
 put('PROFILE',ag_stores:profile_index());put('PULSES',p.quantity/p.pair);put('PAIR',p.pair)
 put('MISSION_SLOT',ag_stores.mission_slots[target_station()]or 1)
 put('SERVICE_ACTIVE',ag_stores.servicing and 1 or 0);put('SERVICE_SEQUENCE',ag_stores.service_sequence)
 put('RELEASE_PENDING',ag_stores.pending and 1 or 0);put('RELEASE_FAILED',(ag_stores.failed or ag_stores:unconfirmed())and 1 or 0)
 put('REMAINING',ag_stores.program and ag_stores.program.remaining or 0)
 put('LABEL',g and g.label or 0);put('TYPE4',g and g.type4 or 0)
 for i=1,3 do put('MODE_AVAILABLE_'..i,store_caps.mode_available(g,i)and 1 or 0)end
 local first=math.max(1,math.min(#ag_stores.groups-4,(g and g.index or 1)-2))
 for i=1,5 do
  local row=ag_stores.groups[first+i-1];local prefix='STORE_'..i..'_'
  put(prefix..'LABEL',row and row.label or 0);put(prefix..'COUNT',row and row.count or 0)
  put(prefix..'INDEX',row and row.index or 0)
  put(prefix..'SELECTED',ag_submode~=1 and row and row.key==ag_stores.selected and 1 or 0)
 end
 for i=0,10 do
  local cap=store_caps.describe(station_infos[i]);local prefix=string.format('STATION_%02d_',i)
  put(prefix..'LABEL',cap and cap.label or 0);put(prefix..'COUNT',cap and cap.count or 0)
  put(prefix..'ACTIVE',i==target_station()and 1 or 0);put(prefix..'TARGET_VALID',ag_stores:target(i)and 1 or 0)
  put(prefix..'PRESENT',cap and 1 or 0);put(prefix..'SELECTED',cap and cap.key==ag_stores.selected and 1 or 0)
  put(prefix..'GENERATION',ag_stores:generation(i))
  put(prefix..'INVENTORY_VALID',ag_stores.stations[i]and ag_stores.stations[i].valid and 1 or 0)
 end
end
local function newest_ground_shot(pending)
 if not pending then return nil end
 local best
 for i=1,16 do
  local prefix=string.format('F22_SHOT_%02d_',i)
  local function r(n)return get_param_handle(prefix..n):get()end
  local sequence=r('SEQUENCE')
  if sequence>pending.sequence and r('STATION')==pending.station and r('MODE')==7 and r('TYPE')==pending.type4 and (not best or sequence>best.sequence)then
   best={sequence=sequence,id=r('ID'),station=r('STATION'),mode=r('MODE'),type4=r('TYPE'),time=r('TIME')}
  end
 end
 return best
end
local function acknowledge_release(now)
 local accepted,complete,q=ag_stores:acknowledge(station_infos,now,newest_ground_shot(ag_stores.pending))
 if accepted==nil then return end
 if accepted then
  ag_release_sequence=ag_release_sequence+1;get_param_handle('F22_AG_RELEASE_SEQUENCE'):set(ag_release_sequence)
 end
 if not accepted or complete then pickle_consumed=true;weapon_release_state=0;pickle_pos=0 end
 if log and log.write then log.write('F22_AG_RELEASE_ACK',log.INFO,string.format('t=%.3f accepted=%s station=%d requested=%.3f sequence=%d evidence=%d native_id=%d native_sequence=%d native_time=%.3f complete=%s',now,tostring(accepted),q.station,q.time,ag_release_sequence,q.evidence or 0,q.native_id or 0,q.native_sequence or 0,q.native_time or 0,tostring(complete)))end
end
-- The display owns manual ground-service selection. Airborne carriage follows
-- the selected payload, independently of the display's faster refresh cadence.
local function active_bay(ground_contact, station, manual_selection)
    if ground_contact or station < 0 then return manual_selection end
    if station == 0 then return 1 end
    if station == 10 then return 3 end
    return 2
end
local function choose_station(native,step)
    local eligible={};local total=0;local infos={}
    for i=0,10 do
        local ok,info=pcall(function() return native:get_station_info(i) end)
        if ok then infos[i]=info end
    end
    station_infos=infos
    vehicle_inventory_stamp = physical_supply.valid and physical_supply.stamp or -1
    ag_stores:refresh(infos)
    acknowledge_release(type(get_model_time)=='function'and get_model_time()or diagnostic_clock)
    local group=ag_stores:group()
    for i=0,10 do local info=infos[i]
        local kind=store_kind(info)
        local matches=kind==mode_state
        if mode_state==7 then
            matches=false
            for _,station in ipairs(group and group.supported and group.stations or {})do if station==i and ag_stores:station_ready(i)then matches=true end end
        end
        if matches then eligible[#eligible+1]=i;total=total+(info.count or 0) end
    end
    get_param_handle('F22_WEAPON_CATEGORY_COUNT'):set(total)
    local next_station=eligible[1]or -1
    if mode_state==7 and selected_station<0 then for _,station in ipairs(eligible)do if station==ag_program_station then next_station=station end end end
    for j,id in ipairs(eligible) do if id==selected_station then
        next_station=step and eligible[j%#eligible+1] or id;break
    end end
    if mode_state==5 or mode_state==1 or (mode_state==7 and ag_submode==1)then next_station=-1 end
    if selected_station~=next_station then
        if mode_state==7 then get_param_handle('F22_AG_SOLUTION_VALID'):set(0) end
        native:select_station(next_station);selected_station=next_station
    end
    if mode_state==7 and selected_station>=0 then ag_program_station=selected_station end
    get_param_handle('F22_WEAPON_STATION'):set(selected_station)
    local info=infos[selected_station];local w=info and info.weapon or {}
    local selected=store_caps.selected(infos,selected_station,mode_state,ag_submode==1)
    if mode_state==7 and ag_submode~=1 and not info and group then
        selected.name=group.hud or group.identity or group.name
    end
    get_param_handle('F22_WEAPON_NAME'):set(selected.hud~='' and selected.hud or selected.name)
    get_param_handle('F22_WEAPON_EMPTY_TEXT'):set(mode_state==3 and 'NO SRM' or 'NO MRM')
    get_param_handle('F22_WEAPON_COUNT'):set(selected.count)
    get_param_handle('F22_WEAPON_SELECTED_VALID'):set(selected_station>=0 and 1 or 0)
    get_param_handle('F22_WEAPON_KIND'):set(selected.kind or 0)
    get_param_handle('F22_WEAPON_SUPPORTED'):set(selected.supported and 1 or 0)
    get_param_handle('F22_WEAPON_TYPE4'):set(w.level4 or 0)
    local bomb=mode_state==7 and selected_station>=0 and w.level2==5
    get_param_handle('F22_AG_BOMB_SELECTED'):set(bomb and 1 or 0)
    get_param_handle('F22_AG_GUIDED_SELECTED'):set(bomb and w.level3==36 and 1 or 0)
    get_param_handle('F22_AG_WEAPON_TYPE3'):set(bomb and w.level3 or 0)
    get_param_handle('F22_AG_WEAPON_TYPE4'):set(bomb and w.level4 or 0)
    if bomb and ag_first_selection then ag_submode=ag_stores:profile().mode;ag_first_selection=false end
    publish_stores()
    get_param_handle('F22_IR_STATION'):set(mode_state==3 and selected_station or -1)
    get_param_handle('F22_IR_STORE_GENERATION'):set(ir_instance_generation(selected_station))
    -- Events/counts cannot prove every unobserved replacement.
    get_param_handle('F22_SMS_STORE_GENERATION_VALID'):set(0)
    for level=1,4 do get_param_handle('F22_IR_TYPE'..level):set(w['level'..level] or 0) end
    get_param_handle('F22_IR_AIM9X_PROFILE'):set(mode_state==3 and ir_seeker_module.profile(info) or 0)
end
-- Declare a complete invalid/empty display snapshot before indicators bind.
publish_stores()
for _,name in ipairs({'HUD_IR_SEEKER_X_SLOPE','HUD_IR_SEEKER_Y_SLOPE',
    'HUD_IR_SEEKER_AVAILABLE','HUD_IR_SEEKER_VALID'}) do
    get_param_handle(name):set(0)
end
------------------------------------------------------------------FUNCTION-POSTINIT---------------------------------------------------------------------------------------------------

function post_initialize()
    reset_ir_feedback()
    trigger_input:reset()
    equipment_held={}
    ag_stores=dofile(LockOn_Options.script_path..'Systems/AG_Stores.lua').new()
    mode_state,master_arm_state=1,0
    fire_z_weapons,first_state,weapon_release_state,air_oride=0,0,0,0
    detent_pos,pickle_pos,release_baseline=0,0,0
    ag_consent_target,pickle_consumed=nil,false
    caged,gun_command_active,native_pickle_active=true,false,false
    selected_station,ag_program_station,station_refresh=-1,-1,0
    physical_supply:update()
    get_param_handle('F22_IR_EXPOSURE_VALID'):set(0)
    get_param_handle('F22_IR_EXPOSED'):set(0)
    get_param_handle('F22_IR_RELEASE_REQUEST'):set(0)
    publish_control_state()

	local bay_option_state = get_aircraft_property("BAY_DOOR_OPTION")--ME Option Box
	local birth = LockOn_Options.init_conditions.birth_place
	if birth == "GROUND_COLD" then
		parameters.BAY_OPTION:set(bay_option_state) -- Unchecked = 0 Checked = 1	
	elseif birth == "GROUND_HOT" or birth == "AIR_HOT" then
		parameters.BAY_OPTION:set(1)
		--dev:performClickableAction(battery_switch, 1, false)
	end
	--Bay Arg Preset
	if bay_option_state == 0 then
		--parameters.GROUND_ORIDE:set(1)
		set_aircraft_draw_argument_value(600,1)
		set_aircraft_draw_argument_value(601,1)
		set_aircraft_draw_argument_value(602,1)
	elseif bay_option_state == 1 then
		parameters.GROUND_ORIDE:set(0)
		set_aircraft_draw_argument_value(600,0)
		set_aircraft_draw_argument_value(601,0)
		set_aircraft_draw_argument_value(602,0)
	end
end
local function cancel_release()
    trigger_input:cancel()
    local held=weapon_release_state==1
    ag_stores:cancel(true)
    weapon_release_state, pickle_pos, fire_z_weapons, first_state = 0, 0, 0, 0
    pickle_consumed=held or pickle_consumed
    ag_consent_target=nil
    native_command(85); native_command(351)
    native_pickle_active, gun_command_active = false, false
    get_param_handle('F22_IR_RELEASE_REQUEST'):set(0)
    publish_control_state()
end
local function withdraw_physical_consent()
    if weapon_release_state == 1 or fire_z_weapons == 1 or first_state == 1
        or ag_stores.program or native_pickle_active or gun_command_active then
        local entry = ag_stores.entry
        cancel_release()
        if physical_supply.electrical then ag_stores.entry = entry end
    end
    if native_arm then
        native_command(283)
        native_arm = false
    end
    get_param_handle('F22_IR_EXPOSURE_VALID'):set(0)
    get_param_handle('F22_IR_EXPOSED'):set(0)
    get_param_handle('F22_IR_RELEASE_REQUEST'):set(0)
    get_param_handle('F22_AG_RELEASE_CONSENT'):set(0)
end
local function refresh_physical_supply()
    local owned, generation = physical_supply.owned, physical_supply.generation
    physical_supply:update()
    local replaced = physical_supply.owned and physical_supply.valid
        and (not owned or generation ~= physical_supply.generation)
    if replaced or not physical_supply.mission then withdraw_physical_consent() end
    if replaced then
        caged = true
        selected_station = -2
        station_refresh = 0
        get_param_handle('F22_AG_GUIDANCE_CACHE_VALID'):set(0)
        get_param_handle('F22_AG_SOLUTION_VALID'):set(0)
    end
end
function CockpitEvent(event, _)
    if event=='WeaponRearmFirstStep' or event=='WeaponRearmComplete'
        or event=='UnlimitedWeaponStationRestore' then
        cancel_release()
        ag_stores:service(event~='WeaponRearmFirstStep')
        caged=true
        selected_station=-2;station_refresh=0
        get_param_handle('F22_AG_GUIDANCE_CACHE_VALID'):set(0)
        get_param_handle('F22_AG_SOLUTION_VALID'):set(0)
        get_param_handle('F22_IR_STORE_GENERATION'):set(-ag_stores.service_sequence-1)
        publish_stores()
    end
end
local function committed_entry_value(field)
    local profile=ag_stores:profile()
    if field==1 then return profile.quantity
    elseif field==2 then return profile.interval*1000
    elseif field==3 then return profile.spacing_ft
    elseif field==4 then return profile.quantity/profile.pair
    elseif field==5 then return profile.pair end
end
local function correlated_commit(sequence)
    local command,wanted=entry_transactions:take(sequence)
    if not command then return end
    local entry=ag_stores.entry
    local context=(mode_state==1 or mode_state==7) and parameters.MAIN_POWER:get()>.5
        and get_param_handle('F22_SMS_PROGRAM_PAGE'):get()>.5
    local field=entry and entry.field
    local valid=command==10979 and context and entry and tonumber(entry.buffer)==wanted
    local accepted=valid and ag_stores:commit()or false
    entry_transactions:finish(sequence,accepted,accepted and committed_entry_value(field)or 0)
    publish_stores()
end
------------------------------------------------------------------FUNCTION-SETCOMMAND---------------------------------------------------------------------------------------------------
local function handle_command(command,value)
    local trigger_permitted = not ag_stores.servicing and physical_supply.mission
        and master_arm_state == 1 and parameters.WoW:get() < .5
    if trigger_input:input(command, value, trigger_permitted) then
        first_state, fire_z_weapons = trigger_input:state()
        detent_pos = fire_z_weapons == 1 and 1 or first_state * .5
        if fire_z_weapons == 0 and gun_command_active then
            native_command(85); gun_command_active = false
        end
        return
    end
    if command==11800 then correlated_commit(value);return end
    if command==11121 then
        local down=dofile(LockOn_Options.script_path..'Systems/Input_Value.lua')(value,devices.WEAPON_SYSTEM)>.5
        local previous=equipment_held[command];equipment_held[command]=down
        if not down or previous or parameters.MAIN_POWER:get()<.5 then return end
        cancel_release()
        local station=target_station()
        local slot=(ag_stores.mission_slots[station]or 1)%4+1
        ag_stores.mission_slots[station]=slot
        ag_stores:select_mission(station,slot)
        publish_control_state();publish_stores();return
    end
    if command==emer_jet or command==PlaneJettisonWeapons or command==PlaneJettisonFuelTanks then
        cancel_release()
    end
    if command>=10975 and command<=10980 or command==10985 or command==10986 or command==10990 then
        local context=(mode_state==7 or mode_state==1) and parameters.MAIN_POWER:get()>.5 and get_param_handle('F22_SMS_PROGRAM_PAGE'):get()>.5
        if command==10980 or not context then ag_stores.entry=nil;publish_stores();return end
        if command==10975 or command==10976 or command==10985 or command==10986 or command==10990 then
            if dofile(LockOn_Options.script_path..'Systems/Input_Value.lua')(value,devices.WEAPON_SYSTEM)<=0 then return end
            local was_held=weapon_release_state==1
            weapon_release_state=0;pickle_pos=0;pickle_consumed=was_held or pickle_consumed
            native_command(351);native_pickle_active=false
            ag_stores:begin_entry(command==10975 and 1 or command==10976 and 2 or command==10985 and 3 or command==10990 and 5 or 4)
        elseif command==10977 then ag_stores:digit(value)
        elseif command==10978 then ag_stores:backspace()
        elseif command==10979 then ag_stores:commit() end
        publish_stores();return
    end
    if command==10987 or command==10988 then
        local down=dofile(LockOn_Options.script_path..'Systems/Input_Value.lua')(value,devices.WEAPON_SYSTEM)>.5
        if down and parameters.MAIN_POWER:get()>.5 and (mode_state==7 or mode_state==1)then
            local station=target_station()
            local held=weapon_release_state==1;weapon_release_state=0;pickle_pos=0;pickle_consumed=held or pickle_consumed
            native_command(351);native_pickle_active=false
            if command==10988 then ag_stores:clear_target(station)
            elseif get_param_handle('HUD_AG_TARGET_VALID'):get()>.5 then
                ag_stores:capture_target(station,{n=get_param_handle('HUD_AG_MARK_NORTH'):get(),
                    u=get_param_handle('HUD_AG_MARK_ALT'):get(),e=get_param_handle('HUD_AG_MARK_EAST'):get(),
                    source=get_param_handle('F22_AG_TARGET_SOURCE'):get(),
                    sequence=get_param_handle('F22_AG_TARGET_SEQUENCE'):get(),
                    time=type(get_model_time)=='function'and get_model_time()or diagnostic_clock})
            end
            get_param_handle('F22_AG_SOLUTION_VALID'):set(0);publish_stores()
        end
        return
    end
    -- Store edits cancel a pending release before changing its immutable program.
    if command>=10970 and command<=10974 or command>=10981 and command<=10984 then
        local down=dofile(LockOn_Options.script_path..'Systems/Input_Value.lua')(value,devices.WEAPON_SYSTEM)>.5
        if down and (mode_state==7 or mode_state==1)then
            local was_held=weapon_release_state==1
            ag_stores:cancel();weapon_release_state=0;pickle_pos=0;pickle_consumed=was_held or pickle_consumed
            native_command(351);native_pickle_active=false
            if command==10970 or command==10971 or command==10981 then
                if command==10981 then ag_stores:select(math.floor(value+.5))else ag_stores:step(command==10970 and -1 or 1)end
                ag_submode=ag_stores:profile().mode;selected_station=-2;station_refresh=0
            else
                ag_stores:edit(command==10972 and 'less' or command==10973 and 'more' or command==10974 and 'interval' or command==10982 and 'profile' or command==10983 and 'unit' or 'pair')
                ag_submode=ag_stores:profile().mode
            end
            publish_stores()
        end
        return
    end
    -- Absolute private controls prevent repeated/late releases from toggling fire ON.
    if command==10800 then
        if value==1 or value==2 or value==3 or value==5 or value==7 then
            trigger_input:cancel()
            ag_stores:cancel();mode_state=value;fire_z_weapons=0;first_state=0;weapon_release_state=0
            if value==7 then ag_first_selection=true end
            parameters.HUD_MODE:set(value)
            native_command(85);native_command(351);gun_command_active=false;native_pickle_active=false
            selected_station=-2;station_refresh=0
        end
        return
    elseif command==10803 then
        if value>0 and mode_state==7 and ag_submode==1 then weapon_release_state=0;pickle_pos=0;return end
        if value<=0 then ag_stores:cancel(true);pickle_consumed=false;ag_consent_target=nil
        elseif weapon_release_state==0 and not pickle_consumed then
            release_baseline=get_param_handle('F22_WEAPON_CATEGORY_COUNT'):get()
            ag_consent_target=mode_state==7 and ag_submode==3 and get_param_handle('F22_AG_TARGET_SEQUENCE'):get()or nil
            if mode_state==7 then
                local now=type(get_model_time)=='function' and get_model_time()or diagnostic_clock
                local point
                if get_param_handle('HUD_AG_TARGET_VALID'):get()>.5 then point={n=get_param_handle('HUD_AG_MARK_NORTH'):get(),u=get_param_handle('HUD_AG_MARK_ALT'):get(),e=get_param_handle('HUD_AG_MARK_EAST'):get(),sequence=get_param_handle('F22_AG_TARGET_SEQUENCE'):get()}end
                local group=ag_stores:group()
                local guided_ccip=ag_submode==2 and group and group.guided
                local captured=guided_ccip and ccip_target.capture(ground_parameter,now,selected_station)
                if guided_ccip and not captured then pickle_consumed=true
                elseif not ag_stores:start(now,ag_consent_target,point)then pickle_consumed=true
                elseif guided_ccip then ag_stores.program.ccip_target=captured end
                publish_delivery_target()
            end
        end
        weapon_release_state=value>0 and not pickle_consumed and 1 or 0;pickle_pos=weapon_release_state
        if weapon_release_state==0 then native_command(351);native_pickle_active=false end
        return
    elseif command==10804 then
        if mode_state==1 then
            local g=ag_stores:group();local current=target_station()
            for i,station in ipairs(g and g.stations or {})do if station==current then ag_program_station=g.stations[i%#g.stations+1];break end end
            ag_stores.entry=nil;publish_stores()
        else
            if mode_state==7 then
                local held=weapon_release_state==1;ag_stores:cancel();weapon_release_state=0;pickle_pos=0;pickle_consumed=held or pickle_consumed
                native_command(351);native_pickle_active=false
            end
            local ok,native=pcall(GetDevice,devices.WEAPON_NATIVE)
            if ok and native and native_ready then choose_station(native,true)end
        end
        return
    elseif command==10805 then caged=not caged;return
    elseif command==10806 then master_arm_state=value>0 and 1 or 0;return
    elseif command==10807 or command==10808 or command==10809 or command==10813 then
        local down=dofile(LockOn_Options.script_path..'Systems/Input_Value.lua')(value,devices.WEAPON_SYSTEM)>.5
        if down and (mode_state==7 or mode_state==1)then
            if command==10813 and ag_submode==1 then return end
            local requested=command==10813 and (ag_submode==2 and 3 or 2)or command-10806
            if requested~=1 and not store_caps.mode_available(ag_stores:group(),requested)then return end
            ag_submode=requested
            trigger_input:cancel()
            ag_stores:cancel();ag_first_selection=false;station_refresh=0;selected_station=-2
            get_param_handle('F22_AG_SOLUTION_VALID'):set(0)
            if ag_submode~=1 then ag_stores:profile().mode=ag_submode end
            weapon_release_state=0;pickle_pos=0;pickle_consumed=false;fire_z_weapons=0
            native_command(85);native_command(351);gun_command_active=false;native_pickle_active=false
        end
        return
    end
--WEP JET
	if command == emer_jet then
		dispatch_action(nil,PlaneJettisonWeapons)
	end
--Air Override
	if (command == 10006 or command == 10024) and air_oride == 0 and parameters.MAIN_POWER:get() == 1 then
		air_oride = 1
	elseif (command == 10006 or command == 10024) and air_oride == 1 and parameters.MAIN_POWER:get() == 1 then
		air_oride = 0
	end
-- Legacy master-mode keys obey the same captured-consent boundary.
if command==PlaneModeNAV or command==PlaneModeBVR or command==PlaneModeVS or command==PlaneModeBore or command==PlaneModeFI0 or command==PlaneModeCannon or command==PlaneModeGround then
 trigger_input:cancel();fire_z_weapons,first_state=0,0
 local held=weapon_release_state==1
 ag_stores:cancel(true);weapon_release_state=0;pickle_pos=0;pickle_consumed=held or pickle_consumed
 native_command(351);native_pickle_active=false
end
--Mode States
	if command == PlaneModeNAV then
		mode_state = 1
        hud_radar_request = 0
	elseif command == PlaneModeBVR then
		mode_state = 2
        hud_radar_request = 1
	elseif command == PlaneModeVS then
        if mode_state~=5 then mode_state=3 end
        hud_radar_request = 3
	elseif command == PlaneModeBore then
        if mode_state~=5 then mode_state=3 end
        hud_radar_request = 4
	elseif command == PlaneModeFI0 then
        if mode_state~=5 then mode_state=3 end
        hud_radar_request = 5
    elseif command == PlaneModeCannon then
        mode_state = 5
        hud_radar_request = 4
    elseif command == PlaneModeGround then
        mode_state = 7
        ag_first_selection=true
        hud_radar_request = 0
    elseif command == PlaneRadarChangeMode and mode_state == 2 then
        -- Tracks requested radar presentation; no APG-77 feedback is available.
        hud_radar_request = hud_radar_request == 2 and 1 or 2
    elseif command == ChangeReleaseMode and mode_state == 7 then
        handle_command(10813,1);return
    end					
--Master Arm JOYSTICK/KEYBOARD BINDS
	if (command == 10007 or command == 10008 or command == master_arm_switch) and master_arm_state == 0 then
		master_arm_state = 1
	elseif (command == 10007 or command == 10008 or command == master_arm_switch) and master_arm_state == 1 then
		master_arm_state = 0
	end		
	-- --Bay Doors Open Close

    if command == 10026 then
        -- Value-based press/release for a real momentary input. Nil remains a
        -- backwards-compatible toggle for a legacy action with no value.
        local requested = (value == nil) and (weapon_release_state == 0)
            or (value ~= nil and value > 0)
        local permitted = master_arm_state == 1 and
            physical_supply.mission and
            parameters.WoW:get() < 0.5
        weapon_release_state = (requested and permitted) and 1 or 0
        pickle_pos = weapon_release_state
    end


end
function SetCommand(command,value)
    refresh_physical_supply()
    handle_command(command,value)
    -- A press received while unavailable must not survive even if power
    -- returns before the next update callback.
    if not physical_supply.mission then withdraw_physical_consent() end
    -- Cancellation and SAFE must reach the native callback guard within this
    -- input call, rather than leaving old consent/arm visible for 20 ms.
    if master_arm_state==0 and (weapon_release_state==1 or ag_stores.program
        or ag_stores.pending or fire_z_weapons==1 or first_state==1 or gun_command_active)then
        local entry=ag_stores.entry
        cancel_release()
        ag_stores.entry=entry
    end
    publish_control_state()
end
------------------------------------------------------------------FUNCTION-UPDATE---------------------------------------------------------------------------------------------------
function update()
    refresh_physical_supply()
    if diagnostic_clock>=next_missile_diag then
        next_missile_diag=diagnostic_clock+1
        local function r(n)return get_param_handle(n):get()end
        if log and log.write then log.write('F22_MISSILE_DIAG',log.INFO,string.format(
            'data=%.0f min=%.1f max=%.1f speed=%.1f life=%.1f seq=%.0f id=%.0f target=%.0f mode=%.0f alive=%.0f active=%.0f active_range=%.1f pos=(%.1f,%.1f,%.1f)',
            r('F22_MISSILE_DATA_VALID'),r('F22_MISSILE_NATIVE_MIN'),r('F22_MISSILE_NATIVE_MAX'),r('F22_MISSILE_AVERAGE_SPEED'),r('F22_MISSILE_LIFETIME'),
            r('F22_LAUNCH_SEQUENCE'),r('F22_SHOT_01_ID'),r('F22_SHOT_01_TARGET'),r('F22_SHOT_01_MODE'),r('F22_SHOT_01_ALIVE'),r('F22_SHOT_01_ACTIVE'),
            r('F22_SHOT_01_ACTIVE_RANGE'),r('F22_SHOT_01_N'),r('F22_SHOT_01_U'),r('F22_SHOT_01_E'))) end
    end
    local ok,native=false,nil
    if GetDevice then ok,native=pcall(GetDevice,devices.WEAPON_NATIVE) end
    native_ready=ok and native and type(native.get_station_info)=='function' or false
    get_param_handle('F22_WEAPON_BACKEND_READY'):set(native_ready and 1 or 0)
    local native_permitted=not ag_stores.servicing and native_ready
        and master_arm_state==1 and physical_supply.mission and parameters.WoW:get()<.5
    if native_arm~=native_permitted then native_command(283);native_arm=native_permitted end
    station_refresh=station_refresh-update_time_step
    if native_ready and station_refresh<=0 then
        choose_station(native,false);station_refresh=.25
        if mode_state~=7 and weapon_release_state==1 and get_param_handle('F22_WEAPON_CATEGORY_COUNT'):get()<release_baseline then
            pickle_consumed=true;weapon_release_state=0;pickle_pos=0
        end

    end
    -- Weapon selection cages the new seeker. Radar acquisition never uncages it.
    if mode_state~=previous_mode then caged=true end
    previous_mode=mode_state
    get_param_handle('F22_IR_MODE'):set(mode_state)
    -- Native weapon service supplies the payload and independent IR seeker.
    if native_ready then
        if not pointer_logged and log and log.write then
            log.write('F22_NATIVE_BRIDGE',log.INFO,'weapon link='..tostring(native.link));pointer_logged=true
        end
        local locked=get_param_handle('F22_RADAR_STT_VALID'):get()>.5
        local az,el=0,0
        if mode_state==3 and not caged and locked then
            -- Native seeker desired azimuth is opposite to radar body +Z.
            az=-get_param_handle('F22N_RADAR_STT_AZIMUTH'):get()
            el=get_param_handle('F22N_RADAR_STT_ELEVATION'):get()
        end
        get_param_handle('WS_IR_MISSILE_SEEKER_DESIRED_AZIMUTH'):set(az)
        get_param_handle('WS_IR_MISSILE_SEEKER_DESIRED_ELEVATION'):set(el)
    end
    get_param_handle('F22_IR_CAGED'):set(caged and 1 or 0)
    get_param_handle('HUD_IR_BACKEND_READY'):set(get_param_handle('F22_IR_API_READY'):get())
    local ir_now=type(get_model_time)=='function' and get_model_time() or diagnostic_clock
    local ir_az,ir_el,ir_feedback=ir_seeker:update(mode_state==3 and physical_supply.mission,
        update_time_step,ir_now)
    local ir_available,ir_locked=ir_feedback.available,ir_feedback.locked
    ir_feedback_outputs.OWNER:set(ir_feedback.owned and 1 or 0)
    ir_feedback_outputs.VALID:set(ir_feedback.valid and 1 or 0)
    ir_feedback_outputs.AVAILABLE:set(ir_available and 1 or 0)
    ir_feedback_outputs.LOCK:set(ir_locked and 1 or 0)
    ir_feedback_outputs.CUE_VALID:set(ir_az and ir_el and 1 or 0)
    local ir_inhibit=warning_audio_inhibit()
    local audio_ok,audio_error=pcall(ir_audio.update,ir_audio,mode_state==3 and ir_available,
        get_param_handle('F22_IR_TYPE4'):get(),ir_feedback.strength,
        ir_az or 0,ir_el or 0,get_param_handle('F22_IR_AIM9X_PROFILE'):get()>.5,
        ir_inhibit)
    get_param_handle('F22_IR_AUDIO_READY'):set(audio_ok and 1 or 0)
    -- An unavailable sound resource must not stop stores, sensors, or displays.
    if not audio_ok and not ir_audio.reported then
        ir_audio.reported=true
        if log and log.write then log.write('F22_IR_AUDIO',log.ERROR,tostring(audio_error)) end
    end
    local ir_x,ir_y=hud_projection.polar(ir_az,ir_el)
    get_param_handle('HUD_IR_SEEKER_AVAILABLE'):set(ir_available and ir_x and 1 or 0)
    get_param_handle('HUD_IR_SEEKER_X_SLOPE'):set(ir_x or 0)
    get_param_handle('HUD_IR_SEEKER_Y_SLOPE'):set(ir_y or 0)
    get_param_handle('HUD_IR_SEEKER_VALID'):set(mode_state==3 and ir_locked and ir_x and ir_y and 1 or 0)
    get_param_handle('HUD_IR_SEEKER_AZ'):set(ir_az or 0)
    get_param_handle('HUD_IR_SEEKER_EL'):set(ir_el and math.atan2(math.sin(ir_el),math.cos(ir_el)*math.cos(ir_az)) or 0)
    -- Interlock all locally dispatched weapon requests on ground, power loss,
    -- and master-arm loss. Do not confuse gear-down with weight-on-wheels.
    local ready_to_release = not ag_stores.servicing and master_arm_state == 1
        and physical_supply.mission
        and parameters.WoW:get() < 0.5
    if not ready_to_release then
        local entry=ag_stores.entry
        ag_stores:cancel(true)
        if parameters.MAIN_POWER:get()>=.5 then ag_stores.entry=entry end
        if weapon_release_state == 1 then
            weapon_release_state = 0
            pickle_pos = 0
        end
        fire_z_weapons = 0
        first_state = 0
        trigger_input:cancel()
        detent_pos = 0
    end
    local ground_gun=mode_state==7 and ag_submode==1

    -- Single owner for all bay positions. Independent main/left/right bay
    -- requests, ramped with physical time, no repeated writes/overshoots.
    -- Rate approximations reproduce the earlier intended 0.02s Lua cadence.
    local mainPower = physical_supply.electrical
    local missionPower = physical_supply.mission
    -- The EFM owns hydraulic authority. A GPU supplies electricity, not
    -- pressure; ground-crew requests therefore obey the same physical supply.
    local actuatorAuthority=physical_supply.utility
    get_param_handle('F22_BAY_ACTUATOR_AUTHORITY'):set(actuatorAuthority)
    get_param_handle('F22_BAY_ACTUATOR_VALID'):set(physical_supply.utility_valid and 1 or 0)
    local groundContact = parameters.WoW:get() >= 0.5
    local selected = math.floor(parameters.BAY_STATION:get() + 0.5)
    if selected < 1 or selected > 4 then
        selected = prev_bay_selection
    else
        prev_bay_selection = selected
    end
    selected = active_bay(groundContact, selected_station, selected)
    local groundOverride = groundContact and mainPower
        and parameters.GROUND_ORIDE:get() >= 0.5
    local groundCrewLeft = groundContact and parameters.GROUND_POWER:get() >= 0.5
        and parameters.GROUND_ORIDE:get() < 0.5
    -- Mod workflow estimate: prepare the selected SRM before release consent.
    -- Head cage controls seeker pointing, not whether its carrier is exposed.
    local irPreparation = mode_state==3 and selected_station>=0 and get_param_handle('F22_WEAPON_COUNT'):get()>0
    local bayRequest = not groundContact and missionPower and master_arm_state == 1
        and (weapon_release_state == 1 or air_oride == 1 or irPreparation)
    local openAll = groundOverride or (bayRequest and selected == 4)
    local openMain = openAll or (bayRequest and selected == 2)
    local openLeft = openAll or groundCrewLeft or (bayRequest and selected == 1)
    local openRight = openAll or (bayRequest and selected == 3)

    -- Normal actuator model [normalized travel/second]. True real rates
    -- depend on hydraulics and are not available in the public documents.
    local function stepDoor(current, open, rate, powered)
        current = math.max(0, math.min(1, current))
        if not powered then return current end
        local target = open and 1 or 0
        local maximum = rate * update_time_step * actuatorAuthority
        return math.max(0, math.min(1,
            current + math.max(-maximum, math.min(maximum, target-current))))
    end
    local bay_door_pos = stepDoor(get_aircraft_draw_argument_value(600),
        openMain, groundContact and 0.11 or 2.5, mainPower)
    local left_door_pos = stepDoor(get_aircraft_draw_argument_value(601),
        openLeft, groundContact and (groundCrewLeft and 0.25 or 0.11) or 2.5,
        mainPower or groundCrewLeft)
    local right_door_pos = stepDoor(get_aircraft_draw_argument_value(602),
        openRight, groundContact and 0.11 or 2.5, mainPower)
    set_aircraft_draw_argument_value(600,bay_door_pos)
    set_aircraft_draw_argument_value(601,left_door_pos)
    set_aircraft_draw_argument_value(602,right_door_pos)

    parameters.ORIDE_X:set(groundContact and 0 or 1)
    parameters.ORIDE_TEXT:set(groundContact and
        (bay_door_pos > 0.01 or left_door_pos > 0.01 or right_door_pos > 0.01)
        and 1 or 0)
    -- Arm annunciation depends on real WOW and main-power availability.
    parameters.ARM_STATUS:set(groundContact and 2 or
        (master_arm_state == 1 and missionPower and 1 or 0))

    -- Weapon release is a request distinct from an actual launch or clearance.
    local chosenBayReady = (selected == 1 and left_door_pos >= 0.98) or
        (selected == 2 and bay_door_pos >= 0.98) or
        (selected == 3 and right_door_pos >= 0.98) or
        (selected == 4 and bay_door_pos >= 0.98
            and left_door_pos >= 0.98 and right_door_pos >= 0.98)
    get_param_handle('F22_IR_EXPOSURE_VALID'):set((not physical_supply.owned or physical_supply.valid)and 1 or 0)
    get_param_handle('F22_IR_EXPOSED'):set(mode_state==3 and chosenBayReady and missionPower and 1 or 0)
    local exposure_time=type(get_model_time)=='function'and get_model_time()or diagnostic_clock
    get_param_handle('F22_IR_EXPOSURE_TIME'):set(exposure_time)
    -- Native clear-ray origin, not recovered launcher geometry.
    get_param_handle('F22_IR_APERTURE_APPROXIMATION'):set(1)
    local canCommandNativePickle = not ag_stores.servicing and missionPower and not groundContact
        and master_arm_state == 1 and weapon_release_state == 1
        and chosenBayReady and selected_station>=0 and mode_state ~= 5 and mode_state ~= 1
        and get_param_handle('F22_WEAPON_SUPPORTED'):get()>.5
    -- IR launch belongs to the typed seeker that actually acquired the target.
    -- The generic device otherwise launches its separate, empty seeker record.
    get_param_handle('F22_IR_RELEASE_REQUEST'):set(canCommandNativePickle and mode_state==3 and 1 or 0)
    local mrm_supported=get_param_handle('RADAR_PWR'):get()>.5 and
        get_param_handle('F22_RADAR_BACKEND_READY'):get()>.5 and
        get_param_handle('F22_RADAR_WEAPON_TARGET_ID'):get()>0 and
        get_param_handle('F22_TWS_GUIDANCE_BACKEND_READY'):get()>.5
    get_param_handle('F22_MRM_RELEASE_INHIBIT'):set(mode_state==2 and not mrm_supported and 1 or 0)
    canCommandNativePickle=canCommandNativePickle and mode_state~=3 and (mode_state~=2 or mrm_supported)
    if mode_state==7 then
        local live_sequence=get_param_handle('F22_AG_TARGET_SEQUENCE'):get()
        if ag_stores.program and not ag_stores:consent_current(selected_station,live_sequence)then
            ag_stores:cancel();weapon_release_state=0;pickle_pos=0;pickle_consumed=true
        end
        local now=type(get_model_time)=='function'and get_model_time()or diagnostic_clock
        if ag_stores.pending then choose_station(native,false)end
        local solution_age=now-get_param_handle('F22_AG_SOLUTION_TIME'):get()
        local solution=get_param_handle('F22_AG_SOLUTION_VALID'):get()>.5
            and get_param_handle('F22_AG_SOLUTION_SCHEMA'):get()==2
            and solution_age>=0 and solution_age<=.2
            and get_param_handle('F22_AG_SOLUTION_STATION'):get()==selected_station
        local guided=get_param_handle('F22_AG_GUIDED_SELECTED'):get()>.5
        local auto_ready=ag_submode==3 and get_param_handle('F22_AG_AUTO_RELEASE'):get()>.5
        local permitted=solution and (ag_submode==2 or auto_ready)
        if guided then
            local function r(n)return get_param_handle(n):get()end
            local cache_age=now-r('F22_AG_GUIDANCE_CACHE_TIME')
            local cached=r('F22_AG_GUIDANCE_CACHE_VALID')>.5 and cache_age>=-.01 and cache_age<=.2
                and r('F22_AG_GUIDANCE_CACHE_STATION')==selected_station
                and r('F22_AG_SOLUTION_SEQUENCE')>0
                and r('F22_AG_GUIDANCE_CACHE_SOLUTION_SEQUENCE')==r('F22_AG_SOLUTION_SEQUENCE')
            for _,key in ipairs({'SOURCE','SEQUENCE','N','U','E'})do
                if r('F22_AG_GUIDANCE_CACHE_TARGET_'..key)~=r('F22_AG_DELIVERY_TARGET_'..key)then cached=false end
            end
            permitted=permitted and cached and r('F22_AG_DELIVERY_TARGET_VALID')>.5 and r('F22_AG_GUIDANCE_BACKEND_READY')>.5
        end
        local impact={n=get_param_handle('F22_AG_SOLUTION_IMPACT_N'):get(),e=get_param_handle('F22_AG_SOLUTION_IMPACT_E'):get(),vn=get_param_handle('EFM_HUD_VN'):get(),ve=get_param_handle('EFM_HUD_VE'):get()}
        publish_control_state()
        if canCommandNativePickle and permitted and not pickle_consumed and ag_stores:due(now,impact)and type(native.launch_station)=='function'then
            if ag_stores:request(selected_station,station_infos[selected_station],now,impact,get_param_handle('F22_LAUNCH_SEQUENCE'):get())then
                if log and log.write then
                    local function r(n)return get_param_handle(n):get()end
                    local actual_n,actual_u,actual_e=sensor_data.getSelfCoordinates()
                    log.write('F22_AG_RELEASE',log.INFO,string.format('t=%.3f station=%d mode=%d predicted=(%.3f,%.3f,%.3f) origin=(%.3f,%.3f,%.3f) actual=(%.3f,%.3f,%.3f) velocity=(%.3f,%.3f,%.3f) wind=(%.3f,%.3f,%.3f) pitch=%.4f bank=%.4f delay=%.3f solution_age=%.3f remaining=%d target=(%.3f,%.3f,%.3f) target_source=%.0f target_sequence=%.0f request_time=%.6f native_time=%.6f published_time=%.6f solver_sequence=%.0f prediction_sec=%.6f',now,selected_station,ag_submode,impact.n,r('F22_AG_SOLUTION_IMPACT_U'),impact.e,r('F22_AG_OWN_N'),r('F22_AG_OWN_U'),r('F22_AG_OWN_E'),actual_n,actual_u,actual_e,r('EFM_HUD_VN'),r('EFM_HUD_VU'),r('EFM_HUD_VE'),r('EFM_HUD_WN'),r('EFM_HUD_WU'),r('EFM_HUD_WE'),sensor_data.getPitch(),sensor_data.getRoll(),r('F22_AG_BOMB_RELEASE_DELAY'),solution_age,ag_stores.program.remaining,r('F22_AG_DELIVERY_TARGET_N'),r('F22_AG_DELIVERY_TARGET_U'),r('F22_AG_DELIVERY_TARGET_E'),r('F22_AG_DELIVERY_TARGET_SOURCE'),r('F22_AG_DELIVERY_TARGET_SEQUENCE'),r('F22_AG_SOLUTION_REQUEST_TIME'),r('F22_AG_SOLUTION_NATIVE_TIME'),r('F22_AG_SOLUTION_PUBLICATION_TIME'),r('F22_AG_SOLUTION_SEQUENCE'),r('F22_AG_SOLUTION_PREDICTION_SEC')))
                end
                -- A successful call is only a request. A matching armed native
                -- launch must acknowledge it before another store can be requested.
                -- Guided permission above requires an actual native cache
                -- acknowledgement. dispatch_action is queued, so an immediate
                -- refresh call cannot establish readiness before launch_station.
                local accepted=pcall(native.launch_station,native,selected_station)
                if not accepted then ag_stores:fail_request();pickle_consumed=true;weapon_release_state=0;pickle_pos=0 end
                station_refresh=0;choose_station(native,false)
            end
        end
        publish_stores()
        canCommandNativePickle=false
    else get_param_handle('F22_AG_RELEASE_CONSENT'):set(0)end
    if canCommandNativePickle ~= native_pickle_active then
            native_command(canCommandNativePickle and PickleON or PickleOFF)
        native_pickle_active = canCommandNativePickle
    end

    -- Gun door has its own hydraulic actuation path, documented by USAF.
    local cannon_request = (mode_state == 5 or ground_gun) and missionPower
        and not groundContact and master_arm_state == 1
        and (first_state == 1 or fire_z_weapons == 1)
    local canon_door_pos = stepDoor(get_aircraft_draw_argument_value(614),
        cannon_request, 4.5, mainPower)
    set_aircraft_draw_argument_value(614, canon_door_pos)
    local canon_rotate = get_aircraft_draw_argument_value(615)
    if cannon_request then
        canon_rotate = (canon_rotate + update_time_step * 2 * (actuatorAuthority>0 and 1 or 0)) % 1
    else
        canon_rotate = 0
    end
    set_aircraft_draw_argument_value(615, canon_rotate)

		--CANON FIRE
        -- Emit a trigger command only on an actual state transition.
        -- This also guarantees a release when power/ground/arm interlocks change.
        local can_fire_gun = (not ag_stores.servicing and native_ready
            and (mode_state == 5 or ground_gun) and master_arm_state == 1
            and missionPower and parameters.WoW:get() < 0.5
            and canon_door_pos >= 0.8 and actuatorAuthority>0)
        local gun_requested = (fire_z_weapons == 1 and can_fire_gun)
        if gun_requested ~= gun_command_active then
            native_command(gun_requested and PlaneFire or PlaneFireOff)
            gun_command_active = gun_requested
        end
        parameters.HUD_GUN_READY:set(can_fire_gun and 1 or 0)
        parameters.HUD_GUN_TRIGGER:set(gun_command_active and 1 or 0)

    vehicle_stores:update(physical_supply, update_time_step, station_infos,
        native_ready, ag_stores.servicing, vehicle_inventory_stamp)

	parameters.BAY_C_ARG:set(bay_door_pos)
	parameters.BAY_L_ARG:set(left_door_pos)
	parameters.BAY_R_ARG:set(right_door_pos)
	publish_control_state()
	parameters.DOGFIGHT:set(dogfight_mode)
	parameters.AIR_ORIDE:set(air_oride)
	parameters.HUD_MODE:set(mode_state)
    if mode_state == 2 then
        -- PMFD owns the native RWS/TWS selection. Do not let the HUD maintain
        -- a second toggle that diverges when the pilot uses the OSB.
        hud_radar_request = parameters.PMFD_RADAR_MODE:get() >= 0.5 and 2 or 1
    end
    parameters.HUD_RADAR_REQUEST:set(hud_radar_request)
    parameters.HUD_WEAPON:set(mode_state == 5 and 1 or
        ((mode_state == 3 or mode_state == 4 or mode_state == 6) and 2 or
        (mode_state == 2 and 3 or (mode_state == 7 and 4 or 0))))
    parameters.HUD_ARMED:set(master_arm_state)
    parameters.HUD_AG_SUBMODE:set(ag_submode)
	parameters.DETENT:set(detent_pos)
	parameters.PICKLE:set(pickle_pos)
    -- Run the native seeker from the cockpit activity, including active pause.
    -- Physics time must not own seeker power/consent or IR launch state.
    dispatch_action(nil,10850,update_time_step)
    diagnostic_clock=diagnostic_clock+update_time_step
    if log and log.write then
        local az = get_param_handle('HUD_GUN_NATIVE_AZ'):get()
        local el = get_param_handle('HUD_GUN_NATIVE_EL'):get()
        local valid = get_param_handle('HUD_GUN_NATIVE_VALID'):get() == 1
        if diagnostic_clock>=next_telemetry then
            next_telemetry=diagnostic_clock+1
            log.write('F22_IR_NATIVE',log.INFO,string.format('ticks=%.0f api=%.0f abi=%.0f available=%.0f state=%.0f strength=%.3f caged=%.0f radar_config=%.0f radar_reason=%.0f min_m=%.0f el_limit=%.3f launch_seq=%.0f launch_id=%.0f',
                get_param_handle('F22_COMBAT_NATIVE_TICKS'):get(),get_param_handle('F22_IR_API_READY'):get(),
                get_param_handle('F22_IR_ABI_ERROR'):get(),get_param_handle('F22_IR_AVAILABLE'):get(),
                get_param_handle('F22_IR_STATE'):get(),get_param_handle('F22_IR_STRENGTH'):get(),
                get_param_handle('F22_IR_CAGED'):get(),get_param_handle('F22_RADAR_NATIVE_CONFIGURED'):get(),
                get_param_handle('F22_RADAR_NATIVE_CONFIG_REASON'):get(),get_param_handle('F22_RADAR_NATIVE_MIN_METRES'):get(),
                get_param_handle('F22_RADAR_NATIVE_EL_LIMIT'):get(),
                get_param_handle('F22_IR_LAUNCH_SEQUENCE'):get(),get_param_handle('F22_IR_LAUNCH_ID'):get()))
            log.write('F22_IR_AUDIO_STATE',log.INFO,string.format(
                'valid=%d available=%d age=%.3f inhibit=%d on=%d starts=%d stops=%d',
                ir_feedback.valid and 1 or 0,ir_available and 1 or 0,ir_now-ir_feedback.time,
                ir_inhibit and 1 or 0,ir_audio.on and 1 or 0,ir_audio.starts,ir_audio.stops))
            if ir_available then
                log.write('F22_IR_DIAG',log.INFO,string.format('search=%.0f sensor_mode=%.0f parent=%.0f target=%.0f sun=%.0f electric=%.0f world=(%.1f,%.1f,%.1f)',
                    get_param_handle('F22_IR_SEARCH_ACTIVE'):get(),get_param_handle('F22_IR_SENSOR_MODE'):get(),
                    get_param_handle('F22_IR_PARENT_VALID'):get(),get_param_handle('F22_IR_NATIVE_TARGET_ID'):get(),
                    get_param_handle('F22_IR_SUN'):get(),get_param_handle('F22_IR_ELECTRIC'):get(),
                    get_param_handle('F22_IR_WORLD_NORTH'):get(),get_param_handle('F22_IR_WORLD_ALT'):get(),get_param_handle('F22_IR_WORLD_EAST'):get()))
                log.write('F22_IR_SENSOR',log.INFO,string.format('power=%.0f init=%.0f aperture=%.5f type=%.0f timer=%.0f hits=%.0f fwd=(%.5f,%.5f,%.5f)',
                    get_param_handle('F22_IR_SENSOR_POWER'):get(),get_param_handle('F22_IR_INITIALIZED'):get(),get_param_handle('F22_IR_APERTURE'):get(),
                    get_param_handle('F22_IR_NATIVE_TYPE'):get(),get_param_handle('F22_IR_TIMER'):get(),get_param_handle('F22_IR_CONTACTS'):get(),
                    get_param_handle('F22_IR_WORLD_FWD_N'):get(),get_param_handle('F22_IR_WORLD_FWD_U'):get(),get_param_handle('F22_IR_WORLD_FWD_E'):get()))
            end
            log.write('F22_FIRE_CONTROL',log.INFO,string.format('mode=%d stt=%d range=%.1f los=(%.5f,%.5f) pipper=(%.5f,%.5f) ir=%.0f seeker=(%.5f,%.5f) desired=(%.5f,%.5f) stores=%.0f gun_ammo=%.0f ammo_valid=%.0f',
                mode_state,get_param_handle('F22_RADAR_STT_VALID'):get(),get_param_handle('F22N_RADAR_STT_RANGE'):get(),
                get_param_handle('F22N_RADAR_STT_AZIMUTH'):get(),get_param_handle('F22N_RADAR_STT_ELEVATION'):get(),az or 0,el or 0,
                get_param_handle('F22_IR_LOCK'):get(),get_param_handle('F22_IR_AZ'):get(),get_param_handle('F22_IR_EL'):get(),
                get_param_handle('WS_IR_MISSILE_SEEKER_DESIRED_AZIMUTH'):get(),get_param_handle('WS_IR_MISSILE_SEEKER_DESIRED_ELEVATION'):get(),get_param_handle('F22_WEAPON_COUNT'):get(),
                get_param_handle('F22_GUN_AMMO_COUNT'):get(),get_param_handle('F22_GUN_AMMO_VALID'):get()))
        end
        local status=string.format('api=%s mode=%d arm=%d station=%d trigger=%s sight=%s first=%d second=%d power=%.1f wow=%.1f door=%.2f',
            tostring(native_ready),mode_state,master_arm_state,selected_station,tostring(gun_command_active),
            tostring(valid),first_state,fire_z_weapons,parameters.MAIN_POWER:get(),parameters.WoW:get(),canon_door_pos)
        if status~=last_native_diagnostic and diagnostic_clock>=next_diagnostic then
            log.write('F22_WEAPON',log.INFO,status);last_native_diagnostic=status;next_diagnostic=diagnostic_clock+.25
        end
    end

end
