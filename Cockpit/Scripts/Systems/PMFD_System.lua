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


dofile(LockOn_Options.script_path.."devices.lua")
dofile(LockOn_Options.script_path.."command_defs.lua")
local dev = GetSelf()
local sensor_data		= get_base_data()
local update_time_step = 0.006 --0.006
make_default_activity(update_time_step)
local parameters = {
    --PMFD_PAGE             = get_param_handle("PMFD_PAGE"),
    PMFD_MENU_PAGE          = get_param_handle("PMFD_MENU_PAGE"),
    PMFD_RDR_PAGE           = get_param_handle("PMFD_RDR_PAGE"),
    PMFD_MAP_PAGE           = get_param_handle("PMFD_MAP_PAGE"),
    PMFD_SYS_PAGE           = get_param_handle("PMFD_SYS_PAGE"),
    PMFD_SFM_PAGE           = get_param_handle("PMFD_SFM_PAGE"),
    PMFD_CONFIG_PAGE        = get_param_handle("PMFD_CONFIG_PAGE"),
    PMFD_BLANK_PAGE         = get_param_handle("PMFD_BLANK_PAGE"),
    PMFD_MASK               = get_param_handle("PMFD_MASK"),

    APU_POWER			    = get_param_handle("APU_POWER"),
    APU_RPM_STATE		    = get_param_handle("APU_RPM_STATE"),
    BATTERY_POWER		    = get_param_handle("BATTERY_POWER"),
    MAIN_POWER			    = get_param_handle("MAIN_POWER"),
    WoW			            = get_param_handle("WoW"),
    RADAR_MODE			    = get_param_handle("RADAR_MODE"),
    RADAR_PWR   			= get_param_handle("RADAR_PWR"),
    DOGFIGHT			    = get_param_handle("DOGFIGHT"),
    GARFIELD                = get_param_handle("GARFIELD"),
    TINT                    = get_param_handle("TINT"),
    FLOOD_COLOR             = get_param_handle("FLOOD_COLOR"),
    CLIPBOARD_L             = get_param_handle("CLIPBOARD_L"),
    CLIPBOARD_R             = get_param_handle("CLIPBOARD_R"),
    PHOTO                   = get_param_handle("PHOTO"),
    VISOR                   = get_param_handle("VISOR"),
    GARFIELD_PITCH          = get_param_handle("GARFIELD_PITCH"),
    GARFIELD_ROLL           = get_param_handle("GARFIELD_ROLL"),
    TAIL_PITCHRATE          = get_param_handle("TAIL_PITCHRATE"),
    TAIL_ROLLRATE           = get_param_handle("TAIL_ROLLRATE"),
    TAIL_GFORCE             = get_param_handle("TAIL_GFORCE"),
}
local clickable = {
    P_OSB_1            = device_commands.Button_1,
    P_OSB_2            = device_commands.Button_2,
    P_OSB_3            = device_commands.Button_3,
    P_OSB_4            = device_commands.Button_4,
    P_OSB_5            = device_commands.Button_5,
    P_OSB_6            = device_commands.Button_6,
    P_OSB_7            = device_commands.Button_7,
    P_OSB_8            = device_commands.Button_8,
    P_OSB_9            = device_commands.Button_9,
    P_OSB_10           = device_commands.Button_10,
    P_OSB_11           = device_commands.Button_11,
    P_OSB_12           = device_commands.Button_12,
    P_OSB_13           = device_commands.Button_13,
    P_OSB_14           = device_commands.Button_14,
    P_OSB_15           = device_commands.Button_15,
    P_OSB_16           = device_commands.Button_16,
    P_OSB_17           = device_commands.Button_17,
    P_OSB_18           = device_commands.Button_18,
    P_OSB_19           = device_commands.Button_19,
    P_OSB_20           = device_commands.Button_20,
}

