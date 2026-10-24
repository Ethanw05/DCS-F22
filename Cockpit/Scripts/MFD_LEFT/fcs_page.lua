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
        width = 0.015 --height / 2
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
local FCS_PAGE      = MakeMaterial(LockOn_Options.script_path.."../Scripts/IndicationTextures/fcs_page.dds", GreenColor)
local FCS_IND       = MakeMaterial(LockOn_Options.script_path.."../Scripts/IndicationTextures/fcs_ind.dds", WhiteColor)
local MASK_BOX	    = MakeMaterial(LockOn_Options.script_path.."../Scripts/IndicationTextures/mask_box.dds", ScreenColor)
local MASK_BOX_IND  = MakeMaterial(LockOn_Options.script_path.."../Scripts/IndicationTextures/mask_box.dds", RedColor)
--------------------------------------------------------------------------------------------------------------------------------------------
local ClippingPlaneSize = 1.1 --Clipping Masks
local ClippingWidth 	= 1.1 --Clipping Masks
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
BGROUND                     = CreateElement "ceTexPoly"
BGROUND.name    			= "BackGround"
BGROUND.material			= MASK_BOX
BGROUND.change_opacity 		= false
BGROUND.collimated 			= false
BGROUND.isvisible 			= true
BGROUND.init_pos 			= {0, 0, 0} --L-R,U-D,F-B
BGROUND.init_rot 			= {0, 0, 0}
BGROUND.element_params 		= {"MFD_OPACITY","LMFD_FCS_PAGE"}--this may not be bneeded check when more pages done for backlight on page 7 SMS fc3 bs
BGROUND.controllers			= {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1}}--MENU PAGE = 1
BGROUND.level 				= 2
BGROUND.h_clip_relation     = h_clip_relations.COMPARE
vertices(BGROUND,3)
Add(BGROUND)
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--FCS PAGE
FCSP                        = CreateElement "ceTexPoly"
FCSP.name    			    = "menu"
FCSP.material			    = FCS_PAGE
FCSP.change_opacity 		= false
FCSP.collimated 			= false
FCSP.isvisible 			    = true
FCSP.init_pos 			    = {0, 0, 0} --L-R,U-D,F-B
FCSP.init_rot 			    = {0, 0, 0}
FCSP.element_params 		= {"MFD_OPACITY","LMFD_FCS_PAGE"}--this may not be bneeded check when more pages done for backlight on page 7 SMS fc3 bs
FCSP.controllers			= {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1}}--MENU PAGE = 1
FCSP.level 				    = 2
FCSP.h_clip_relation        = h_clip_relations.COMPARE
FCSP.parent_element         = BGROUND.name
vertices(FCSP,2)
Add(FCSP)
----------------------------------------------------------------------------------------------------------------------------------------------------------
--FCS INDICATORS
FCSIND                        = CreateElement "ceTexPoly"
FCSIND.name    			    = "menu"
FCSIND.material			    = FCS_IND
FCSIND.change_opacity 		= false
FCSIND.collimated 			= false
FCSIND.isvisible 			= true
FCSIND.init_pos 			= {0, 0, 0} --L-R,U-D,F-B
FCSIND.init_rot 			= {0, 0, 0}
FCSIND.element_params 		= {"MFD_OPACITY","LMFD_FCS_PAGE"}--this may not be bneeded check when more pages done for backlight on page 7 SMS fc3 bs
FCSIND.controllers			= {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1}}--MENU PAGE = 1
FCSIND.level 				= 2
FCSIND.h_clip_relation      = h_clip_relations.COMPARE
FCSIND.parent_element       = BGROUND.name
vertices(FCSIND,2)
Add(FCSIND)
-----------------------------------------------------------------------------------------------RIGHT RUDDER
FCS_RR                    = CreateElement "ceTexPoly"
FCS_RR.name    			    = "menu"
FCS_RR.material			    = MASK_BOX_IND
FCS_RR.change_opacity 		= false
FCS_RR.collimated 			= false
FCS_RR.isvisible 			= true
FCS_RR.init_pos 			= {0.2075, -0.17, 0} --L-R,U-D,F-B
FCS_RR.init_rot 			= {180, 0, 0}
FCS_RR.element_params 		= {"MFD_OPACITY","LMFD_FCS_PAGE","FCS_RR"}--this may not be bneeded check when more pages done for backlight on page 7 SMS fc3 bs
FCS_RR.controllers			=   {
                                    {"opacity_using_parameter",0},
                                    {"parameter_in_range",1,0.9,1.1},
                                    {"move_left_right_using_parameter",2,0.01,0},
                                    --{"move_left_right_using_parameter",3,0.005,0}
                                }
