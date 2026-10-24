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


dofile(LockOn_Options.script_path.."MFD_LEFT/definitions.lua")
dofile(LockOn_Options.script_path.."fonts.lua")
dofile(LockOn_Options.script_path.."materials.lua")
SetScale(FOV)

local function vertices(object, height, half_or_double)
    local width = height
    
    if half_or_double == true then --
        width = height / 2
    end

    if half_or_double == false then
        width = height * 2
    end

    local half_width = width / 2
    local half_height = height / 2
    local x_positive = half_width
    local x_negative = half_width * -1.0
    local y_positive = half_height
    local y_negative = half_height * -1.0

    object.vertices =
    {
        {x_negative, y_positive},
        {x_positive, y_positive},
        {x_positive, y_negative},
        {x_negative, y_negative}
    }

    object.indices = {0, 1, 2, 2, 3, 0}

    object.tex_coords =
    {
        {0, 0},
        {1, 0},
        {1, 1},
        {0, 1}
    }
end
local IndicationTexturesPath = LockOn_Options.script_path.."../IndicationTextures/"--I dont think this is correct might have to add scripts.
local BlackColor  			= {0, 0, 0, 255}--RGBA
local WhiteColor 			= {255, 255, 255, 255}--RGBA
local MainColor 			= {255, 255, 255, 255}--RGBA
local GreenColor 		    = {0, 255, 0, 255}--RGBA
local YellowColor 			= {255, 255, 0, 255}--RGBA
local OrangeColor           = {255, 102, 0, 255}--RGBA
local RedColor 				= {255, 0, 0, 255}--RGBA
local ScreenColor			= {3, 3, 12, 255}--RGBA DO NOT TOUCH 3-3-12-255 is good for on screen
--------------------------------------------------------------------------------------------------------------------------------------------
local MASK_BOX	    = MakeMaterial(LockOn_Options.script_path.."../Scripts/IndicationTextures/mask_box.dds", ScreenColor)--SYSTEM TEST
--------------------------------------------------------------------------------------------------------------------------------------------
local ClippingPlaneSize = 1.1 --Clipping Masks
local ClippingWidth 	= 1.1--Clipping Masks
local PFD_MASK_BASE1 	= MakeMaterial(nil,{255,0,0,255})--Clipping Masks
local PFD_MASK_BASE2 	= MakeMaterial(nil,{0,255,0,255})--Clipping Masks
--Clipping Masks
local total_field_of_view           = CreateElement "ceMeshPoly"
total_field_of_view.name            = "total_field_of_view"
total_field_of_view.primitivetype   = "triangles"
total_field_of_view.vertices        = {
										{-1 * ClippingWidth,-1 * ClippingPlaneSize},
										{1 * ClippingWidth,-1 * ClippingPlaneSize},
										{1 * ClippingWidth,1 * ClippingPlaneSize},
										{-1 * ClippingWidth,1 * ClippingPlaneSize},										
									}
total_field_of_view.material        = PFD_MASK_BASE1
total_field_of_view.indices         = {0,1,2,2,3,0}
total_field_of_view.init_pos        = {0, 0, 0}
total_field_of_view.init_rot        = { 0, 0, 0} -- degree NOT rad
total_field_of_view.h_clip_relation = h_clip_relations.REWRITE_LEVEL
total_field_of_view.level           = 1
total_field_of_view.collimated      = false
total_field_of_view.isvisible       = false
Add(total_field_of_view)
--Clipping Masks
local clipPoly               = CreateElement "ceMeshPoly"
clipPoly.name                = "clipPoly-1"
clipPoly.primitivetype       = "triangles"
clipPoly.init_pos            = {0, 0, 0}
clipPoly.init_rot            = { 0, 0 , 0} -- degree NOT rad
clipPoly.vertices            = {
								{-1 * ClippingWidth,-1 * ClippingPlaneSize},
								{1 * ClippingWidth,-1 * ClippingPlaneSize},
								{1 * ClippingWidth,1 * ClippingPlaneSize},
								{-1 * ClippingWidth,1 * ClippingPlaneSize},										
									}
