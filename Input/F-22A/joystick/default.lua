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


local res = external_profile("Config/Input/Aircrafts/base_joystick_binding.lua")
ignore_features(res.keyCommands,{"dragchute"})
-- Input profiles run outside the cockpit devices.lua environment.
local flight_guidance_device = 25 -- Checked against the registered device contract.

local SelectLeft    = 10000
local SelectRight   = 10001
local SelectCenter  = 10002
local SelectAll     = 10003
local SelectStep    = 10004
local Dogfight      = 10005
local AirORIDE      = 10006
local MasterArm     = 10007
local MasterArm_T   = 10008
local Battery       = 10009
local Battery_T     = 10010
local L_GEN         = 10011
local L_GEN_T       = 10012
local R_GEN         = 10013
local R_GEN_T       = 10014
local AAR           = 10015
local AAR_T         = 10016
local DayNight      = 10017
local DayNight_T    = 10018
local Park          = 10019
local Park_T        = 10020
local Detent_F      = 10021
local Detent_S      = 10022
local AirORIDE_T    = 10024
local APU           = 10025  
local PICKLE        = 10026  
local SMFD_Swap     = 10027  
local L_cutoff      = 10028
local R_cutoff      = 10029    
--local FCSCenter     = 10030
--local FCSNoseUp     = 10031
--local FCSNoseDn     = 10032
--local FCSRel        = 10033
--local FCSMode       = 10034
--local FCSAOA        = 10035
--local FCSG          = 10036
--local FCSStep       = 10037
--local FCSpitch      = 10040
local ICP_COM1      = 10041
local ICP_COM2      = 10042
local ICP_NAV       = 10043
local ICP_STPT      = 10044
local ICP_ALT       = 10045
local ICP_HUD       = 10046
local ICP_AP        = 10047
local ICP_OP1       = 10048
local ICP_OP2       = 10049
local ICP_OP3       = 10050
local ICP_OP4       = 10051
local ICP_OP5       = 10052
local ICP_OTHR      = 10053
local CLIPBOARD_L   = 10054
local CLIPBOARD_R   = 10055
local L_BRAKE       = 10056
local R_BRAKE       = 10057
local B_BRAKE       = 10058

--Left MFD
local LMFD_OSB_01    = 10061
local LMFD_OSB_02    = 10062
local LMFD_OSB_03    = 10063
local LMFD_OSB_04    = 10064
local LMFD_OSB_05    = 10065
local LMFD_OSB_06    = 10066
local LMFD_OSB_07    = 10067
local LMFD_OSB_08    = 10068
local LMFD_OSB_09    = 10069
local LMFD_OSB_10    = 10070
local LMFD_OSB_11    = 10071
local LMFD_OSB_12    = 10072
local LMFD_OSB_13    = 10073
local LMFD_OSB_14    = 10074
local LMFD_OSB_15    = 10075
local LMFD_OSB_16    = 10076
local LMFD_OSB_17    = 10077
local LMFD_OSB_18    = 10078
local LMFD_OSB_19    = 10079
local LMFD_OSB_20    = 10080
--Right MFD
local RMFD_OSB_01    = 10091
local RMFD_OSB_02    = 10092
local RMFD_OSB_03    = 10093
local RMFD_OSB_04    = 10094
local RMFD_OSB_05    = 10095
local RMFD_OSB_06    = 10096
local RMFD_OSB_07    = 10097
local RMFD_OSB_08    = 10098
local RMFD_OSB_09    = 10099
local RMFD_OSB_10    = 10100
local RMFD_OSB_11    = 10101
local RMFD_OSB_12    = 10102
local RMFD_OSB_13    = 10103
local RMFD_OSB_14    = 10104
local RMFD_OSB_15    = 10105
local RMFD_OSB_16    = 10106
local RMFD_OSB_17    = 10107
local RMFD_OSB_18    = 10108
local RMFD_OSB_19    = 10109
local RMFD_OSB_20    = 10110
--Center MFD
local CMFD_OSB_01    = 10111
local CMFD_OSB_02    = 10112
local CMFD_OSB_03    = 10113
local CMFD_OSB_04    = 10114
local CMFD_OSB_05    = 10115
local CMFD_OSB_06    = 10116
local CMFD_OSB_07    = 10117
local CMFD_OSB_08    = 10118
local CMFD_OSB_09    = 10119
local CMFD_OSB_10    = 10120
local CMFD_OSB_11    = 10121
local CMFD_OSB_12    = 10122
local CMFD_OSB_13    = 10123
local CMFD_OSB_14    = 10124
local CMFD_OSB_15    = 10125
local CMFD_OSB_16    = 10126
local CMFD_OSB_17    = 10127
local CMFD_OSB_18    = 10128
local CMFD_OSB_19    = 10129
local CMFD_OSB_20    = 10130
--PMFD
local PMFD_OSB_01    = 10131
local PMFD_OSB_02    = 10132
local PMFD_OSB_03    = 10133
local PMFD_OSB_04    = 10134
local PMFD_OSB_05    = 10135
local PMFD_OSB_06    = 10136
local PMFD_OSB_07    = 10137
local PMFD_OSB_08    = 10138
local PMFD_OSB_09    = 10139
local PMFD_OSB_10    = 10140
local PMFD_OSB_11    = 10141
local PMFD_OSB_12    = 10142
local PMFD_OSB_13    = 10143
local PMFD_OSB_14    = 10144
local PMFD_OSB_15    = 10145
local PMFD_OSB_16    = 10146
local PMFD_OSB_17    = 10147
local PMFD_OSB_18    = 10148
local PMFD_OSB_19    = 10149
local PMFD_OSB_20    = 10150

local LIGHT_TAXI      = 10151
local LIGHT_TAXI_T    = 10152
local LIGHT_LANDING   = 10153
local LIGHT_LANDING_T = 10154

