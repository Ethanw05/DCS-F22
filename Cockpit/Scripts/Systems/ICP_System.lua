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

    APU_POWER			    = get_param_handle("APU_POWER"),
    APU_RPM_STATE		    = get_param_handle("APU_RPM_STATE"),
    BATTERY_POWER		    = get_param_handle("BATTERY_POWER"),
    MAIN_POWER			    = get_param_handle("MAIN_POWER"),
    WoW			            = get_param_handle("WoW"),
    RADAR_MODE			    = get_param_handle("RADAR_MODE"),
    RADAR_PWR   			= get_param_handle("RADAR_PWR"),
    ICP_OPACITY             = get_param_handle("ICP_OPACITY"),
    ICP_HUD_MENU            = get_param_handle("ICP_HUD_MENU"),
    ICP_AP_MENU             = get_param_handle("ICP_AP_MENU"),

}

 local   COM1               = device_commands.Button_1
 local   COM2               = device_commands.Button_2
 local   NAV                = device_commands.Button_3
 local   STP                = device_commands.Button_4
 local   ALT                = device_commands.Button_5
 local   HUD                = device_commands.Button_6
 local   OTHR               = device_commands.Button_7
 local   OP1                = device_commands.Button_8
 local   OP2                = device_commands.Button_9
 local   OP3                = device_commands.Button_10
 local   OP4                = device_commands.Button_11
 local   OP5                = device_commands.Button_12
 local   UP                 = device_commands.Button_13
 local   DWN                = device_commands.Button_14
 local   AP                 = device_commands.Button_15
 local   MRK                = device_commands.Button_16
 local   N1                 = device_commands.Button_17
 local   N2                 = device_commands.Button_18
 local   N3                 = device_commands.Button_19
 local   N4                 = device_commands.Button_20
 local   N5                 = device_commands.Button_21
 local   N6                 = device_commands.Button_22
 local   N7                 = device_commands.Button_23
 local   N8                 = device_commands.Button_24
 local   N9                 = device_commands.Button_25
 local   CKE                = device_commands.Button_26
 local   N0                 = device_commands.Button_27
 local   UNDO               = device_commands.Button_28
 local   WHEELUP            = device_commands.Button_29
 local   WHEELDWN           = device_commands.Button_30
 local   KNEE_NEXT          = device_commands.Button_31
 local   KNEE_PREV          = device_commands.Button_32
-- dev:listen_command(COM1)
-- dev:listen_command(COM2)
-- dev:listen_command(NAV)

--REF
    --jettison
    --local PlaneJettisonWeapons 			= Keys.PlaneJettisonWeapons
    --local PlaneJettisonFuelTanks 			= Keys.PlaneJettisonFuelTanks
    --local PlaneWheelBrakeON 				= 74
    --local PlaneWheelBrakeOff 				= Keys.PlaneWheelBrakeOff
    --local PlaneFuelOn 					= Keys.PlaneFuelOn --fuel dump
--modes
local PlaneModeNAV 						= Keys.PlaneModeNAV	--1						
local PlaneModeBVR 						= Keys.PlaneModeBVR	--2						
local PlaneModeVS 						= Keys.PlaneModeVS --3								
local PlaneModeBore 					= Keys.PlaneModeBore --4
local PlaneModeFI0 						= Keys.PlaneModeFI0 --6
--rwr
local PlaneThreatWarnSoundVolumeDown 	= 409
local PlaneThreatWarnSoundVolumeUp 		= 410
--NAV
local NextSteer			 	= Keys.PlaneChangeTarget --steer point up
local PrevSteer 			= 1315 --steer point prev
--AP
local AutoAttHold 		    = 62
local AutoAltHold 		    = 389
local AutoCancel 		    = 408
local PlaneShowKneeboard    = 1587
local Kneeboard_Next        = 3001
local Kneeboard_Prev        = 3002
local Kneeboard_Mark        = 3003
local Radio_Menu            = 179
local Rearm_Menu            = 1560
local F1                    = 7
local F2                    = 8
local F3                    = 9
local F4                    = 359
local F5                    = 14
local F6                    = 149
local F7                    = 10
local F8                    = 151
local F9                    = 13
local F10                   = 15
local HUDcolor = 156
local HUDup = 746
local HUDdn = 747
--ICP
local ICP_COM1         = 10041
local ICP_COM2         = 10042
local ICP_NAV          = 10043
local ICP_STPT         = 10044
local ICP_ALT          = 10045
local ICP_HUD          = 10046
local ICP_AP           = 10047
local ICP_OP1          = 10048
local ICP_OP2          = 10049
local ICP_OP3          = 10050
local ICP_OP4          = 10051
local ICP_OP5          = 10052
local ICP_OTHR         = 10053

