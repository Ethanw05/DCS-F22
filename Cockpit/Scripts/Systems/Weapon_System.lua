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

local update_time_step = 0.02
make_default_activity(update_time_step)

local sensor_data		= get_base_data()
local gun_director=dofile(LockOn_Options.script_path..'Systems/Gun_Director.lua').new(
    sensor_data,function(n)return get_param_handle(n):get()end,
    function(n,v)get_param_handle(n):set(v)end,dispatch_action,
    dofile(LockOn_Options.script_path..'Systems/Radar_Display.lua'),devices.WEAPON_NATIVE)
local gun_funnel=dofile(LockOn_Options.script_path..'Systems/Gun_Funnel.lua').new(
    sensor_data,function(n)return get_param_handle(n):get()end,
    function(n,v)get_param_handle(n):set(v)end,dispatch_action,devices.WEAPON_NATIVE)

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
local PlaneJettisonWeapons 				= Keys.PlaneJettisonWeapons
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
local air_oride				= 0
local detent_pos			= 0
local pickle_pos			= 0
local hud_radar_request = 1 -- 1 RWS, 2 TWS request, 3 VS, 4 ACM, 5 FLOOD
local ag_submode = 1 -- 1 MAN, 2 CCIP request, 3 CCRP request
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
local selected_station=-1
local station_refresh=0
local last_native_diagnostic=nil
local diagnostic_clock=0;local next_diagnostic=0;local next_telemetry=0;local next_missile_diag=0
local function native_command(c) dispatch_action(devices.WEAPON_NATIVE,c,1) end
for _,c in ipairs({10800,10801,10802,10803,10804,10805,10806}) do dev:listen_command(c) end
local ir_clsids={['{5CE2FF2A-645A-4197-B48D-8720AC69394F}']=true,
 ['{6CEB49FC-DED8-4DED-B053-E1F033FF72D3}']=true,['{AIM9X-BLKII}']=true}
local function store_kind(info)
    if not info or (info.count or 0)<=0 then return nil end
    local id=info.CLSID or info.clsid or ''
    if ir_clsids[id] or string.find(id,'AIM9',1,true) then return 3 end
    if id=='{40EF17B7-F508-45de-8566-6FFECC0C1AB8}' or
       id=='{C8E06185-7CD6-4C90-959F-044679E90751}' or string.find(id,'AIM-120',1,true) then return 2 end