join(res.keyCommands,{    

		{down = iCommandPlaneTrimUp, up = iCommandPlaneTrimStop, name = "F-22: Trim Up", category = "Flight Control"},
        {down = iCommandPlaneTrimDown, up = iCommandPlaneTrimStop, name = "F-22: Trim Down", category = "Flight Control"},
        {down = iCommandPlaneTrimCancel, name = "F-22: Reset Trim", category = "Flight Control"},
  --      {down = 10500, value_down = 1.0, name = _('F-22: Altitude Hold Toggle'), category = _('F-22 EFM Commands')},
    --    {down = 10501, value_down = 1.0, name = _('F-22: Attitude Hold Toggle'), category = _('F-22 EFM Commands')},
     --   {down = 10502, value_down = 1.0, name = _('F-22: Auto Throttle Toggle'), category = _('F-22 EFM Commands')},
     --   {down = 10503, value_down = 1.0, name = _('F-22: Autopilot Disengage'), category = _('F-22 EFM Commands')},
		{ down = 11905, cockpit_device_id = flight_guidance_device, value_down = 1.0, name = _("Taxi Lights Toggle"), category = _("External Lights") },
		{ down = 11906, cockpit_device_id = flight_guidance_device, value_down = 1.0, name = _("Landing Lights Toggle"), category = _("External Lights") },
		{ down = 11907, cockpit_device_id = flight_guidance_device, value_down = 1.0, name = _("Formation Light Toggle"), category = _("External Lights") },
		{ down = 11908, cockpit_device_id = flight_guidance_device, value_down = 1.0, name = _("Navigation White Light Toggle"), category = _("External Lights") },
		{ down = 11909, cockpit_device_id = flight_guidance_device, value_down = 1.0, name = _("Anti-Collision Light Toggle"), category = _("External Lights") },
		{ down = 11910, cockpit_device_id = flight_guidance_device, value_down = 1.0, name = _("AAR Light Toggle"), category = _("External Lights") },
		{ down = 11911, cockpit_device_id = flight_guidance_device, value_down = 1.0, name = _("Navigation Lights Toggle"), category = _("External Lights") },
		{ down = 11912, cockpit_device_id = flight_guidance_device, value_down = 1.0, name = _("Master External Lights Toggle"), category = _("External Lights") },

--SMFD Both    
    {down=SMFD_Swap,up=SMFD_Swap,value_up=0,                  name = _('SMFD Page Swap'),                       category = _('F-22A Systems')},
--MFD LEFT    
    {down = LMFD_OSB_01,                name = _('MFD Left OSB 1'),                       category = _('F-22A MFD Left')},
    {down = LMFD_OSB_02,                name = _('MFD Left OSB 2'),                       category = _('F-22A MFD Left')},
    {down = LMFD_OSB_03,                name = _('MFD Left OSB 3'),                       category = _('F-22A MFD Left')},
    {down = LMFD_OSB_04,                name = _('MFD Left OSB 4'),                       category = _('F-22A MFD Left')},
    {down = LMFD_OSB_05,                name = _('MFD Left OSB 5'),                       category = _('F-22A MFD Left')},
    {down = LMFD_OSB_06,                name = _('MFD Left OSB 6'),                       category = _('F-22A MFD Left')},
    {down = LMFD_OSB_07,                name = _('MFD Left OSB 7'),                       category = _('F-22A MFD Left')},
    {down = LMFD_OSB_08,                name = _('MFD Left OSB 8'),                       category = _('F-22A MFD Left')},
    {down = LMFD_OSB_09,                name = _('MFD Left OSB 9'),                       category = _('F-22A MFD Left')},
    {down = LMFD_OSB_10,                name = _('MFD Left OSB 10'),                      category = _('F-22A MFD Left')},
    {down = LMFD_OSB_11,                name = _('MFD Left OSB 11'),                      category = _('F-22A MFD Left')},
    {down = LMFD_OSB_12,                name = _('MFD Left OSB 12'),                      category = _('F-22A MFD Left')},
    {down = LMFD_OSB_13,                name = _('MFD Left OSB 13'),                      category = _('F-22A MFD Left')},
    {down = LMFD_OSB_14,                name = _('MFD Left OSB 14'),                      category = _('F-22A MFD Left')},
    {down = LMFD_OSB_15,                name = _('MFD Left OSB 15'),                      category = _('F-22A MFD Left')},
    {down = LMFD_OSB_16,                name = _('MFD Left OSB 16'),                      category = _('F-22A MFD Left')},
    {down = LMFD_OSB_17,                name = _('MFD Left OSB 17'),                      category = _('F-22A MFD Left')},
    {down = LMFD_OSB_18,                name = _('MFD Left OSB 18'),                      category = _('F-22A MFD Left')},
    {down = LMFD_OSB_19,                name = _('MFD Left OSB 19'),                      category = _('F-22A MFD Left')},
    {down = LMFD_OSB_20,                name = _('MFD Left OSB 20'),                      category = _('F-22A MFD Left')},
--MFD RIGHT
    {down = RMFD_OSB_01,                name = _('MFD Right OSB 1'),                      category = _('F-22A MFD Right')},
    {down = RMFD_OSB_02,                name = _('MFD Right OSB 2'),                      category = _('F-22A MFD Right')},
    {down = RMFD_OSB_03,                name = _('MFD Right OSB 3'),                      category = _('F-22A MFD Right')},
    {down = RMFD_OSB_04,                name = _('MFD Right OSB 4'),                      category = _('F-22A MFD Right')},
    {down = RMFD_OSB_05,                name = _('MFD Right OSB 5'),                      category = _('F-22A MFD Right')},
    {down = RMFD_OSB_06,                name = _('MFD Right OSB 6'),                      category = _('F-22A MFD Right')},
    {down = RMFD_OSB_07,                name = _('MFD Right OSB 7'),                      category = _('F-22A MFD Right')},
    {down = RMFD_OSB_08,                name = _('MFD Right OSB 8'),                      category = _('F-22A MFD Right')},
    {down = RMFD_OSB_09,                name = _('MFD Right OSB 9'),                      category = _('F-22A MFD Right')},
    {down = RMFD_OSB_10,                name = _('MFD Right OSB 10'),                     category = _('F-22A MFD Right')},
    {down = RMFD_OSB_11,                name = _('MFD Right OSB 11'),                     category = _('F-22A MFD Right')},
    {down = RMFD_OSB_12,                name = _('MFD Right OSB 12'),                     category = _('F-22A MFD Right')},
    {down = RMFD_OSB_13,                name = _('MFD Right OSB 13'),                     category = _('F-22A MFD Right')},
    {down = RMFD_OSB_14,                name = _('MFD Right OSB 14'),                     category = _('F-22A MFD Right')},
    {down = RMFD_OSB_15,                name = _('MFD Right OSB 15'),                     category = _('F-22A MFD Right')},
    {down = RMFD_OSB_16,                name = _('MFD Right OSB 16'),                     category = _('F-22A MFD Right')},
    {down = RMFD_OSB_17,                name = _('MFD Right OSB 17'),                     category = _('F-22A MFD Right')},
    {down = RMFD_OSB_18,                name = _('MFD Right OSB 18'),                     category = _('F-22A MFD Right')},
    {down = RMFD_OSB_19,                name = _('MFD Right OSB 19'),                     category = _('F-22A MFD Right')},
    {down = RMFD_OSB_20,                name = _('MFD Right OSB 20'),                     category = _('F-22A MFD Right')},
--MFD CENTER
    {down = CMFD_OSB_01,                name = _('MFD Center OSB 1'),                     category = _('F-22A MFD Center')},
    {down = CMFD_OSB_02,                name = _('MFD Center OSB 2'),                     category = _('F-22A MFD Center')},
    {down = CMFD_OSB_03,                name = _('MFD Center OSB 3'),                     category = _('F-22A MFD Center')},
    {down = CMFD_OSB_04,                name = _('MFD Center OSB 4'),                     category = _('F-22A MFD Center')},
    {down = CMFD_OSB_05,                name = _('MFD Center OSB 5'),                     category = _('F-22A MFD Center')},
    {down = CMFD_OSB_06,                name = _('MFD Center OSB 6'),                     category = _('F-22A MFD Center')},
    {down = CMFD_OSB_07,                name = _('MFD Center OSB 7'),                     category = _('F-22A MFD Center')},
    {down = CMFD_OSB_08,                name = _('MFD Center OSB 8'),                     category = _('F-22A MFD Center')},
    {down = CMFD_OSB_09,                name = _('MFD Center OSB 9'),                     category = _('F-22A MFD Center')},
    {down = CMFD_OSB_10,                name = _('MFD Center OSB 10'),                    category = _('F-22A MFD Center')},
    {down = CMFD_OSB_11,                name = _('MFD Center OSB 11'),                    category = _('F-22A MFD Center')},
    {down = CMFD_OSB_12,                name = _('MFD Center OSB 12'),                    category = _('F-22A MFD Center')},
    {down = CMFD_OSB_13,                name = _('MFD Center OSB 13'),                    category = _('F-22A MFD Center')},
    {down = CMFD_OSB_14,                name = _('MFD Center OSB 14'),                    category = _('F-22A MFD Center')},
    {down = CMFD_OSB_15,                name = _('MFD Center OSB 15'),                    category = _('F-22A MFD Center')},
    {down = CMFD_OSB_16,                name = _('MFD Center OSB 16'),                    category = _('F-22A MFD Center')},
    {down = CMFD_OSB_17,                name = _('MFD Center OSB 17'),                    category = _('F-22A MFD Center')},
    {down = CMFD_OSB_18,                name = _('MFD Center OSB 18'),                    category = _('F-22A MFD Center')},
    {down = CMFD_OSB_19,                name = _('MFD Center OSB 19'),                    category = _('F-22A MFD Center')},
    {down = CMFD_OSB_20,                name = _('MFD Center OSB 20'),                    category = _('F-22A MFD Center')},
--PMFD
    {down = PMFD_OSB_01,                name = _('PMFD OSB 1'),                           category = _('F-22A PMFD')},
    {down = PMFD_OSB_02,                name = _('PMFD OSB 2'),                           category = _('F-22A PMFD')},
    {down = PMFD_OSB_03,                name = _('PMFD OSB 3'),                           category = _('F-22A PMFD')},
    {down = PMFD_OSB_04,                name = _('PMFD OSB 4'),                           category = _('F-22A PMFD')},
    {down = PMFD_OSB_05,                name = _('PMFD OSB 5'),                           category = _('F-22A PMFD')},
    {down = PMFD_OSB_06,                name = _('PMFD OSB 6'),                           category = _('F-22A PMFD')},
    {down = PMFD_OSB_07,                name = _('PMFD OSB 7'),                           category = _('F-22A PMFD')},
    {down = PMFD_OSB_08,                name = _('PMFD OSB 8'),                           category = _('F-22A PMFD')},
    {down = PMFD_OSB_09,                name = _('PMFD OSB 9'),                           category = _('F-22A PMFD')},
    {down = PMFD_OSB_10,                name = _('PMFD OSB 10'),                          category = _('F-22A PMFD')},
    {down = PMFD_OSB_11,                name = _('PMFD OSB 11'),                          category = _('F-22A PMFD')},
    {down = PMFD_OSB_12,                name = _('PMFD OSB 12'),                          category = _('F-22A PMFD')},
    {down = PMFD_OSB_13,                name = _('PMFD OSB 13'),                          category = _('F-22A PMFD')},
    {down = PMFD_OSB_14,                name = _('PMFD OSB 14'),                          category = _('F-22A PMFD')},
    {down = PMFD_OSB_15,                name = _('PMFD OSB 15'),                          category = _('F-22A PMFD')},
    {down = PMFD_OSB_16,                name = _('PMFD OSB 16'),                          category = _('F-22A PMFD')},
    {down = PMFD_OSB_17,                name = _('PMFD OSB 17'),                          category = _('F-22A PMFD')},
    {down = PMFD_OSB_18,                name = _('PMFD OSB 18'),                          category = _('F-22A PMFD')},
    {down = PMFD_OSB_19,                name = _('PMFD OSB 19'),                          category = _('F-22A PMFD')},
    {down = PMFD_OSB_20,                name = _('PMFD OSB 20'),                          category = _('F-22A PMFD')},  
--CLIPBOARD BINDS               
    {down = CLIPBOARD_L,                name = _('Clipboard Left Show/Hide'),            category = _('F-22A Systems')},
    {down = CLIPBOARD_R,                name = _('Clipboard Right Show/Hide'),           category = _('F-22A Systems')},
--ICP BINDS
    {down=11401,up=11401,value_down=1,value_up=0,cockpit_device_id=7,name=_('ICP IFF'),category=_('F-22A ICP')},
    {down=11402,up=11402,value_down=1,value_up=0,cockpit_device_id=7,name=_('ICP DVR'),category=_('F-22A ICP')},
    {down = ICP_COM1,                   name = _('ICP COMM 1'),                          category = _('F-22A ICP')},
    {down = ICP_COM2,                   name = _('ICP COMM 2'),                          category = _('F-22A ICP')},
    {down = ICP_NAV,                    name = _('ICP NAV'),                             category = _('F-22A ICP')},
    {down = ICP_STPT,                   name = _('ICP STPT'),                            category = _('F-22A ICP')},
    {down = ICP_ALT,                    name = _('ICP ALT'),                             category = _('F-22A ICP')},
    {down = ICP_HUD,                    name = _('ICP HUD'),                             category = _('F-22A ICP')},
    {down = ICP_AP,                     name = _('ICP AP'),                              category = _('F-22A ICP')},
    {down = ICP_OTHR,                   name = _('ICP OTHR'),                            category = _('F-22A ICP')},
    {down = ICP_OP1,                    name = _('ICP Option 1'),                        category = _('F-22A ICP')},
    {down = ICP_OP2,                    name = _('ICP Option 2'),                        category = _('F-22A ICP')},
    {down = ICP_OP3,                    name = _('ICP Option 3'),                        category = _('F-22A ICP')},
    {down = ICP_OP4,                    name = _('ICP Option 4'),                        category = _('F-22A ICP')},
    {down = ICP_OP5,                    name = _('ICP Option 5'),                        category = _('F-22A ICP')},
--F-22 Weapons
    {down = Detent_F, up = Detent_F, value_down = 1, value_up = 0,
        name = _('Weapons: Trigger First Detent'), category = _('F-22A HOTAS')},
    {down = Detent_S, up = Detent_S, value_down = 1, value_up = 0,
        name = _('Weapons: Trigger Second Detent'), category = _('F-22A HOTAS')},
    {down = PICKLE, up = PICKLE,        name = _('Weapons: Release'),                   category = _('F-22A HOTAS')},
--F-22 CUSTOM BINDS
    {down = SelectLeft,                 name = _('Weapon Bay: Select Left'),            category = _('F-22A HOTAS')},
    {down = SelectRight,                name = _('Weapon Bay: Select Right'),           category = _('F-22A HOTAS')},
    {down = SelectCenter,               name = _('Weapon Bay: Select Center'),          category = _('F-22A HOTAS')},
    {down = SelectAll,                  name = _('Weapon Bay: Select All'),             category = _('F-22A HOTAS')},
    {down = SelectStep,                 name = _('Weapon Bay: Select Toggle'),          category = _('F-22A HOTAS')},
    {down = AirORIDE, up = AirORIDE,    name = _('Weapon Bay: Override (AIR)'),         category = _('F-22A HOTAS')},
    {down = AirORIDE_T,                 name = _('Weapon Bay: Override Toggle (AIR)'),  category = _('F-22A HOTAS')},
    {down = Dogfight,                   name = _('Dogfight MFD Override'),              category = _('F-22A HOTAS')},
    {down = APU, up = APU, value_down = 1, value_up = 0,
        name = _('APU Start'), category = _('F-22A HOTAS')},

    {down = L_cutoff, up = L_cutoff, value_down = 1, value_up = 0,
        name = _('Throttle (Left) - OFF/IDLE'),          category = _('F-22A HOTAS')},
    {down = R_cutoff, up = R_cutoff, value_down = 1, value_up = 0,
        name = _('Throttle (Right) - OFF/IDLE'),         category = _('F-22A HOTAS')},
--Special Switch Functionality
    {down = Battery, up = Battery,      name = _('Battery On/Off'),                     category = _('F-22A Systems')},
    {down = Battery_T,                  name = _('Battery Toggle'),                     category = _('F-22A Systems')},
    {down = MasterArm, up = MasterArm,  name = _('Master Arm On/Off'),                  category = _('F-22A Systems')},
    {down = MasterArm_T,                name = _('Master Arm Toggle'),                  category = _('F-22A Systems')},
    {down = DayNight, up = DayNight,    name = _('Day/Night Mode'),                     category = _('F-22A Systems')},
    {down = DayNight_T,                 name = _('Day/Night Mode Toggle'),              category = _('F-22A Systems')},
    {down = L_GEN, up = L_GEN,          name = _('Generator Left On/Off'),              category = _('F-22A Systems')},
    {down = L_GEN_T,                    name = _('Generator Left Toggle'),              category = _('F-22A Systems')},
    {down = R_GEN, up = R_GEN,          name = _('Generator Right On/Off'),             category = _('F-22A Systems')},
    {down = R_GEN_T,                    name = _('Generator Right Toggle'),             category = _('F-22A Systems')},
    {down = AAR,   up = AAR,            name = _('Air-Air Refuel Open/Close'),          category = _('F-22A Systems')},
    {down = AAR_T,                      name = _('Air-Air Refuel Toggle'),              category = _('F-22A Systems')},
    {down = Park, up = Park,            name = _('Parking Brake On/Off'),               category = _('F-22A Systems')},
    {down = Park_T,                     name = _('Parking Brake Toggle'),               category = _('F-22A Systems')},
    {down = LIGHT_TAXI, up = LIGHT_TAXI,        name = _('Taxi Light On/Off'),          category = _('F-22A Systems')},   
    {down = LIGHT_TAXI_T,               name = _('Taxi Light Toggle'),                  category = _('F-22A Systems')},
    {down = LIGHT_LANDING, up = LIGHT_LANDING,  name = _('Landing Light On/Off'),       category = _('F-22A Systems')},   
    {down = LIGHT_LANDING_T,            name = _('Landing Light Toggle'),               category = _('F-22A Systems')},   
-------------------------------------------------------------------------------------------------------------------------------------------------------
-- Autopilot
-- Flight Control
    --{down = iCommandPlaneTrimOn, up = iCommandPlaneTrimOff, name = _('T/O Trim'), category = _('Flight Control')},
-- Systems
    {down = iCommandPlaneAirRefuel,                                                                                 name = _('Refueling Boom'), category = _('Systems')},
    {down = iCommandPlaneJettisonFuelTanks,                                                                         name = _('Jettison Fuel Tanks'), category = _('Systems')},
    {down = iCommandPlane_HOTAS_NoseWheelSteeringButton, up = iCommandPlane_HOTAS_NoseWheelSteeringButton,          name = _('Nose Gear Maneuvering Range'), category = _('Systems')},
    {down = iCommandPlane_HOTAS_NoseWheelSteeringButtonOff, up = iCommandPlane_HOTAS_NoseWheelSteeringButtonOff,    name = _('Nose Wheel Steering'), category = _('Systems')},
    {down = L_BRAKE, up = L_BRAKE, value_down = 1, value_up = -1,                                     name = _('Wheel Brake Left On/Off'), category = _('Systems')},
    {down = R_BRAKE, up = R_BRAKE, value_down = 1, value_up = -1,                                   name = _('Wheel Brake Right On/Off'), category = _('Systems')},
-- Modes
    {down = iCommandPlaneModeBVR,   name = _('(2) Beyond Visual Range Mode'),                       category = _('Modes')},
    {down = iCommandPlaneModeVS,    name = _('(3) Close Air Combat Vertical Scan Mode'),            category = _('Modes')},
    {down = iCommandPlaneModeBore,  name = _('(4) Close Air Combat Bore Mode'),                     category = _('Modes')},
    {down = iCommandPlaneModeFI0,   name = _('(6) Longitudinal Missile Aiming Mode/FLOOD mode'),    category = _('Modes')},
-- Sensors
    {down = iCommandPlaneChangeLock, up = iCommandPlaneChangeLockUp,    name = _('Target Lock'),                            category = _('Sensors')},
    {down = iCommandSensorReset,                                        name = _('Radar - Return To Search/NDTWS'),         category = _('Sensors')},
    {down = iCommandRefusalTWS,                                         name = _('Unlock TWS Target'),                      category = _('Sensors')},
    {down = iCommandPlaneRadarOnOff,                                    name = _('Radar On/Off'),                           category = _('Sensors')},
    {down = iCommandPlaneRadarChangeMode,                               name = _('Radar RWS/TWS Mode Select'),              category = _('Sensors')},
    {down = iCommandPlaneRadarCenter,                                   name = _('Target Designator To Center'),            category = _('Sensors')},
    {down = iCommandPlaneChangeRadarPRF,                                name = _('Radar Pulse Repeat Frequency Select'),    category = _('Sensors')},

    {pressed = iCommandPlaneRadarUp,    up = iCommandPlaneRadarStop, name = _('Target Designator Up'),    category = _('Sensors')},
    {pressed = iCommandPlaneRadarDown,  up = iCommandPlaneRadarStop, name = _('Target Designator Down'),  category = _('Sensors')},
    {pressed = iCommandPlaneRadarLeft,  up = iCommandPlaneRadarStop, name = _('Target Designator Left'),  category = _('Sensors')},
    {pressed = iCommandPlaneRadarRight, up = iCommandPlaneRadarStop, name = _('Target Designator Right'), category = _('Sensors')},

    {pressed = iCommandSelecterUp,    up = iCommandSelecterStop, name = _('Scan Zone Up'),    category = _('Sensors')},
    {pressed = iCommandSelecterDown,  up = iCommandSelecterStop, name = _('Scan Zone Down'),  category = _('Sensors')},
    {pressed = iCommandSelecterLeft,  up = iCommandSelecterStop, name = _('Scan Zone Left'),  category = _('Sensors')},
    {pressed = iCommandSelecterRight, up = iCommandSelecterStop, name = _('Scan Zone Right'), category = _('Sensors')},

    {down = iCommandPlaneZoomIn,  name = _('Display Zoom In'),  category = _('Sensors')},
    {down = iCommandPlaneZoomOut, name = _('Display Zoom Out'), category = _('Sensors')},

    {down = iCommandDecreaseRadarScanArea, name = _('Radar Scan Zone Decrease'), category = _('Sensors')},
    {down = iCommandIncreaseRadarScanArea, name = _('Radar Scan Zone Increase'), category = _('Sensors')},

    {pressed = iCommandPlaneIncreaseBase_Distance, up = iCommandPlaneStopBase_Distance, name = _('Target Specified Size Increase'), category = _('Sensors')},
    {pressed = iCommandPlaneDecreaseBase_Distance, up = iCommandPlaneStopBase_Distance, name = _('Target Specified Size Decrease'), category = _('Sensors')},

    {down = iCommandChangeRWRMode,                  name = _('RWR/SPO Mode Select'),                category = _('Sensors')},
    {down = iCommandPlaneThreatWarnSoundVolumeDown, name = _('RWR/SPO Sound Signals Volume Down'),  category = _('Sensors')},
    {down = iCommandPlaneThreatWarnSoundVolumeUp,   name = _('RWR/SPO Sound Signals Volume Up'),    category = _('Sensors')},
-- Weapons                                                                        
    {down = iCommandPlaneSalvoOnOff,     name = _('Salvo Mode'),                                category = _('Weapons')},
    {down = iCommandChangeGunRateOfFire, name = _('Cannon Rate Of Fire / Cut Of Burst select'), category = _('Weapons')},
    })

    join(res.axisCommands,{

    --F-22A Custom Axis
    {action = B_BRAKE,		                        name = _('F-22 Wheel Brake Both')},
    {action = L_BRAKE,		                        name = _('F-22 Wheel Brake Left')},
    {action = R_BRAKE,		                        name = _('F-22 Wheel Brake Right')},
    --Core
    {action = iCommandPlaneSelecterHorizontalAbs,   name = _('TDC Slew Horizontal')},
    {action = iCommandPlaneSelecterVerticalAbs,     name = _('TDC Slew Vertical')},
    {action = iCommandPlaneRadarHorizontalAbs,      name = _('Radar Horizontal')},
    {action = iCommandPlaneRadarVerticalAbs,        name = _('Radar Vertical')},
    {action = iCommandPlaneMFDZoomAbs,              name = _('MFD Range')},
    {action = iCommandPlaneBase_DistanceAbs,        name = _('Base/Distance')},
    })

