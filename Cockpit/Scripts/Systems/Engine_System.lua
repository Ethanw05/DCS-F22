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

local dt = 0.024
make_default_activity(dt)

local sensor_data		= get_base_data()

local APU   			= get_param_handle("APU")
local APU_POWER			= get_param_handle ("APU_POWER")
local BATTERY_POWER		= get_param_handle ("BATTERY_POWER")
local L_GEN_POWER		= get_param_handle ("L_GEN_POWER")
local R_GEN_POWER		= get_param_handle ("R_GEN_POWER")
local MAIN_POWER		= get_param_handle ("MAIN_POWER")
local GROUND_POWER		= get_param_handle("GROUND_POWER")
local SOUND_APU     	= get_param_handle("SOUND_APU")
local APU_RPM_STATE		= get_param_handle("APU_RPM_STATE")
local UFD_ADI	        = get_param_handle ("UFD_ADI")
local L_TOE	        	= get_param_handle ("L_TOE")
local R_TOE	        	= get_param_handle ("R_TOE")
local B_TOE	        	= get_param_handle ("B_TOE")
local L_THROTTLE_CUT 	= get_param_handle ("L_THROTTLE_CUT")
local L_THROTTLE_POS 	= get_param_handle ("L_THROTTLE_POS")
local R_THROTTLE_CUT 	= get_param_handle ("R_THROTTLE_CUT")
local R_THROTTLE_POS 	= get_param_handle ("R_THROTTLE_POS")
local APU_READY			= get_param_handle("APU_READY")
local ufd_swap_adi 		= 0
local PARK			    = get_param_handle("PARK")
local IAS				= get_param_handle("IAS")
local PowerOnOff      	= Keys.PowerOnOff
local EnginesStart 		= Keys.EnginesStart
local EnginesStop 		= Keys.EnginesStop
local L_Eng_Start 		= Keys.LeftEngineStart
local R_Eng_Start 		= Keys.RightEngineStart
local L_Eng_Stop 		= Keys.LeftEngineStop
local R_Eng_Stop 		= Keys.RightEngineStop
local PlaneGear			= Keys.PlaneGear

dev:listen_command(PowerOnOff)
dev:listen_command(EnginesStart)
dev:listen_command(EnginesStop)
dev:listen_command(L_Eng_Start)
dev:listen_command(R_Eng_Start)
dev:listen_command(L_Eng_Stop)
dev:listen_command(R_Eng_Stop)
dev:listen_command(PlaneGear)
dev:listen_command(2004)
dev:listen_command(2005)
dev:listen_command(2006)

dev:listen_event("GroundPowerOn")
dev:listen_event("GroundPowerOff")

local battery_state = 0 --track on off state
local apu_state 	= 0 --track if apu was set to start
local apu_pwr		= 0 --track if the apu has full power
local apu_rpm		= 0 --track apu spool up time
local L_gen_state 	= 0 --track on off state
local R_gen_state 	= 0 --track on off state
local L_gen_pwr 	= 0
local R_gen_pwr 	= 0
local main_pwr		= 0
local B_axis_value  = -1
local park_state    = 0 
local gpu_cart		= 0
local apu_played 	= false
local BrakesON  	= false
local BrakesOFF 	= true 
local L_throttle_pos = 1 --1=idle -1=full
local R_throttle_pos = 1
local L_cutoff		 = 0
local R_cutoff		 = 0

local apu_autooff = 0
local apu_autooff_timer = 0

local L_axis_value = -1
local R_axis_value = -1

