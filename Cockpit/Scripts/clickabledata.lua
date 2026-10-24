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


dofile(LockOn_Options.script_path.."command_defs.lua")
dofile(LockOn_Options.script_path.."devices.lua")
--dofile(LockOn_Options.script_path.."sounds.lua")

local gettext = require("i_18n")
_ = gettext.translate

cursor_mode = 
{ 
    CUMODE_CLICKABLE = 0,
    CUMODE_CLICKABLE_AND_CAMERA  = 1,
    CUMODE_CAMERA = 2,
};

clickable_mode_initial_status  = cursor_mode.CUMODE_CLICKABLE
use_pointer_name			   = true

function default_button(hint_,device_,command_,arg_,arg_val_,arg_lim_)

	local   arg_val_ = arg_val_ or 1
	local   arg_lim_ = arg_lim_ or {0,1}

	return  {	
				class 				= {class_type.BTN},
				hint  				= hint_,
				device 				= device_,
				action 				= {command_},
				stop_action 		= {command_},
				arg 				= {arg_},
				arg_value			= {arg_val_}, 
				arg_lim 			= {arg_lim_},
				use_release_message = {false},
				updatable 	= true, 
			}
end

-- default_1_position_tumb = bouton 2 positions 0 et 1 souris gauche, souris droite inop�rante
function default_1_position_tumb(hint_, device_, command_, arg_, arg_val_, arg_lim_, sound_)
	local   arg_val_ = arg_val_ or 1
	local   arg_lim_ = arg_lim_ or {0,1}
	return  {	
				class 		= {class_type.TUMB},
				hint  		= hint_,
				device 		= device_,
				action 		= {command_},
				arg 	  	= {arg_},
				arg_value 	= {arg_val_}, 
				arg_lim   	= {arg_lim_},
				updatable 	= true, 
				use_OBB 	= true,
				sound = sound_ and {{sound_,sound_}} or nil
			}
end

-- default_2_position_tumb = bouton 2 positions 0 et 1 souris gauche ou souris droite indiff�remment
function default_2_position_tumb(hint_, device_, command_, arg_, sound_)
	return  {	
				class 		= {class_type.TUMB,class_type.TUMB},
				hint  		= hint_,
				device 		= device_,
				action 		= {command_,command_},
				arg 	  	= {arg_,arg_},
				arg_value 	= {-1,1}, 
				arg_lim   	= {{0,1},{0,1}},
				updatable 	= true, 
				use_OBB 	= true,
				sound = sound_ and {{sound_,sound_}} or nil
			}
end

-- default_3_position_tumb = bouton 3 positions -1,0,1 souris gauche ou souris droite indiff�remment
function default_3_position_tumb(hint_,device_,command_,arg_,cycled_,inversed_)
	local cycled = true
	local val =  1
	if inversed_ then
	      val = -1
	end
	if cycled_ ~= nil then
	   cycled = cycled_
	end
	return  {	
				class 		= {class_type.TUMB,class_type.TUMB},
				hint  		= hint_,
				device 		= device_,
				action 		= {command_,command_},
				arg 	  	= {arg_,arg_},
				arg_value 	= {val,-val}, 
				arg_lim   	= {{-1,1},{-1,1}},
				updatable 	= true, 
				use_OBB 	= true,
				cycle       = cycled
			}
end

-- default_axis = bouton rotatif
-- relative_ important
-- de 0 � 1
function default_axis(hint_,device_,command_,arg_, default_, gain_,updatable_,relative_)
	
	local default = default_ or 1
	local gain = gain_ or 0.1
	local updatable = updatable_ or false
	local relative  = relative_ or false
	
	return  {	
				class 		= {class_type.LEV},
				hint  		= hint_,
				device 		= device_,
				action 		= {command_},
				arg 	  	= {arg_},
				arg_value 	= {default}, 
				arg_lim   	= {{0,1}},
				updatable 	= updatable, 
				use_OBB 	= true,
				gain		= {gain},
				relative    = {relative}, 				
			}
end

-- default_movable_axis se d�place avec la souris gauche et renvoie la valeur atteinte
-- default_ mieux si �gal � 0
-- de 0 � 1
function default_movable_axis(hint_,device_,command_,arg_, default_, gain_,updatable_,relative_)
	
	local default = default_ or 1
	local gain = gain_ or 0.1
	local updatable = updatable_ or false
	local relative  = relative_ or false
	
	return  {	
				class 		= {class_type.MOVABLE_LEV},
				hint  		= hint_,
				device 		= device_,
				action 		= {command_},
				arg 	  	= {arg_},
				arg_value 	= {default}, 
				arg_lim   	= {{0,1}},
				updatable 	= updatable, 
				use_OBB 	= true,
				gain		= {gain},
				relative    = {relative}, 				
			}
end

-- default_axis_limited = bouton rotatif
-- relative_ important
-- arg_lim definissable
--[[function default_axis_limited(hint_,device_,command_,arg_, default_, gain_,updatable_,relative_, arg_lim_)
	
	local relative = false
	local default = default_ or 0
	local updatable = updatable_ or false
	if relative_ ~= nil then
		relative = relative_
	end

	local gain = gain_ or 0.1
	return  {	
				class 		= {class_type.LEV},
				hint  		= hint_,
				device 		= device_,
				action 		= {command_},
				arg 	  	= {arg_},
				arg_value 	= {default}, 
				arg_lim   	= {arg_lim_},
				updatable 	= updatable, 
				use_OBB 	= false,
				gain		= {gain},
				relative    = {relative},  
			}
end]]