local PlaneZoomIn           = 103 --range
local PlaneZoomOut          = 104 --range
local SelecterUp            = 141 --scan zone
local SelecterDown          = 142 --scan zone
local SelecterStop          = 230 --scan zone
local PlaneRadarOnOff       = 86  --Radar Power
local PlaneChangeRadarPRF	= 394 --radar pluse freq
local Radar_Mode            = 10011
local Radar_Power           = 10010
local PlaneRadarChangeMode  = 285 --RWS/TWS
local weight_on_wheels      = 1 -- 0 = air 1 = ground
local radar_mode_state      = 0 -- 0-RWS 1-TWS
local radar_state           = 0 -- 0-Off 1-On
local scan_up               = 0
local garfield              = 0
local tint                  = 0 -- 0 gold 0.5 black 1 clear
local pmfd_current_page     = 0   -- 0 = menu 1 = radar 2 = map 3 = sys 4 = config 5 = sfm
local flood_sel             = 0
local family                = 0
local board_L               = 0
local board_R               = 0
local visor_color           = 0

dev:listen_command(PlaneRadarOnOff)
dev:listen_command(Radar_Power)
dev:listen_command(Radar_Mode)
dev:listen_command(10005)
dev:listen_command(10054)
dev:listen_command(10055)

dev:listen_command(10131)--PMFD_OSB_01
dev:listen_command(10132)--PMFD_OSB_02
dev:listen_command(10133)--PMFD_OSB_03
dev:listen_command(10134)--PMFD_OSB_04
dev:listen_command(10135)--PMFD_OSB_05
dev:listen_command(10136)--PMFD_OSB_06
dev:listen_command(10137)--PMFD_OSB_07
dev:listen_command(10138)--PMFD_OSB_08
dev:listen_command(10139)--PMFD_OSB_09
dev:listen_command(10140)--PMFD_OSB_10
dev:listen_command(10141)--PMFD_OSB_11
dev:listen_command(10142)--PMFD_OSB_12
dev:listen_command(10143)--PMFD_OSB_13
dev:listen_command(10144)--PMFD_OSB_14
dev:listen_command(10145)--PMFD_OSB_15
dev:listen_command(10146)--PMFD_OSB_16
dev:listen_command(10147)--PMFD_OSB_17
dev:listen_command(10148)--PMFD_OSB_18
dev:listen_command(10149)--PMFD_OSB_19
dev:listen_command(10150)--PMFD_OSB_20

------------------------------------------------------------------FUNCTION-POST-INIT---------------------------------------------------------------------------------------------------
function post_initialize()	
    --print_message_to_user("PMFD POST INIT")
    local birth_place = LockOn_Options.init_conditions.birth_place

	if birth_place == "GROUND_COLD" then
        pmfd_current_page = 0
	elseif birth_place == "GROUND_HOT" or birth_place == "AIR_HOT" then
        pmfd_current_page = 1
    end