-- Own radar computer (not inherited FC3 request labels).
join(res.keyCommands,{
    {down=10600,value_down=1,cockpit_device_id=14,name=_('Radar Emission - Transmit / Standby'),category=_('F-22 Radar')},
    {down=10601,value_down=1,cockpit_device_id=14,name=_('Search Mode - Range While Search (RWS)'),category=_('F-22 Radar')},
    {down=10602,value_down=1,cockpit_device_id=14,name=_('Search Mode - Track While Scan (TWS)'),category=_('F-22 Radar')},
    {down=10603,value_down=1,cockpit_device_id=14,name=_('Search Mode - Toggle RWS / TWS'),category=_('F-22 Radar')},
    {down=10604,value_down=1,cockpit_device_id=14,name=_('ACM Acquisition - Vertical Scan'),category=_('F-22 Radar')},
    {down=10605,value_down=1,cockpit_device_id=14,name=_('ACM Acquisition - Boresight Scan'),category=_('F-22 Radar')},
    {down=10606,value_down=1,cockpit_device_id=14,name=_('Target Designation - Designate / Enter STT'),category=_('F-22 Radar')},
    {down=10607,value_down=1,cockpit_device_id=14,name=_('Radar Range - Increase'),category=_('F-22 Radar')},
    {down=10608,value_down=1,cockpit_device_id=14,name=_('Radar Range - Decrease'),category=_('F-22 Radar')},
    {down=10609,value_down=1,cockpit_device_id=14,name=_('Target Designation - Clear / Break Lock'),category=_('F-22 Radar')},
    {down=10610,value_down=1,cockpit_device_id=14,name=_('Radar Cursor - Up'),category=_('F-22 HOTAS - Throttle')},
    {down=10611,value_down=1,cockpit_device_id=14,name=_('Radar Cursor - Down'),category=_('F-22 HOTAS - Throttle')},
    {down=10612,value_down=1,cockpit_device_id=14,name=_('Radar Cursor - Left'),category=_('F-22 HOTAS - Throttle')},
    {down=10613,value_down=1,cockpit_device_id=14,name=_('Radar Cursor - Right'),category=_('F-22 HOTAS - Throttle')},
    {down=10614,value_down=1,cockpit_device_id=14,name=_('Radar Antenna Elevation - Up'),category=_('F-22 HOTAS - Throttle')},
    {down=10615,value_down=1,cockpit_device_id=14,name=_('Radar Antenna Elevation - Down'),category=_('F-22 HOTAS - Throttle')},
    {down=10616,value_down=1,cockpit_device_id=14,name=_('Search Width - Cycle 30 / 60 / 120 Degrees'),category=_('F-22 Radar')},
    {down=10617,value_down=1,cockpit_device_id=14,name=_('Search Volume and Cursor - Recenter'),category=_('F-22 Radar')},
    {down=10618,value_down=1,cockpit_device_id=14,name=_('Target Designation - Next Track'),category=_('F-22 Radar')},
    {down=10619,value_down=1,cockpit_device_id=14,name=_('Identification - IFF Interrogate'),category=_('F-22 Radar')},
    {down=10631,value_down=1,cockpit_device_id=14,name=_('Identification - Automatic IFF On/Off'),category=_('F-22 Radar')},
})
join(res.axisCommands,{
 {action=10620,cockpit_device_id=14,name=_('Radar Cursor - Horizontal Axis'),category=_('F-22 HOTAS - Throttle')},
 {action=10621,cockpit_device_id=14,name=_('Radar Cursor - Vertical Axis'),category=_('F-22 HOTAS - Throttle')},
})