FCS_RR.level 				= 2
FCS_RR.h_clip_relation      = h_clip_relations.COMPARE
vertices(FCS_RR,0.06,true)
Add(FCS_RR)
-----------------------------------------------------------------------------------------------LEFT RUDDER
FCS_LR                    = CreateElement "ceTexPoly"
FCS_LR.name    			    = "menu"
FCS_LR.material			    = MASK_BOX_IND
FCS_LR.change_opacity 		= false
FCS_LR.collimated 			= false
FCS_LR.isvisible 			= true
FCS_LR.init_pos 			= {-0.2125, -0.17, 0} --L-R,U-D,F-B
FCS_LR.init_rot 			= {180, 0, 0}
FCS_LR.element_params 		= {"MFD_OPACITY","LMFD_FCS_PAGE","FCS_LR"}--this may not be bneeded check when more pages done for backlight on page 7 SMS fc3 bs
FCS_LR.controllers			=   {
                                    {"opacity_using_parameter",0},
                                    {"parameter_in_range",1,0.9,1.1},
                                    {"move_left_right_using_parameter",2,0.01,0},
                                    --{"move_left_right_using_parameter",3,0.005,0}
                                }
FCS_LR.level 				= 2
FCS_LR.h_clip_relation      = h_clip_relations.COMPARE
vertices(FCS_LR,0.06,true)
Add(FCS_LR)
---------------------------------------------------------------------------------------------------LEFT AILERON
FCS_LA                    = CreateElement "ceTexPoly"
FCS_LA.name    			    = "BG"
FCS_LA.material			    = MASK_BOX_IND
FCS_LA.change_opacity 		= false
FCS_LA.collimated 			= false
FCS_LA.isvisible 			= true
FCS_LA.init_pos 			= {-0.7535, -0.3175, 0} --L-R,U-D,F-B
FCS_LA.init_rot 			= {90, 0, 0}
FCS_LA.element_params 		= {"MFD_OPACITY","LMFD_FCS_PAGE","FCS_LA"}--this may not be bneeded check when more pages done for backlight on page 7 SMS fc3 bs
FCS_LA.controllers			=   {
                                    {"opacity_using_parameter",0},
                                    {"parameter_in_range",1,0.9,1.1},
                                    {"move_left_right_using_parameter",2,0.01,0}}--MENU PAGE = 1
FCS_LA.level 				= 2
FCS_LA.h_clip_relation      = h_clip_relations.COMPARE
vertices(FCS_LA,0.06,true)
Add(FCS_LA)
--------------------------------------------------------------------------------------------------- RIGHT AILERON
FCS_RA                    = CreateElement "ceTexPoly"
FCS_RA.name    			    = "BG"
FCS_RA.material			    = MASK_BOX_IND
FCS_RA.change_opacity 		= false
FCS_RA.collimated 			= false
FCS_RA.isvisible 			= true
FCS_RA.init_pos 			= {0.7535, -0.315, 0} --L-R,U-D,F-B
FCS_RA.init_rot 			= {90, 0, 0}
FCS_RA.element_params 		= {"MFD_OPACITY","LMFD_FCS_PAGE","FCS_RA"}--this may not be bneeded check when more pages done for backlight on page 7 SMS fc3 bs
FCS_RA.controllers			=   {
                                    {"opacity_using_parameter",0},
                                    {"parameter_in_range",1,0.9,1.1},
                                    {"move_left_right_using_parameter",2,0.01,0}}--MENU PAGE = 1
FCS_RA.level 				= 2
FCS_RA.h_clip_relation      = h_clip_relations.COMPARE
vertices(FCS_RA,0.06,true)
Add(FCS_RA)
---------------------------------------------------------------------------------------------------LEFT ELEVATOR
FCS_LE                    = CreateElement "ceTexPoly"
FCS_LE.name    			    = "BG"
FCS_LE.material			    = MASK_BOX_IND
FCS_LE.change_opacity 		= false
FCS_LE.collimated 			= false
FCS_LE.isvisible 			= true
FCS_LE.init_pos 			= {-0.562, -0.70, 0} --L-R,U-D,F-B
FCS_LE.init_rot 			= {90, 0, 0}
FCS_LE.element_params 		= {"MFD_OPACITY","LMFD_FCS_PAGE","FCS_LE"}--this may not be bneeded check when more pages done for backlight on page 7 SMS fc3 bs
FCS_LE.controllers			=   {
                                    {"opacity_using_parameter",0},
                                    {"parameter_in_range",1,0.9,1.1},
                                    {"move_left_right_using_parameter",2,0.01,0}}--MENU PAGE = 1