end
------------------------------------------------------------------FUNCTION-SETCOMMAND---------------------------------------------------------------------------------------------------
function SetCommand(command,value)
------------------------------------------PRIMARY MFD PAGE LOGIC---------------------------------------------------------------------------------------------------
    -- 0 = menu 1 = radar 2 = map 3 = sys 4 = config 5 = sfm
    --Dogfight ORIDE
        if command == 10005 and parameters.MAIN_POWER:get() == 1 then
            pmfd_current_page = 1
        end
    --Clipboards
    if command == 10054 and board_L == 0 then
        board_L = 1
    elseif command == 10054 and board_L == 1 then
        board_L = 0
    elseif command == 10055 and board_R == 0 then
        board_R = 1
    elseif command == 10055 and board_R == 1 then
        board_R = 0
    
    end   
        ------------------------------------------CONFIG-PAGE-LOGIC--------------------------------------------------------------------------------------------------
    --Garfield / Canopy Swap
    if (command == clickable.P_OSB_16 or command == 10146) and garfield == 0 and pmfd_current_page == 4 and parameters.MAIN_POWER:get() == 1 and parameters.WoW:get() == 1 then
        garfield = 1
        set_aircraft_draw_argument_value(620, garfield)
        --print_message_to_user("Garfield ON")
    elseif (command == clickable.P_OSB_16 or command == 10146) and garfield == 1 and pmfd_current_page == 4 and parameters.MAIN_POWER:get() == 1 and parameters.WoW:get() == 1 then
        garfield = 0
        set_aircraft_draw_argument_value(620, garfield)
        --print_message_to_user("Garfield OFF")
    elseif (command == clickable.P_OSB_20 or command == 10150) and tint == 0 and pmfd_current_page == 4 and parameters.MAIN_POWER:get() == 1 and parameters.WoW:get() == 1 then
        tint = 0.5
        set_aircraft_draw_argument_value(619, tint)
        --print_message_to_user("TINT BLACK")
    elseif (command == clickable.P_OSB_20 or command == 10150) and tint == 0.5 and pmfd_current_page == 4 and parameters.MAIN_POWER:get() == 1 and parameters.WoW:get() == 1 then
        tint = 1
        set_aircraft_draw_argument_value(619, tint)
        --print_message_to_user("TINT CLEAR")
    elseif (command == clickable.P_OSB_20 or command == 10150) and tint == 1 and pmfd_current_page == 4 and parameters.MAIN_POWER:get() == 1 and parameters.WoW:get() == 1 then
        tint = 0
        set_aircraft_draw_argument_value(619, tint)
        --print_message_to_user("TINT GOLD")
    elseif (command == clickable.P_OSB_18 or command == 10148) and flood_sel == 0 and pmfd_current_page == 4 and parameters.MAIN_POWER:get() == 1 and parameters.WoW:get() == 1 then
        flood_sel = 0.2
        --print_message_to_user("FLOOD COLOR BLUE")
    elseif (command == clickable.P_OSB_18 or command == 10148) and flood_sel == 0.2 and pmfd_current_page == 4 and parameters.MAIN_POWER:get() == 1 and parameters.WoW:get() == 1 then
        flood_sel = 0.4
        --print_message_to_user("FLOOD COLOR RED")  
    elseif (command == clickable.P_OSB_18 or command == 10148) and flood_sel == 0.4 and pmfd_current_page == 4 and parameters.MAIN_POWER:get() == 1 and parameters.WoW:get() == 1 then
        flood_sel = 0.6
        --print_message_to_user("FLOOD COLOR WHITE")
    elseif (command == clickable.P_OSB_18 or command == 10148) and flood_sel == 0.6 and pmfd_current_page == 4 and parameters.MAIN_POWER:get() == 1 and parameters.WoW:get() == 1 then
        flood_sel = 0
        --print_message_to_user("FLOOD COLOR GREEN")  
    elseif (command == clickable.P_OSB_17 or command == 10147) and family == 0 and pmfd_current_page == 4 and parameters.MAIN_POWER:get() == 1 and parameters.WoW:get() == 1 then
        family = 1
        --print_message_to_user("FAMILY PHOTO ON")
    elseif (command == clickable.P_OSB_17 or command == 10147) and family == 1 and pmfd_current_page == 4 and parameters.MAIN_POWER:get() == 1 and parameters.WoW:get() == 1 then
        family = 0
        --print_message_to_user("FAMILY PHOTO OFF")    
    elseif (command == clickable.P_OSB_19 or command == 10149) and visor_color == 0 and pmfd_current_page == 4 and parameters.MAIN_POWER:get() == 1 and parameters.WoW:get() == 1 then
        visor_color = 0.1
        set_aircraft_draw_argument_value(621, visor_color)
        --print_message_to_user("VISOR GOLD")
    elseif (command == clickable.P_OSB_19 or command == 10149) and visor_color == 0.1 and pmfd_current_page == 4 and parameters.MAIN_POWER:get() == 1 and parameters.WoW:get() == 1 then
        visor_color = 0.2
        set_aircraft_draw_argument_value(621, visor_color)
        --print_message_to_user("VISOR TINTED")  
    elseif (command == clickable.P_OSB_19 or command == 10149) and visor_color == 0.2 and pmfd_current_page == 4 and parameters.MAIN_POWER:get() == 1 and parameters.WoW:get() == 1 then
        visor_color = 0.3
        set_aircraft_draw_argument_value(621, visor_color)
        --print_message_to_user("VISOR CLEAR")
    elseif (command == clickable.P_OSB_19 or command == 10149) and visor_color == 0.3 and pmfd_current_page == 4 and parameters.MAIN_POWER:get() == 1 and parameters.WoW:get() == 1 then
        visor_color = 0.4
        set_aircraft_draw_argument_value(621, visor_color)
        --print_message_to_user("AVIATORS") 
    elseif (command == clickable.P_OSB_19 or command == 10149) and visor_color == 0.4 and pmfd_current_page == 4 and parameters.MAIN_POWER:get() == 1 and parameters.WoW:get() == 1 then
        visor_color = 0
        set_aircraft_draw_argument_value(621, visor_color)
        --print_message_to_user("VISOR MIRROR")      
    end
    -------------------------------------------PAGE-LOGIC--------------------------------------------------------------------------------------------------
    if (command == clickable.P_OSB_13 or command == 10143) and pmfd_current_page == 0 and parameters.MAIN_POWER:get() == 1 then     --MENU PAGE go RADAR
        pmfd_current_page = 1
    elseif (command == clickable.P_OSB_14 or command == 10144) and pmfd_current_page == 0 and parameters.MAIN_POWER:get() == 1 then --MENU PAGE go to MAP
        pmfd_current_page = 2
    elseif (command == clickable.P_OSB_12 or command == 10142) and pmfd_current_page == 0 and parameters.MAIN_POWER:get() == 1 then --MENU PAGE go to SYS
        pmfd_current_page = 3
    elseif (command == clickable.P_OSB_16 or command == 10146) and pmfd_current_page == 0 and parameters.MAIN_POWER:get() == 1 then --MENU PAGE go to CONFIG
        pmfd_current_page = 4
    elseif (command == clickable.P_OSB_11 or command == 10141) and pmfd_current_page == 0 and parameters.MAIN_POWER:get() == 1 then --MENU PAGE go to SFM
        pmfd_current_page = 5
    elseif (command == clickable.P_OSB_13 or command == 10143) and pmfd_current_page == 1 and parameters.MAIN_POWER:get() == 1 then --RADAR PAGE go to MENU
        pmfd_current_page = 0
    elseif (command == clickable.P_OSB_15 or command == 10145) and pmfd_current_page == 2 and parameters.MAIN_POWER:get() == 1 then --MAP PAGE go to MENU
        pmfd_current_page = 0
    elseif (command == clickable.P_OSB_15 or command == 10145) and pmfd_current_page == 3 and parameters.MAIN_POWER:get() == 1 then --SYS PAGE go to MENU
        pmfd_current_page = 0
    elseif (command == clickable.P_OSB_15 or command == 10145) and pmfd_current_page == 4 and parameters.MAIN_POWER:get() == 1 then --CONFIG PAGE go to MENU
        pmfd_current_page = 0
    elseif (command == clickable.P_OSB_15 or command == 10145) and pmfd_current_page == 5 and parameters.MAIN_POWER:get() == 1 then --SFM PAGE go to MENU
        pmfd_current_page = 0
    end
    ------------------------------------------RADAR-PAGE-LOGIC---------------------------------------------------------------------------------------------------
    --RADAR ON-OFF
    if (command == clickable.P_OSB_11 or command == 10141) and radar_state == 0 and pmfd_current_page == 1 and parameters.WoW:get() == 0 and parameters.MAIN_POWER:get() == 1 then --Radar Page
        dispatch_action(nil,PlaneRadarOnOff)
        radar_state = 1
    elseif (command == clickable.P_OSB_11 or command == 10141) and radar_state == 1 and pmfd_current_page == 1 and parameters.WoW:get() == 0 and parameters.MAIN_POWER:get() == 1 then --Radar Page
        radar_state = 0
        dispatch_action(nil,PlaneRadarOnOff)
    end
    --RWS-TWS
    if (command == clickable.P_OSB_15 or command == 10145) and radar_mode_state == 0 and pmfd_current_page == 1 and parameters.WoW:get() == 0 and parameters.MAIN_POWER:get() == 1 then --Radar Page
        radar_mode_state = 1
        dispatch_action(nil,PlaneRadarChangeMode)
    elseif (command == clickable.P_OSB_15 or command == 10145) and radar_mode_state == 1 and pmfd_current_page == 1 and parameters.WoW:get() == 0 and parameters.MAIN_POWER:get() == 1 then --Radar Page
        radar_mode_state = 0
        dispatch_action(nil,PlaneRadarChangeMode)
    end 
    --RADAR ZOOM IN-OUT
    if (command == clickable.P_OSB_6 or command == 10136) and pmfd_current_page == 1 and parameters.WoW:get() == 0 and parameters.MAIN_POWER:get() == 1 then
        dispatch_action(nil,PlaneZoomOut)
    end
    if (command == clickable.P_OSB_7 or command == 10137) and pmfd_current_page == 1 and parameters.WoW:get() == 0 and parameters.MAIN_POWER:get() == 1 then    
        dispatch_action(nil,PlaneZoomIn)
    end
    --RADAR PULSE FREQ
    if (command == clickable.P_OSB_14 or command == 10144) and pmfd_current_page == 1 and parameters.WoW:get() == 0 and parameters.MAIN_POWER:get() == 1 then
        dispatch_action(nil,PlaneChangeRadarPRF) 
    end