clipPoly.indices             = {0,1,2,2,3,0}
clipPoly.material            = PFD_MASK_BASE2
clipPoly.h_clip_relation     = h_clip_relations.INCREASE_IF_LEVEL
clipPoly.level               = 1
clipPoly.collimated          = false
clipPoly.isvisible           = false
Add(clipPoly)
------------------------------------------------------------------------------------------------CLIPPING-END----------------------------------------------------------------------------------------------
BGROUND                    = CreateElement "ceTexPoly"
BGROUND.name    			= "BG"
BGROUND.material			= MASK_BOX
BGROUND.change_opacity 		= false
BGROUND.collimated 			= false
BGROUND.isvisible 			= true
BGROUND.init_pos 			= {0, 0, 0} --L-R,U-D,F-B
BGROUND.init_rot 			= {0, 0, 0}
BGROUND.element_params 		= {"MFD_OPACITY","LMFD_MENU_PAGE"}--this may not be bneeded check when more pages done for backlight on page 7 SMS fc3 bs
BGROUND.controllers			= {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1}}--MENU PAGE = 1
BGROUND.level 				= 2
BGROUND.h_clip_relation     = h_clip_relations.COMPARE
vertices(BGROUND,3)
Add(BGROUND)
----------------------------------------------------------------------------------------------------------------ADI
--ADI TEXT
ADITEXT 					    = CreateElement "ceStringPoly"
ADITEXT.name 				    = "menu"
ADITEXT.material 			    = UFD_FONT
ADITEXT.value 				    = "ADI"
ADITEXT.stringdefs 		        = {0.0050, 0.0050, 0.0004, 0.001}
ADITEXT.alignment 			    = "CenterCenter"
ADITEXT.formats 			    = {"%s"}
ADITEXT.h_clip_relation         = h_clip_relations.COMPARE
ADITEXT.level 				    = 2
ADITEXT.init_pos 			    = {-0.9, 0.42, 0}
ADITEXT.init_rot 			    = {0, 0, 0}
ADITEXT.element_params 	        = {"MFD_OPACITY","LMFD_MENU_PAGE"}
ADITEXT.controllers		        =   {
                                            {"opacity_using_parameter",0},
                                            {"parameter_in_range",1,0.9,1.1},--MENU PAGE = 0
						                }
Add(ADITEXT)
----------------------------------------------------------------------------------------------------------------ADI
--HSI TEXT
HSITEXT 					    = CreateElement "ceStringPoly"
HSITEXT.name 				    = "menu"
HSITEXT.material 			    = UFD_FONT
HSITEXT.value 				    = "HSI"
HSITEXT.stringdefs 		        = {0.0050, 0.0050, 0.0004, 0.001}
HSITEXT.alignment 			    = "CenterCenter"
HSITEXT.formats 			    = {"%s"}
HSITEXT.h_clip_relation         = h_clip_relations.COMPARE
HSITEXT.level 				    = 2
HSITEXT.init_pos 			    = {0.9, 0.42, 0}
HSITEXT.init_rot 			    = {0, 0, 0}
HSITEXT.element_params 	        = {"MFD_OPACITY","LMFD_MENU_PAGE"}
HSITEXT.controllers		        =   {
                                            {"opacity_using_parameter",0},
                                            {"parameter_in_range",1,0.9,1.1},--MENU PAGE = 0
						                }
Add(HSITEXT)
----------------------------------------------------------------------------------------------------------------ENG
--ENG TEXT
ENGTEXT 					    = CreateElement "ceStringPoly"
ENGTEXT.name 				    = "menu"
ENGTEXT.material 			    = UFD_FONT
ENGTEXT.value 				    = "ENG"
ENGTEXT.stringdefs 		        = {0.0050, 0.0050, 0.0004, 0.001}
ENGTEXT.alignment 			    = "CenterCenter"
ENGTEXT.formats 			    = {"%s"}
ENGTEXT.h_clip_relation         = h_clip_relations.COMPARE
ENGTEXT.level 				    = 2
ENGTEXT.init_pos 			    = {-0.90, -0.14, 0}
ENGTEXT.init_rot 			    = {0, 0, 0}
ENGTEXT.element_params 	        = {"MFD_OPACITY","LMFD_MENU_PAGE"}
ENGTEXT.controllers		        =   {
                                            {"opacity_using_parameter",0},
                                            {"parameter_in_range",1,0.9,1.1},--MENU PAGE = 0
						                }
Add(ENGTEXT)
----------------------------------------------------------------------------------------------------------------FCS
--FCS TEXT
FCSTEXT 					    = CreateElement "ceStringPoly"
FCSTEXT.name 				    = "menu"
FCSTEXT.material 			    = UFD_FONT
FCSTEXT.value 				    = "FCS"
FCSTEXT.stringdefs 		        = {0.0050, 0.0050, 0.0004, 0.001}
FCSTEXT.alignment 			    = "CenterCenter"
FCSTEXT.formats 			    = {"%s"}
FCSTEXT.h_clip_relation         = h_clip_relations.COMPARE
FCSTEXT.level 				    = 2
FCSTEXT.init_pos 			    = {0.90,-0.14, 0}
FCSTEXT.init_rot 			    = {0, 0, 0}
FCSTEXT.element_params 	        = {"MFD_OPACITY","LMFD_MENU_PAGE"}
FCSTEXT.controllers		        =   {
                                            {"opacity_using_parameter",0},
                                            {"parameter_in_range",1,0.9,1.1},--MENU PAGE = 0
						                }