dev:listen_command(ICP_COM1)
dev:listen_command(ICP_COM2)
dev:listen_command(ICP_NAV)
dev:listen_command(ICP_ALT)
dev:listen_command(ICP_HUD)
dev:listen_command(ICP_AP)
dev:listen_command(ICP_OTHR)
dev:listen_command(ICP_OP1)
dev:listen_command(ICP_OP2)
dev:listen_command(ICP_OP3)
dev:listen_command(ICP_OP4)
dev:listen_command(ICP_OP5)

dev:listen_command(PlaneModeNAV)
dev:listen_command(PlaneModeBVR)
dev:listen_command(PlaneModeVS)
dev:listen_command(PlaneModeBore)
dev:listen_command(PlaneModeFI0)
dev:listen_command(PlaneThreatWarnSoundVolumeDown)
dev:listen_command(PlaneThreatWarnSoundVolumeUp)
dev:listen_command(NextSteer)
dev:listen_command(PrevSteer)
dev:listen_command(AutoAttHold)
dev:listen_command(AutoAltHold)
dev:listen_command(AutoCancel)
dev:listen_command(PlaneShowKneeboard)
-- dev:listen_command(Kneeboard_Next)
-- dev:listen_command(Kneeboard_Prev)
dev:listen_command(Kneeboard_Mark)
dev:listen_command(HUDcolor)
dev:listen_command(HUDup)
dev:listen_command(HUDdn)
dev:listen_command(F1)
dev:listen_command(F2)
dev:listen_command(F3)
dev:listen_command(F4)
dev:listen_command(F5)
dev:listen_command(F6)
dev:listen_command(F7)
dev:listen_command(F8)
dev:listen_command(F9)

local ap_timer     = 0
local ap_menu      = 0
local alt_state    = 0

local hud_timer    = 0
local hud_menu     = 0

------------------------------------------------------------------FUNCTION-POST-INIT---------------------------------------------------------------------------------------------------
function post_initialize()
    --print_message_to_user("ICP POST INIT")
end
------------------------------------------------------------------FUNCTION-SETCOMMAND---------------------------------------------------------------------------------------------------
function SetCommand(command,value)
--RADIO/REARM/KNEEBOARD
    if command == COM1 or command == ICP_COM1 then
        dispatch_action(nil,Radio_Menu)
    elseif command == COM2 or command == ICP_COM2 then
        dispatch_action(nil,Rearm_Menu)
    elseif command == STP or command == ICP_STPT then
        dispatch_action(nil,PlaneShowKneeboard)
    end
--ICP COMMANDS
    if (command == NAV or command == ICP_NAV) and parameters.MAIN_POWER:get() == 1 then
        dispatch_action(nil,PlaneModeNAV)
    elseif command == UP and parameters.MAIN_POWER:get() == 1 then
        dispatch_action(nil,NextSteer)
    elseif command == DWN and parameters.MAIN_POWER:get() == 1 then
        dispatch_action(nil,PrevSteer)
    elseif command == WHEELUP and parameters.MAIN_POWER:get() == 1 then
        dispatch_action(nil,HUDup)
    elseif command == WHEELDWN and parameters.MAIN_POWER:get() == 1 then
        dispatch_action(nil,HUDdn)
    elseif (command == OTHR or command == ICP_OTHR) and parameters.MAIN_POWER:get() == 1 then
        dispatch_action(nil,HUDcolor)
    end