--Clickable Data
local battery_switch = device_commands.Button_1 --track mouse clicks
dev:listen_command(battery_switch)
local apu_switch = device_commands.Button_2 --track mouse clicks
dev:listen_command(apu_switch)
local L_gen_switch = device_commands.Button_3 --track mouse clicks
dev:listen_command(L_gen_switch)
local R_gen_switch = device_commands.Button_4 --track mouse clicks
dev:listen_command(R_gen_switch)
local L_Eng_Click = device_commands.Button_9 --track mouse clicks
dev:listen_command(L_Eng_Click)
local R_Eng_Click = device_commands.Button_10 --track mouse clicks
dev:listen_command(R_Eng_Click)
local Gear_Click = device_commands.Button_11 --track mouse clicks
dev:listen_command(Gear_Click)
local PARK_BRAKE = device_commands.Button_12 --track mouse clicks
dev:listen_command(PARK_BRAKE)

dev:listen_command(74)--Brakes on
dev:listen_command(75)--Brakes off
dev:listen_command(10009)--BAT
dev:listen_command(10010)--BAT T
dev:listen_command(10011)--L GEN
dev:listen_command(10012)--L GEN T
dev:listen_command(10013)--R GEN
dev:listen_command(10014)--R GEN T
dev:listen_command(10019)--Park
dev:listen_command(10020)--Park

dev:listen_command(10023)--wheel brake axis both
dev:listen_command(10025)--APU TOGGLE
dev:listen_command(10028)--L Cutoff
dev:listen_command(10029)--R cutoff

dev:listen_command(1073)--f-16 thing
dev:listen_command(10038)--Brakes On
dev:listen_command(10039)--Brakes Off

dev:listen_command(10056)--L Brake
dev:listen_command(10057)--R Brake
dev:listen_command(10058)--B Brake

function createExternal(sound_host, sdef_name)
	return sound_host:create_sound("Aircrafts/F-22A/External/" .. sdef_name)
end
function playSoundOnce(sound)
	if sound then
		if sound:is_playing() then 
			sound:stop() 
		end		
		sound:play_once()
	end	
end
function stopSound(sound)	
	if sound and sound:is_playing() then
		sound:stop()		
	end	
end
function createExternalLoop(sound_host, start_sound_length, sdef_name_start, sdef_name_loop, sdef_name_end)
	start_length_ = start_sound_length or 0
	
	if sdef_name_start then
		sound_start_ = createExternal(sound_host, sdef_name_start)
	else
		sound_start_ = nil
	end
	
	sound_loop_ = createExternal(sound_host, sdef_name_loop)
	
	if sdef_name_end then
		sound_end_ = createExternal(sound_host, sdef_name_end)
	else
		sound_end_ = nil
	end	
	
	return {
		startLength = start_length_,
		timePlaying = 0,
		isPlaying = false,
		sound_start = sound_start_,
		sound_loop = sound_loop_,
		sound_end = sound_end_,
	}
end    

function post_initialize()

	local birth = LockOn_Options.init_conditions.birth_place
	
	if birth == "GROUND_HOT" or birth == "AIR_HOT" then
		L_cutoff = 1
		R_cutoff = 1
		dispatch_action(nil,PowerOnOff)
		dev:performClickableAction(battery_switch, 1, false)--set battery switch ON
		dev:performClickableAction(L_gen_switch, 1, false)--set L Gen switch ON
		dev:performClickableAction(R_gen_switch, 1, false)--set R Gen switch ON
		dev:performClickableAction(apu_switch, -1, false)--set apu switch OFF
		set_aircraft_draw_argument_value(616, 0)--GPU CART ON/OFF
		set_aircraft_draw_argument_value(617, -1)--GPU CART START LOCATION
		--print_message_to_user("HOT START")
		--dispatch_action(nil,1073)
	elseif birth =="GROUND_COLD" then
		dev:performClickableAction(apu_switch, -1, false)--set apu switch OFF
		--dev:performClickableAction(PARK_BRAKE, 1, false)--set parking brakes ON
		set_aircraft_draw_argument_value(610, 1)--set open
		set_aircraft_draw_argument_value(611, 1)--set open
		--set_aircraft_draw_argument_value(15, -0.5)--set down
		--set_aircraft_draw_argument_value(16, -0.5)--set down
		--set_aircraft_draw_argument_value(600, 1)--set open
		--set_aircraft_draw_argument_value(601, 1)--set open
		--set_aircraft_draw_argument_value(602, 1)--set open
		set_aircraft_draw_argument_value(616, 0)--GPU CART ON/OFF
		set_aircraft_draw_argument_value(617, -1)--GPU CART START LOCATION
		--print_message_to_user("COLD START")
	end
	
	sound 			= create_sound_host("EXTERNAL_AIRCRAFT","3D",0,0,0)
	sound_apu    	= createExternalLoop(sound, 14, "apu_start","apu_run","apu_stop")

	SOUND_APU:set(-999)