--END Radar Page

    -- if command == 10149 and p_19 == 0 then
    --     p_19 = 1
    -- elseif command == 10149 and p_19 == 1 then
    --     p_19 = 0
    -- elseif command == 10150 and p_20 == 0 then
    --     p_20 = 1
    -- elseif command == 10150 and p_20 == 1 then
    --     p_20 = 0
    -- end

end
------------------------------------------------------------------FUNCTION-UPDATE---------------------------------------------------------------------------------------------------
function update()
    --print_message_to_user(sensor_data.getHorizontalAcceleration())

    parameters.GARFIELD:set(garfield)
    parameters.TINT:set(tint)
    parameters.FLOOD_COLOR:set(flood_sel)
    parameters.PHOTO:set(family)
    parameters.CLIPBOARD_L:set(board_L)
    parameters.CLIPBOARD_R:set(board_R)
    parameters.VISOR:set(visor_color)

    parameters.TAIL_GFORCE      :set(sensor_data.getVerticalAcceleration())
    parameters.TAIL_ROLLRATE    :set(sensor_data.getRateOfRoll()/math.pi*180*0.01)-- Testing
    parameters.TAIL_PITCHRATE   :set(sensor_data.getHorizontalAcceleration() / -1.5)-- Testing
--TAIL LOGIC
    --print_message_to_user(parameters.TAIL_ROLLRATE:get())

    local garfield_roll  = parameters.TAIL_ROLLRATE:get()
    local garfield_pitch = parameters.TAIL_PITCHRATE :get()