-- BEGIN F22 COMBAT CONTROLS
join(res.keyCommands,{
 {down=10714,up=10714,value_down=1,value_up=0,cockpit_device_id=16,name=_('Nosewheel Steering / Undesignate; Hold: Next Weapon Station'),category=_('F-22 HOTAS - Stick')},
 {down=10701,up=10701,value_down=1,value_up=0,cockpit_device_id=16,name=_('Target Management Right - Next Target; Hold: RWS / TWS; ACM: Wide Scan'),category=_('F-22 HOTAS - Stick')},
 {down=10727,up=10727,value_down=1,value_up=0,cockpit_device_id=16,name=_('Radar Range - Decrease'),category=_('F-22 HOTAS - Throttle')},
 {down=10723,up=10723,value_down=1,value_up=0,cockpit_device_id=16,name=_('Contextual Cage - NAV FPM / Weapon Seeker'),category=_('F-22 HOTAS - Throttle')},
 {down=10721,up=10721,value_down=1,value_up=0,cockpit_device_id=16,name=_('Master Mode - Navigation'),category=_('F-22 HOTAS - Throttle')},
 {down=10703,up=10703,value_down=1,value_up=0,cockpit_device_id=16,name=_('Target Management Left - IFF Interrogate; Hold: Interrogate Line of Sight'),category=_('F-22 HOTAS - Stick')},
 {down=10720,up=10720,value_down=1,value_up=0,cockpit_device_id=16,name=_('Weapon Select - Cycle Weapons (Optional)'),category=_('F-22 HOTAS - Throttle')},
 {down=10725,up=10725,value_down=1,value_up=0,cockpit_device_id=16,name=_('Radar Emission - Transmit / Standby'),category=_('F-22 HOTAS - Throttle')},
 {down=10710,up=10710,value_down=1,value_up=0,cockpit_device_id=16,
  name=_('Countermeasures Down - Authorize / SEMI Consent'),category=_('F-22 HOTAS - Stick')},
 {down=10718,up=10718,value_down=1,value_up=0,cockpit_device_id=16,name=_('Weapon Release - Fire Selected Weapon'),category=_('F-22 HOTAS - Stick')},
 {down=10709,up=10709,value_down=1,value_up=0,cockpit_device_id=16,
  name=_('Countermeasures Right - Revoke and Stop'),category=_('F-22 HOTAS - Stick')},
 {down=10729,up=10729,value_down=1,value_up=0,cockpit_device_id=16,name=_('Weapon Select - AIM-9 Sidewinder'),category=_('F-22 HOTAS - Throttle')},
 {down=10717,up=10717,value_down=1,value_up=0,cockpit_device_id=16,name=_('Trigger - Second Stage / Fire Gun'),category=_('F-22 HOTAS - Stick')},
 {down=10706,up=10706,value_down=1,value_up=0,cockpit_device_id=16,name=_('Sensor Control Switch Down - Focus Primary / Acquire Ground Target'),category=_('F-22 HOTAS - Stick')},
 {down=10704,up=10704,value_down=1,value_up=0,cockpit_device_id=16,name=_('Sensor Control Switch Up - Select HUD'),category=_('F-22 HOTAS - Stick')},
 {down=10722,up=10722,value_down=1,value_up=0,cockpit_device_id=16,name=_('Radar Coverage - Press: Scan Width; Hold: Scan Height'),category=_('F-22 HOTAS - Throttle')},
 {down=10705,up=10705,value_down=1,value_up=0,cockpit_device_id=16,name=_('Sensor Control Switch Right - Select Right MFD'),category=_('F-22 HOTAS - Stick')},
 {down=10728,up=10728,value_down=1,value_up=0,cockpit_device_id=16,name=_('Weapon Select - Gun'),category=_('F-22 HOTAS - Throttle')},
 {down=10726,up=10726,value_down=1,value_up=0,cockpit_device_id=16,name=_('Radar Range - Increase'),category=_('F-22 HOTAS - Throttle')},
 {down=10724,up=10724,value_down=1,value_up=0,cockpit_device_id=16,name=_('Master Arm - Safe / Armed'),category=_('F-22 HOTAS - Throttle')},
 {down=10719,up=10719,value_down=1,value_up=0,cockpit_device_id=16,name=_('Dogfight Override - Toggle (Optional)'),category=_('F-22 HOTAS - Throttle')},
 {down=10707,up=10707,value_down=1,value_up=0,cockpit_device_id=16,name=_('Sensor Control Switch Left - Select Left MFD'),category=_('F-22 HOTAS - Stick')},
 {down=10711,up=10711,value_down=1,value_up=0,cockpit_device_id=16,
  name=_('Countermeasures Left - Direct Selected Program'),category=_('F-22 HOTAS - Stick')},
 {down=10712,up=10712,value_down=1,value_up=0,cockpit_device_id=16,
  name=_('Countermeasures Press - Direct Bank 3'),category=_('F-22 HOTAS - Stick')},
 {down=10708,up=10708,value_down=1,value_up=0,cockpit_device_id=16,
  name=_('Countermeasures Up - Normal Selected Program'),category=_('F-22 HOTAS - Stick')},
 {down=10715,up=10715,value_down=1,value_up=0,cockpit_device_id=16,name=_('Paddle - Disengage Autopilot'),category=_('F-22 HOTAS - Stick')},
 {down=10713,up=10713,value_down=1,value_up=0,cockpit_device_id=16,name=_('Sensor Display - Expand / Normal'),category=_('F-22 HOTAS - Stick')},
 {down=10730,up=10730,value_down=1,value_up=0,cockpit_device_id=16,name=_('Weapon Select - AIM-120 AMRAAM'),category=_('F-22 HOTAS - Throttle')},
 {down=10716,up=10716,value_down=1,value_up=0,cockpit_device_id=16,name=_('Trigger - First Stage'),category=_('F-22 HOTAS - Stick')},
 {down=10702,up=10702,value_down=1,value_up=0,cockpit_device_id=16,name=_('Target Management Down - Break Lock; ACM: Vertical Scan'),category=_('F-22 HOTAS - Stick')},
 {down=10700,up=10700,value_down=1,value_up=0,cockpit_device_id=16,name=_('Target Management Up - Designate / STT; ACM: Boresight Scan'),category=_('F-22 HOTAS - Stick')},
})
join(res.keyCommands,{
 {down=10731,up=10731,value_down=1,value_up=0,cockpit_device_id=16,name=_('Master Mode - Air-to-Air / Return to Navigation'),category=_('F-22 HOTAS - Throttle')},
 {down=10732,up=10732,value_down=1,value_up=0,cockpit_device_id=16,name=_('Master Mode - Air-to-Ground / Return to Navigation'),category=_('F-22 HOTAS - Throttle')},
 {down=10733,up=10733,value_down=1,value_up=0,cockpit_device_id=16,name=_('Radar Cursor Press - Designate / STT'),category=_('F-22 HOTAS - Throttle')},
})
-- END F22 COMBAT CONTROLS