end

----------------------------------------------------------------------FUNCTION-COCKPIT-EVENT---------------------------------------------------------------------------------------------------
function CockpitEvent(event,val)
	if event == "GroundPowerOff" then
		GROUND_POWER:set(0)
		--gpu_cart = 0
	elseif event == "GroundPowerOn" then
		GROUND_POWER:set(1)
		--gpu_cart = 1
	end
end
-----------------------------------------------------------------FUNCTION-SETCOMMAND---------------------------------------------------------------------------------------------------
	function SetCommand(command,value)

--Axis Wheel Brakes 
	if command == 10056 then -- brake axis left
		L_axis_value = value
	--RIGHT Axis Wheel Brakes 
	elseif command == 10057 then -- brake axis RIGHT
		R_axis_value = value
	--BOTH Axis Wheel Brakes
	elseif command == 10058 then -- brake axis both
		L_axis_value = value
		R_axis_value = value
	end
	--Keybaord Brakes BOTH
	if command == 10038 and (BrakesON == false or BrakesOFF == true) then
		BrakesON = true
		BrakesOFF = false
		L_axis_value = 1
		R_axis_value = 1
		--dispatch_action(nil, 10023, -0.30)--Brakes on
		--print_message_to_user("Brakes ON")
	elseif command == 10039 and (BrakesON == true or BrakesOFF == false) then
		BrakesON = false
		BrakesOFF = true
		L_axis_value = -1
		R_axis_value = -1
		--dispatch_action(nil, 10023, 1)--Brakes off
		--print_message_to_user("Brakes OFF")
	end
--Parking Brakes
		if (command == PARK_BRAKE or command == 10019 or command == 10020) and park_state == 0 then
		    park_state = 1
		elseif (command == PARK_BRAKE or command == 10019 or command == 10020) and park_state == 1 then
		    park_state = 0
		    --dispatch_action(nil,75)
		end
	local apu_switch_pos = get_cockpit_draw_argument_value(701)
--Disable Engines Start Keyboard Command on Ground	
		if command == EnginesStart and apu_pwr == 0 and sensor_data.getWOW_NoseLandingGear() == 1 and sensor_data.getEngineLeftRPM() < 3 and sensor_data.getEngineRightRPM() < 3 then
			dispatch_action(nil,EnginesStop)
			print_message_to_user("**COMMAND DISABLED ON GROUND||MUST USE APU TO COLD START THE JET**")
		end
--Disable Left Engine Keyboard Command on Ground	
		if (command == L_Eng_Start or command == L_Eng_Click) and apu_pwr == 0 and sensor_data.getWOW_NoseLandingGear() == 1 and sensor_data.getEngineLeftRPM() < 3 then
			dispatch_action(nil,L_Eng_Stop)
			print_message_to_user("**COMMAND DISABLED ON GROUND||MUST USE APU TO COLD START THE JET**")
		end
--Disable Right Engine Keyboard Command on Ground	
		if (command == R_Eng_Start or command == R_Eng_Click) and apu_pwr == 0 and sensor_data.getWOW_NoseLandingGear() == 1 and sensor_data.getEngineRightRPM() < 3 then
			dispatch_action(nil,R_Eng_Stop)
			print_message_to_user("**COMMAND DISABLED ON GROUND||MUST USE APU TO COLD START THE JET**")
		end	