function default_axis_limited(hint_,device_,command_,arg_, default_, gain_,updatable_,relative_, arg_lim_)
	
	
	local default = default_ or 0
	local gain = gain_ or 0.1
	local updatable = updatable_ or false
	local relative  = relative_ or false
	--[[
	local relative = false
	if relative_ ~= nil then
		relative = relative_
	end
	]]

	return  {	
				class 		= {class_type.LEV},
				hint  		= hint_,
				device 		= device_,
				action 		= {command_},
				arg 	  	= {arg_},
				arg_value 	= {default}, 
				arg_lim   	= {arg_lim_},
				updatable 	= updatable, 
				use_OBB 	= true,--false,
				gain		= {gain},
				relative    = {relative},
				cycle     	= false,
			}
end
-- multiposition_switch = bouton multi-position
-- count_ = nb positions
-- delta_ = valeur entre deux positions
function multiposition_switch(hint_,device_,command_,arg_,count_,delta_,inversed_, min_)
    local min_   = min_ or 0
	local delta_ = delta_ or 0.5
	
	local inversed = 1
	if	inversed_ then
		inversed = -1
	end
	
	return  {	
				class 		= {class_type.TUMB,class_type.TUMB},
				hint  		= hint_,
				device 		= device_,
				action 		= {command_,command_},
				arg 	  	= {arg_,arg_},
				arg_value 	= {-delta_ * inversed,delta_ * inversed}, 
				arg_lim   	= {{min_, min_ + delta_ * (count_ -1)},
							   {min_, min_ + delta_ * (count_ -1)}},
				updatable 	= true, 
				use_OBB 	= true
			}
end
-- multiposition_switch_limited = bouton multi-position non cycled
function multiposition_switch_limited(hint_,device_,command_,arg_,count_,delta_,inversed_,min_,sound_)
    local min_   = min_ or 0
	local delta_ = delta_ or 0.5
	
	local inversed = 1
	if	inversed_ then
		inversed = -1
	end
	
	return  {	
				class 		= {class_type.TUMB,class_type.TUMB},
				hint  		= hint_,
				device 		= device_,
				action 		= {command_,command_},
				arg 	  	= {arg_,arg_},
				arg_value 	= {-delta_ * inversed,delta_ * inversed}, 
				arg_lim   	= {{min_, min_ + delta_ * (count_ -1)},
							   {min_, min_ + delta_ * (count_ -1)}},
				updatable 	= true, 
				use_OBB 	= true,
				cycle     	= false, 
				sound = sound_ and {{sound_,sound_}} or nil
			}
end
-- default_button_axis = bouton rotatif � deux commandes ???
function default_button_axis(hint_, device_,command_1, command_2, arg_1, arg_2, limit_1, limit_2)
	local limit_1_   = limit_1 or 1.0
	local limit_2_   = limit_2 or 1.0
return {
			class		=	{class_type.BTN, class_type.LEV},
			hint		=	hint_,
			device		=	device_,
			action		=	{command_1, command_2},
			stop_action =   {command_1, 0},
			arg			=	{arg_1, arg_2},
			arg_value	= 	{1, 0.5},
			arg_lim		= 	{{0, limit_1_}, {0,limit_2_}},
			animated        = {false,true},
			animation_speed = {0, 0.4},
			gain = {0, 0.1},
			relative	= 	{false, true},
			updatable 	= 	true, 
			use_OBB 	= 	true,
			use_release_message = {true, false}
	}
end
-- default_animated_lever = levier anim�
-- animation_speed_ 0.5 plus lent que 0.8
-- la valeur n'est retourn�e qu'apr�s l'animation
function default_animated_lever(hint_, device_, command_, arg_, animation_speed_,arg_lim_)
local arg_lim__ = arg_lim_ or {0.0,1.0}
return  {	
	class  = {class_type.TUMB, class_type.TUMB},
	hint   	= hint_, 
	device 	= device_,
	action 	= {command_, command_},
	arg 		= {arg_, arg_},
	arg_value 	= {1, 0},
	arg_lim 	= {arg_lim__, arg_lim__},
	updatable  = true, 
	gain 		= {0.1, 0.1},
	animated 	= {true, true},
	animation_speed = {animation_speed_, 0},
	cycle = true
}
end
-- default_button_tumb = bouton � deux commandes
-- bouton gauche commande 1
-- bouton droit commande 2
-- stop_action = {command1_,0}, => le bouton gauche revient au 0, alors que le bouton droit non/ the left button returns to 0, while the right button does not
-- stop_action = {command1_,command2_}, => le bouton gauche et le bouton droit reviennent au 0/ left button and right button return to 0
function default_button_tumb(hint_, device_, command1_, command2_, arg_,style)
	if style == 1 or style == nil then
		stop_action_ = {command1_,0}
	elseif style == 2 then -- speedbrake
		stop_action_ = {command1_,command2_}
	end
	return  {	
				class 		= {class_type.BTN,class_type.TUMB},
				hint  		= hint_,
				device 		= device_,
				action 		= {command1_,command2_},
				stop_action = stop_action_,
				arg 	  	= {arg_,arg_},
				arg_value 	= {-1,1},
				arg_lim   	= {{-1,0},{0,1}},
				updatable 	= true, 
				use_OBB 	= true,
				use_release_message = {true,false}
			}