end
local function choose_station(native,step)
    local eligible={};local total=0;local infos={}
    for i=0,10 do
        local ok,info=pcall(function() return native:get_station_info(i) end)
        if ok and store_kind(info)==mode_state then
            eligible[#eligible+1]=i;infos[i]=info;total=total+(info.count or 0)
        end
    end
    get_param_handle('F22_WEAPON_COUNT'):set(total)
    local next_station=eligible[1] or -1
    for j,id in ipairs(eligible) do if id==selected_station then
        next_station=step and eligible[j%#eligible+1] or id;break
    end end
    if mode_state==5 or mode_state==1 then next_station=-1 end
    if selected_station~=next_station then
        native:select_station(next_station);selected_station=next_station
    end
    get_param_handle('F22_WEAPON_STATION'):set(selected_station)
    local info=infos[selected_station];local w=info and info.weapon or {}
    get_param_handle('F22_WEAPON_TYPE4'):set(w.level4 or 0)
    get_param_handle('F22_IR_STATION'):set(mode_state==3 and selected_station or -1)
    for level=1,4 do get_param_handle('F22_IR_TYPE'..level):set(w['level'..level] or 0) end
    get_param_handle('F22_IR_AIM9X_PROFILE'):set(mode_state==3 and ir_seeker_module.profile(info) or 0)
    -- Side bays are stations 0 and 10; other internal missiles use main bay.
    if selected_station>=0 then parameters.BAY_STATION:set(selected_station==0 and 1 or selected_station==10 and 3 or 2) end
end
------------------------------------------------------------------FUNCTION-POSTINIT---------------------------------------------------------------------------------------------------

function post_initialize()

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
------------------------------------------------------------------FUNCTION-SETCOMMAND---------------------------------------------------------------------------------------------------
function SetCommand(command,value)
    -- Absolute private controls prevent repeated/late releases from toggling fire ON.
    if command==10800 then
        if value==1 or value==2 or value==3 or value==5 or value==7 then
            mode_state=value;fire_z_weapons=0;first_state=0;weapon_release_state=0
            parameters.HUD_MODE:set(value)
            native_command(85);native_command(351);gun_command_active=false;native_pickle_active=false
            selected_station=-2;station_refresh=0
        end
        return
    elseif command==10801 then first_state=value>0 and 1 or 0;detent_pos=first_state*.5;return
    elseif command==10802 then
        fire_z_weapons=value>0 and 1 or 0;detent_pos=fire_z_weapons==1 and 1 or first_state*.5
        if fire_z_weapons==0 then native_command(85);gun_command_active=false end
        return
    elseif command==10803 then
        if value<=0 then pickle_consumed=false
        elseif weapon_release_state==0 and not pickle_consumed then release_baseline=get_param_handle('F22_WEAPON_COUNT'):get() end
        weapon_release_state=value>0 and not pickle_consumed and 1 or 0;pickle_pos=weapon_release_state
        if weapon_release_state==0 then native_command(351);native_pickle_active=false end
        return
    elseif command==10804 then
        local ok,native=pcall(GetDevice,devices.WEAPON_NATIVE)
        if ok and native and native_ready then choose_station(native,true) end
        return
    elseif command==10805 then caged=not caged;return
    elseif command==10806 then master_arm_state=value>0 and 1 or 0;return end
--WEP JET
	if command == emer_jet then
		dispatch_action(nil,178)
	end
--Air Override
	if (command == 10006 or command == 10024) and air_oride == 0 and parameters.MAIN_POWER:get() == 1 then
		air_oride = 1
	elseif (command == 10006 or command == 10024) and air_oride == 1 and parameters.MAIN_POWER:get() == 1 then
		air_oride = 0
	end
-- --Trigger Detent
if command == 10021 and first_state == 0 and parameters.MAIN_POWER:get() == 1 then
	first_state = 1
	detent_pos = 0.50
elseif command == 10021 and first_state == 1 and parameters.MAIN_POWER:get() == 1 then
	first_state = 0
	detent_pos = 0
end
--Second Trigger Detent
if command == 10022 and fire_z_weapons == 0 and parameters.MAIN_POWER:get() == 1 then
	fire_z_weapons = 1
	detent_pos = 1
	--first_state    = 1
elseif command == 10022 and fire_z_weapons == 1 and parameters.MAIN_POWER:get() == 1 then
	fire_z_weapons = 0
	detent_pos = 0.50
	--first_state    = 0
	dispatch_action(nil,PlaneFireOff)
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
        hud_radar_request = 0
    elseif command == PlaneRadarChangeMode and mode_state == 2 then
        -- Tracks requested radar presentation; no APG-77 feedback is available.
        hud_radar_request = hud_radar_request == 2 and 1 or 2
    elseif command == ChangeReleaseMode and mode_state == 7 then
        ag_submode = ag_submode % 3 + 1
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
            parameters.MAIN_POWER:get() >= 0.5 and
            parameters.WoW:get() < 0.5
        weapon_release_state = (requested and permitted) and 1 or 0
        pickle_pos = weapon_release_state
    end


end
------------------------------------------------------------------FUNCTION-UPDATE---------------------------------------------------------------------------------------------------
function update()
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
    local native_permitted=native_ready and master_arm_state==1 and parameters.MAIN_POWER:get()>.5 and parameters.WoW:get()<.5
    if native_arm~=native_permitted then native_command(283);native_arm=native_permitted end
    station_refresh=station_refresh-update_time_step
    if native_ready and station_refresh<=0 then
        choose_station(native,false);station_refresh=.25
        if weapon_release_state==1 and get_param_handle('F22_WEAPON_COUNT'):get()<release_baseline then
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
    local ir_available=get_param_handle('F22_IR_AVAILABLE'):get()>.5
    local ir_locked=ir_available and get_param_handle('F22_IR_LOCK'):get()>.5
    local ir_az,ir_el=ir_seeker:update(mode_state==3 and ir_available,update_time_step)
    local audio_ok,audio_error=pcall(ir_audio.update,ir_audio,mode_state==3 and ir_available and parameters.MAIN_POWER:get()>.5,
        get_param_handle('F22_IR_TYPE4'):get(),get_param_handle('F22_IR_STRENGTH'):get(),
        ir_az or 0,ir_el or 0,get_param_handle('F22_IR_AIM9X_PROFILE'):get()>.5,
        get_param_handle('F22_MWS_AUDIO_PRIORITY'):get()>.5)
    get_param_handle('F22_IR_AUDIO_READY'):set(audio_ok and 1 or 0)
    -- An unavailable sound resource must not stop stores, sensors, or displays.
    if not audio_ok and not ir_audio.reported then
        ir_audio.reported=true
        if log and log.write then log.write('F22_IR_AUDIO',log.ERROR,tostring(audio_error)) end
    end
    get_param_handle('HUD_IR_SEEKER_AVAILABLE'):set(ir_available and ir_az and 1 or 0)
    get_param_handle('HUD_IR_SEEKER_VALID'):set(mode_state==3 and ir_locked and 1 or 0)
    get_param_handle('HUD_IR_SEEKER_AZ'):set(ir_az or 0)
    get_param_handle('HUD_IR_SEEKER_EL'):set(ir_el and math.atan2(math.sin(ir_el),math.cos(ir_el)*math.cos(ir_az)) or 0)
    -- Computed director is the sole gun aiming source.
    local az,el=gun_director:update(native_ready and mode_state==5 and parameters.MAIN_POWER:get()>.5)
    local valid=az~=nil and el~=nil
    get_param_handle('F22_GUN_USING_DIRECTOR'):set(valid and 1 or 0)
    get_param_handle('HUD_GUN_NATIVE_VALID'):set(valid and 1 or 0)
    get_param_handle('HUD_GUN_NATIVE_AZ'):set(valid and az or 0)
    get_param_handle('HUD_GUN_NATIVE_EL'):set(valid and el or 0)
    gun_funnel:update(native_ready and mode_state==5 and parameters.MAIN_POWER:get()>.5)
    -- Interlock all locally dispatched weapon requests on ground, power loss,
    -- and master-arm loss. Do not confuse gear-down with weight-on-wheels.
    local ready_to_release = master_arm_state == 1
        and parameters.MAIN_POWER:get() == 1
        and parameters.WoW:get() < 0.5
    if not ready_to_release then
        if weapon_release_state == 1 then
            weapon_release_state = 0
            pickle_pos = 0
        end
        fire_z_weapons = 0
        first_state = 0
        detent_pos = 0
    end

    -- Single owner for all bay positions. Independent main/left/right bay
    -- requests, ramped with physical time, no repeated writes/overshoots.
    -- Rate approximations reproduce the earlier intended 0.02s Lua cadence.
    local mainPower = parameters.MAIN_POWER:get() >= 0.5
    local groundContact = parameters.WoW:get() >= 0.5
    local selected = math.floor(parameters.BAY_STATION:get() + 0.5)
    if selected < 1 or selected > 4 then
        selected = prev_bay_selection
    else
        prev_bay_selection = selected
    end
    local groundOverride = groundContact and mainPower
        and parameters.GROUND_ORIDE:get() >= 0.5
    local groundCrewLeft = groundContact and parameters.GROUND_POWER:get() >= 0.5
        and parameters.GROUND_ORIDE:get() < 0.5
    local releaseRequest = not groundContact and mainPower and master_arm_state == 1
        and (weapon_release_state == 1 or air_oride == 1 or (mode_state==3 and not caged and get_param_handle('F22_WEAPON_COUNT'):get()>0))
    local openAll = groundOverride or (releaseRequest and selected == 4)
    local openMain = openAll or (releaseRequest and selected == 2)
    local openLeft = openAll or groundCrewLeft or (releaseRequest and selected == 1)
    local openRight = openAll or (releaseRequest and selected == 3)

    -- Normal actuator model [normalized travel/second]. True real rates
    -- depend on hydraulics and are not available in the public documents.
    local function stepDoor(current, open, rate, powered)
        current = math.max(0, math.min(1, current))
        if not powered then return current end
        local target = open and 1 or 0
        local maximum = rate * update_time_step
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
        (master_arm_state == 1 and mainPower and 1 or 0))

    -- Weapon release is a request distinct from an actual launch or clearance.
    local chosenBayReady = (selected == 1 and left_door_pos >= 0.98) or
        (selected == 2 and bay_door_pos >= 0.98) or
        (selected == 3 and right_door_pos >= 0.98) or
        (selected == 4 and bay_door_pos >= 0.98
            and left_door_pos >= 0.98 and right_door_pos >= 0.98)
    local canCommandNativePickle = mainPower and not groundContact
        and master_arm_state == 1 and weapon_release_state == 1
        and chosenBayReady and selected_station>=0 and mode_state ~= 5 and mode_state ~= 1
    -- IR launch belongs to the typed seeker that actually acquired the target.
    -- The generic device otherwise launches its separate, empty seeker record.
    get_param_handle('F22_IR_RELEASE_REQUEST'):set(canCommandNativePickle and mode_state==3 and 1 or 0)
    local mrm_supported=get_param_handle('RADAR_PWR'):get()>.5 and
        get_param_handle('F22_RADAR_BACKEND_READY'):get()>.5 and
        get_param_handle('F22_RADAR_WEAPON_TARGET_ID'):get()>0 and
        get_param_handle('F22_TWS_GUIDANCE_BACKEND_READY'):get()>.5
    get_param_handle('F22_MRM_RELEASE_INHIBIT'):set(mode_state==2 and not mrm_supported and 1 or 0)
    canCommandNativePickle=canCommandNativePickle and mode_state~=3 and (mode_state~=2 or mrm_supported)
    if canCommandNativePickle ~= native_pickle_active then
            native_command(canCommandNativePickle and PickleON or PickleOFF)
        native_pickle_active = canCommandNativePickle
    end

    -- Gun door has its own hydraulic actuation path, documented by USAF.
    local cannon_request = mode_state == 5 and mainPower
        and not groundContact and master_arm_state == 1
        and (first_state == 1 or fire_z_weapons == 1)
    local canon_door_pos = stepDoor(get_aircraft_draw_argument_value(614),
        cannon_request, 4.5, mainPower)
    set_aircraft_draw_argument_value(614, canon_door_pos)
    local canon_rotate = get_aircraft_draw_argument_value(615)
    if cannon_request then
        canon_rotate = (canon_rotate + update_time_step * 2) % 1
    else
        canon_rotate = 0
    end
    set_aircraft_draw_argument_value(615, canon_rotate)

		--CANON FIRE
        -- Emit a trigger command only on an actual state transition.
        -- This also guarantees a release when power/ground/arm interlocks change.
        local can_fire_gun = (native_ready and mode_state == 5 and master_arm_state == 1
            and parameters.MAIN_POWER:get() == 1 and parameters.WoW:get() < 0.5
            and canon_door_pos >= 0.8)
        local gun_requested = (fire_z_weapons == 1 and can_fire_gun)
        if gun_requested ~= gun_command_active then
            native_command(gun_requested and PlaneFire or PlaneFireOff)
            gun_command_active = gun_requested
        end
        parameters.HUD_GUN_READY:set(can_fire_gun and 1 or 0)
        parameters.HUD_GUN_TRIGGER:set(gun_command_active and 1 or 0)

	parameters.BAY_C_ARG:set(bay_door_pos)
	parameters.BAY_L_ARG:set(left_door_pos)
	parameters.BAY_R_ARG:set(right_door_pos)
	parameters.MASTER_ARM:set(master_arm_state)
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