--Battery Switch Click
		if (command == battery_switch or command == 10009 or command == 10010) and battery_state == 0 then
			battery_state = 1
			dispatch_action(nil, PowerOnOff)
			--print_message_to_user("BAT ON")
		elseif (command == battery_switch or command == 10009 or command == 10010) and battery_state == 1 then
			battery_state = 0
			dispatch_action(nil, PowerOnOff)
			--print_message_to_user("BAT OFF")
		end
--Left Gen Switch
		if (command == L_gen_switch or command == 10011 or command == 10012) and L_gen_state == 0 then
			L_gen_state = 1
			--ufd_swap_adi = 1
			--print_message_to_user("LEFT GEN ON")
		elseif (command == L_gen_switch or command == 10011 or command == 10012) and L_gen_state == 1 then
			L_gen_state = 0
			--ufd_swap_adi = 0
			--print_message_to_user("LEFT GEN OFF")
		end
--Right Gen Switch
		if (command == R_gen_switch or command == 10013 or command == 10014) and R_gen_state == 0 then
			R_gen_state = 1
			--print_message_to_user("RIGHT GEN ON")
		elseif (command == R_gen_switch or command == 10013 or command == 10014) and R_gen_state == 1 then
			R_gen_state = 0
			--print_message_to_user("RIGHT GEN OFF")
		end	
--Engine Start	Switch 
		if (command == L_Eng_Click or command == L_Eng_Start) and L_cutoff == 0 and apu_pwr == 0 then
			L_cutoff = 1
		elseif (command == R_Eng_Click or command == R_Eng_Start) and R_cutoff == 0 and apu_pwr == 0 then
			R_cutoff = 1
		elseif (command == L_Eng_Click or command == L_Eng_Start) and L_cutoff == 0 and apu_pwr == 1 then
			L_cutoff = 1
			dispatch_action(nil,L_Eng_Start)
		elseif (command == R_Eng_Click or command == R_Eng_Start) and R_cutoff == 0 and apu_pwr == 1 then
			R_cutoff = 1
			dispatch_action(nil,R_Eng_Start)
		elseif command == 10028 and L_cutoff == 0 and apu_pwr == 0 and sensor_data.getEngineLeftRPM() < 39 then
			L_cutoff = 1
			--print_message_to_user("LEFT ENG BYPASS ON")--WARTHOG DETENT
		elseif command == 10028 and L_cutoff == 0 and (apu_pwr == 1 or sensor_data.getEngineLeftRPM() > 40) then
			L_cutoff = 1
			dispatch_action(nil,L_Eng_Start)
			--print_message_to_user("LEFT ENG START WARTHORG")
		elseif command == 10028 and L_cutoff == 1 then
			L_cutoff = 0
			dispatch_action(nil,L_Eng_Stop)
			--print_message_to_user("LEFT ENG OFF WARTHOG")
		elseif command == L_Eng_Stop then
			L_cutoff = 0
			--print_message_to_user("LEFT ENG STOP")
		elseif command == 10029 and R_cutoff == 0 and apu_pwr == 0 and sensor_data.getEngineRightRPM() < 39 then
			R_cutoff = 1
			--print_message_to_user("RIGHT ENG BYPASS ON")--WARTHOG DETENT
		elseif command == 10029 and R_cutoff == 0 and (apu_pwr == 1 or sensor_data.getEngineRightRPM() > 40) then
			R_cutoff = 1
			dispatch_action(nil,R_Eng_Start)
			--print_message_to_user("RIGHT ENG START WARTHORG")
		elseif command == 10029 and R_cutoff == 1 then
			R_cutoff = 0
			dispatch_action(nil,R_Eng_Stop)
			--print_message_to_user("RIGHT ENG OFF WARTHOG")
		elseif command == R_Eng_Stop then
			R_cutoff = 0
			--print_message_to_user("RIGHT ENG STOP")
		elseif command == EnginesStart then
			L_cutoff = 1
			R_cutoff = 1
		elseif command == EnginesStop then
			L_cutoff = 0
			R_cutoff = 0
		end