--Roll Logic
    if parameters.TAIL_GFORCE:get() < 0 then
        garfield_roll = garfield_roll + parameters.TAIL_GFORCE:get()
        --print_message_to_user("G CONTROL")
    elseif parameters.TAIL_GFORCE:get() < 0 and parameters.TAIL_ROLLRATE:get() > -1 then
        garfield_roll  = garfield_roll + parameters.TAIL_GFORCE:get()
        --print_message_to_user("FIX TO FUCKUP???")
    elseif parameters.TAIL_GFORCE:get() >= 0 then
        garfield_roll  = garfield_roll
        --print_message_to_user("ROLL CONTROL")
    end
--Pitch Logic
    parameters.GARFIELD_PITCH   :set(garfield_pitch)
    parameters.GARFIELD_ROLL    :set(garfield_roll)
    --print_message_to_user(garfield_roll)

--WoW Logic
    if sensor_data.getWOW_NoseLandingGear() == 0 and sensor_data.getWOW_RightMainLandingGear() == 0 and sensor_data.getWOW_LeftMainLandingGear() == 0 then
        weight_on_wheels = 0 -- in air
    else
        weight_on_wheels = 1
    end
--END WoW
--Radar Scan Zone Logic    
    local osb_19 = get_cockpit_draw_argument_value(839)
    local osb_20 = get_cockpit_draw_argument_value(840)
    if (osb_20 == 1 or SelectorUP == 1) and pmfd_current_page == 1 and parameters.WoW:get() == 0 and parameters.MAIN_POWER:get() == 1 then
        dispatch_action(nil,SelecterUp)
    elseif osb_19 == 1 and pmfd_current_page == 1 and parameters.WoW:get() == 0 and parameters.MAIN_POWER:get() == 1 then
        dispatch_action(nil,SelecterDown)
    else
        dispatch_action(nil,SelecterStop)
    end
