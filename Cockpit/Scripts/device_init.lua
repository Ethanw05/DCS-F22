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


mount_vfs_texture_archives("Bazar/Textures/AvionicsCommon")

dofile(LockOn_Options.common_script_path.."tools.lua")
dofile(LockOn_Options.script_path.."devices.lua")
dofile(LockOn_Options.script_path.."materials.lua")
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
layoutGeometry = {}
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
MainPanel = {"ccMainPanel",LockOn_Options.script_path.."mainpanel_init.lua"}
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
attributes = {
	"support_for_cws",
}
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
creators = {}
creators[devices.AVIONICS]			 	 = {"avLuaDevice"		    ,LockOn_Options.script_path.."Systems/Avionics.lua"}
creators[devices.ELECTRICAL_SYSTEM]		 = {"avLuaDevice"		    ,LockOn_Options.script_path.."Systems/Electrical_System.lua"}
creators[devices.ENGINE_SYSTEM]			 = {"avLuaDevice"		    ,LockOn_Options.script_path.."Systems/Engine_System.lua"}
creators[devices.WEAPON_SYSTEM]			 = {"avLuaDevice"		    ,LockOn_Options.script_path.."Systems/Weapon_System.lua"}
creators[devices.MFD_SYSTEM]			 = {"avLuaDevice"		    ,LockOn_Options.script_path.."Systems/MFD_System.lua"}
creators[devices.PMFD_SYSTEM]			 = {"avLuaDevice"		    ,LockOn_Options.script_path.."Systems/PMFD_System.lua"}
creators[devices.ICP_SYSTEM]			 = {"avLuaDevice"		    ,LockOn_Options.script_path.."Systems/ICP_System.lua"}
creators[devices.ILS_NATIVE] = {"avILS", LockOn_Options.script_path.."Systems/ILS_Native.lua"}
creators[devices.NAV_POWER_NATIVE] = {"avSimpleElectricSystem", LockOn_Options.script_path.."Systems/Navigation_Power.lua"}
creators[devices.FLIGHT_GUIDANCE] = {"avLuaDevice", LockOn_Options.script_path.."Systems/Flight_Guidance.lua"}
creators[devices.NAV_SYSTEM] = {"avLuaDevice", LockOn_Options.script_path.."Systems/Navigation_System.lua"}
creators[devices.AG_MARK_SYSTEM] = {"avLuaDevice", LockOn_Options.script_path.."Systems/AG_Mark_System.lua"}
creators[devices.RADAR_DATA_BRIDGE] = {"avLuaDevice", LockOn_Options.script_path.."Systems/Radar_Data_Bridge.lua"}
creators[devices.AG_BALLISTIC_COMPUTER] = {"avLuaDevice", LockOn_Options.script_path.."Systems/AG_Ballistic_Computer.lua"}
creators[devices.HUD_FLIGHT_DATA] = {"avLuaDevice", LockOn_Options.script_path.."Systems/HUD_Flight_Data.lua"}
local radar_config=dofile(LockOn_Options.script_path.."Systems/Radar_Config.lua")
if radar_config.native_backend_enabled then
    creators[devices.RADAR_NATIVE] = {"avSimpleRadar", LockOn_Options.script_path.."Systems/Radar_Native.lua"}