--THROTTLE ANIMATION		
		if command == 2004 and L_cutoff == 1 and R_cutoff == 1 then --common
			L_throttle_pos = value
			R_throttle_pos = value
		elseif command == 2004 and L_cutoff == 0 and R_cutoff == 0 then --common
			L_throttle_pos = 1
			R_throttle_pos = 1
		elseif command == 2005 and L_cutoff == 1 then --Left
			L_throttle_pos = value
		elseif command == 2005 and L_cutoff == 0 then --Left
			L_throttle_pos = 1
		elseif command == 2006 and R_cutoff == 1 then --Right
			R_throttle_pos = value
		elseif command == 2006 and R_cutoff == 0 then --Right
			R_throttle_pos = 1
		end
--APU START/RUN/STOP	
		if command == apu_switch and battery_state == 1 and apu_state == 0 and apu_switch_pos == 1 then
			apu_state = 1
			-- print_message_to_user("APU START")
		elseif command == apu_switch and battery_state >= 0 and apu_state == 1 and apu_switch_pos == -1 then --made a change here bat state was == 1. grin
			apu_state = 0
			--print_message_to_user("APU SHUTDOWN")
		end
		if command == 10025 and battery_state == 1 and apu_state == 0 and apu_switch_pos < 1 then
			apu_state = 1
			dev:performClickableAction(apu_switch, 1, false)	
			--dev:performClickableAction(apu_switch, 0, false)
			--print_message_to_user("APU START")
		elseif command == 10025 and battery_state == 1 and apu_state == 1 and apu_switch_pos == 1 then
			dev:performClickableAction(apu_switch, 0, false)
			--print_message_to_user("else")		
		end
--Gear Handle Click
		if command == Gear_Click then
			dispatch_action(nil, PlaneGear)
			--print_message_to_user("GEAR UP DOWN")
		end
	end

	function stopLoopSound(loopSound, playEndSound)
		stopSound(loopSound.sound_start)
		stopSound(loopSound.sound_loop)
		loopSound.isPlaying = false
		loopSound.timePlaying = 0
		if playEndSound then
			playSoundOnce(loopSound.sound_end)
		end
	end
	function updateLoopSoundParameters(loopSound, pitch, gain, lowpass)
		updateSoundParameters(loopSound.sound_start, pitch, gain, lowpass)
		updateSoundParameters(loopSound.sound_loop, pitch, gain, lowpass)
		updateSoundParameters(loopSound.sound_end, pitch, gain, lowpass)
	end
	function playSoundOnceFromParam(param, sound)
		if param:get() > -999 then
			if sound then
				if sound:is_playing() then 
					sound:stop() 
				end
				if param:get() ~= 0 then
					sound:play_once()				
				end
			end
			param:set(-999)
		end
	end
	function playLoopingSound(loopSound)
		loopSound.sound_loop:play_continue()
	end
	function playLoopingSoundFromParam(param, loopSound)
		if param == nil then
			loopSound.sound_loop:play_continue()
			return
		end

		if param:get() > -999 then
			if loopSound then
				if param:get() == 0 and loopSound.isPlaying then
					--Stop command given
					stopLoopSound(loopSound, true)
				elseif param:get() ~= 0 then
					--Play command given
					if loopSound.isPlaying then
						-- first stop if playing
						stopLoopSound(loopSound)
					end

					if loopSound.sound_start then
						loopSound.sound_start:play_once()
					else
						loopSound.sound_loop:play_continue()
					end
					loopSound.isPlaying = true

				end
			end
			param:set(-999)
		else
	        --no sound command given, manage start/looping sound
			if loopSound.isPlaying then
				loopSound.timePlaying = loopSound.timePlaying + dt

				if loopSound.sound_start and loopSound.sound_start:is_playing() then
					if loopSound.timePlaying > (loopSound.startLength - dt) then					
						loopSound.sound_loop:play_continue()
					end
					if loopSound.timePlaying > loopSound.startLength then
						loopSound.sound_start:stop()
						loopSound.sound_loop:play_continue()
					end
				else
					loopSound.sound_loop:play_continue()
				end
			end
		end
	end
	local prev_L_throttle_val = -1
	local prev_R_throttle_val = -1
