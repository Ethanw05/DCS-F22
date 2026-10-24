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


shape_name   	   			 = "Cockpit_F-22A"
is_EDM			   			 = true
new_model_format   			 = true
ambient_light      			 = {255,255,255}
ambient_color_day_texture    = {72, 100, 160}
ambient_color_night_texture  = {40, 60 ,150}
ambient_color_from_devices   = {50, 50, 40}
ambient_color_from_panels	 = {35, 25, 25}

dusk_border					 = 0.4
draw_pilot					 = false

external_model_canopy_arg	 = 38

use_external_views = false 
--cockpit_local_point = {-1.321,0.369,0.0} --0.354
cockpit_local_point = {6.958000,1.360000,0.000000}--{7.105000,1.350000,0.000000}--{6.957000,1.322000,0.000000} with dummy at 0,0,0 {6.958000,1.336000,0.000000}
day_texture_set_value   = 0.0
night_texture_set_value = 0.1

local controllers = LoRegisterPanelControls()

mirrors_data = 
{
    center_point 	= {0.6,0.40,0.00},
    width 		 	= 0.3,
    aspect 		 	= 1.7, 
	rotation 	 	= math.rad(-20);
	animation_speed = 2.0;
	near_clip 		= 0.1;
	middle_clip		= 10;
	far_clip		= 60000;
}

FloodLight    						= CreateGauge("parameter")
FloodLight.parameter_name   		= "FLOOD_LIGHT"
FloodLight.arg_number 				= 750
FloodLight.input   					= {0,1}
FloodLight.output  					= {0,1}

PanelLight    						= CreateGauge("parameter")
PanelLight.parameter_name   		= "PANEL_LIGHT"
PanelLight.arg_number 				= 751
PanelLight.input   					= {0,1}
PanelLight.output  					= {0,1}

LMFDMask							= CreateGauge("parameter")
LMFDMask.parameter_name				= "LMFD_MASK"
LMFDMask.arg_number					= 719
LMFDMask.input						= {0,1}
LMFDMask.output						= {0,1}

RMFDMask							= CreateGauge("parameter")
RMFDMask.parameter_name				= "RMFD_MASK"
RMFDMask.arg_number					= 720
RMFDMask.input						= {0,1}
RMFDMask.output						= {0,1}

PMFDMask							= CreateGauge("parameter")
PMFDMask.parameter_name				= "PMFD_MASK"
PMFDMask.arg_number					= 721
PMFDMask.input						= {0,1}
PMFDMask.output						= {0,1}

MASTERARM							= CreateGauge("parameter")
MASTERARM.parameter_name			= "MASTER_ARM"
MASTERARM.arg_number				= 708
MASTERARM.input						= {0,1}
MASTERARM.output					= {0,1}

LGEN								= CreateGauge("parameter")
LGEN.parameter_name					= "L_GEN_POWER"
LGEN.arg_number						= 702
LGEN.input							= {0,1}
LGEN.output							= {0,1}

RGEN								= CreateGauge("parameter")
RGEN.parameter_name					= "R_GEN_POWER"
RGEN.arg_number						= 703
RGEN.input							= {0,1}
RGEN.output							= {0,1}

DAYNIGHT							= CreateGauge("parameter")
DAYNIGHT.parameter_name				= "DAY_NIGHT"
DAYNIGHT.arg_number					= 718
DAYNIGHT.input						= {0,1}
DAYNIGHT.output						= {0,1}

BATTERY							    = CreateGauge("parameter")
BATTERY.parameter_name				= "BATTERY_POWER"
BATTERY.arg_number					= 700
BATTERY.input						= {0,1}
BATTERY.output						= {0,1}

AAR							    	= CreateGauge("parameter")
AAR.parameter_name					= "AAR"
AAR.arg_number						= 712
AAR.input							= {0,1}
AAR.output							= {0,1}

PARK							    = CreateGauge("parameter")
PARK.parameter_name					= "PARK"
PARK.arg_number						= 710
PARK.input							= {0,1}
PARK.output							= {0,1}

N_GEAR							    = CreateGauge("parameter")
N_GEAR.parameter_name				= "N_GEAR_LIGHT"
N_GEAR.arg_number					= 723
N_GEAR.input						= {0,1}
N_GEAR.output						= {0,1}

R_GEAR							    = CreateGauge("parameter")
R_GEAR.parameter_name				= "N_GEAR_LIGHT"
R_GEAR.arg_number					= 725
R_GEAR.input						= {0,1}
R_GEAR.output						= {0,1}

L_GEAR							    = CreateGauge("parameter")
L_GEAR.parameter_name				= "N_GEAR_LIGHT"
L_GEAR.arg_number					= 724
L_GEAR.input						= {0,1}
L_GEAR.output						= {0,1}

CLIPBOARD1							= CreateGauge("parameter")
CLIPBOARD1.parameter_name			= "CLIPBOARD_L"
CLIPBOARD1.arg_number				= 752
CLIPBOARD1.input					= {0,1}
CLIPBOARD1.output					= {0,1}

CLIPBOARD2							= CreateGauge("parameter")
CLIPBOARD2.parameter_name			= "CLIPBOARD_R"
CLIPBOARD2.arg_number				= 753
CLIPBOARD2.input					= {0,1}
CLIPBOARD2.output					= {0,1}