end

function Switch_Up_Down_Release(hint_, command_, arg_, sound_)
    return {
        class           = {class_type.TUMB, class_type.TUMB},
        hint            = hint_,
        device          = devices.ENGINE_SYSTEM,
		arg 			= {arg_, arg_},
        action          = {command_, command_}, --right click no | left yes up
        stop_action     = {nil, command_},
        arg_value       = {-1,1},
		arg_lim   		= {{-1,0},{0,1}},
        updatable       = true,
		sound = sound_ and {{sound_,sound_}} or nil
    }
end

elements = {}
--Engine System
	elements["BATTERY_PNT"] 	= default_2_position_tumb(_("Battery"), 				devices.ENGINE_SYSTEM, device_commands.Button_1, 700, TOGGLECLICK)
	elements["APU_PNT"] 		= Switch_Up_Down_Release(_("APU"), 						device_commands.Button_2, 701, TOGGLECLICK)
	elements["LGEN_PNT"] 		= default_2_position_tumb(_("Left Generator"), 		    devices.ENGINE_SYSTEM, device_commands.Button_3, 	702, 			 TOGGLECLICK)
	elements["RGEN_PNT"] 		= default_2_position_tumb(_("Right Generator"),		    devices.ENGINE_SYSTEM, device_commands.Button_4, 	703, 			 TOGGLECLICK)
	elements["LTHROT_PNT"] 	    = default_1_position_tumb(_("Left Engine Start"),   	devices.ENGINE_SYSTEM, device_commands.Button_9, 	999, 1, {0,1},   TOGGLECLICK)
	elements["RTHRT_PNT"] 	    = default_1_position_tumb(_("Right Engine Start"),   	devices.ENGINE_SYSTEM, device_commands.Button_10,	999, 1, {0,1},   TOGGLECLICK)
	elements["GEAR_PNT"] 	    = default_1_position_tumb(_("Landing Gear"),   			devices.ENGINE_SYSTEM, device_commands.Button_11,	999, 1, {0,1},   TOGGLECLICK)
	elements["PARK_PNT"] 	    = default_2_position_tumb(_("Parking Brake"),   		devices.ENGINE_SYSTEM, device_commands.Button_12,   710, 1, {0,1},   TOGGLECLICK)
--Electrical System
	elements["AAR_PNT"] 	    = default_2_position_tumb(_("Open/Close AAR Port"),   	devices.ELECTRICAL_SYSTEM, device_commands.Button_1,   712, 1, {0,1},   TOGGLECLICK)
	elements["AARLIGHT_PNT"] 	= default_axis_limited(_("AAR Lights"),   				devices.ELECTRICAL_SYSTEM, device_commands.Button_2,   713, 0.0, 0.3, false, false, {0,1})
	elements["EXTLIGHT_PNT"] 	= multiposition_switch_limited(_("Nav Lights"),   		devices.ELECTRICAL_SYSTEM, device_commands.Button_3,   715, 5, 0.1, nil, nil,    TOGGLECLICK)
	elements["TAXI_PNT"] 	    = default_3_position_tumb(_("Taxi/Landing Lights"),   	devices.ELECTRICAL_SYSTEM, device_commands.Button_4,   709, false, true,    TOGGLECLICK)
--Weapon System
	elements["MASTER_PNT"] 	    = default_2_position_tumb(_("Master Arm"),   			devices.WEAPON_SYSTEM, device_commands.Button_1,    708, 1, {0,1},   TOGGLECLICK)
	elements["JETT_PNT"] 	    = default_button(_("Emergency Jettison"),   		    devices.WEAPON_SYSTEM, device_commands.Button_2,   	711, 1, {0,1},   TOGGLECLICK)--Electrical System
	--elements["RWR_UP_PNT"] 	    = default_2_position_tumb(_("RWR Volume Up"),   		devices.WEAPON_SYSTEM, device_commands.Button_2,  	999, 1, {0,1},   TOGGLECLICK)
	--elements["RWR_DWN_PNT"]     = default_2_position_tumb(_("RWR Volume Down"),   		devices.WEAPON_SYSTEM, device_commands.Button_3,  	999, 1, {0,1},   TOGGLECLICK)
