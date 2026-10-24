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


dofile(LockOn_Options.common_script_path.."devices_defs.lua")

indicator_type = indicator_types.COMMON
purposes 	 = {render_purpose.GENERAL}
init_pageID		= 1

-------PAGE IDs-------
MENU   		= 1
RADAR  		= 2
CONFIG		= 3
SYS			= 4
MAP 		= 5
SFM			= 6
BLANK		= 7

--INDICATION = 2

page_subsets  = {
[MENU]    		= LockOn_Options.script_path.."PMFD_CENTER/menu_page.lua",
[RADAR]			= LockOn_Options.script_path.."PMFD_CENTER/radar_page.lua",
[CONFIG]		= LockOn_Options.script_path.."PMFD_CENTER/config_page.lua",
[SYS]			= LockOn_Options.script_path.."PMFD_CENTER/sys_page.lua",
[MAP]  		    = LockOn_Options.script_path.."PMFD_CENTER/map_page.lua",
[SFM]  		    = LockOn_Options.script_path.."PMFD_CENTER/sfm_page.lua",
[BLANK]  		= LockOn_Options.script_path.."PMFD_CENTER/blank_page.lua",
}

pages = 
{
	{
	 MENU,
	 RADAR,
	 CONFIG,		
	 SYS,	
	 MAP,	
	 SFM,
	 BLANK,
	},
}