--Special ICP
    if (command == HUD or command == ICP_HUD) and hud_menu == 0 and ap_menu == 0 and parameters.MAIN_POWER:get() == 1 then
        hud_menu = 1
        ap_menu  = 0
        ap_timer = 0
    elseif (command == HUD or command == ICP_HUD) and hud_menu == 0 and ap_menu == 1 and parameters.MAIN_POWER:get() == 1 then
        hud_menu = 1
        ap_menu  = 0
        ap_timer = 0
    elseif (command == AP or command == ICP_AP) and ap_menu == 0 and hud_menu == 0 and parameters.MAIN_POWER:get() == 1 then
        hud_menu  = 0
        ap_menu   = 1
        hud_timer = 0
    elseif (command == AP or command == ICP_AP) and ap_menu == 0 and hud_menu == 1 and parameters.MAIN_POWER:get() == 1 then
        hud_menu  = 0
        ap_menu   = 1
        hud_timer = 0
    elseif (command == ALT or command == ICP_ALT) and ap_menu == 0 and hud_menu == 0 and parameters.MAIN_POWER:get() == 1 then
        hud_menu  = 0
        ap_menu   = 1
        hud_timer = 0
        dispatch_action(nil,AutoAltHold)
    elseif (command == ALT or command == ICP_ALT) and ap_menu == 1 and hud_menu == 0 and parameters.MAIN_POWER:get() == 1 then
        hud_menu  = 0
        ap_menu   = 1
        hud_timer = 0
        dispatch_action(nil,AutoAltHold)
    elseif (command == ALT or command == ICP_ALT) and ap_menu == 0 and hud_menu == 1 and parameters.MAIN_POWER:get() == 1 then
        hud_menu  = 0
        ap_menu   = 1
        hud_timer = 0
        dispatch_action(nil,AutoAltHold)
    end
--HUD MODE COMMAND LOGIC
    if (command == OP1 or command == ICP_OP1) and hud_menu == 1 and parameters.MAIN_POWER:get() == 1 then
        hud_timer = 0
        dispatch_action(nil,PlaneModeNAV)
    elseif (command == OP2 or command == ICP_OP2) and hud_menu == 1 and parameters.MAIN_POWER:get() == 1 then
        hud_timer = 0
        dispatch_action(nil,PlaneModeBVR)
    elseif (command == OP3 or command == ICP_OP3) and hud_menu == 1 and parameters.MAIN_POWER:get() == 1 then
        hud_timer = 0
        dispatch_action(nil,PlaneModeVS)
    elseif (command == OP4 or command == ICP_OP4) and hud_menu == 1 and parameters.MAIN_POWER:get() == 1 then
        hud_timer = 0
        dispatch_action(nil,PlaneModeBore)
    elseif (command == OP5 or command == ICP_OP5) and hud_menu == 1 and parameters.MAIN_POWER:get() == 1 then
        hud_timer = 0
        dispatch_action(nil,PlaneModeFI0)
    elseif (command == OP1 or command == ICP_OP1) and ap_menu == 1 and parameters.MAIN_POWER:get() == 1 then
        ap_timer = 0
        dispatch_action(nil,AutoAltHold)
    elseif (command == OP2 or command == ICP_OP2) and ap_menu == 1 and parameters.MAIN_POWER:get() == 1 then
        ap_timer = 0
        dispatch_action(nil,AutoAttHold)
    elseif (command == OP3 or command == ICP_OP3) and ap_menu == 1 and parameters.MAIN_POWER:get() == 1 then
        ap_timer = 0
        dispatch_action(nil,AutoCancel)
    end
end
------------------------------------------------------------------FUNCTION-UPDATE---------------------------------------------------------------------------------------------------
function update()
    --print_message_to_user(ap_timer)
--HUD / AP MENU TIMER
    if hud_menu == 1 and parameters.MAIN_POWER:get() == 1 and hud_timer < 6 then
        hud_timer = (hud_timer + update_time_step)
    elseif hud_menu == 1 and parameters.MAIN_POWER:get() == 1 and hud_timer > 5 then
        hud_menu  = 0
        hud_timer = 0
    elseif ap_menu == 1 and parameters.MAIN_POWER:get() == 1 and ap_timer < 6 then
        ap_timer = (ap_timer + update_time_step)
    elseif ap_menu == 1 and parameters.MAIN_POWER:get() == 1 and ap_timer > 5 then
        ap_menu  = 0
        ap_timer = 0
    end
--ICP OPACITY
    if parameters.MAIN_POWER:get() == 1 then
        parameters.ICP_OPACITY:set(1)
    else
        parameters.ICP_OPACITY:set(0)
    end
--SET PARAMS
    parameters.ICP_AP_MENU:set(ap_menu)
    parameters.ICP_HUD_MENU:set(hud_menu)

end

need_to_be_closed = false