end
creators[devices.RADAR_COMPUTER] = {"avLuaDevice", LockOn_Options.script_path.."Systems/Radar_System.lua"}
creators[devices.WEAPON_NATIVE] = {"avSimpleWeaponSystem", LockOn_Options.script_path.."Systems/Weapon_Native.lua"}
creators[devices.COMBAT_SYSTEM] = {"avLuaDevice", LockOn_Options.script_path.."Systems/Combat_System.lua"}
creators[devices.RWR_NATIVE] = {"avSimpleRWR", LockOn_Options.script_path.."Systems/RWR_Native.lua"}
creators[devices.RWR_SYSTEM] = {"avLuaDevice", LockOn_Options.script_path.."Systems/RWR_System.lua"}
creators[devices.ENGAGEMENT_SYSTEM] = {"avLuaDevice", LockOn_Options.script_path.."Systems/Engagement_System.lua"}
creators[devices.EW_SYSTEM] = {"avLuaDevice", LockOn_Options.script_path.."Systems/EW_System.lua"}
creators[devices.MWS_NATIVE] = {"avMLWS", LockOn_Options.script_path.."Systems/MWS_Native.lua"}
creators[devices.MWS_SYSTEM] = {"avLuaDevice", LockOn_Options.script_path.."Systems/MWS_System.lua"}
creators[devices.ALTITUDE_SYSTEM] = {"avLuaDevice", LockOn_Options.script_path.."Systems/Altitude_System.lua"}
creators[devices.PILOT_WARNING_SYSTEM] = {"avLuaDevice", LockOn_Options.script_path.."Systems/Pilot_Warning_System.lua"}

--creators[devices.KNEEBOARD] = {"avKneeboard",LockOn_Options.common_script_path.."KNEEBOARD/device/init.lua"}

indicators = {}
-- The shipped EDM has no HUD-CENTER/DOWN/RIGHT connector triplet.
-- Use explicit cockpit geometry until editable HUD anchors are available.
-- Position and optical alignment still require a 2D/VR in-game check.
indicators[#indicators + 1] = {"ccIndicator", LockOn_Options.script_path.."HUD/init.lua",
    nil,
    {
        {},
        {sx = 0.0, sy = 0.0, sz = 0.0, sw = 0.14, sh = 0.12,
         rx = 0, ry = 0, rz = 0}
    }
}
--PFD LEFT
indicators[#indicators + 1] = {"ccIndicator", LockOn_Options.script_path.."UFD_LEFT/init.lua",
	nil,
	{
		{"LEFT-PFD-CENTER", "LEFT-PFD-DOWN", "LEFT-PFD-RIGHT"}
	}
}
--PFD RIGHT
indicators[#indicators + 1] = {"ccIndicator", LockOn_Options.script_path.."UFD_RIGHT/init.lua",
	nil,
	{
		{"RIGHT-PFD-CENTER", "RIGHT-PFD-DOWN", "RIGHT-PFD-RIGHT"}
	}
}
--ICP
indicators[#indicators + 1] = {"ccIndicator", LockOn_Options.script_path.."ICP/init.lua",
	nil,
	{
		{"ICP_DISPLAY_CENTER", "ICP_DISPLAY_BOTTOM", "ICP_DISPLAY_RIGHT"}
	}
}
--MFD CENTER
indicators[#indicators + 1] = {"ccIndicator", LockOn_Options.script_path.."MFD_CENTER/init.lua",
	nil,
	{
		{"MFD-CENTER", "MFD-DOWN", "MFD-RIGHT"}
	}
}
--MFD RIGHT
indicators[#indicators + 1] = {"ccIndicator", LockOn_Options.script_path.."MFD_RIGHT/init.lua",
	nil,
	{
		{"RIGHT-MFD-CENTER", "RIGHT-MFD-DOWN", "RIGHT-MFD-RIGHT"}
	}
}
--MFD LEFT
indicators[#indicators + 1] = {"ccIndicator", LockOn_Options.script_path.."MFD_LEFT/init.lua",
	nil,
	{
		{"LEFT-MFD-CENTER", "LEFT-MFD-DOWN", "LEFT-MFD-RIGHT"}
	}
}
-- Create the native render_target_9 material (target8 is zero-based) before the display consumers.
indicators[#indicators + 1] = {"ccIndicator", LockOn_Options.script_path.."Systems/AG_Radar_Video/init.lua", devices.RADAR_COMPUTER}

--PMFD CENTER
indicators[#indicators + 1] = {"ccIndicator", LockOn_Options.script_path.."PMFD_CENTER/init.lua",
	nil,
	{
		{"PMFD-CENTER", "PMFD-DOWN", "PMFD-RIGHT"}
	}
}
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
dofile(LockOn_Options.common_script_path.."KNEEBOARD/declare_kneeboard_device.lua")
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