FCS_LE.level 				= 2
FCS_LE.h_clip_relation      = h_clip_relations.COMPARE
vertices(FCS_LE,0.06,true)
Add(FCS_LE)
--------------------------------------------------------------------------------------------------- RIGHT ELEVATOR
FCS_RE                    = CreateElement "ceTexPoly"
FCS_RE.name    			    = "BG"
FCS_RE.material			    = MASK_BOX_IND
FCS_RE.change_opacity 		= false
FCS_RE.collimated 			= false
FCS_RE.isvisible 			= true
FCS_RE.init_pos 			= {0.562, -0.70, 0} --L-R,U-D,F-B
FCS_RE.init_rot 			= {90, 0, 0}
FCS_RE.element_params 		= {"MFD_OPACITY","LMFD_FCS_PAGE","FCS_RE"}--this may not be bneeded check when more pages done for backlight on page 7 SMS fc3 bs
FCS_RE.controllers			=   {
                                   {"opacity_using_parameter",0},
                                   {"parameter_in_range",1,0.9,1.1},
                                   {"move_left_right_using_parameter",2,0.01,0}}--MENU PAGE = 1
FCS_RE.level 				= 2
FCS_RE.h_clip_relation      = h_clip_relations.COMPARE
vertices(FCS_RE,0.06,true)
Add(FCS_RE)
---------------------------------------------------------------------------------------------------LEFT FLAPS
FCS_LF                    = CreateElement "ceTexPoly"
FCS_LF.name    			    = "BG"
FCS_LF.material			    = MASK_BOX_IND
FCS_LF.change_opacity 		= false
FCS_LF.collimated 			= false
FCS_LF.isvisible 			= true
FCS_LF.init_pos 			= {0.54, 0.591, 0} --L-R,U-D,F-B
FCS_LF.init_rot 			= {270, 0, 0}
FCS_LF.element_params 		= {"MFD_OPACITY","LMFD_FCS_PAGE","FCS_LF"}--this may not be bneeded check when more pages done for backlight on page 7 SMS fc3 bs
FCS_LF.controllers			=   {
                                    {"opacity_using_parameter",0},
                                    {"parameter_in_range",1,0.9,1.1},
                                    {"move_left_right_using_parameter",2,0.0190,0}}--MENU PAGE = 1
FCS_LF.level 				= 2
FCS_LF.h_clip_relation      = h_clip_relations.COMPARE
vertices(FCS_LF,0.06,true)
Add(FCS_LF)
--------------------------------------------------------------------------------------------------- RIGHT FLAPS
FCS_RF                    = CreateElement "ceTexPoly"
FCS_RF.name    			    = "BG"
FCS_RF.material			    = MASK_BOX_IND
FCS_RF.change_opacity 		= false
FCS_RF.collimated 			= false
FCS_RF.isvisible 			= true
FCS_RF.init_pos 			= {0.734, 0.591, 0} --L-R,U-D,F-B
FCS_RF.init_rot 			= {270, 0, 0}
FCS_RF.element_params 		= {"MFD_OPACITY","LMFD_FCS_PAGE","FCS_RF"}--this may not be bneeded check when more pages done for backlight on page 7 SMS fc3 bs
FCS_RF.controllers			=   {
                                    {"opacity_using_parameter",0},
                                    {"parameter_in_range",1,0.9,1.1},
                                    {"move_left_right_using_parameter",2,0.0190,0}}--MENU PAGE = 1