join(res.keyCommands,{
 {down=10628,value_down=1,cockpit_device_id=14,name=_('Target Designation - Secondary at Cursor'),category=_('F-22 Radar')},
 {down=10629,value_down=1,cockpit_device_id=14,name=_('Target Designation - Swap Primary / Secondary (Search Only)'),category=_('F-22 Radar')},
 {down=10630,value_down=1,cockpit_device_id=14,name=_('Target Designation - Clear Secondary'),category=_('F-22 Radar')},
 {down=10900,value_down=1,cockpit_device_id=18,name=_('F-22 RWR power'),category=_('F-22 Sensors')},
 {down=10901,value_down=1,cockpit_device_id=18,name=_('F-22 RWR audio mute'),category=_('F-22 Sensors')},
 {down=10902,value_down=1,cockpit_device_id=18,name=_('F-22 RWR ALL / threat filter'),category=_('F-22 Sensors')},
})
join(res.keyCommands,{
 {down=10903,value_down=1,cockpit_device_id=18,name=_('F-22 HUD EW repeater'),category=_('F-22 Sensors')},
 {down=10910,up=10910,value_down=1,value_up=0,cockpit_device_id=1,name=_('F-22 UFD ADI / cautions swap'),category=_('F-22 Sensors')},
})
join(res.keyCommands,{
 {down=10904,value_down=1,cockpit_device_id=18,name=_('F-22 RWR volume up'),category=_('F-22 Sensors')},
 {down=10905,value_down=1,cockpit_device_id=18,name=_('F-22 RWR volume down'),category=_('F-22 Sensors')},
})
join(res.keyCommands,{
 {down=10830,up=10830,value_down=1,value_up=0,cockpit_device_id=8,name=_('F-22 Next steerpoint'),category=_('F-22 Navigation')},
 {down=10831,up=10831,value_down=1,value_up=0,cockpit_device_id=8,name=_('F-22 Previous steerpoint'),category=_('F-22 Navigation')},
 {down=10832,up=10832,value_down=1,value_up=0,cockpit_device_id=8,name=_('F-22 Navigation AUTO / MAN sequencing'),category=_('F-22 Navigation')},
 {down=10833,up=10833,value_down=1,value_up=0,cockpit_device_id=8,name=_('F-22 Navigation range decrease'),category=_('F-22 Navigation')},
 {down=10834,up=10834,value_down=1,value_up=0,cockpit_device_id=8,name=_('F-22 Navigation range increase'),category=_('F-22 Navigation')},
 {down=10835,up=10835,value_down=1,value_up=0,cockpit_device_id=8,name=_('F-22 Direct to selected steerpoint'),category=_('F-22 Navigation')},
 {down=10836,up=10836,value_down=1,value_up=0,cockpit_device_id=8,name=_('F-22 Reload mission route'),category=_('F-22 Navigation')},
})
-- Preserve the base command names/default key combinations, but own routing.
for _, binding in ipairs(res.keyCommands) do
 local command
 if iCommandPlaneDropFlareOnce and binding.down==iCommandPlaneDropFlareOnce then command=10840
 elseif iCommandPlaneDropChaffOnce and binding.down==iCommandPlaneDropChaffOnce then command=10841
 elseif iCommandActiveJamming and binding.down==iCommandActiveJamming then command=10842 end
 if command then
  binding.down=command;binding.up=command;binding.value_down=1;binding.value_up=0
  binding.cockpit_device_id=20
 end