--Avionics System
	elements["LMAP_PNT"] 	    = default_axis_limited(_("Map Light"),   				devices.AVIONICS, device_commands.Button_1,  	    716, 0.0, 0.25, false, false, {0,1})
	elements["RMAP_PNT"] 	    = default_axis_limited(_("Map Light"),   				devices.AVIONICS, device_commands.Button_2,  	    717, 0.0, 0.25, false, false, {0,1})
	elements["EJECT_PNT"] 		= default_button(_("Eject Handle"),	  					devices.AVIONICS, device_commands.Button_11, 		999, 1, {0,1},   TOGGLECLICK)
	--elements["LMAP_PNT"] 	    = default_2_position_tumb(_("Map Light"),   			devices.AVIONICS, device_commands.Button_1,  	    716, 1, {0,1},   TOGGLECLICK)
	--elements["RMAP_PNT"] 	    = default_2_position_tumb(_("Map Light"),   			devices.AVIONICS, device_commands.Button_2,  	    717, 1, {0,1},   TOGGLECLICK)
	elements["MFD_PNT"] 		= default_axis_limited(_("MFD Brightness"),   			devices.AVIONICS, device_commands.Button_3, 704, 0.0, 0.3, false, false, {0,1})
	elements["PFD_PNT"]			= default_axis_limited(_("PFD Brightness"),   			devices.AVIONICS, device_commands.Button_4, 705, 0.0, 0.3, false, false, {0,1})
	elements["CONSOLE_PNT"] 	= default_axis_limited(_("Console Lights"),   			devices.AVIONICS, device_commands.Button_5, 706, 0.0, 0.3, false, false, {0,1})
	elements["FLOOD_PNT"] 		= default_axis_limited(_("Flood Lights"),     			devices.AVIONICS, device_commands.Button_6, 707, 0.0, 0.3, false, false, {0,1})
	elements["FORMLIGHT_PNT"] 	= default_axis_limited(_("Formation Lights"), 			devices.AVIONICS, device_commands.Button_7, 714, 0.0, 0.3, false, false, {0,1})
	elements["DAY_NIGHT_PNT"]   = default_2_position_tumb(_("Day/Night Mode"),			devices.AVIONICS, device_commands.Button_8,  	    718, 1, {0,1},   TOGGLECLICK)
--Left UFD
	elements["L_SMFD_1_PNT"] 	= default_button(_("SMFD OSB 1"),	  devices.AVIONICS, device_commands.Button_10, 	881, 1, {0,1},   TOGGLECLICK)
	--elements["L_SMFD_2_PNT"] 	= default_2_position_tumb(_("SMFD OSB 2"),	  devices.AVIONICS, device_commands.Button_10, 	882, 1, {0,1},   TOGGLECLICK)
	--elements["L_SMFD_3_PNT"] 	= default_2_position_tumb(_("SMFD OSB 3"),	  devices.AVIONICS, device_commands.Button_10, 	883, 1, {0,1},   TOGGLECLICK)
	--elements["L_SMFD_4_PNT"] 	= default_2_position_tumb(_("SMFD OSB 4"),	  devices.AVIONICS, device_commands.Button_10, 	884, 1, {0,1},   TOGGLECLICK)
	--Right UFD
	elements["R_SMFD_1_PNT"] 	= default_button(_("SMFD OSB 1"),	  devices.AVIONICS, device_commands.Button_9, 	885, 1, {0,1},   TOGGLECLICK)
	--elements["R_SMFD_2_PNT"] 	= default_2_position_tumb(_("SMFD OSB 2"),	  devices.AVIONICS, device_commands.Button_9, 	886, 1, {0,1},   TOGGLECLICK)
	--elements["R_SMFD_3_PNT"] 	= default_2_position_tumb(_("SMFD OSB 3"),	  devices.AVIONICS, device_commands.Button_9, 	887, 1, {0,1},   TOGGLECLICK)
	--elements["R_SMFD_4_PNT"] 	= default_2_position_tumb(_("SMFD OSB 4"),	  devices.AVIONICS, device_commands.Button_9, 	888, 1, {0,1},   TOGGLECLICK)
-- Left MFD
	elements["L_MFD_1_PNT"]      = default_button(_("OSB 1"),   		devices.MFD_SYSTEM, device_commands.Button_1,  		801, 1, {0,1},   TOGGLECLICK)
	elements["L_MFD_2_PNT"]      = default_button(_("OSB 2"),   		devices.MFD_SYSTEM, device_commands.Button_2,  		802, 1, {0,1},   TOGGLECLICK)
	elements["L_MFD_3_PNT"]      = default_button(_("OSB 3"),   		devices.MFD_SYSTEM, device_commands.Button_3,  		803, 1, {0,1},   TOGGLECLICK)
	elements["L_MFD_4_PNT"]      = default_button(_("OSB 4"),   		devices.MFD_SYSTEM, device_commands.Button_4,  		804, 1, {0,1},   TOGGLECLICK)
	elements["L_MFD_5_PNT"]      = default_button(_("OSB 5"),   		devices.MFD_SYSTEM, device_commands.Button_5,  		805, 1, {0,1},   TOGGLECLICK)
	elements["L_MFD_6_PNT"]      = default_button(_("OSB 6"),   		devices.MFD_SYSTEM, device_commands.Button_6,  		806, 1, {0,1},   TOGGLECLICK)
	elements["L_MFD_7_PNT"]      = default_button(_("OSB 7"),   		devices.MFD_SYSTEM, device_commands.Button_7,  		807, 1, {0,1},   TOGGLECLICK)
	elements["L_MFD_8_PNT"]      = default_button(_("OSB 8"),   		devices.MFD_SYSTEM, device_commands.Button_8,  		808, 1, {0,1},   TOGGLECLICK)
	elements["L_MFD_9_PNT"]      = default_button(_("OSB 9"),   		devices.MFD_SYSTEM, device_commands.Button_9,  		809, 1, {0,1},   TOGGLECLICK)
	elements["L_MFD_10_PNT"]     = default_button(_("OSB 10"),   		devices.MFD_SYSTEM, device_commands.Button_10,  	810, 1, {0,1},   TOGGLECLICK)
	elements["L_MFD_11_PNT"]     = default_button(_("OSB 11"),   		devices.MFD_SYSTEM, device_commands.Button_11,  	811, 1, {0,1},   TOGGLECLICK)
	elements["L_MFD_12_PNT"]     = default_button(_("OSB 12"),   		devices.MFD_SYSTEM, device_commands.Button_12,  	812, 1, {0,1},   TOGGLECLICK)
	elements["L_MFD_13_PNT"]     = default_button(_("OSB 13"),   		devices.MFD_SYSTEM, device_commands.Button_13,  	813, 1, {0,1},   TOGGLECLICK)
	elements["L_MFD_14_PNT"]     = default_button(_("OSB 14"),   		devices.MFD_SYSTEM, device_commands.Button_14,  	814, 1, {0,1},   TOGGLECLICK)
	elements["L_MFD_15_PNT"]     = default_button(_("OSB 15"),   		devices.MFD_SYSTEM, device_commands.Button_15,  	815, 1, {0,1},   TOGGLECLICK)
	elements["L_MFD_16_PNT"]     = default_button(_("OSB 16"),   		devices.MFD_SYSTEM, device_commands.Button_16,  	816, 1, {0,1},   TOGGLECLICK)
	elements["L_MFD_17_PNT"]     = default_button(_("OSB 17"),   		devices.MFD_SYSTEM, device_commands.Button_17,  	817, 1, {0,1},   TOGGLECLICK)
	elements["L_MFD_18_PNT"]     = default_button(_("OSB 18"),   		devices.MFD_SYSTEM, device_commands.Button_18,  	818, 1, {0,1},   TOGGLECLICK)
	elements["L_MFD_19_PNT"]     = default_button(_("OSB 19"),   		devices.MFD_SYSTEM, device_commands.Button_19,  	819, 1, {0,1},   TOGGLECLICK)
	elements["L_MFD_20_PNT"]     = default_button(_("OSB 20"),   		devices.MFD_SYSTEM, device_commands.Button_20,  	820, 1, {0,1},   TOGGLECLICK)
