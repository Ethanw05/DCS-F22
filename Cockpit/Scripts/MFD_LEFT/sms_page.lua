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
BGROUND.element_params 		= {"MFD_OPACITY","LMFD_SMS_PAGE"}--this may not be bneeded check when more pages done for backlight on page 7 SMS fc3 bs
BGROUND.controllers			= {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1}}--MENU PAGE = 1
BGROUND.level 				= 2
BGROUND.h_clip_relation     = h_clip_relations.COMPARE
vertices(BGROUND,3)
Add(BGROUND)
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--MENU TEXT
MENU_CHK_TEXT 					    = CreateElement "ceStringPoly"
MENU_CHK_TEXT.name 				    = "menu"
MENU_CHK_TEXT.material 			    = UFD_FONT
MENU_CHK_TEXT.value 				= "MENU"
MENU_CHK_TEXT.stringdefs 		    = {0.0050, 0.0050, 0.0004, 0.001}
MENU_CHK_TEXT.alignment 			= "CenterCenter"
MENU_CHK_TEXT.formats 			    = {"%s"}
MENU_CHK_TEXT.h_clip_relation       = h_clip_relations.COMPARE
MENU_CHK_TEXT.level 				= 2
MENU_CHK_TEXT.init_pos 			    = {0,-0.92, 0}
MENU_CHK_TEXT.init_rot 			    = {0, 0, 0}
MENU_CHK_TEXT.element_params 	    = {"MFD_OPACITY","LMFD_SMS_PAGE"}
MENU_CHK_TEXT.controllers		    =   {
                                        {"opacity_using_parameter",0},
                                        {"parameter_in_range",1,0.9,1.1},--ENGINE PAGE = 0
						            }
Add(MENU_CHK_TEXT)
-------------------------------
--MENU TEXT
CENTER_TEXT 					    = CreateElement "ceStringPoly"
CENTER_TEXT.name 				    = "menu"
CENTER_TEXT.material 			    = UFD_FONT
CENTER_TEXT.value 				    = "CENTER"
CENTER_TEXT.stringdefs 		        = {0.0060, 0.0060, 0.0004, 0.001}
CENTER_TEXT.alignment 			    = "CenterCenter"
CENTER_TEXT.formats 			    = {"%s"}
CENTER_TEXT.h_clip_relation         = h_clip_relations.COMPARE
CENTER_TEXT.level 				    = 2
CENTER_TEXT.init_pos 			    = {0,-0.20, 0}
CENTER_TEXT.init_rot 			    = {0, 0, 0}
CENTER_TEXT.element_params 	        = {"MFD_OPACITY","LMFD_SMS_PAGE","BAY_STATION"}
CENTER_TEXT.controllers		        =   {
                                        {"opacity_using_parameter",0},
                                        {"parameter_in_range",1,0.9,1.1},
                                        {"parameter_in_range",2,1.9,2.1}
						                }
Add(CENTER_TEXT)
-------------------------------
--MENU TEXT
LEFT_TEXT 					        = CreateElement "ceStringPoly"
LEFT_TEXT.name 				        = "menu"
LEFT_TEXT.material 			        = UFD_FONT
LEFT_TEXT.value 				    = "LEFT"
LEFT_TEXT.stringdefs 		        = {0.0060, 0.0060, 0.0004, 0.001}
LEFT_TEXT.alignment 			    = "CenterCenter"
LEFT_TEXT.formats 			        = {"%s"}
LEFT_TEXT.h_clip_relation           = h_clip_relations.COMPARE
LEFT_TEXT.level 				    = 2
LEFT_TEXT.init_pos 			        = {0,-0.20, 0}
LEFT_TEXT.init_rot 			        = {0, 0, 0}
LEFT_TEXT.element_params 	        = {"MFD_OPACITY","LMFD_SMS_PAGE","BAY_STATION"}
LEFT_TEXT.controllers		        =   {
                                        {"opacity_using_parameter",0},
                                        {"parameter_in_range",1,0.9,1.1},
                                        {"parameter_in_range",2,0.9,1.1}
						                }
Add(LEFT_TEXT)
--MENU TEXT
RIGHT_TEXT 					        = CreateElement "ceStringPoly"
RIGHT_TEXT.name 				    = "menu"
RIGHT_TEXT.material 			    = UFD_FONT
RIGHT_TEXT.value 				    = "RIGHT"
RIGHT_TEXT.stringdefs 		        = {0.0060, 0.0060, 0.0004, 0.001}
RIGHT_TEXT.alignment 			    = "CenterCenter"
RIGHT_TEXT.formats 			        = {"%s"}
RIGHT_TEXT.h_clip_relation          = h_clip_relations.COMPARE
RIGHT_TEXT.level 				    = 2
RIGHT_TEXT.init_pos 			    = {0,-0.20, 0}
RIGHT_TEXT.init_rot 			    = {0, 0, 0}
RIGHT_TEXT.element_params 	        = {"MFD_OPACITY","LMFD_SMS_PAGE","BAY_STATION"}
RIGHT_TEXT.controllers		        =   {
                                        {"opacity_using_parameter",0},
                                        {"parameter_in_range",1,0.9,1.1},
                                        {"parameter_in_range",2,2.9,3.1}
						                }
Add(RIGHT_TEXT)
--MENU TEXT
ALL_TEXT 					        = CreateElement "ceStringPoly"
ALL_TEXT.name 				        = "menu"
ALL_TEXT.material 			        = UFD_FONT
ALL_TEXT.value 				        = "ALL"
ALL_TEXT.stringdefs 		        = {0.0060, 0.0060, 0.0004, 0.001}
ALL_TEXT.alignment 			        = "CenterCenter"
ALL_TEXT.formats 			        = {"%s"}
ALL_TEXT.h_clip_relation            = h_clip_relations.COMPARE
ALL_TEXT.level 				        = 2
ALL_TEXT.init_pos 			        = {0,-0.20, 0}
ALL_TEXT.init_rot 			        = {0, 0, 0}
ALL_TEXT.element_params 	        = {"MFD_OPACITY","LMFD_SMS_PAGE","BAY_STATION"}
ALL_TEXT.controllers		        =   {
                                        {"opacity_using_parameter",0},
                                        {"parameter_in_range",1,0.9,1.1},
                                        {"parameter_in_range",2,3.9,4.1}
						                }
Add(ALL_TEXT)