Add(FCSTEXT)
----------------------------------------------------------------------------------------------------------------FUEL
--FUEL TEXT
FUELTEXT 					    = CreateElement "ceStringPoly"
FUELTEXT.name 				    = "menu"
FUELTEXT.material 			    = UFD_FONT
FUELTEXT.value 				    = "FUEL"
FUELTEXT.stringdefs 		    = {0.0050, 0.0050, 0.0004, 0.001}
FUELTEXT.alignment 			    = "CenterCenter"
FUELTEXT.formats 			    = {"%s"}
FUELTEXT.h_clip_relation         = h_clip_relations.COMPARE
FUELTEXT.level 				    = 2
FUELTEXT.init_pos 			    = {0.89, -0.70, 0}
FUELTEXT.init_rot 			    = {0, 0, 0}
FUELTEXT.element_params 	        = {"MFD_OPACITY","LMFD_MENU_PAGE"}
FUELTEXT.controllers		        =   {
                                            {"opacity_using_parameter",0},
                                            {"parameter_in_range",1,0.9,1.1},--MENU PAGE = 0
						                }
Add(FUELTEXT)
----------------------------------------------------------------------------------------------------------------FUEL
--FUEL TEXT
BAYTEXT 					    = CreateElement "ceStringPoly"
BAYTEXT.name 				    = "menu"
BAYTEXT.material 			    = UFD_FONT
BAYTEXT.value 				    = "BAY"
BAYTEXT.stringdefs 		    = {0.0050, 0.0050, 0.0004, 0.001}
BAYTEXT.alignment 			    = "CenterCenter"
BAYTEXT.formats 			    = {"%s"}
BAYTEXT.h_clip_relation         = h_clip_relations.COMPARE
BAYTEXT.level 				    = 2
BAYTEXT.init_pos 			    = {-0.90, -0.70, 0}
BAYTEXT.init_rot 			    = {0, 0, 0}
BAYTEXT.element_params 	        = {"MFD_OPACITY","LMFD_MENU_PAGE"}
BAYTEXT.controllers		        =   {
                                            {"opacity_using_parameter",0},
                                            {"parameter_in_range",1,0.9,1.1},--MENU PAGE = 0
						                }
Add(BAYTEXT)
----------------------------------------------------------------------------------------------------------------CHK
--CHK TEXT
CHKTEXT 					    = CreateElement "ceStringPoly"
CHKTEXT.name 				    = "menu"
CHKTEXT.material 			    = UFD_FONT
CHKTEXT.value 				    = "CHK"
CHKTEXT.stringdefs 		        = {0.0050, 0.0050, 0.0004, 0.001}
CHKTEXT.alignment 			    = "CenterCenter"
CHKTEXT.formats 			    = {"%s"}
CHKTEXT.h_clip_relation         = h_clip_relations.COMPARE
CHKTEXT.level 				    = 2
CHKTEXT.init_pos 			    = {0, 0.92, 0}
CHKTEXT.init_rot 			    = {0, 0, 0}
CHKTEXT.element_params 	        = {"MFD_OPACITY","LMFD_MENU_PAGE"}
CHKTEXT.controllers		        =   {
                                            {"opacity_using_parameter",0},
                                            {"parameter_in_range",1,0.9,1.1},--MENU PAGE = 0
						                }
Add(CHKTEXT)
----------------------------------------------------------------------------------------------------------------CHK
--CHK TEXT
SMSTEXT 					    = CreateElement "ceStringPoly"
SMSTEXT.name 				    = "menu"
SMSTEXT.material 			    = UFD_YEL
SMSTEXT.value 				    = "SMS"
SMSTEXT.stringdefs 		        = {0.0050, 0.0050, 0.0004, 0.001}
SMSTEXT.alignment 			    = "CenterCenter"
SMSTEXT.formats 			    = {"%s"}
SMSTEXT.h_clip_relation         = h_clip_relations.COMPARE
SMSTEXT.level 				    = 2
SMSTEXT.init_pos 			    = {0,-0.92, 0}
SMSTEXT.init_rot 			    = {0, 0, 0}
SMSTEXT.element_params 	        = {"MFD_OPACITY","LMFD_MENU_PAGE"}
SMSTEXT.controllers		        =   {
                                            {"opacity_using_parameter",0},
                                            {"parameter_in_range",1,0.9,1.1},--MENU PAGE = 0
						                }
Add(SMSTEXT)
------------------------------------------------------------------------------------------------