FCS_RF.level 				= 2
FCS_RF.h_clip_relation      = h_clip_relations.COMPARE
vertices(FCS_RF,0.06,true)
Add(FCS_RF)
---------------------------------------------------------------------------------------------------LEFT LEF
FCS_L_LEF                       = CreateElement "ceTexPoly"
FCS_L_LEF.name    			    = "BG"
FCS_L_LEF.material			    = MASK_BOX_IND
FCS_L_LEF.change_opacity 		= false
FCS_L_LEF.collimated 			= false
FCS_L_LEF.isvisible 			= true
FCS_L_LEF.init_pos 			    = {-0.674, 0.592, 0} --L-R,U-D,F-B
FCS_L_LEF.init_rot 			    = {270, 0, 0}
FCS_L_LEF.element_params 		= {"MFD_OPACITY","LMFD_FCS_PAGE","FCS_LEF"}--this may not be bneeded check when more pages done for backlight on page 7 SMS fc3 bs
FCS_L_LEF.controllers			=   {
                                        {"opacity_using_parameter",0},
                                        {"parameter_in_range",1,0.9,1.1},
                                        {"move_left_right_using_parameter",2,0.019,0}}--MENU PAGE = 1
FCS_L_LEF.level 				= 2
FCS_L_LEF.h_clip_relation       = h_clip_relations.COMPARE
vertices(FCS_L_LEF,0.06,true)
Add(FCS_L_LEF)
--------------------------------------------------------------------------------------------------- RIGHT LEF
FCS_R_LEF                       = CreateElement "ceTexPoly"
FCS_R_LEF.name    			    = "BG"
FCS_R_LEF.material			    = MASK_BOX_IND
FCS_R_LEF.change_opacity 		= false
FCS_R_LEF.collimated 			= false
FCS_R_LEF.isvisible 			= true
FCS_R_LEF.init_pos 			    = {-0.476, 0.592, 0} --L-R,U-D,F-B
FCS_R_LEF.init_rot 			    = {270, 0, 0}
FCS_R_LEF.element_params 		= {"MFD_OPACITY","LMFD_FCS_PAGE","FCS_LEF"}--this may not be bneeded check when more pages done for backlight on page 7 SMS fc3 bs
FCS_R_LEF.controllers			=   {
                                        {"opacity_using_parameter",0},
                                        {"parameter_in_range",1,0.9,1.1},
                                        {"move_left_right_using_parameter",2,0.019,0}}--MENU PAGE = 1
FCS_R_LEF.level 				= 2
FCS_R_LEF.h_clip_relation       = h_clip_relations.COMPARE
vertices(FCS_R_LEF,0.06,true)
Add(FCS_R_LEF)
--------------------------------------------------------------------------------------------------- MENU TEXT
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
MENU_CHK_TEXT.init_pos 			    = {-0.565, 0.92, 0}
MENU_CHK_TEXT.init_rot 			    = {0, 0, 0}
MENU_CHK_TEXT.element_params 	    = {"MFD_OPACITY","LMFD_FCS_PAGE"}
MENU_CHK_TEXT.controllers		    =   {
                                        {"opacity_using_parameter",0},
                                        {"parameter_in_range",1,0.9,1.1},--ENGINE PAGE = 0
						            }