--END Scan Logic
--PMFD PAGE UPDATE 0 = menu 1 = radar 2 = map 3 = sys 4 = config 5 = sfm
    -- if pmfd_current_page >= 0 and parameters.MAIN_POWER:get() == 1 and parameters.DOGFIGHT:get() == 1 then --DOGFIGHT MODE
    --     pmfd_current_page = 1
    --     parameters.PMFD_RDR_PAGE:set(1)
    --     parameters.PMFD_MASK:set(1)
    --     parameters.PMFD_MENU_PAGE:set(0)
    --     parameters.PMFD_MAP_PAGE:set(0)
    --     parameters.PMFD_SFM_PAGE:set(0)
    --     parameters.PMFD_SYS_PAGE:set(0)
    --     parameters.PMFD_CONFIG_PAGE:set(0)
    -- if parameters.DOGFIGHT:get() == 1 and parameters.MAIN_POWER:get() == 1 then
    --     pmfd_current_page = 1
    --     parameters.PMFD_RDR_PAGE:set(1)
    --     parameters.PMFD_MASK:set(1)
    -- else
    --     pmfd_current_page = (pmfd_current_page)    
    -- end

    if parameters.APU_RPM_STATE:get() >= 2 and parameters.MAIN_POWER:get() == 0 then
		parameters.PMFD_BLANK_PAGE:set(1)      
	elseif parameters.APU_RPM_STATE:get() >= 2 and parameters.MAIN_POWER:get() == 1 then
		parameters.PMFD_BLANK_PAGE:set(0)   
	elseif parameters.MAIN_POWER:get() == 0 then
		parameters.PMFD_BLANK_PAGE:set(0)
	end

    if pmfd_current_page == 0 and parameters.MAIN_POWER:get() == 1 then --MENU --FIX THIS FUCKING SHIT
        parameters.PMFD_MENU_PAGE:set(1)
        parameters.PMFD_RDR_PAGE:set(0)
        parameters.PMFD_MASK:set(0)
        parameters.PMFD_MAP_PAGE:set(0)
        parameters.PMFD_SFM_PAGE:set(0)
        parameters.PMFD_SYS_PAGE:set(0)
        parameters.PMFD_CONFIG_PAGE:set(0)
    elseif pmfd_current_page == 1 and parameters.MAIN_POWER:get() == 1 then --RADAR
        parameters.PMFD_RDR_PAGE:set(1)
        parameters.PMFD_MASK:set(1)
        parameters.PMFD_MENU_PAGE:set(0)
        parameters.PMFD_MAP_PAGE:set(0)
        parameters.PMFD_SFM_PAGE:set(0)
        parameters.PMFD_SYS_PAGE:set(0)
        parameters.PMFD_CONFIG_PAGE:set(0)
    elseif pmfd_current_page == 2 and parameters.MAIN_POWER:get() == 1 then --MAP
        parameters.PMFD_MENU_PAGE:set(0)
        parameters.PMFD_RDR_PAGE:set(0)
        parameters.PMFD_MASK:set(0)
        parameters.PMFD_MAP_PAGE:set(1)
        parameters.PMFD_SFM_PAGE:set(0)
        parameters.PMFD_SYS_PAGE:set(0)
        parameters.PMFD_CONFIG_PAGE:set(0)
    elseif pmfd_current_page == 3 and parameters.MAIN_POWER:get() == 1 then --SYS
        parameters.PMFD_MENU_PAGE:set(0)
        parameters.PMFD_RDR_PAGE:set(0)
        parameters.PMFD_MASK:set(0)
        parameters.PMFD_MAP_PAGE:set(0)
        parameters.PMFD_SFM_PAGE:set(0)
        parameters.PMFD_SYS_PAGE:set(1)
        parameters.PMFD_CONFIG_PAGE:set(0)
    elseif pmfd_current_page == 4 and parameters.MAIN_POWER:get() == 1 then --CONFIG
        parameters.PMFD_MENU_PAGE:set(0)
        parameters.PMFD_RDR_PAGE:set(0)
        parameters.PMFD_MASK:set(0)
        parameters.PMFD_MAP_PAGE:set(0)
        parameters.PMFD_SFM_PAGE:set(0)
        parameters.PMFD_SYS_PAGE:set(0)
        parameters.PMFD_CONFIG_PAGE:set(1)
    elseif pmfd_current_page == 5 and parameters.MAIN_POWER:get() == 1 then --SFM
        parameters.PMFD_MENU_PAGE:set(0)
        parameters.PMFD_RDR_PAGE:set(0)
        parameters.PMFD_MASK:set(0)
        parameters.PMFD_MAP_PAGE:set(0)
        parameters.PMFD_SFM_PAGE:set(1)
        parameters.PMFD_SYS_PAGE:set(0)
        parameters.PMFD_CONFIG_PAGE:set(0)
    elseif pmfd_current_page >= 0 and parameters.APU_RPM_STATE:get() >= 2 and parameters.MAIN_POWER:get() == 0 then -- and parameters.DAY_NIGHT:get() == 1    
        parameters.PMFD_MENU_PAGE:set(0)
        parameters.PMFD_RDR_PAGE:set(0)
        parameters.PMFD_MASK:set(1)
        parameters.PMFD_MAP_PAGE:set(0)
        parameters.PMFD_SFM_PAGE:set(0)
        parameters.PMFD_SYS_PAGE:set(0)
        parameters.PMFD_CONFIG_PAGE:set(0)
    elseif parameters.MAIN_POWER:get() == 0 then
        parameters.PMFD_MASK:set(0)
    end