end
join(res.keyCommands,{
 {down=10920,up=10920,value_down=1,value_up=0,cockpit_device_id=22,name=_('F-22 Missile warning power'),category=_('F-22 Sensors')},
 {down=10921,up=10921,value_down=1,value_up=0,cockpit_device_id=22,name=_('F-22 Missile warning audio mute'),category=_('F-22 Sensors')},
})
join(res.keyCommands,{
 {down=10622,value_down=1,cockpit_device_id=14,name=_('ACM Acquisition - Wide Scan'),category=_('F-22 Radar')},
 {down=10623,value_down=1,cockpit_device_id=14,name=_('Search Height - Cycle 10 / 20 / 40 Degrees'),category=_('F-22 Radar')},
 {down=10632,value_down=1,cockpit_device_id=14,name=_('Target Designation - Enter STT on Primary Target'),category=_('F-22 Radar')},
})
-- Group the inherited flight axes, trim hat and speedbrake with the HOTAS.
-- Only presentation changes: DCS command identity and saved assignments survive.
local inherited_hotas = {
 {iCommandPlaneTrimUp, _('Trim Hat - Nose Up'), _('F-22 HOTAS - Stick')},
 {iCommandPlaneTrimDown, _('Trim Hat - Nose Down'), _('F-22 HOTAS - Stick')},
 {iCommandPlaneTrimLeft, _('Trim Hat - Left Wing Down'), _('F-22 HOTAS - Stick')},
 {iCommandPlaneTrimRight, _('Trim Hat - Right Wing Down'), _('F-22 HOTAS - Stick')},
 {iCommandPlaneAirBrake, _('Speedbrake - Toggle Extend / Retract'), _('F-22 HOTAS - Throttle')},
 {iCommandPlaneAirBrakeOn, _('Speedbrake - Extend'), _('F-22 HOTAS - Throttle')},
 {iCommandPlaneAirBrakeOff, _('Speedbrake - Retract'), _('F-22 HOTAS - Throttle')},
}
for _, binding in ipairs(res.keyCommands) do
 for _, spec in ipairs(inherited_hotas) do
  if spec[1] and (binding.down==spec[1] or binding.pressed==spec[1]) then
   binding.name=spec[2];binding.category=spec[3]
  end
 end
end
local inherited_axes = {
 {iCommandPlanePitch, _('Stick - Pitch'), _('F-22 HOTAS - Stick')},
 {iCommandPlaneRoll, _('Stick - Roll'), _('F-22 HOTAS - Stick')},
 {iCommandPlaneThrustCommon, _('Throttle - Both Engines'), _('F-22 HOTAS - Throttle')},
 {iCommandPlaneThrustLeft, _('Throttle - Left Engine'), _('F-22 HOTAS - Throttle')},
 {iCommandPlaneThrustRight, _('Throttle - Right Engine'), _('F-22 HOTAS - Throttle')},
}
for _, binding in ipairs(res.axisCommands or {}) do
 for _, spec in ipairs(inherited_axes) do
  if spec[1] and binding.action==spec[1] then
   binding.name=spec[2];binding.category=spec[3]
  end
 end
end
join(res.keyCommands,{
 {down=10734,up=10734,value_down=1,value_up=0,cockpit_device_id=16,name=_('Air-to-Ground - Select Gun'),category=_('F-22 HOTAS - Throttle')},
 {down=10735,up=10735,value_down=1,value_up=0,cockpit_device_id=16,name=_('Air-to-Ground - Select CCIP Bomb Delivery'),category=_('F-22 HOTAS - Throttle')},
 {down=10736,up=10736,value_down=1,value_up=0,cockpit_device_id=16,name=_('Air-to-Ground - Select AUTO Bomb Delivery'),category=_('F-22 HOTAS - Throttle')},
 {down=10737,up=10737,value_down=1,value_up=0,cockpit_device_id=16,name=_('Air-to-Ground - Cycle Gun / CCIP / AUTO'),category=_('F-22 HOTAS - Throttle')},
 {down=10738,up=10738,value_down=1,value_up=0,cockpit_device_id=16,name=_('Air-to-Ground - Designate Selected Steerpoint'),category=_('F-22 HOTAS - Stick')},
 {down=10739,up=10739,value_down=1,value_up=0,cockpit_device_id=16,name=_('Air-to-Ground - Designate HUD Line of Sight'),category=_('F-22 HOTAS - Stick')},
 {down=10740,up=10740,value_down=1,value_up=0,cockpit_device_id=16,name=_('Air-to-Ground - Clear Ground Designation'),category=_('F-22 HOTAS - Stick')},
 {down=10741,up=10741,value_down=1,value_up=0,cockpit_device_id=16,name=_('Sensor Control Switch Depress - Execute Focused Screen Function'),category=_('F-22 HOTAS - Stick')},
})

