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
			ECM_ARG				= get_param_handle("ECM_ARG"),
			LMFD_PAGE           = get_param_handle("LMFD_PAGE"),
			BAY_STATION         = get_param_handle("BAY_STATION"),
			AIR_ORIDE			= get_param_handle("AIR_ORIDE"),
			MASTER_ARM			= get_param_handle("MASTER_ARM"),
			DOGFIGHT			= get_param_handle("DOGFIGHT"),
			HUD_MODE			= get_param_handle("HUD_MODE"),
            HUD_WEAPON = get_param_handle("HUD_WEAPON"),
            HUD_RADAR_REQUEST = get_param_handle("HUD_RADAR_REQUEST"),
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

local ActiveJamming						= Keys.ActiveJamming

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
dev:listen_command(ActiveJamming)
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
local ecm_state				= 0 --track E keybind press
local bay_air_state			= 0
local hotas_station			= 2
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
local prev_bay_selection = 2
------------------------------------------------------------------FUNCTION-POSTINIT---------------------------------------------------------------------------------------------------

function post_initialize()
	--print_message_to_user("WEAPON SYSTEM POST INIT")
	
	local bay_option_state = get_aircraft_property("BAY_DOOR_OPTION")--ME Option Box
	local birth = LockOn_Options.init_conditions.birth_place
	--print_message_to_user(bay_option_state)
	if birth == "GROUND_COLD" then
		parameters.BAY_OPTION:set(bay_option_state) -- Unchecked = 0 Checked = 1	
	elseif birth == "GROUND_HOT" or birth == "AIR_HOT" then
		parameters.BAY_OPTION:set(1)
		--dispatch_action(nil,Battery)
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
-- 	if command == 10021 and master_arm_state == 1 and first_state == 0 and parameters.MAIN_POWER:get() == 1 then
-- 		first_state = 1
-- 		--print_message_to_user("FIRST DETENT")
-- 	elseif command == 10021 and master_arm_state == 1 and first_state == 1 and parameters.MAIN_POWER:get() == 1 then
-- 		first_state = 0
-- 		--print_message_to_user("FIRST RELEASE")
-- 	elseif command == 10022 and master_arm_state == 1 and first_state == 1 and fire_z_weapons == 0 and parameters.MAIN_POWER:get() == 1 then
-- 		fire_z_weapons = 1
-- 		--print_message_to_user("FIRE Z WEAPONS!!!!")
-- 	elseif command == 10022 and master_arm_state == 1 and first_state == 1 and fire_z_weapons == 1 and parameters.MAIN_POWER:get() == 1 then
-- 		fire_z_weapons = 0
-- 		dispatch_action(nil,PlaneFireOff)
-- 		--print_message_to_user("STOP FIRE Z WEAPONS!!!!")
-- 	end

--First Trigger Detent
if command == 10021 and first_state == 0 and parameters.MAIN_POWER:get() == 1 then
	first_state = 1
	detent_pos = 0.50
	--print_message_to_user("FIRST DETENT")
elseif command == 10021 and first_state == 1 and parameters.MAIN_POWER:get() == 1 then
	first_state = 0
	detent_pos = 0
	--print_message_to_user("FIRST RELEASE")
end
--Second Trigger Detent
if command == 10022 and fire_z_weapons == 0 and parameters.MAIN_POWER:get() == 1 then
	fire_z_weapons = 1
	detent_pos = 1
	--first_state    = 1
	--print_message_to_user("FIRE Z WEAPONS!!!!")
elseif command == 10022 and fire_z_weapons == 1 and parameters.MAIN_POWER:get() == 1 then
	fire_z_weapons = 0
	detent_pos = 0.50
	--first_state    = 0
	dispatch_action(nil,PlaneFireOff)
	--print_message_to_user("STOP FIRE Z WEAPONS!!!!")
end	
--Mode States
	if command == PlaneModeNAV then
		mode_state = 1
        hud_radar_request = 0
	elseif command == PlaneModeBVR then
		mode_state = 2
        hud_radar_request = 1
	elseif command == PlaneModeVS then
		mode_state = 3
        hud_radar_request = 3
	elseif command == PlaneModeBore then
		mode_state = 4
        hud_radar_request = 4
	elseif command == PlaneModeFI0 then
        mode_state = 6
        hud_radar_request = 5
    elseif command == PlaneModeCannon then
        mode_state = 5
        hud_radar_request = 4
    elseif command == PlaneModeGround then
        mode_state = 7
        hud_radar_request = 0
    elseif command == PlaneRadarChangeMode and mode_state == 2 then
        -- Tracks requested radar presentation; no APG-77 feedback is available.
        -- The native FC3 radar receives the same key binding independently.
        hud_radar_request = hud_radar_request == 2 and 1 or 2
    elseif command == ChangeReleaseMode and mode_state == 7 then
        ag_submode = ag_submode % 3 + 1
    end					