Add(MENU_CHK_TEXT)
--------------------------------------------------------------------------------------------------- NAV
MENU_TEXT1 					        = CreateElement "ceStringPoly"
MENU_TEXT1.name 				    = "menu"
MENU_TEXT1.material 			    = UFD_GRN
MENU_TEXT1.value 				    = "SMS"
MENU_TEXT1.stringdefs 		        = {0.0050, 0.0050, 0.0004, 0.001}
MENU_TEXT1.alignment 			    = "CenterCenter"
MENU_TEXT1.formats 			        = {"%s"}
MENU_TEXT1.h_clip_relation          = h_clip_relations.COMPARE
MENU_TEXT1.level 				    = 2
MENU_TEXT1.init_pos 			        = {-0.265, 0.92, 0}
MENU_TEXT1.init_rot 			        = {0, 0, 0}
MENU_TEXT1.element_params 	        = {"MFD_OPACITY","LMFD_FCS_PAGE"}
MENU_TEXT1.controllers		        =   {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1},}
Add(MENU_TEXT1)
--------------------------------------------------------------------------------------------------- NAV
MENU_TEXT2 					        = CreateElement "ceStringPoly"
MENU_TEXT2.name 				    = "menu"
MENU_TEXT2.material 			    = UFD_GRN
MENU_TEXT2.value 				    = "ENG"
MENU_TEXT2.stringdefs 		        = {0.0050, 0.0050, 0.0004, 0.001}
MENU_TEXT2.alignment 			    = "CenterCenter"
MENU_TEXT2.formats 			        = {"%s"}
MENU_TEXT2.h_clip_relation          = h_clip_relations.COMPARE
MENU_TEXT2.level 				    = 2
MENU_TEXT2.init_pos 			        = {0.265, 0.92, 0}
MENU_TEXT2.init_rot 			        = {0, 0, 0}
MENU_TEXT2.element_params 	        = {"MFD_OPACITY","LMFD_FCS_PAGE"}
MENU_TEXT2.controllers		        =   {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1},}
Add(MENU_TEXT2)
--------------------------------------------------------------------------------------------------- NAV
MENU_TEXT3 					        = CreateElement "ceStringPoly"
MENU_TEXT3.name 				    = "menu"
MENU_TEXT3.material 			    = UFD_GRN
MENU_TEXT3.value 				    = "FUEL"
MENU_TEXT3.stringdefs 		        = {0.0050, 0.0050, 0.0004, 0.001}
MENU_TEXT3.alignment 			    = "CenterCenter"
MENU_TEXT3.formats 			        = {"%s"}
MENU_TEXT3.h_clip_relation          = h_clip_relations.COMPARE
MENU_TEXT3.level 				    = 2
MENU_TEXT3.init_pos 			        = {0.565, 0.92, 0}
MENU_TEXT3.init_rot 			        = {0, 0, 0}
MENU_TEXT3.element_params 	        = {"MFD_OPACITY","LMFD_FCS_PAGE"}
MENU_TEXT3.controllers		        =   {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1},}
Add(MENU_TEXT3)
--------------------------------88888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888
--------------------------------------------------------------------------------------------------- AUTO
-- AUTO_FCS 					        = CreateElement "ceStringPoly"
-- AUTO_FCS.name 				        = "menu"
-- AUTO_FCS.material 			        = UFD_RED
-- AUTO_FCS.value 				        = "ORIDE"
-- AUTO_FCS.stringdefs 		        = {0.0050, 0.0050, 0.0004, 0.001}
-- AUTO_FCS.alignment 			        = "CenterCenter"
-- AUTO_FCS.formats 			        = {"%s"}
-- AUTO_FCS.h_clip_relation            = h_clip_relations.COMPARE
-- AUTO_FCS.level 				        = 2
-- AUTO_FCS.init_pos 			        = {0, -0.92, 0}
-- AUTO_FCS.init_rot 			        = {0, 0, 0}
-- AUTO_FCS.element_params 	        = {"MFD_OPACITY","LMFD_FCS_PAGE","FCS_AUTO"}
-- AUTO_FCS.controllers		        =   {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1},{"parameter_in_range",2,0.9,1.1}}
-- Add(AUTO_FCS)
-- --------------------------------------------------------------------------------------------------- ORIDE
-- ORIDE_FCS 					        = CreateElement "ceStringPoly"
-- ORIDE_FCS.name 				        = "menu"
-- ORIDE_FCS.material 			        = UFD_GRN
-- ORIDE_FCS.value 				    = "AUTO"
-- ORIDE_FCS.stringdefs 		        = {0.0050, 0.0050, 0.0004, 0.001}
-- ORIDE_FCS.alignment 			        = "CenterCenter"
-- ORIDE_FCS.formats 			        = {"%s"}
-- ORIDE_FCS.h_clip_relation            = h_clip_relations.COMPARE
-- ORIDE_FCS.level 				        = 2
-- ORIDE_FCS.init_pos 			        = {0, -0.92, 0}
-- ORIDE_FCS.init_rot 			        = {0, 0, 0}
-- ORIDE_FCS.element_params 	        = {"MFD_OPACITY","LMFD_FCS_PAGE","FCS_AUTO"}
-- ORIDE_FCS.controllers		        =   {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1},{"parameter_in_range",2,-0.1,0.1}}
-- Add(ORIDE_FCS)
-- --------------------------------------------------------------------------------------------------- G MODE
-- G_FCS 					        = CreateElement "ceStringPoly"
-- G_FCS.name 				        = "menu"
-- G_FCS.material 			        = UFD_GRN
-- G_FCS.value 				    = "ACL"
-- G_FCS.stringdefs 		        = {0.0050, 0.0050, 0.0004, 0.001}
-- G_FCS.alignment 			        = "CenterCenter"
-- G_FCS.formats 			        = {"%s"}
-- G_FCS.h_clip_relation            = h_clip_relations.COMPARE
-- G_FCS.level 				        = 2
-- G_FCS.init_pos 			        = {-0.265, -0.92, 0}
-- G_FCS.init_rot 			        = {0, 0, 0}
-- G_FCS.element_params 	        = {"MFD_OPACITY","LMFD_FCS_PAGE"}
-- G_FCS.controllers		        =   {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1}}
-- Add(G_FCS)
-- --------------------------------AOA
-- A_FCS 					        = CreateElement "ceStringPoly"
-- A_FCS.name 				        = "menu"
-- A_FCS.material 			        = UFD_GRN
-- A_FCS.value 				    = "AOA"
-- A_FCS.stringdefs 		        = {0.0050, 0.0050, 0.0004, 0.001}
-- A_FCS.alignment 			        = "CenterCenter"
-- A_FCS.formats 			        = {"%s"}
-- A_FCS.h_clip_relation            = h_clip_relations.COMPARE
-- A_FCS.level 				        = 2
-- A_FCS.init_pos 			        = {0.265, -0.92, 0}
-- A_FCS.init_rot 			        = {0, 0, 0}
-- A_FCS.element_params 	        = {"MFD_OPACITY","LMFD_FCS_PAGE"}
-- A_FCS.controllers		        =   {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1}}
-- Add(A_FCS)
-- --888888888888888888888888888888888888888888888888888888
-- --888888888888888888888888888888888888888888888888888888
-- --888888888888888888888888888888888888888888888888888888
-- --888888888888888888888888888888888888888888888888888888
-- --------------------------------------------------------------------------------------------------- AUTO
-- INFO_FCS_AUTO 					        = CreateElement "ceStringPoly"
-- INFO_FCS_AUTO.name 				        = "menu"
-- INFO_FCS_AUTO.material 			        = UFD_GRN
-- INFO_FCS_AUTO.value 				    = "FCS AUTO"
-- INFO_FCS_AUTO.stringdefs 		        = {0.0050, 0.0050, 0.0004, 0.001}
-- INFO_FCS_AUTO.alignment 			    = "CenterCenter"
-- INFO_FCS_AUTO.formats 			        = {"%s"}
-- INFO_FCS_AUTO.h_clip_relation           = h_clip_relations.COMPARE
-- INFO_FCS_AUTO.level 				        = 2
-- INFO_FCS_AUTO.init_pos 			        = {0, 0.05, 0}
-- INFO_FCS_AUTO.init_rot 			        = {0, 0, 0}
-- INFO_FCS_AUTO.element_params 	        = {"MFD_OPACITY","LMFD_FCS_PAGE","FCS_MODE"}
-- INFO_FCS_AUTO.controllers		        =   {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1},{"parameter_in_range",2,-0.1,0.1}}
-- Add(INFO_FCS_AUTO)
-- --------------------------------------------------------------------------------------------------- AUTO G
-- INFO_FCS_AUTO 					        = CreateElement "ceStringPoly"
-- INFO_FCS_AUTO.name 				        = "menu"
-- INFO_FCS_AUTO.material 			        = UFD_FONT
-- INFO_FCS_AUTO.value 				    = "G"
-- INFO_FCS_AUTO.stringdefs 		        = {0.0050, 0.0050, 0.0004, 0.001}
-- INFO_FCS_AUTO.alignment 			    = "CenterCenter"
-- INFO_FCS_AUTO.formats 			        = {"%s"}
-- INFO_FCS_AUTO.h_clip_relation           = h_clip_relations.COMPARE
-- INFO_FCS_AUTO.level 				        = 2
-- INFO_FCS_AUTO.init_pos 			        = {0, -0.05, 0}
-- INFO_FCS_AUTO.init_rot 			        = {0, 0, 0}
-- INFO_FCS_AUTO.element_params 	        = {"MFD_OPACITY","LMFD_FCS_PAGE","HUD_MODE","FCS_MODE"}
-- INFO_FCS_AUTO.controllers		        =   {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1},{"parameter_in_range",2,0.9,1.1},{"parameter_in_range",3,-0.1,0.1}}
-- Add(INFO_FCS_AUTO)
-- --------------------------------------------------------------------------------------------------- AUTO G
-- INFO_FCS_AUTO 					        = CreateElement "ceStringPoly"
-- INFO_FCS_AUTO.name 				        = "menu"
-- INFO_FCS_AUTO.material 			        = UFD_FONT
-- INFO_FCS_AUTO.value 				    = "AOA"
-- INFO_FCS_AUTO.stringdefs 		        = {0.0050, 0.0050, 0.0004, 0.001}
-- INFO_FCS_AUTO.alignment 			    = "CenterCenter"
-- INFO_FCS_AUTO.formats 			        = {"%s"}
-- INFO_FCS_AUTO.h_clip_relation           = h_clip_relations.COMPARE
-- INFO_FCS_AUTO.level 				        = 2
-- INFO_FCS_AUTO.init_pos 			        = {0, -0.05, 0}
-- INFO_FCS_AUTO.init_rot 			        = {0, 0, 0}
-- INFO_FCS_AUTO.element_params 	        = {"MFD_OPACITY","LMFD_FCS_PAGE","HUD_MODE","FCS_MODE"}
-- INFO_FCS_AUTO.controllers		        =   {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1},{"parameter_in_range",2,1.1,9},{"parameter_in_range",3,-0.1,0.1}}
-- Add(INFO_FCS_AUTO)