-- Independent navigation and EFM flight guidance.
join(res.keyCommands,{
 {down=10930,up=10930,value_down=1,value_up=0,cockpit_device_id=25,name=_('Navigation Source - Cycle WPT / TACAN / ILS'),category=_('F-22 Navigation')},
 {down=10931,up=10931,value_down=1,value_up=0,cockpit_device_id=25,name=_('Navigation Course - Increase'),category=_('F-22 Navigation')},
 {down=10932,up=10932,value_down=1,value_up=0,cockpit_device_id=25,name=_('Navigation Course - Decrease'),category=_('F-22 Navigation')},
 {down=10933,up=10933,value_down=1,value_up=0,cockpit_device_id=25,name=_('TACAN Channel - Increase'),category=_('F-22 Navigation')},
 {down=10934,up=10934,value_down=1,value_up=0,cockpit_device_id=25,name=_('TACAN Channel - Decrease'),category=_('F-22 Navigation')},
 {down=10935,up=10935,value_down=1,value_up=0,cockpit_device_id=25,name=_('TACAN Band - X / Y'),category=_('F-22 Navigation')},
 {down=10936,up=10936,value_down=1,value_up=0,cockpit_device_id=25,name=_('TACAN Mode - OFF / REC / T-R / A-A REC / A-A T-R'),category=_('F-22 Navigation')},
 {down=10937,up=10937,value_down=1,value_up=0,cockpit_device_id=25,name=_('ILS Frequency - Next Channel'),category=_('F-22 Navigation')},
 {down=10938,up=10938,value_down=1,value_up=0,cockpit_device_id=25,name=_('ILS Frequency - Previous Channel'),category=_('F-22 Navigation')},
 {down=10939,up=10939,value_down=1,value_up=0,cockpit_device_id=25,name=_('Navigation Reference - True / Magnetic'),category=_('F-22 Navigation')},
 {down=10940,up=10940,value_down=1,value_up=0,cockpit_device_id=25,name=_('Navigation GPS Aiding - Toggle Simulator Model'),category=_('F-22 Navigation')},
 {down=10941,up=10941,value_down=1,value_up=0,cockpit_device_id=25,name=_('Navigation Course - Resume Route Leg'),category=_('F-22 Navigation')},
 {down=10942,up=10942,value_down=1,value_up=0,cockpit_device_id=25,name=_('INS - Restart Ground Alignment'),category=_('F-22 Navigation')},
 {down=10950,up=10950,value_down=1,value_up=0,cockpit_device_id=25,name=_('Autopilot - Barometric Altitude Hold'),category=_('F-22 Autopilot')},
 {down=10951,up=10951,value_down=1,value_up=0,cockpit_device_id=25,name=_('Autopilot - Attitude Hold Toggle'),category=_('F-22 Autopilot')},
 {down=10952,up=10952,value_down=1,value_up=0,cockpit_device_id=25,name=_('Autothrottle - Calibrated Airspeed Hold'),category=_('F-22 Autopilot')},
 {down=10953,up=10953,value_down=1,value_up=0,cockpit_device_id=25,name=_('Autopilot and Autothrottle - Disengage'),category=_('F-22 Autopilot')},
 {down=10954,up=10954,value_down=1,value_up=0,cockpit_device_id=25,name=_('Autopilot - Heading Select'),category=_('F-22 Autopilot')},
 {down=10955,up=10955,value_down=1,value_up=0,cockpit_device_id=25,name=_('Autopilot - Navigation Coupled'),category=_('F-22 Autopilot')},
 {down=10956,up=10956,value_down=1,value_up=0,cockpit_device_id=25,name=_('Autopilot Selected Heading - Decrease 1 Degree'),category=_('F-22 Autopilot')},
 {down=10957,up=10957,value_down=1,value_up=0,cockpit_device_id=25,name=_('Autopilot Selected Heading - Increase 1 Degree'),category=_('F-22 Autopilot')},
 {down=10958,up=10958,value_down=1,value_up=0,cockpit_device_id=25,name=_('Autopilot Selected Altitude - Decrease 100 Feet'),category=_('F-22 Autopilot')},
 {down=10959,up=10959,value_down=1,value_up=0,cockpit_device_id=25,name=_('Autopilot Selected Altitude - Increase 100 Feet'),category=_('F-22 Autopilot')},
 {down=10960,up=10960,value_down=1,value_up=0,cockpit_device_id=25,name=_('Autopilot - Radar Altitude Hold'),category=_('F-22 Autopilot')},
 {down=10963,up=10963,value_down=1,value_up=0,cockpit_device_id=25,name=_('Autopilot Vertical Speed - Decrease 100 FPM'),category=_('F-22 Autopilot')},
 {down=10964,up=10964,value_down=1,value_up=0,cockpit_device_id=25,name=_('Autopilot Vertical Speed - Increase 100 FPM'),category=_('F-22 Autopilot')},
 {down=10965,up=10965,value_down=1,value_up=0,cockpit_device_id=25,name=_('Autothrottle Selected Speed - Decrease 5 Knots or 0.01 Mach'),category=_('F-22 Autopilot')},
 {down=10966,up=10966,value_down=1,value_up=0,cockpit_device_id=25,name=_('Autothrottle Selected Speed - Increase 5 Knots or 0.01 Mach'),category=_('F-22 Autopilot')},
 {down=10967,up=10967,value_down=1,value_up=0,cockpit_device_id=25,name=_('Autopilot Selected Heading - Sync Current Heading'),category=_('F-22 Autopilot')},
 {down=10968,up=10968,value_down=1,value_up=0,cockpit_device_id=25,name=_('Autothrottle - Mach Hold'),category=_('F-22 Autopilot')},
 {down=10969,up=10969,value_down=1,value_up=0,cockpit_device_id=25,name=_('Autopilot - Vertical Speed Hold'),category=_('F-22 Autopilot')},
 {down=10961,up=10962,value_down=1,value_up=1,cockpit_device_id=25,name=_('Autopilot Override Paddle - Hold / Release'),category=_('F-22 Autopilot')},
})
join(res.keyCommands,{
 {down=10838,up=10838,value_down=1,value_up=0,cockpit_device_id=8,name=_('Navigation - Store Own Position Markpoint'),category=_('F-22 Navigation')},
 {down=10840,up=10840,value_down=1,value_up=0,cockpit_device_id=8,name=_('Navigation - Undo Last Coordinate Edit or Markpoint'),category=_('F-22 Navigation')},
})
join(res.keyCommands,{
 {down=10841,up=10841,value_down=1,value_up=0,cockpit_device_id=8,name=_('Navigation - WPDSG Designate Selected Waypoint as Target'),category=_('F-22 Navigation')},
 {down=10842,up=10842,value_down=1,value_up=0,cockpit_device_id=8,name=_('Navigation - Undesignate Target / Return to Waypoint'),category=_('F-22 Navigation')},
 {down=10943,up=10943,value_down=1,value_up=0,cockpit_device_id=25,name=_('Navigation Source - Waypoint'),category=_('F-22 Navigation')},
 {down=10944,up=10944,value_down=1,value_up=0,cockpit_device_id=25,name=_('Navigation Source - TACAN'),category=_('F-22 Navigation')},
 {down=10945,up=10945,value_down=1,value_up=0,cockpit_device_id=25,name=_('Navigation Source - ILS'),category=_('F-22 Navigation')},
})

-- Altimetry and pilot warnings; physical assignments remain pilot-selected.
join(res.keyCommands,{
 {down=11020,up=11020,value_down=1,value_up=0,cockpit_device_id=27,name=_('Altimeter - Standard Pressure / Restore QNH'),category=_('F-22 Altimetry')},
 {down=11021,up=11021,value_down=1,value_up=0,cockpit_device_id=27,name=_('Altimeter Pressure - Increase'),category=_('F-22 Altimetry')},
 {down=11022,up=11022,value_down=1,value_up=0,cockpit_device_id=27,name=_('Altimeter Pressure - Decrease'),category=_('F-22 Altimetry')},
 {down=11023,up=11023,value_down=1,value_up=0,cockpit_device_id=27,name=_('Altimeter Pressure Units - INHG / HPA'),category=_('F-22 Altimetry')},
 {down=11000,up=11000,value_down=1,value_up=0,cockpit_device_id=28,name=_('Pilot Caution - Acknowledge'),category=_('F-22 HOTAS - Stick')},
 {down=11001,up=11001,value_down=1,value_up=0,cockpit_device_id=28,name=_('Pilot Warning Voice - Test / Cancel'),category=_('F-22 Warnings')},
 {down=11002,up=11002,value_down=1,value_up=0,cockpit_device_id=28,name=_('Pilot Warning Voice - Volume Increase'),category=_('F-22 Warnings')},
 {down=11003,up=11003,value_down=1,value_up=0,cockpit_device_id=28,name=_('Pilot Warning Voice - Volume Decrease'),category=_('F-22 Warnings')},
 {down=11004,up=11004,value_down=1,value_up=0,cockpit_device_id=28,name=_('Pilot Warning Voice - Mute / Unmute'),category=_('F-22 Warnings')},
})

-- Independent native datalink terminal; bind to controls as desired.
join(res.keyCommands,{
 {down=10917,up=10917,value_down=1,value_up=0,cockpit_device_id=18,name=_('Datalink - Receive On / Off'),category=_('F-22 Datalink')},
 {down=10918,up=10918,value_down=1,value_up=0,cockpit_device_id=18,name=_('IFDL - Transmit / Receive On / Off'),category=_('F-22 Datalink')},
})