GARFIELD							= CreateGauge("parameter")
GARFIELD.parameter_name				= "GARFIELD"
GARFIELD.arg_number					= 760
GARFIELD.input						= {0,1}
GARFIELD.output						= {0,1}

FLOOD_COLOR							= CreateGauge("parameter")
FLOOD_COLOR.parameter_name			= "FLOOD_COLOR"
FLOOD_COLOR.arg_number				= 754
FLOOD_COLOR.input					= {0,1}
FLOOD_COLOR.output					= {0,1}

PHOTO								= CreateGauge("parameter")
PHOTO.parameter_name				= "PHOTO"
PHOTO.arg_number					= 755
PHOTO.input							= {0,1}
PHOTO.output						= {0,1}

GARFIELD_PITCH						= CreateGauge("parameter")
GARFIELD_PITCH.parameter_name		= "GARFIELD_PITCH"
GARFIELD_PITCH.arg_number			= 921
GARFIELD_PITCH.input				= {-1,1}
GARFIELD_PITCH.output				= {-1,1}

GARFIELD_ROLL						= CreateGauge("parameter")
GARFIELD_ROLL.parameter_name		= "GARFIELD_ROLL"
GARFIELD_ROLL.arg_number			= 920
GARFIELD_ROLL.input					= {-1,1}
GARFIELD_ROLL.output				= {-1,1}

TOE_L								= CreateGauge("parameter")
TOE_L.parameter_name				= "L_TOE"
TOE_L.arg_number					= 761
TOE_L.input							= {-1,1}
TOE_L.output						= {-1,1}

TOE_R								= CreateGauge("parameter")
TOE_R.parameter_name				= "R_TOE"
TOE_R.arg_number					= 762
TOE_R.input							= {-1,1}
TOE_R.output						= {-1,1}

T_DETENT							= CreateGauge("parameter")
T_DETENT.parameter_name				= "DETENT"
T_DETENT.arg_number					= 763
T_DETENT.input						= {0,1}
T_DETENT.output						= {0,1}

PICKLE								= CreateGauge("parameter")
PICKLE.parameter_name				= "PICKLE"
PICKLE.arg_number					= 764
PICKLE.input						= {0,1}
PICKLE.output						= {0,1}

R_THROTC							= CreateGauge("parameter")
R_THROTC.parameter_name				= "R_THROTTLE_CUT"
R_THROTC.arg_number					= 765
R_THROTC.input						= {0,1}
R_THROTC.output						= {0,1}

R_THROT								= CreateGauge("parameter")
R_THROT.parameter_name				= "R_THROTTLE_POS"
R_THROT.arg_number					= 766
R_THROT.input						= {-1,1}
R_THROT.output						= {-1,1}

L_THROTC							= CreateGauge("parameter")
L_THROTC.parameter_name				= "L_THROTTLE_CUT"
L_THROTC.arg_number					= 767
L_THROTC.input						= {0,1}
L_THROTC.output						= {0,1}

L_THROT								= CreateGauge("parameter")
L_THROT.parameter_name				= "L_THROTTLE_POS"
L_THROT.arg_number					= 768
L_THROT.input						= {-1,1}
L_THROT.output						= {-1,1}

need_to_be_closed = true -- close lua state after initialization 

Z_test =
{
	near = 0.05,
	far  = 4.0,
}


--[[ available functions 

 --base_gauge_RadarAltitude
 --base_gauge_BarometricAltitude
 --base_gauge_AngleOfAttack
 --base_gauge_AngleOfSlide
 --base_gauge_VerticalVelocity
 --base_gauge_TrueAirSpeed
 --base_gauge_IndicatedAirSpeed
 --base_gauge_MachNumber
 --base_gauge_VerticalAcceleration --Ny
 --base_gauge_HorizontalAcceleration --Nx
 --base_gauge_LateralAcceleration --Nz
 --base_gauge_RateOfRoll
 --base_gauge_RateOfYaw
 --base_gauge_RateOfPitch
 --base_gauge_Roll
 --base_gauge_MagneticHeading
 --base_gauge_Pitch
 --base_gauge_Heading
 --base_gauge_EngineLeftFuelConsumption
 --base_gauge_EngineRightFuelConsumption
 --base_gauge_EngineLeftTemperatureBeforeTurbine
 --base_gauge_EngineRightTemperatureBeforeTurbine
 --base_gauge_EngineLeftRPM
 --base_gauge_EngineRightRPM
 --base_gauge_WOW_RightMainLandingGear
 --base_gauge_WOW_LeftMainLandingGear
 --base_gauge_WOW_NoseLandingGear
 --base_gauge_RightMainLandingGearDown
 --base_gauge_LeftMainLandingGearDown
 --base_gauge_NoseLandingGearDown
 --base_gauge_RightMainLandingGearUp
 --base_gauge_LeftMainLandingGearUp
 --base_gauge_NoseLandingGearUp
 --base_gauge_LandingGearHandlePos
 --base_gauge_StickRollPosition
 --base_gauge_StickPitchPosition
 --base_gauge_RudderPosition
 --base_gauge_ThrottleLeftPosition
 --base_gauge_ThrottleRightPosition
 --base_gauge_HelicopterCollective
 --base_gauge_HelicopterCorrection
 --base_gauge_CanopyPos
 --base_gauge_CanopyState
 --base_gauge_FlapsRetracted
 --base_gauge_SpeedBrakePos
 --base_gauge_FlapsPos
 --base_gauge_TotalFuelWeight

--]]
