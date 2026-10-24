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
-- 0=MENU, 1=ENG, 2=FCS, 3=FUEL, 4=ADI, 5=BAY, 6=CHKLIST, 7=SMS, 8=HSI   
MENU    = 1
ENG		= 2
FCS 	= 3
FUEL	= 4
ADI		= 5
BAY		= 6
CHK		= 7
HSI		= 8
SMS		= 9

page_subsets  = {
	[MENU]   		= LockOn_Options.script_path.."MFD_LEFT/menu_page.lua",
	[ENG]    		= LockOn_Options.script_path.."MFD_LEFT/eng_page.lua",
	[FCS]   		= LockOn_Options.script_path.."MFD_LEFT/fcs_page.lua",
	[FUEL]    		= LockOn_Options.script_path.."MFD_LEFT/fuel_page.lua",
	[ADI]   		= LockOn_Options.script_path.."MFD_LEFT/adi_page.lua",
	[BAY]    		= LockOn_Options.script_path.."MFD_LEFT/bay_page.lua",
	[CHK]   		= LockOn_Options.script_path.."MFD_LEFT/checklist_page.lua",
	[HSI]    		= LockOn_Options.script_path.."MFD_LEFT/hsi_page.lua",
	[SMS]    		= LockOn_Options.script_path.."MFD_LEFT/sms_page.lua",

}
pages = 
{
	{
	 
		MENU,
		ENG,
		FCS, 
		FUEL,
		ADI, 
		BAY, 
		CHK, 
		HSI, 
		SMS, 
		
	
	 },
}