-- --------------------------------------------------------------------------------------------------- ORIDE
-- INFO_FCS_ORIDE 					        = CreateElement "ceStringPoly"
-- INFO_FCS_ORIDE.name 				    = "menu"
-- INFO_FCS_ORIDE.material 			    = UFD_RED
-- INFO_FCS_ORIDE.value 				    = "FCS OVERRIDE"
-- INFO_FCS_ORIDE.stringdefs 		        = {0.0050, 0.0050, 0.0004, 0.001}
-- INFO_FCS_ORIDE.alignment 			    = "CenterCenter"
-- INFO_FCS_ORIDE.formats 			        = {"%s"}
-- INFO_FCS_ORIDE.h_clip_relation          = h_clip_relations.COMPARE
-- INFO_FCS_ORIDE.level 				    = 2
-- INFO_FCS_ORIDE.init_pos 			    = {0, 0.05, 0}
-- INFO_FCS_ORIDE.init_rot 			    = {0, 0, 0}
-- INFO_FCS_ORIDE.element_params 	        = {"MFD_OPACITY","LMFD_FCS_PAGE","FCS_MODE"}
-- INFO_FCS_ORIDE.controllers		        =   {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1},{"parameter_in_range",2,2.9,3.1}}
-- Add(INFO_FCS_ORIDE)
-- --------------------------------------------------------------------------------------------------- AOA
-- INFO_FCS_G 					        = CreateElement "ceStringPoly"
-- INFO_FCS_G.name 				    = "menu"
-- INFO_FCS_G.material 			    = UFD_YEL
-- INFO_FCS_G.value 				    = "FCS AOA OVRD"
-- INFO_FCS_G.stringdefs 		        = {0.0050, 0.0050, 0.0004, 0.001}
-- INFO_FCS_G.alignment 			    = "CenterCenter"
-- INFO_FCS_G.formats 			        = {"%s"}
-- INFO_FCS_G.h_clip_relation          = h_clip_relations.COMPARE
-- INFO_FCS_G.level 				    = 2
-- INFO_FCS_G.init_pos 			    = {0, 0.05, 0}
-- INFO_FCS_G.init_rot 			    = {0, 0, 0}
-- INFO_FCS_G.element_params 	        = {"MFD_OPACITY","LMFD_FCS_PAGE","FCS_MODE"}
-- INFO_FCS_G.controllers		        =   {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1},{"parameter_in_range",2,0.9,1.1}}
-- Add(INFO_FCS_G)
-- --------------------------------------------------------------------------------------------------- ACL
-- INFO_FCS_A 					        = CreateElement "ceStringPoly"
-- INFO_FCS_A.name 				    = "menu"
-- INFO_FCS_A.material 			    = UFD_YEL
-- INFO_FCS_A.value 				    = "FCS G OVRD"
-- INFO_FCS_A.stringdefs 		        = {0.0050, 0.0050, 0.0004, 0.001}
-- INFO_FCS_A.alignment 			    = "CenterCenter"
-- INFO_FCS_A.formats 			        = {"%s"}
-- INFO_FCS_A.h_clip_relation          = h_clip_relations.COMPARE
-- INFO_FCS_A.level 				    = 2
-- INFO_FCS_A.init_pos 			    = {0, 0.05, 0}
-- INFO_FCS_A.init_rot 			    = {0, 0, 0}
-- INFO_FCS_A.element_params 	        = {"MFD_OPACITY","LMFD_FCS_PAGE","FCS_MODE"}
-- INFO_FCS_A.controllers		        =   {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1},{"parameter_in_range",2,1.9,2.1}}
-- Add(INFO_FCS_A)
--888888888888888888888888888888888888888888888888888888