-- PMFD
	elements["PMFD_1_PNT"]      = default_button(_("OSB 1"),   			devices.PMFD_SYSTEM, device_commands.Button_1,  			821, 1, {0,1},   TOGGLECLICK)
	elements["PMFD_2_PNT"]      = default_button(_("OSB 2"),   			devices.PMFD_SYSTEM, device_commands.Button_2,  			822, 1, {0,1},   TOGGLECLICK)
	elements["PMFD_3_PNT"]      = default_button(_("OSB 3"),   			devices.PMFD_SYSTEM, device_commands.Button_3,  			823, 1, {0,1},   TOGGLECLICK)
	elements["PMFD_4_PNT"]      = default_button(_("OSB 4"),   			devices.PMFD_SYSTEM, device_commands.Button_4,  			824, 1, {0,1},   TOGGLECLICK)
	elements["PMFD_5_PNT"]      = default_button(_("OSB 5"),   			devices.PMFD_SYSTEM, device_commands.Button_5,  			825, 1, {0,1},   TOGGLECLICK)
	elements["PMFD_6_PNT"]      = default_button(_("OSB 6"),   			devices.PMFD_SYSTEM, device_commands.Button_6,  			826, 1, {0,1},   TOGGLECLICK)
	elements["PMFD_7_PNT"]      = default_button(_("OSB 7"),   			devices.PMFD_SYSTEM, device_commands.Button_7,  			827, 1, {0,1},   TOGGLECLICK)
	elements["PMFD_8_PNT"]      = default_button(_("OSB 8"),   			devices.PMFD_SYSTEM, device_commands.Button_8,  			828, 1, {0,1},   TOGGLECLICK)
	elements["PMFD_9_PNT"]      = default_button(_("OSB 9"),   			devices.PMFD_SYSTEM, device_commands.Button_9,  			829, 1, {0,1},   TOGGLECLICK)
	elements["PMFD_10_PNT"]     = default_button(_("OSB 10"),   		devices.PMFD_SYSTEM, device_commands.Button_10,  			830, 1, {0,1},   TOGGLECLICK)
	elements["PMFD_11_PNT"]     = default_button(_("OSB 11"),   		devices.PMFD_SYSTEM, device_commands.Button_11,  			831, 1, {0,1},   TOGGLECLICK)
	elements["PMFD_12_PNT"]     = default_button(_("OSB 12"),   		devices.PMFD_SYSTEM, device_commands.Button_12,  			832, 1, {0,1},   TOGGLECLICK)
	elements["PMFD_13_PNT"]     = default_button(_("OSB 13"),   		devices.PMFD_SYSTEM, device_commands.Button_13,  			833, 1, {0,1},   TOGGLECLICK)
	elements["PMFD_14_PNT"]     = default_button(_("OSB 14"),   		devices.PMFD_SYSTEM, device_commands.Button_14,  			834, 1, {0,1},   TOGGLECLICK)
	elements["PMFD_15_PNT"]     = default_button(_("OSB 15"),   		devices.PMFD_SYSTEM, device_commands.Button_15,  			835, 1, {0,1},   TOGGLECLICK)
	elements["PMFD_16_PNT"]     = default_button(_("OSB 16"),   		devices.PMFD_SYSTEM, device_commands.Button_16,  			836, 1, {0,1},   TOGGLECLICK)
	elements["PMFD_17_PNT"]     = default_button(_("OSB 17"),   		devices.PMFD_SYSTEM, device_commands.Button_17,  			837, 1, {0,1},   TOGGLECLICK)
	elements["PMFD_18_PNT"]     = default_button(_("OSB 18"),   		devices.PMFD_SYSTEM, device_commands.Button_18,  			838, 1, {0,1},   TOGGLECLICK)
	elements["PMFD_19_PNT"]     = default_button(_("OSB 19"),   		devices.PMFD_SYSTEM, device_commands.Button_19,  			839, 1, {0,1},   TOGGLECLICK)
	elements["PMFD_20_PNT"]     = default_button(_("OSB 20"),   		devices.PMFD_SYSTEM, device_commands.Button_20,  			840, 1, {0,1},   TOGGLECLICK)