------------------------------------------------------------------FUNCTION-UPDATE---------------------------------------------------------------------------------------------------
function update()
	--print_message_to_user(L_throttle_pos)
	--print_message_to_user(R_throttle_pos)
	--print_message_to_user(B_throttle_pos)
	--print_message_to_user(GROUND_POWER:get())
	--print_message_to_user(APU_POWER:get())
	--print_message_to_user(sensor_data.getEngineLeftRPM())

	if L_cutoff == 0 then
		L_throttle_pos = 1
		--print_message_to_user("L ENG OVRIDE to 1")
	end

	if R_cutoff == 0 then
		R_throttle_pos = 1
		--print_message_to_user("L ENG OVRIDE to 1")
	end


--Brakes
	if B_axis_value > 0.1 or (L_axis_value > 0.1 or R_axis_value > 0.1) or park_state == 1 then   
		dispatch_action(nil,74)
		--print_message_to_user("brake")
	else
		dispatch_action(nil,75)
		--print_message_to_user("no brakes")
	end

	-- if L_axis_value > 0.1 then  
	-- 	dispatch_action(nil,74)
	-- 	print_message_to_user(L_axis_value)
	-- else
	-- 	dispatch_action(nil,75)
	-- end

	-- if R_axis_value > 0.1 then  
	-- 	dispatch_action(nil,74)
	-- 	print_message_to_user(R_axis_value)
	-- else
	-- 	dispatch_action(nil,75)
	-- end

	--Param
	APU_POWER		:set(apu_pwr)
	APU_RPM_STATE	:set(apu_rpm)
	BATTERY_POWER	:set(battery_state)
	MAIN_POWER		:set(main_pwr)
	UFD_ADI			:set(ufd_swap_adi)
	L_GEN_POWER		:set(L_gen_state)
	R_GEN_POWER		:set(R_gen_state)
	PARK		    :set(park_state)
	B_TOE			:set(B_axis_value)
	L_TOE			:set(L_axis_value)
	R_TOE			:set(R_axis_value)
	L_THROTTLE_CUT  :set(L_cutoff)
	L_THROTTLE_POS  :set(L_throttle_pos)
	R_THROTTLE_CUT  :set(R_cutoff)
	R_THROTTLE_POS  :set(R_throttle_pos)
	--GROUND_POWER	:set(gpu_cart)

	--print_message_to_user(B_axis_value)
	
	playLoopingSoundFromParam(SOUND_APU, sound_apu)
	
	local apu_switch_pos = get_cockpit_draw_argument_value(701)
	--APU SOUND START
	if apu_played == false and battery_state == 1 and apu_state == 1 and apu_switch_pos == 1 then
		SOUND_APU:set(5)
		apu_played = true
		--print_message_to_user("APU STARTING!!")
	end
	--APU RUN UP CLOCK	
	if battery_state == 1 and apu_state == 1 and apu_switch_pos == 0 and apu_rpm <= 3.99 then	
		apu_rpm = apu_rpm + 0.01
		--print_message_to_user("APU RUNNING!!")
	end
	--APU RUN DOWN CLOCK	
	if battery_state == 1 and apu_state == 0 and apu_switch_pos == -1 and apu_rpm >= 0.01 then	
		apu_rpm = apu_rpm - 0.01
		--print_message_to_user("APU RUNNING!!")
	end
	--APU HAS POWER	
	if battery_state == 1 and apu_state == 1 and apu_switch_pos == 0 and apu_rpm >= 3.80 then
		apu_pwr = 1	
		--print_message_to_user("APU HAS POWER")
	end
	--APU LOST POWER
	if battery_state == 1 and apu_state == 0 and apu_rpm < 1 then
		apu_pwr = 0
	end	
	--APU SOUND SHUTDOWN
	if apu_played == true and battery_state >= 0 and apu_state == 0 and apu_switch_pos == -1 then		
		SOUND_APU:set(0)
		apu_played = false
		--print_message_to_user("APU SHUTDOWN!!")
	end
	--GEN LEFT POWER ON OFF
	if L_gen_state == 1 and sensor_data.getEngineLeftRPM() >= 61 and L_gen_pwr == 0 then
		L_gen_pwr = 1
		--print_message_to_user("LEFT GEN HAS POWER")
	elseif L_gen_state == 1 and sensor_data.getEngineLeftRPM() <= 61 and L_gen_pwr == 1 then
		L_gen_pwr = 0
		--print_message_to_user("LEFT GEN OFF (NO RPM) ")
	elseif L_gen_state == 0 and sensor_data.getEngineLeftRPM() >= 61 and L_gen_pwr == 1 then
		L_gen_pwr = 0
		--print_message_to_user("LEFT GEN OFF (NO POWER) ")
	end
	--GEN RIGHT POWER ON OFF
	if R_gen_state == 1 and sensor_data.getEngineRightRPM() >= 61 and R_gen_pwr == 0 then
		R_gen_pwr = 1
		--print_message_to_user("RIGHT GEN HAS POWER")
	elseif R_gen_state == 1 and sensor_data.getEngineRightRPM() <= 61 and R_gen_pwr == 1 then
		R_gen_pwr = 0
		--print_message_to_user("RIGHT GEN OFF (NO RPM) ")
	elseif R_gen_state == 0 and sensor_data.getEngineRightRPM() >= 61 and R_gen_pwr == 1 then
		R_gen_pwr = 0
		--print_message_to_user("RIGHT GEN OFF (NO POWER) ")
	end
	--FULL POWER
	if L_gen_pwr == 1 or R_gen_pwr == 1 or GROUND_POWER:get() == 1 then
		main_pwr = 1
	else
		main_pwr = 0
	end
	--Update Connectors On moving Throttles	
	local L_THROTTLE = get_cockpit_draw_argument_value(768)
	if prev_L_throttle_val ~= L_THROTTLE then
        local L_throttle_clickable_ref = get_clickable_element_reference("LTHROT_PNT")
        L_throttle_clickable_ref:update() -- ensure the connector moves too
        prev_L_throttle_val = L_THROTTLE
    end
	local R_THROTTLE = get_cockpit_draw_argument_value(766)
	if prev_R_throttle_val ~= R_THROTTLE then
        local R_throttle_clickable_ref = get_clickable_element_reference("RTHRT_PNT")
        R_throttle_clickable_ref:update() -- ensure the connector moves too
        prev_R_throttle_val = R_THROTTLE
    end
	--CLAM SHELL COLD START
	-- Clam positon 1 = open 0 = closed
	--print_message_to_user(right_clam_pos)
	local right_clam_pos = get_aircraft_draw_argument_value(610)
	if (sensor_data.getEngineRightRPM()) <= 35 and right_clam_pos <= 1  then
		right_clam_pos = right_clam_pos + 0.005   
		set_aircraft_draw_argument_value(610, right_clam_pos)--set open
		-- print_message_to_user("plus")
	elseif (sensor_data.getEngineRightRPM()) >= 36 and right_clam_pos >= 0  then
		right_clam_pos = right_clam_pos - 0.005    
		set_aircraft_draw_argument_value(610,right_clam_pos)
		--print_message_to_user("minus")
	end
	local left_clam_pos = get_aircraft_draw_argument_value(611)
	if (sensor_data.getEngineLeftRPM()) <= 35 and left_clam_pos <= 1  then
		left_clam_pos = left_clam_pos + 0.005   
		set_aircraft_draw_argument_value(611, left_clam_pos)--set open
		--print_message_to_user("plus")
	elseif (sensor_data.getEngineLeftRPM()) >= 36 and left_clam_pos >= 0  then
		left_clam_pos = left_clam_pos - 0.005    
		set_aircraft_draw_argument_value(611, left_clam_pos)
		--print_message_to_user("minus")
	end
	--Ground Power Cart
	if GROUND_POWER:get() == 1 then
		gpu_cart = 1
		set_aircraft_draw_argument_value(616, 1)--GPU CART ON/OFF
		--set_aircraft_draw_argument_value(617, -1)--GPU CART START LOCATION
	elseif GROUND_POWER:get() == 0 then
		gpu_cart = 0
		set_aircraft_draw_argument_value(616, 0)--GPU CART ON/OFF
		set_aircraft_draw_argument_value(617, -1)--GPU CART START LOCATION
	end
