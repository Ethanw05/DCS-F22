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

local sensor_data = get_base_data()
local update_time_step = 0.006
make_default_activity(update_time_step)

local parameters =
{
	-- Engine
	APU_POWER			 = get_param_handle("APU_POWER"),
	APU_RPM_STATE		 = get_param_handle("APU_RPM_STATE"),
	BATTERY_POWER		 = get_param_handle("BATTERY_POWER"),
	MAIN_POWER		     = get_param_handle("MAIN_POWER"),
	L_GEN_POWER			 = get_param_handle ("L_GEN_POWER"),
	R_GEN_POWER			 = get_param_handle ("R_GEN_POWER"),

	-- Indicator
	UFD_OPACITY		     = get_param_handle("UFD_OPACITY"),
	MFD_OPACITY		     = get_param_handle("MFD_OPACITY"),
	ICP_OPACITY		     = get_param_handle("ICP_OPACITY"),
	R_ADI_OPACITY     	 = get_param_handle("R_ADI_OPACITY"),
	R_WAR_OPACITY 		 = get_param_handle("R_WAR_OPACITY"),
	L_ADI_OPACITY     	 = get_param_handle("L_ADI_OPACITY"),
	L_WAR_OPACITY 		 = get_param_handle("L_WAR_OPACITY"),
	TAS				     = get_param_handle("TAS"),
	IAS				     = get_param_handle("IAS"),
	GFORCE			     = get_param_handle("GFORCE"),
	AOA			     	 = get_param_handle("AOA"),
	VV			     	 = get_param_handle("VV"),
	ADI_PITCH 		     = get_param_handle("ADIPITCH"),
	ADI_ROLL			 = get_param_handle("ADIROLL"),
	SLIP				 = get_param_handle("SLIP"),
	YAW				     = get_param_handle("YAW"),
	ROLLRATE			 = get_param_handle("ROLLRATE"),
	NAV                  = get_param_handle("NAV"),
	BARO 				 = get_param_handle("BAROALT"),
	RADALT			     = get_param_handle("RADALT"),
	RPM_L                = get_param_handle("RPM_L"),
	RPM_R                = get_param_handle("RPM_R"),
	EGT_L                = get_param_handle("EGT_L"),
	EGT_R                = get_param_handle("EGT_R"),
	FUELL                = get_param_handle("FUELL"),
	FUEL                 = get_param_handle("FUEL"),
	FUELT                = get_param_handle("FUELT"),
	FUELTANK             = get_param_handle("FUELTANK"),
	FLOOD_LIGHT 		 = get_param_handle("FLOOD_LIGHT"),
	PANEL_LIGHT 		 = get_param_handle("PANEL_LIGHT"),	
	CANOPY_LIGHT 		 = get_param_handle("CANOPY_LIGHT"),	
	CHAFF_LIGHT   	     = get_param_handle("CHAFF_LIGHT"),	
	FLARE_LIGHT   	     = get_param_handle("FLARE_LIGHT"),	
	SPD_BRK_LIGHT 	     = get_param_handle("SPD_BRK_LIGHT"),	
	BINGO_LIGHT   	     = get_param_handle("BINGO_LIGHT"),	
	FLAPS_MOVE 		     = get_param_handle("FLAPS_MOVE"),	
	FLAPS_DOWN		     = get_param_handle("FLAPS_DOWN"),	
	AAR_LIGHT 		     = get_param_handle("AAR_LIGHT"),	
	L_FIRE_LIGHT 		 = get_param_handle("L_FIRE_LIGHT"),	
	R_FIRE_LIGHT 		 = get_param_handle("R_FIRE_LIGHT"),	
	L_GEN_OUT 		     = get_param_handle("L_GEN_OUT"),	
	R_GEN_OUT 		     = get_param_handle("R_GEN_OUT"),	
	HYD_LIGHT 		     = get_param_handle("HYD_LIGHT"),	
	CAUTION_LIGHT		 = get_param_handle("CAUTION_LIGHT"),	
	OIL_LIGHT			 = get_param_handle("OIL_LIGHT"),
	APU_READY			 = get_param_handle("APU_READY"),
	APU_SPOOL			 = get_param_handle("APU_SPOOL"),
	L_OIL_COLOR	     	 = get_param_handle("L_OIL_COLOR"),
	R_OIL_COLOR	     	 = get_param_handle("R_OIL_COLOR"),
	L_HYD_COLOR			 = get_param_handle("L_HYD_COLOR"),
	R_HYD_COLOR			 = get_param_handle("R_HYD_COLOR"),

	LMFD_ENG_PAGE        = get_param_handle("LMFD_ENG_PAGE"),
	LMFD_MENU_PAGE       = get_param_handle("LMFD_MENU_PAGE"),
	LMFD_FCS_PAGE        = get_param_handle("LMFD_FCS_PAGE"),
	LMFD_FUEL_PAGE       = get_param_handle("LMFD_FUEL_PAGE"),
	LMFD_ADI_PAGE        = get_param_handle("LMFD_ADI_PAGE"),
	LMFD_BAY_PAGE        = get_param_handle("LMFD_BAY_PAGE"),
	LMFD_CHECKLIST_PAGE  = get_param_handle("LMFD_CHECKLIST_PAGE"),
	LMFD_SMS_PAGE        = get_param_handle("LMFD_SMS_PAGE"),
	LMFD_HSI_PAGE        = get_param_handle("LMFD_HSI_PAGE"),
 	LMFD_PAGE            = get_param_handle("LMFD_PAGE"),
	LMFD_MASK            = get_param_handle("LMFD_MASK"),
	RMFD_MASK            = get_param_handle("RMFD_MASK"),
	PMFD_MASK            = get_param_handle("PMFD_MASK"),
	RMFD_BLANK_PAGE  	 = get_param_handle("RMFD_BLANK_PAGE"),
	CMFD_BLANK_PAGE      = get_param_handle("CMFD_BLANK_PAGE"),
	DAY_NIGHT	         = get_param_handle("DAY_NIGHT"),
	MACH	         	 = get_param_handle("MACH"),
	PITCHRATE	         = get_param_handle("PITCHRATE"),
    YAWRATE	         	 = get_param_handle("YAWRATE"),

    HUD_MODE			 = get_param_handle("HUD_MODE"),
    FCS_AUTO             = get_param_handle("FCS_AUTO"),
    FCS_MODE             = get_param_handle("FCS_MODE"),
    FCS_STATE            = get_param_handle("FCS_STATE"),
}

local fcs_state = 0 --track if fcs_state is on or off
local fcs_mode = 0  -- 0 = AUTO - 1 = AOA Mode - 2 = G Mode - 3 = OFF
local fcs_auto = 1  -- 0 = OFF - 1 = AUTO

function post_initialize()
    -- print_message_to_user("FCS INIT")
        fcs_state = 0
        fcs_auto = 1
        fcs_mode = 0
end

function update()
    parameters.FCS_STATE:set(fcs_state)
    parameters.FCS_AUTO:set(fcs_auto)
    parameters.FCS_MODE:set(fcs_mode)

    local LEF_POS = get_aircraft_draw_argument_value(603)
    if parameters.MAIN_POWER:get() == 1 then
       LEF_POS = parameters.AOA:get() * 0.05
       set_aircraft_draw_argument_value(603, LEF_POS)
    end
end

need_to_be_closed = false