-- Right MF
	elements["R_MFD_1_PNT"]      = default_button(_("OSB 1"),   		devices.MFD_SYSTEM, device_commands.Button_21,  	841, 1, {0,1},   TOGGLECLICK)
	elements["R_MFD_2_PNT"]      = default_button(_("OSB 2"),   		devices.MFD_SYSTEM, device_commands.Button_22,  	842, 1, {0,1},   TOGGLECLICK)
	elements["R_MFD_3_PNT"]      = default_button(_("OSB 3"),   		devices.MFD_SYSTEM, device_commands.Button_23,  	843, 1, {0,1},   TOGGLECLICK)
	elements["R_MFD_4_PNT"]      = default_button(_("OSB 4"),   		devices.MFD_SYSTEM, device_commands.Button_24,  	844, 1, {0,1},   TOGGLECLICK)
	elements["R_MFD_5_PNT"]      = default_button(_("OSB 5"),   		devices.MFD_SYSTEM, device_commands.Button_25,  	845, 1, {0,1},   TOGGLECLICK)
	elements["R_MFD_6_PNT"]      = default_button(_("OSB 6"),   		devices.MFD_SYSTEM, device_commands.Button_26,  	846, 1, {0,1},   TOGGLECLICK)
	elements["R_MFD_7_PNT"]      = default_button(_("OSB 7"),   		devices.MFD_SYSTEM, device_commands.Button_27,  	847, 1, {0,1},   TOGGLECLICK)
	elements["R_MFD_8_PNT"]      = default_button(_("OSB 8"),   		devices.MFD_SYSTEM, device_commands.Button_28,  	848, 1, {0,1},   TOGGLECLICK)
	elements["R_MFD_9_PNT"]      = default_button(_("OSB 9"),   		devices.MFD_SYSTEM, device_commands.Button_29,  	849, 1, {0,1},   TOGGLECLICK)
	elements["R_MFD_10_PNT"]     = default_button(_("OSB 10"),   		devices.MFD_SYSTEM, device_commands.Button_30,  	850, 1, {0,1},   TOGGLECLICK)
	elements["R_MFD_11_PNT"]     = default_button(_("OSB 11"),   		devices.MFD_SYSTEM, device_commands.Button_31,  	851, 1, {0,1},   TOGGLECLICK)
	elements["R_MFD_12_PNT"]     = default_button(_("OSB 12"),   		devices.MFD_SYSTEM, device_commands.Button_32,  	852, 1, {0,1},   TOGGLECLICK)
	elements["R_MFD_13_PNT"]     = default_button(_("OSB 13"),   		devices.MFD_SYSTEM, device_commands.Button_33,  	853, 1, {0,1},   TOGGLECLICK)
	elements["R_MFD_14_PNT"]     = default_button(_("OSB 14"),   		devices.MFD_SYSTEM, device_commands.Button_34,  	854, 1, {0,1},   TOGGLECLICK)
	elements["R_MFD_15_PNT"]     = default_button(_("OSB 15"),   		devices.MFD_SYSTEM, device_commands.Button_35,  	855, 1, {0,1},   TOGGLECLICK)
	elements["R_MFD_16_PNT"]     = default_button(_("OSB 16"),   		devices.MFD_SYSTEM, device_commands.Button_36,  	856, 1, {0,1},   TOGGLECLICK)
	elements["R_MFD_17_PNT"]     = default_button(_("OSB 17"),   		devices.MFD_SYSTEM, device_commands.Button_37,  	857, 1, {0,1},   TOGGLECLICK)
	elements["R_MFD_18_PNT"]     = default_button(_("OSB 18"),   		devices.MFD_SYSTEM, device_commands.Button_38,  	858, 1, {0,1},   TOGGLECLICK)
	elements["R_MFD_19_PNT"]     = default_button(_("OSB 19"),   		devices.MFD_SYSTEM, device_commands.Button_39,  	859, 1, {0,1},   TOGGLECLICK)
	elements["R_MFD_20_PNT"]     = default_button(_("OSB 20"),   		devices.MFD_SYSTEM, device_commands.Button_40,  	860, 1, {0,1},   TOGGLECLICK)
