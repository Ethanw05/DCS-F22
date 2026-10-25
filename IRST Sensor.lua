--[[
    Grinnelli Designs F-22A Raptor
    Copyright (C) 2025, "David McMasters"
    
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

--SENSOR CATEGORY
local SENSOR_IRST = 2
--RADAR
--ASPECT
local ASPECT_HEAD_ON = 0
local ASPECT_TAIL_ON = 1
--HEMISPHERE
local HEMISPHERE_UPPER = 0
local HEMISPHERE_LOWER = 1
--IRST
--OPTIC

-------------------------------
IRST21= {
	Name = "IRST-21",	
	category = SENSOR_IRST,
	scan_volume =
	{
		azimuth = {-90.0, 90.0},
		elevation = {-15.0, 60.0}
	},

	
	detection_distance =
		{
			[HEMISPHERE_UPPER] =
			{
				[ASPECT_HEAD_ON] = 90000.0,
				[ASPECT_TAIL_ON] = 50000.0
			},
			[HEMISPHERE_LOWER] =
			{
				[ASPECT_HEAD_ON] = 90000.0,
				[ASPECT_TAIL_ON] = 50000.0
			}
	},
	lock_on_distance_coeff = 0.5,
	scan_period =  3,
    background_factor = 0.5,	
	laserRanger = true
 }

declare_sensor(IRST21)