--local fcs_mode = 0 -- 0 = AUTO - 1 = AOA ORIDE - 2 = G ORIDE - 3 = OFF
----------------------------------
AOA_NUM				    = CreateElement "ceStringPoly"
AOA_NUM.name				= "AOA_NUM"
AOA_NUM.material			= UFD_FONT
AOA_NUM.init_pos			= {-0.42, 0.1, 0} --L-R,U-D,F-B
AOA_NUM.alignment			= "RightCenter"
AOA_NUM.stringdefs			= {0.0050, 0.0050, 0.0004, 0.001}
AOA_NUM.additive_alpha		= true
AOA_NUM.collimated			= false
AOA_NUM.isdraw				= true	
AOA_NUM.use_mipfilter		= true
AOA_NUM.h_clip_relation	    = h_clip_relations.COMPARE
AOA_NUM.level				= 2
--AOA_NUM.parent_element      = G_NUM.name
AOA_NUM.element_params		= {"MFD_OPACITY","AOA","LMFD_FCS_PAGE"}
AOA_NUM.formats			    = {"%02.2f"}--= {"%02.0f"}
AOA_NUM.controllers		    =   {
                                        {"opacity_using_parameter",0},
                                        {"text_using_parameter",1,0},
                                        {"parameter_in_range",2,0.9,1.1}
                                    }
                                