-- Center MFD
	elements["B_MFD_1_PNT"]      = default_button(_("OSB 1"),   		devices.MFD_SYSTEM, device_commands.Button_41,  		861, 1, {0,1},   TOGGLECLICK)
	elements["B_MFD_2_PNT"]      = default_button(_("OSB 2"),   		devices.MFD_SYSTEM, device_commands.Button_42,  		862, 1, {0,1},   TOGGLECLICK)
	elements["B_MFD_3_PNT"]      = default_button(_("OSB 3"),   		devices.MFD_SYSTEM, device_commands.Button_43,  		863, 1, {0,1},   TOGGLECLICK)
	elements["B_MFD_4_PNT"]      = default_button(_("OSB 4"),   		devices.MFD_SYSTEM, device_commands.Button_44,  		864, 1, {0,1},   TOGGLECLICK)
	elements["B_MFD_5_PNT"]      = default_button(_("OSB 5"),   		devices.MFD_SYSTEM, device_commands.Button_45,  		865, 1, {0,1},   TOGGLECLICK)
	elements["B_MFD_6_PNT"]      = default_button(_("OSB 6"),   		devices.MFD_SYSTEM, device_commands.Button_46,  		866, 1, {0,1},   TOGGLECLICK)
	elements["B_MFD_7_PNT"]      = default_button(_("OSB 7"),   		devices.MFD_SYSTEM, device_commands.Button_47,  		867, 1, {0,1},   TOGGLECLICK)
	elements["B_MFD_8_PNT"]      = default_button(_("OSB 8"),   		devices.MFD_SYSTEM, device_commands.Button_48,  		868, 1, {0,1},   TOGGLECLICK)
	elements["B_MFD_9_PNT"]      = default_button(_("OSB 9"),   		devices.MFD_SYSTEM, device_commands.Button_49,  		869, 1, {0,1},   TOGGLECLICK)
	elements["B_MFD_10_PNT"]     = default_button(_("OSB 10"),   		devices.MFD_SYSTEM, device_commands.Button_50,  	870, 1, {0,1},   TOGGLECLICK)
	elements["B_MFD_11_PNT"]     = default_button(_("OSB 11"),   		devices.MFD_SYSTEM, device_commands.Button_51,  	871, 1, {0,1},   TOGGLECLICK)
	elements["B_MFD_12_PNT"]     = default_button(_("OSB 12"),   		devices.MFD_SYSTEM, device_commands.Button_52,  	872, 1, {0,1},   TOGGLECLICK)
	elements["B_MFD_13_PNT"]     = default_button(_("OSB 13"),   		devices.MFD_SYSTEM, device_commands.Button_53,  	873, 1, {0,1},   TOGGLECLICK)
	elements["B_MFD_14_PNT"]     = default_button(_("OSB 14"),   		devices.MFD_SYSTEM, device_commands.Button_54,  	874, 1, {0,1},   TOGGLECLICK)
	elements["B_MFD_15_PNT"]     = default_button(_("OSB 15"),   		devices.MFD_SYSTEM, device_commands.Button_55,  	875, 1, {0,1},   TOGGLECLICK)
	elements["B_MFD_16_PNT"]     = default_button(_("OSB 16"),   		devices.MFD_SYSTEM, device_commands.Button_56,  	876, 1, {0,1},   TOGGLECLICK)
	elements["B_MFD_17_PNT"]     = default_button(_("OSB 17"),   		devices.MFD_SYSTEM, device_commands.Button_57,  	877, 1, {0,1},   TOGGLECLICK)
	elements["B_MFD_18_PNT"]     = default_button(_("OSB 18"),   		devices.MFD_SYSTEM, device_commands.Button_58,  	878, 1, {0,1},   TOGGLECLICK)
	elements["B_MFD_19_PNT"]     = default_button(_("OSB 19"),   		devices.MFD_SYSTEM, device_commands.Button_59,  	879, 1, {0,1},   TOGGLECLICK)
	elements["B_MFD_20_PNT"]     = default_button(_("OSB 20"),   		devices.MFD_SYSTEM, device_commands.Button_60,  	880, 1, {0,1},   TOGGLECLICK)