--Master Arm JOYSTICK/KEYBOARD BINDS
	if (command == 10007 or command == 10008 or command == master_arm_switch) and master_arm_state == 0 then
		master_arm_state = 1
		--print_message_to_user("MASTER ARM ON")
	elseif (command == 10007 or command == 10008 or command == master_arm_switch) and master_arm_state == 1 then
		master_arm_state = 0
		--print_message_to_user("MASTER ARM OFF")
	end		
	-- --Bay Doors Open Close
	-- if command == PickleON and weapon_release_state == 0 then
	-- 	weapon_release_state = 1
	-- 	--print_message_to_user("COMMAND DEPRESS")
	-- elseif command == PickleOFF and weapon_release_state == 1 then
	-- 	weapon_release_state = 0
	-- 	--print_message_to_user("COMMAND RELEASE")
	-- end	
    -- User-operated pickle switch sets a request. DCS receives PickleON
    -- only after the selected weapon bay has finished opening.
    if command == 10026 then
        if weapon_release_state == 1 then
            weapon_release_state = 0
            pickle_pos = 0
        elseif master_arm_state == 1 and parameters.MAIN_POWER:get() == 1
                and parameters.WoW:get() < 0.5 then
            weapon_release_state = 1
            pickle_pos = 1
        else
            pickle_pos = 0
        end
    end

	--ecm_state JAMMER
	if command == ActiveJamming and ecm_state == 0 then
		ecm_state = 1
		--print_message_to_user("JAMMING")
	elseif command == ActiveJamming and ecm_state == 1 then
		ecm_state = 0
		--print_message_to_user("NOT JAMMING")
	end
	--Dogfight Mode
	-- if command == 10005 and dogfight_mode == 0 then
	-- 	dogfight_mode = 1
	-- 	print_message_to_user("DOGFIGHT MODE ON")
	-- elseif command == 10005 and dogfight_mode == 1 then
	-- 	dogfight_mode = 0
	-- 	print_message_to_user("DOGFIGHT MODE OFF")
	-- end	

