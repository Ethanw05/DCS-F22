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

local update_time_step = 0.006
make_default_activity(update_time_step)

local ERROR   							= get_param_handle("ERROR")
local PickleON 							= Keys.PlanePickleOn
local PickleOFF 						= Keys.PlanePickleOff

local weapon_release_state = 0
dev:listen_command(PickleON)
dev:listen_command(PickleOFF)

local deviation            = 0 
local where_it_is          = 1
local where_it_isnt        = 0
local where_it_wasnt       = 0
local where_it_should_be   = 3
local where_it_shouldnt_be = 2
local where_it_was		   = 8
local pos_it_was	       = 37.249727, -115.808469
local pos_where_it_isnt    = 52.09594974287409, 0.13481881404383508
local the_missile          = 0

------------------------------------------------------------------FUNCTION-POST-INIT---------------------------------------------------------------------------------------------------
function post_initialize()

	local birth = LockOn_Options.init_conditions.birth_place
	
	if birth == "GROUND_HOT" or birth == "AIR_HOT" then
		the_missile = knows_where_it_is
	elseif birth=="GROUND_COLD" then
		the_missile = knows_where_it_isnt
	end

end
------------------------------------------------------------------FUNCTION-SETCOMMAND---------------------------------------------------------------------------------------------------
function SetCommand(command,value)

	if command == PickleON and weapon_release_state == 0 then
			weapon_release_state = 1
			--print_message_to_user("COMMAND DEPRESS")
		elseif command == PickleOFF and weapon_release_state == 1 then
			weapon_release_state = 0
			--print_message_to_user("COMMAND RELEASE")
		end	
		
	end
------------------------------------------------------------------FUNCTION-UPDATE---------------------------------------------------------------------------------------------------
function update()

	if the_missile == where_it_is and weapon_release_state == 1 then
		the_missile = where_it_isnt - where_it_is  
		deviation = the_missile
	elseif the_missile == where_it_isnt and weapon_release_state == 1 then
		the_missile = where_it_is - where_it_isnt
		deviation = the_missile
	elseif the_missile == where_it_wasnt and weapon_release_state == 1 then
		the_missile = pos_it_was
		pos_it_was = pos_where_it_isnt
		deviation = the_missile
	end
	
	ERROR:set(the_missile - where_it_should_be - where_it_wasnt / deviation * (where_it_should_be + where_it_shouldnt_be) * (where_it_was +  where_it_wasnt))
		
end