--ICP Stuff and Shit
	elements["ICP_COM1_PNT"]     = default_button(_("Com 1"),   		devices.ICP_SYSTEM, device_commands.Button_1,  		889, 1, {0,1},   TOGGLECLICK)
	elements["ICP_COM2_PNT"]     = default_button(_("Com 2"),   		devices.ICP_SYSTEM, device_commands.Button_2,  		890, 1, {0,1},   TOGGLECLICK)
	elements["ICP_NAV_PNT"]      = default_button(_("NAV"),   			devices.ICP_SYSTEM, device_commands.Button_3,  		891, 1, {0,1},   TOGGLECLICK)
	elements["ICP_STPT_PNT"]     = default_button(_("STPT"),   			devices.ICP_SYSTEM, device_commands.Button_4,  		892, 1, {0,1},   TOGGLECLICK)
	elements["ICP_ALT_PNT"]      = default_button(_("ALT"),   			devices.ICP_SYSTEM, device_commands.Button_5,  		894, 1, {0,1},   TOGGLECLICK)
	elements["ICP_HUD_PNT"]      = default_button(_("HUD"),   			devices.ICP_SYSTEM, device_commands.Button_6,  		895, 1, {0,1},   TOGGLECLICK)
	elements["ICP_OTHR_PNT"]     = default_button(_("OTHR"),   			devices.ICP_SYSTEM, device_commands.Button_7,  		896, 1, {0,1},   TOGGLECLICK)
	elements["ICP_OP1_PNT"]      = default_button(_("Option 1"),   		devices.ICP_SYSTEM, device_commands.Button_8,  		898, 1, {0,1},   TOGGLECLICK)
	elements["ICP_OP2_PNT"]      = default_button(_("Option 2"),   		devices.ICP_SYSTEM, device_commands.Button_9,  		899, 1, {0,1},   TOGGLECLICK)
	elements["ICP_OP3_PNT"]      = default_button(_("Option 3"),   		devices.ICP_SYSTEM, device_commands.Button_10,  	900, 1, {0,1},   TOGGLECLICK)
	elements["ICP_OP4_PNT"]      = default_button(_("Option 4"),   		devices.ICP_SYSTEM, device_commands.Button_11,  	901, 1, {0,1},   TOGGLECLICK)
	elements["ICP_OP5_PNT"]      = default_button(_("Option 5"),   		devices.ICP_SYSTEM, device_commands.Button_12,  	902, 1, {0,1},   TOGGLECLICK)
	elements["ICP_UP_PNT"]       = default_button(_("Rocker Up"),   	devices.ICP_SYSTEM, device_commands.Button_13,  	903, 1, {0,1},   TOGGLECLICK)
	elements["ICP_DWN_PNT"]      = default_button(_("Rocker Down"),   	devices.ICP_SYSTEM, device_commands.Button_14,  	903, -1, {0,1},   TOGGLECLICK)
	elements["ICP_AP_PNT"]       = default_button(_("Autopilot"),   	devices.ICP_SYSTEM, device_commands.Button_15,  	904, 1, {0,1},   TOGGLECLICK)	
	--elements["ICP_MRK_PNT"]      = default_button(_("MARK"),   			devices.ICP_SYSTEM, device_commands.Button_16,  	905, 1, {0,1},   TOGGLECLICK)	
	elements["ICP_1_PNT"]      	 = default_button(_("1"),   			devices.ICP_SYSTEM, device_commands.Button_17,  	906, 1, {0,1},   TOGGLECLICK)	
	elements["ICP_2_PNT"]      	 = default_button(_("2"),   			devices.ICP_SYSTEM, device_commands.Button_18,  	907, 1, {0,1},   TOGGLECLICK)	
	elements["ICP_3_PNT"]      	 = default_button(_("3"),   			devices.ICP_SYSTEM, device_commands.Button_19,  	908, 1, {0,1},   TOGGLECLICK)	
	elements["ICP_4_PNT"]      	 = default_button(_("4"),   			devices.ICP_SYSTEM, device_commands.Button_20,  	909, 1, {0,1},   TOGGLECLICK)	
	elements["ICP_5_PNT"]      	 = default_button(_("5"),   			devices.ICP_SYSTEM, device_commands.Button_21,  	910, 1, {0,1},   TOGGLECLICK)	
	elements["ICP_6_PNT"]      	 = default_button(_("6"),   			devices.ICP_SYSTEM, device_commands.Button_22,  	911, 1, {0,1},   TOGGLECLICK)	
	elements["ICP_7_PNT"]      	 = default_button(_("7"),   			devices.ICP_SYSTEM, device_commands.Button_23,  	912, 1, {0,1},   TOGGLECLICK)	
	elements["ICP_8_PNT"]      	 = default_button(_("8"),   			devices.ICP_SYSTEM, device_commands.Button_24,  	913, 1, {0,1},   TOGGLECLICK)	
	elements["ICP_9_PNT"]      	 = default_button(_("9"),   			devices.ICP_SYSTEM, device_commands.Button_25,  	914, 1, {0,1},   TOGGLECLICK)	
	elements["ICP_CLR_PNT"]      = default_button(_("CLR"),  			devices.ICP_SYSTEM, device_commands.Button_26,  	915, 1, {0,1},   TOGGLECLICK)	
	elements["ICP_0_PNT"]      	 = default_button(_("0"),   			devices.ICP_SYSTEM, device_commands.Button_27,  	916, 1, {0,1},   TOGGLECLICK)
	elements["ICP_UNDO_PNT"]  	 = default_button(_("UNDO"),   			devices.ICP_SYSTEM, device_commands.Button_28,  	917, 1, {0,1},   TOGGLECLICK)
	elements["ICP_WHEELUP_PNT"]  = default_axis_limited(_("Wheel Up"),  		devices.ICP_SYSTEM, device_commands.Button_29,  	918, 0.0, 0.3, false, false, {0,1})
	elements["ICP_WHEELDWN_PNT"] = default_axis_limited(_("Wheel Down"),		devices.ICP_SYSTEM, device_commands.Button_30,  	918, 0.0, 0.3, false, false, {0,1})
	--elements["ICP_KNEXT_PNT"]    = default_button(_("Kneeboard Next Page"), devices.ICP_SYSTEM, device_commands.Button_31,  	999, 1, {0,1},   TOGGLECLICK)
	--elements["ICP_KPREV_PNT"]    = default_button(_("Kneeboard Prev Page"), devices.ICP_SYSTEM, device_commands.Button_32,  	999, -1, {0,1},   TOGGLECLICK)


--elements["AARLIGHT_PNT"] 	= default_axis_limited(_("AAR Lights"),   				devices.ELECTRICAL_SYSTEM, device_commands.Button_2,   713, 0.0, 0.3, false, false, {0,1})
	
for i,o in pairs(elements) do
	if  o.class[1] == class_type.TUMB or 
	   (o.class[2]  and o.class[2] == class_type.TUMB) or
	   (o.class[3]  and o.class[3] == class_type.TUMB)  then
	   o.updatable = true
	   o.use_OBB   = true
	end
end