--END PMFD UPDATE

    parameters.WoW:set(weight_on_wheels)
    parameters.RADAR_MODE:set(radar_mode_state)
    parameters.RADAR_PWR:set(radar_state)
    --parameters.PMFD_PAGE:set(pmfd_current_page)

end

need_to_be_closed = false

--Ref
    -- parameters.TAS	        :set(sensor_data.getTrueAirSpeed() * 1.944)
	-- parameters.IAS	        :set(sensor_data.getIndicatedAirSpeed() * 1.944)
	-- parameters.GFORCE       :set(sensor_data.getVerticalAcceleration())
	-- parameters.ADI_PITCH    :set(sensor_data.getPitch() )
	-- parameters.ADI_ROLL     :set(sensor_data.getRoll() )
	-- parameters.YAW          :set(sensor_data.getRateOfYaw() )
	-- parameters.ROLLRATE     :set(sensor_data.getRateOfRoll()/math.pi*180)-- Testing
	-- parameters.NAV          :set(360 - sensor_data.getHeading()/math.pi*180) -- Working, don't change
	-- parameters.RADALT       :set(sensor_data.getRadarAltitude() ) -- Working, don't change
	-- parameters.BARO         :set(sensor_data.getBarometricAltitude() * 3.28084 ) -- Working, don't change	
	-- parameters.RPM_L        :set(sensor_data.getEngineLeftRPM())-- Needs to be tested (might not need to multiply by 2750 cause that was from fixed prop? maybe)
	-- parameters.RPM_R        :set(sensor_data.getEngineRightRPM())
	-- parameters.FUELL        :set(sensor_data.getTotalFuelWeight() * 0.01 ) -- Working, don't change: 0.36622 
	-- parameters.FUEL         :set(sensor_data.getTotalFuelWeight() * 2.20462 ) -- Working, don't change: 0.36622
	-- parameters.FUELT        :set(sensor_data.getTotalFuelWeight() * 2.20462 - 13454 ) -- Working, don't change: 0.36622 
	-- parameters.EGT_L        :set(sensor_data.getEngineLeftTemperatureBeforeTurbine())
    -- parameters.EGT_R        :set(sensor_data.getEngineRightTemperatureBeforeTurbine())
    
    --getAngleOfAttack
    --getAngleOfSlide
    --getBarometricAltitude
    --getEngineLeftFuelConsumption
    --getEngineLeftRPM
    --getEngineLeftTemperatureBeforeTurbine
    --getEngineRightFuelConsumption
    --getEngineRightRPM
    --getEngineRightTemperatureBeforeTurbine
    --getHorizontalAcceleration
    --getIndicatedAirSpeed
    --getLateralAcceleration

    --getMachNumber
    --getMagneticHeading
    --getNoseLandingGearDown
    --getNoseLandingGearUp
    --getPitch
    --getRadarAltitude
    --getRateOfPitch
    --getRateOfRoll
    --getRateOfYaw

    --getRoll
    --getRudderPosition
    --getSelfAirspeed
    --getSelfCoordinates
    --getSelfVelocity
   
    --getStickPitchPosition
    --getStickRollPosition
    --getThrottleLeftPosition
    --getThrottleRightPosition
    --getTotalFuelWeight
    --getTrueAirSpeed
    --getVerticalAcceleration
    --getVerticalVelocity

    --getWOW_LeftMainLandingGear
    --getWOW_NoseLandingGear
    --getWOW_RightMainLandingGear