--This did not work well, it can only animate on its way in...it is what it is...
	-- local left_throttle_pos  = get_cockpit_draw_argument_value(104)--Left Throttle
	-- local right_throttle_pos = get_cockpit_draw_argument_value(105)--Left Throttle
	-- if left_throttle_pos > 0.3 or right_throttle_pos > 0.3 then
	-- 	gpu_cart = 0
	-- 	set_aircraft_draw_argument_value(616, 0)--GPU CART ON/OFF
	-- 	set_aircraft_draw_argument_value(617, -1)--GPU CART START LOCATION
	-- 	print_message_to_user("HIDE GPU CART")
	-- end
	
	--Ground Power Animation	
	 local gpu_pos   = get_aircraft_draw_argument_value(617)
	if gpu_cart == 1 and gpu_pos < 1 then
		gpu_pos = gpu_pos + dt / 2
	 	set_aircraft_draw_argument_value(617, gpu_pos)
	elseif gpu_cart == 1 and gpu_pos == 1 then
	 	gpu_pos = 1
		set_aircraft_draw_argument_value(617, gpu_pos)
	elseif gpu_cart == 0 and gpu_pos > -1 then
		gpu_pos = gpu_pos - dt / 2
		 set_aircraft_draw_argument_value(617, gpu_pos)
	elseif gpu_cart == 0 and gpu_pos == -1 then
		set_aircraft_draw_argument_value(616, 0)
	end

	--Beacon Timer
	local beacon_rotate = get_aircraft_draw_argument_value(618)
	if beacon_rotate < 1 then
		beacon_rotate = (beacon_rotate + dt * 2)
		set_aircraft_draw_argument_value(618, beacon_rotate)
	elseif beacon_rotate > 1 then
		beacon_rotate = 0
		set_aircraft_draw_argument_value(618, beacon_rotate)
	end	

	--print_message_to_user(left_throttle_pos)

	--APU SHUTOFF
	if apu_state == 1 and apu_switch_pos == 0 and sensor_data.getEngineLeftRPM() >= 67 and sensor_data.getEngineRightRPM() >= 67 and apu_autooff == 0 then
		apu_autooff_timer = apu_autooff_timer + dt
		--print_message_to_user(apu_autooff_timer)
	elseif apu_state == 0 then
		apu_autooff = 0
		apu_autooff_timer = 0
	end
	--APU AUTO SHUTDOWN
	if apu_autooff_timer >= 60 and apu_switch_pos == 0 and (L_gen_state == 1 or R_gen_state == 1) then
		dev:performClickableAction(apu_switch, -1, false)--set apu switch OFF
	end


end
------------------------------------------------------------------FUNCTION-UPDATE-END-----------------------------------------------------------------------------------------------
function delay_time()
    if mTime > 0 then
        mTime = mTime + dt
        if mTime > 0.4 then
            mTime = 0
        end
    end
end

need_to_be_closed = false
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
getWOW_LeftMainLandingGear
getWOW_NoseLandingGear
getWOW_RightMainLandingGear
--]]