end
------------------------------------------------------------------FUNCTION-UPDATE---------------------------------------------------------------------------------------------------
function update()
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
	-- print_message_to_user(parameters.WoW:get()) --0 no weight 1 weight on wheel
	-- print_message_to_user(canon_rotate)

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
        and (weapon_release_state == 1 or air_oride == 1)
    local openAll = groundOverride or (releaseRequest and selected == 4)
    local openMain = openAll or (releaseRequest and selected == 2)
    local openLeft = openAll or groundCrewLeft or (releaseRequest and selected == 1)
    local openRight = openAll or (releaseRequest and selected == 3)

    -- Normal actuator model [normalized travel/second]. True real rates
    -- depend on hydraulics and are not available in the public documents.
    local function stepDoor(current, open, rate)
        current = math.max(0, math.min(1, current))
        if not mainPower and not groundCrewLeft then return current end
        local target = open and 1 or 0
        local maximum = rate * update_time_step
        return math.max(0, math.min(1,
            current + math.max(-maximum, math.min(maximum, target-current))))
    end
    local bay_door_pos = stepDoor(get_aircraft_draw_argument_value(600),
        openMain, groundContact and 0.11 or 2.5)
    local left_door_pos = stepDoor(get_aircraft_draw_argument_value(601),
        openLeft, groundContact and (groundCrewLeft and 0.25 or 0.11) or 2.5)
    local right_door_pos = stepDoor(get_aircraft_draw_argument_value(602),
        openRight, groundContact and 0.11 or 2.5)
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
        and chosenBayReady and mode_state ~= 5 and mode_state ~= 1
    if canCommandNativePickle ~= native_pickle_active then
        dispatch_action(nil, canCommandNativePickle and PickleON or PickleOFF)
        native_pickle_active = canCommandNativePickle
    end

    -- Gun door has its own hydraulic actuation path, documented by USAF.
    local cannon_request = mode_state == 5 and mainPower
        and not groundContact and master_arm_state == 1
        and (first_state == 1 or fire_z_weapons == 1)
    local canon_door_pos = stepDoor(get_aircraft_draw_argument_value(614),
        cannon_request, 4.5)
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
        local can_fire_gun = (mode_state == 5 and master_arm_state == 1
            and parameters.MAIN_POWER:get() == 1 and parameters.WoW:get() < 0.5
            and canon_door_pos >= 0.8)
        local gun_requested = (fire_z_weapons == 1 and can_fire_gun)
        if gun_requested ~= gun_command_active then
            dispatch_action(nil, gun_requested and PlaneFire or PlaneFireOff)
            gun_command_active = gun_requested
        end
        parameters.HUD_GUN_READY:set(can_fire_gun and 1 or 0)
        parameters.HUD_GUN_TRIGGER:set(gun_command_active and 1 or 0)
		-- --Canon Timer
		-- if first_state == 1 and master_arm_state == 1 and parameters.MAIN_POWER:get() == 1 and canon_rotate < 1 then
		-- 	canon_rotate = (canon_rotate + update_time_step * 2)
		-- 	set_aircraft_draw_argument_value(615, canon_rotate)
		-- elseif first_state == 1 and master_arm_state == 1 and parameters.MAIN_POWER:get() == 1 and canon_rotate > 1 then
		-- 	canon_rotate = 0
		-- 	set_aircraft_draw_argument_value(615, canon_rotate)
		-- end
		
		--Missile
		-- if weapon_release_state == 1 and master_arm_state == 1 and parameters.MAIN_POWER:get() == 1 then
		-- 	dispatch_action(nil,PickleON)
		-- 	print_message_to_user("FIRE Z MISSILE")
		-- else
		-- 	dispatch_action(nil,PickleOFF)
		-- 	print_message_to_user("DONT FIRE Z MISSILE")
		-- end

-----------------------------------------------------------------------

	parameters.BAY_C_ARG:set(bay_door_pos)
	parameters.BAY_L_ARG:set(left_door_pos)
	parameters.BAY_R_ARG:set(right_door_pos)
	parameters.ECM_ARG:set(ecm_state)
	parameters.MASTER_ARM:set(master_arm_state)
	parameters.DOGFIGHT:set(dogfight_mode)
	parameters.AIR_ORIDE:set(air_oride)
	parameters.HUD_MODE:set(mode_state)
    parameters.HUD_RADAR_REQUEST:set(hud_radar_request)
    parameters.HUD_WEAPON:set(mode_state == 5 and 1 or
        ((mode_state == 3 or mode_state == 4 or mode_state == 6) and 2 or
        (mode_state == 2 and 3 or (mode_state == 7 and 4 or 0))))
    parameters.HUD_ARMED:set(master_arm_state)
    parameters.HUD_AG_SUBMODE:set(ag_submode)
	parameters.DETENT:set(detent_pos)
	parameters.PICKLE:set(pickle_pos)

end

--need_to_be_closed = false

----Ref
--[[
getAngleOfAttack
getAngleOfSlide
getBarometricAltitude
getCanopyPos
getCanopyState
getEngineLeftFuelConsumption
getEngineLeftRPM
getEngineLeftTemperatureBeforeTurbine
getEngineRightFuelConsumption
getEngineRightRPM
getEngineRightTemperatureBeforeTurbine
getFlapsPos
getFlapsRetracted
getHeading
getHelicopterCollective
getHelicopterCorrection
getHorizontalAcceleration
getIndicatedAirSpeed
getLandingGearHandlePos
getLateralAcceleration
getLeftMainLandingGearDown
getLeftMainLandingGearUp
getMachNumber
getMagneticHeading
getNoseLandingGearDown
getNoseLandingGearUp
getPitch
getRadarAltitude
getRateOfPitch
getRateOfRoll
getRateOfYaw
getRightMainLandingGearDown
getRightMainLandingGearUp
getRoll
getRudderPosition
getSpeedBrakePos
getStickPitchPosition
getStickRollPosition
getThrottleLeftPosition
getThrottleRightPosition
getTotalFuelWeight
getTrueAirSpeed
getVerticalAcceleration
getVerticalVelocity
getLeftMainLandingGearDown
getNoseLandingGearDown
getRightMainLandingGearDown
]]