Add(AOA_NUM)
------
AOA_TXT 					    = CreateElement "ceStringPoly"
AOA_TXT.name 				    = "pitch"
AOA_TXT.material 			    = UFD_GRN
AOA_TXT.value 				    = "AOA:"
AOA_TXT.stringdefs 		        = {0.0050, 0.0050, 0.0004, 0.001}
AOA_TXT.alignment 			    = "CenterCenter"
AOA_TXT.formats 			    = {"%s"}
AOA_TXT.h_clip_relation         = h_clip_relations.COMPARE
AOA_TXT.level 				    = 2
AOA_TXT.init_pos 			    = {-0.7, 0.1, 0}
AOA_TXT.init_rot 			    = {0, 0, 0}
AOA_TXT.element_params 	        = {"MFD_OPACITY","LMFD_FCS_PAGE"}
AOA_TXT.controllers		        = {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1}}
--AOA_TXT.parent_element            = G_TXT.name
Add(AOA_TXT)
--------------
G_NUM				    = CreateElement "ceStringPoly"
G_NUM.name				= "G_NUM"
G_NUM.material			= UFD_FONT
G_NUM.init_pos			= {-0.42, 0.2, 0} --L-R,U-D,F-B
G_NUM.alignment			= "RightCenter"
G_NUM.stringdefs		= {0.0050, 0.0050, 0.0004, 0.001}
G_NUM.additive_alpha	= true
G_NUM.collimated		= false
G_NUM.isdraw			= true	
G_NUM.use_mipfilter		= true
G_NUM.h_clip_relation	= h_clip_relations.COMPARE
G_NUM.level				= 2
G_NUM.element_params		= {"MFD_OPACITY","GFORCE","LMFD_FCS_PAGE"}
G_NUM.formats			= {"%02.2f"}--= {"%02.0f"}
G_NUM.controllers		=   {
                                        {"opacity_using_parameter",0},
                                        {"text_using_parameter",1,0},
                                        {"parameter_in_range",2,0.9,1.1}
                                    }
                                
Add(G_NUM)
---------------------------------------------------------------------
G_TXT 					    = CreateElement "ceStringPoly"
G_TXT.name 				    = "G_TXT"
G_TXT.material 			    = UFD_GRN
G_TXT.value 				    = "G:"
G_TXT.stringdefs 		        = {0.0050, 0.0050, 0.0004, 0.001}
G_TXT.alignment 			    = "CenterCenter"
G_TXT.formats 			    = {"%s"}
G_TXT.h_clip_relation         = h_clip_relations.COMPARE
G_TXT.level 				    = 2
G_TXT.init_pos 			    = {-0.652, 0.2, 0}
G_TXT.init_rot 			    = {0, 0, 0}
G_TXT.element_params 	        = {"MFD_OPACITY","LMFD_FCS_PAGE"}
G_TXT.controllers		        = {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1}}
Add(G_TXT)