join(res.keyCommands,{
 {down=10638,up=10638,value_down=1,value_up=0,cockpit_device_id=14,name=_('A/G Radar - SIL Toggle'),category=_('F-22 Ground Radar')},
 {down=10639,up=10639,value_down=1,value_up=0,cockpit_device_id=14,name=_('A/G Radar - ACTIVE One Scan'),category=_('F-22 Ground Radar')},
 {down=10640,up=10640,value_down=1,value_up=0,cockpit_device_id=14,name=_('A/G Radar - DATA Toggle'),category=_('F-22 Ground Radar')},
 {down=10641,up=10641,value_down=1,value_up=0,cockpit_device_id=14,name=_('A/G Radar - Gain Increase'),category=_('F-22 Ground Radar')},
 {down=10642,up=10642,value_down=1,value_up=0,cockpit_device_id=14,name=_('A/G Radar - Gain Decrease'),category=_('F-22 Ground Radar')},
 {down=10643,up=10643,value_down=1,value_up=0,cockpit_device_id=14,name=_('A/G Radar - FAST Toggle'),category=_('F-22 Ground Radar')},
 {down=10644,up=10644,value_down=1,value_up=0,cockpit_device_id=14,name=_('A/G Radar - PEN / FAN'),category=_('F-22 Ground Radar')},
 {down=10645,up=10645,value_down=1,value_up=0,cockpit_device_id=14,name=_('A/G Radar - Reset'),category=_('F-22 Ground Radar')},
 {down=10646,up=10646,value_down=1,value_up=0,cockpit_device_id=14,name=_('A/G Radar - Select EXP1 Corral'),category=_('F-22 Ground Radar')},
 {down=10647,up=10647,value_down=1,value_up=0,cockpit_device_id=14,name=_('A/G Radar - Select EXP2 Corral'),category=_('F-22 Ground Radar')},
 {down=10648,up=10648,value_down=1,value_up=0,cockpit_device_id=14,name=_('A/G Radar - Select EXP3 Corral'),category=_('F-22 Ground Radar')},
 {down=10649,up=10649,value_down=1,value_up=0,cockpit_device_id=14,name=_('A/G Radar - SEA Mode'),category=_('F-22 Ground Radar')},
 {down=10650,up=10650,value_down=1,value_up=0,cockpit_device_id=14,name=_('A/G Radar - TA Mode'),category=_('F-22 Ground Radar')},
 {down=10651,up=10651,value_down=1,value_up=0,cockpit_device_id=14,name=_('A/G Radar - AGR Mode'),category=_('F-22 Ground Radar')},
})

-- Additional controls have no default combos; saved physical assignments remain intact.
join(res.keyCommands,{
 {down=11100,up=11100,value_down=1,value_up=0,cockpit_device_id=20,
  name=_('CM - Normal Selected Program'),category=_('F-22 Countermeasures')},
 {down=11101,up=11101,value_down=1,value_up=0,cockpit_device_id=20,
  name=_('CM - Direct Access Program'),category=_('F-22 Countermeasures')},
 {down=11109,up=11109,value_down=1,value_up=0,cockpit_device_id=20,
  name=_('CM - Self Test'),category=_('F-22 Countermeasures')},
 {down=11110,up=11110,value_down=1,value_up=0,cockpit_device_id=20,
  name=_('CM - Neutral Scripted Event (Test)'),category=_('F-22 Countermeasures')},
 {down=11113,up=11113,value_down=1,value_up=0,cockpit_device_id=20,
  name=_('CM - Stop Program'),category=_('F-22 Countermeasures')},
 {down=11130,up=11130,value_down=1,value_up=0,cockpit_device_id=18,
  name=_('IFF - Simulated Responder Toggle'),category=_('F-22 Identification')},
 {down=11131,up=11131,value_down=1,value_up=0,cockpit_device_id=18,
  name=_('IFF - Simulated Emergency ID Toggle'),category=_('F-22 Identification')},
 {down=11132,up=11132,value_down=1,value_up=0,cockpit_device_id=18,
  name=_('IFF - Neutral Game Interrogation (Test)'),category=_('F-22 Identification')},
 {down=11120,up=11120,value_down=1,value_up=0,cockpit_device_id=4,
  name=_('Stores - Simulation Mode'),category=_('F-22 Weapons')},
        {down = 11700, name = _('Alternate Landing Gear Extension (SES)'), category = _('F-22A Systems')},
        {down = 11701, value_down = 1, name = _('Nosewheel Steering Select'), category = _('F-22A Systems')},
        {down = 11701, value_down = 0, name = _('Nosewheel Steering Deselect'), category = _('F-22A Systems')},
        {down = 11702, value_down = 1, name = _('Arresting Hook Extend'), category = _('F-22A Systems')},
        {down = 11702, value_down = 0, name = _('Arresting Hook Retract'), category = _('F-22A Systems')},
        {down = 11703, name = _('Left Engine Fire Isolation'), category = _('F-22A Systems')},
        {down = 11704, name = _('Right Engine Fire Isolation'), category = _('F-22A Systems')},
        {down = 11705, name = _('Selected Engine Fire Bottle Discharge'), category = _('F-22A Systems')},
        {down = 11706, name = _('Ground Service SES and Oxygen Reserves'), category = _('F-22A Systems')},
        {down = 11707, value_down = 1, name = _('Left Engine Bleed On'), category = _('F-22A Systems')},
        {down = 11707, value_down = 0, name = _('Left Engine Bleed Off'), category = _('F-22A Systems')},
        {down = 11708, value_down = 1, name = _('Right Engine Bleed On'), category = _('F-22A Systems')},
        {down = 11708, value_down = 0, name = _('Right Engine Bleed Off'), category = _('F-22A Systems')},
        {down = 11709, value_down = 1, name = _('ECS On'), category = _('F-22A Systems')},
        {down = 11709, value_down = 0, name = _('ECS Off'), category = _('F-22A Systems')},
        {down = 11710, value_down = 1, name = _('Defog On'), category = _('F-22A Systems')},
        {down = 11710, value_down = 0, name = _('Defog Off'), category = _('F-22A Systems')},
        {down = 11711, value_down = 1, name = _('Manual Backup Oxygen On'), category = _('F-22A Systems')},
        {down = 11711, value_down = 0, name = _('Manual Backup Oxygen Off'), category = _('F-22A Systems')},
        {down = 11714, value_down = 100, name = _('Bingo Fuel Increase 100 kg'), category = _('F-22A Systems')},
        {down = 11714, value_down = -100, name = _('Bingo Fuel Decrease 100 kg'), category = _('F-22A Systems')},

        {down = 11716, name = _('Ground Service Hydraulic Fluid'), category = _('F-22A Systems')},
        {down = 11717, name = _('Ground Tow Brake Pressure Service'), category = _('F-22A Systems')},
        {down = 11718, value_down = 1, name = _('Ground Maintenance Hydraulic Transfer On'), category = _('F-22A Systems')},
        {down = 11718, value_down = 0, name = _('Ground Maintenance Hydraulic Transfer Off'), category = _('F-22A Systems')},
        {down = 11719, value_down = 1, name = _('Left Engine Starter On'), category = _('F-22A Engine Start')},
        {down = 11719, value_down = 0, name = _('Left Engine Starter Off'), category = _('F-22A Engine Start')},
        {down = 11720, value_down = 1, name = _('Right Engine Starter On'), category = _('F-22A Engine Start')},
        {down = 11720, value_down = 0, name = _('Right Engine Starter Off'), category = _('F-22A Engine Start')},
        {down = 11721, value_down = 1, name = _('Left Engine Fuel On'), category = _('F-22A Engine Start')},
        {down = 11721, value_down = 0, name = _('Left Engine Fuel Off'), category = _('F-22A Engine Start')},
        {down = 11722, value_down = 1, name = _('Right Engine Fuel On'), category = _('F-22A Engine Start')},
        {down = 11722, value_down = 0, name = _('Right Engine Fuel Off'), category = _('F-22A Engine Start')},
        {down = 11723, value_down = 1, name = _('Left Engine Ignition On'), category = _('F-22A Engine Start')},
        {down = 11723, value_down = 0, name = _('Left Engine Ignition Off'), category = _('F-22A Engine Start')},
        {down = 11724, value_down = 1, name = _('Right Engine Ignition On'), category = _('F-22A Engine Start')},
        {down = 11724, value_down = 0, name = _('Right Engine Ignition Off'), category = _('F-22A Engine Start')},
        {down = 11725, value_down = 1, name = _('Left Engine Start Fault Reset'), category = _('F-22A Engine Start')},
        {down = 11726, value_down = 1, name = _('Right Engine Start Fault Reset'), category = _('F-22A Engine Start')},
})

return res
