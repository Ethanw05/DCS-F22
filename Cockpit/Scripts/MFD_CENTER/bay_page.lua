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


dofile(LockOn_Options.script_path.."MFD_CENTER/definitions.lua")
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
local BlueColor 			= {0, 0, 255, 255}--RGBA
local ScreenColor			= {3, 3, 12, 255}--RGBA DO NOT TOUCH 3-3-12-255 is good for on screen
--------------------------------------------------------------------------------------------------------------------------------------------
local BAY               = MakeMaterial(LockOn_Options.script_path.."../Scripts/IndicationTextures/bay_frame.dds", GreenColor)--SYSTEM TEST
local LABLE             = MakeMaterial(LockOn_Options.script_path.."../Scripts/IndicationTextures/bay_txt.dds", GreenColor)--SYSTEM TEST
local BAY_DOOR_BOX      = MakeMaterial(LockOn_Options.script_path.."../Scripts/IndicationTextures/bay_box.dds", WhiteColor)--SYSTEM TEST

local BAY_BOX           = MakeMaterial(LockOn_Options.script_path.."../Scripts/IndicationTextures/bay_midbox.dds", WhiteColor)--SYSTEM TEST
local BAY_SQ            = MakeMaterial(LockOn_Options.script_path.."../Scripts/IndicationTextures/bay_bbox.dds", WhiteColor)--SYSTEM TEST
local BAY_ORIDE         = MakeMaterial(LockOn_Options.script_path.."../Scripts/IndicationTextures/bay_oride.dds", WhiteColor)--SYSTEM TEST
local BAY_X             = MakeMaterial(LockOn_Options.script_path.."../Scripts/IndicationTextures/bay_x.dds", YellowColor)--SYSTEM TEST

local BAY_L             = MakeMaterial(LockOn_Options.script_path.."../Scripts/IndicationTextures/bay_L.dds", GreenColor)--SYSTEM TEST
local BAY_R             = MakeMaterial(LockOn_Options.script_path.."../Scripts/IndicationTextures/bay_R.dds", GreenColor)--SYSTEM TEST
local BAY_C             = MakeMaterial(LockOn_Options.script_path.."../Scripts/IndicationTextures/bay_C.dds", GreenColor)--SYSTEM TEST

local BAY_L_OPEN        = MakeMaterial(LockOn_Options.script_path.."../Scripts/IndicationTextures/bay_L_open.dds", GreenColor)--SYSTEM TEST
local BAY_R_OPEN        = MakeMaterial(LockOn_Options.script_path.."../Scripts/IndicationTextures/bay_R_open.dds", GreenColor)--SYSTEM TEST
local BAY_C_OPEN        = MakeMaterial(LockOn_Options.script_path.."../Scripts/IndicationTextures/bay_C_open.dds", GreenColor)--SYSTEM TEST

local BAY_L_SEL         = MakeMaterial(LockOn_Options.script_path.."../Scripts/IndicationTextures/bay_L_select.dds", WhiteColor)--SYSTEM TEST
local BAY_R_SEL         = MakeMaterial(LockOn_Options.script_path.."../Scripts/IndicationTextures/bay_R_select.dds", WhiteColor)--SYSTEM TEST
local BAY_C_SEL         = MakeMaterial(LockOn_Options.script_path.."../Scripts/IndicationTextures/bay_C_select.dds", WhiteColor)--SYSTEM TEST
local BAY_A_SEL         = MakeMaterial(LockOn_Options.script_path.."../Scripts/IndicationTextures/bay_A_select.dds", WhiteColor)--SYSTEM TEST

local RING_EGT_G        = MakeMaterial(LockOn_Options.script_path.."../Scripts/IndicationTextures/ring_egt.dds", GreenColor)--SYSTEM TEST
local RING_NEEDLE_G     = MakeMaterial(LockOn_Options.script_path.."../Scripts/IndicationTextures/ring_needle.dds", GreenColor)--SYSTEM TEST
local MASK_BOX	        = MakeMaterial(LockOn_Options.script_path.."../Scripts/IndicationTextures/mask_box.dds", ScreenColor)--SYSTEM TEST
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
BGROUND                    = CreateElement "ceTexPoly"
BGROUND.name    			= "LMFD_PAGE"
BGROUND.material			= MASK_BOX
BGROUND.change_opacity 		= false
BGROUND.collimated 			= false
BGROUND.isvisible 			= true
BGROUND.init_pos 			= {0, 0, 0} --L-R,U-D,F-B
BGROUND.init_rot 			= {0, 0, 0}
BGROUND.element_params 		= {"MFD_OPACITY","CMFD_BAY_PAGE"}--this may not be bneeded check when more pages done for backlight on page 7 SMS fc3 bs
BGROUND.controllers			= {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1}}--MENU PAGE = 1
BGROUND.level 				= 2
BGROUND.h_clip_relation     = h_clip_relations.COMPARE
vertices(BGROUND,3)
---------------------
Add(BGROUND)
LABLES                    = CreateElement "ceTexPoly"
LABLES.name    			= "Lables"
LABLES.material			= LABLE
LABLES.change_opacity 		= false
LABLES.collimated 			= false
LABLES.isvisible 			= true
LABLES.init_pos 			= {0, 0, 0} --L-R,U-D,F-B
LABLES.init_rot 			= {0, 0, 0}
LABLES.element_params 		= {"MFD_OPACITY","CMFD_BAY_PAGE"}--this may not be bneeded check when more pages done for backlight on page 7 SMS fc3 bs
LABLES.controllers			= {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1}}--MENU PAGE = 1
LABLES.level 				= 2
LABLES.h_clip_relation     = h_clip_relations.COMPARE
vertices(LABLES,2)
Add(LABLES)
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
BAYFRAME                        = CreateElement "ceTexPoly"
BAYFRAME.name    			    = "BG"
BAYFRAME.material			    = BAY
BAYFRAME.change_opacity 		= false
BAYFRAME.collimated 			= false
BAYFRAME.isvisible 			    = true
BAYFRAME.init_pos 			    = {0, 0, 0} --L-R,U-D,F-B
BAYFRAME.init_rot 			    = {0, 0, 0}
BAYFRAME.element_params 		= {"MFD_OPACITY","CMFD_BAY_PAGE"}--this may not be bneeded check when more pages done for backlight on page 7 SMS fc3 bs
BAYFRAME.controllers			= {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1}}--MENU PAGE = 1
BAYFRAME.level 				    = 2
BAYFRAME.h_clip_relation        = h_clip_relations.COMPARE
vertices(BAYFRAME,2)
Add(BAYFRAME)
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
BAYBOX                          = CreateElement "ceTexPoly"
BAYBOX.name    			        = "BG"
BAYBOX.material			        = BAY_BOX
BAYBOX.change_opacity 		    = false
BAYBOX.collimated 			    = false
BAYBOX.isvisible 			    = true
BAYBOX.init_pos 			    = {0, 0, 0} --L-R,U-D,F-B
BAYBOX.init_rot 			    = {0, 0, 0}
BAYBOX.element_params 		    = {"MFD_OPACITY","CMFD_BAY_PAGE"}--this may not be bneeded check when more pages done for backlight on page 7 SMS fc3 bs
BAYBOX.controllers			    = {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1}}--MENU PAGE = 1
BAYBOX.level 				    = 2
BAYBOX.h_clip_relation          = h_clip_relations.COMPARE
vertices(BAYBOX,2)
Add(BAYBOX)
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
BAYSQC                           = CreateElement "ceTexPoly"
BAYSQC.name    			        = "BG"
BAYSQC.material			        = BAY_SQ
BAYSQC.change_opacity 		    = false
BAYSQC.collimated 			    = false
BAYSQC.isvisible 			    = true
BAYSQC.init_pos 			        = {0, 0, 0} --L-R,U-D,F-B
BAYSQC.init_rot 			        = {0, 0, 0}
BAYSQC.element_params 		    = {"MFD_OPACITY","CMFD_BAY_PAGE"}--this may not be bneeded check when more pages done for backlight on page 7 SMS fc3 bs
BAYSQC.controllers			    = {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1}}--MENU PAGE = 1
BAYSQC.level 				    = 2
BAYSQC.h_clip_relation           = h_clip_relations.COMPARE
vertices(BAYSQC,2)
Add(BAYSQC)
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
BAYXC                           = CreateElement "ceTexPoly"
BAYXC.name    			        = "BG"
BAYXC.material			        = BAY_X
BAYXC.change_opacity 		    = false
BAYXC.collimated 			    = false
BAYXC.isvisible 			    = true
BAYXC.init_pos 			        = {0, 0, 0} --L-R,U-D,F-B
BAYXC.init_rot 			        = {0, 0, 0}
BAYXC.element_params 		    = {"MFD_OPACITY","CMFD_BAY_PAGE","ECM_ARG"}--this may not be bneeded check when more pages done for backlight on page 7 SMS fc3 bs
BAYXC.controllers			    = {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1},{"parameter_in_range",2,0.9,1.1}}--MENU PAGE = 1
BAYXC.level 				    = 2
BAYXC.h_clip_relation           = h_clip_relations.COMPARE
vertices(BAYXC,2)
Add(BAYXC)
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
BAYSQL                           = CreateElement "ceTexPoly"
BAYSQL.name    			        = "BG"
BAYSQL.material			        = BAY_SQ
BAYSQL.change_opacity 		    = false
BAYSQL.collimated 			    = false
BAYSQL.isvisible 			    = true
BAYSQL.init_pos 			        = {-0.30, 0, 0} --L-R,U-D,F-B
BAYSQL.init_rot 			        = {0, 0, 0}
BAYSQL.element_params 		    = {"MFD_OPACITY","CMFD_BAY_PAGE"}--this may not be bneeded check when more pages done for backlight on page 7 SMS fc3 bs
BAYSQL.controllers			    = {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1}}--MENU PAGE = 1
BAYSQL.level 				    = 2
BAYSQL.h_clip_relation           = h_clip_relations.COMPARE
vertices(BAYSQL,2)
Add(BAYSQL)
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
BAYXL                           = CreateElement "ceTexPoly"
BAYXL.name    			        = "BG"
BAYXL.material			        = BAY_X
BAYXL.change_opacity 		    = false
BAYXL.collimated 			    = false
BAYXL.isvisible 			    = true
BAYXL.init_pos 			        = {-0.30, 0, 0} --L-R,U-D,F-B
BAYXL.init_rot 			        = {0, 0, 0}
BAYXL.element_params 		    = {"MFD_OPACITY","CMFD_BAY_PAGE","CHAFF_LIGHT"}--this may not be bneeded check when more pages done for backlight on page 7 SMS fc3 bs
BAYXL.controllers			    = {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1},{"parameter_in_range",2,0.1,1.1}}--MENU PAGE = 1
BAYXL.level 				    = 2
BAYXL.h_clip_relation           = h_clip_relations.COMPARE
vertices(BAYXL,2)
Add(BAYXL)
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
BAYSQR                           = CreateElement "ceTexPoly"
BAYSQR.name    			        = "BG"
BAYSQR.material			        = BAY_SQ
BAYSQR.change_opacity 		    = false
BAYSQR.collimated 			    = false
BAYSQR.isvisible 			    = true
BAYSQR.init_pos 			        = {0.30, 0, 0} --L-R,U-D,F-B
BAYSQR.init_rot 			        = {0, 0, 0}
BAYSQR.element_params 		    = {"MFD_OPACITY","CMFD_BAY_PAGE"}--this may not be bneeded check when more pages done for backlight on page 7 SMS fc3 bs
BAYSQR.controllers			    = {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1}}--MENU PAGE = 1
BAYSQR.level 				    = 2
BAYSQR.h_clip_relation           = h_clip_relations.COMPARE
vertices(BAYSQR,2)
Add(BAYSQR)
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
BAYXR                           = CreateElement "ceTexPoly"
BAYXR.name    			        = "BG"
BAYXR.material			        = BAY_X
BAYXR.change_opacity 		    = false
BAYXR.collimated 			    = false
BAYXR.isvisible 			    = true
BAYXR.init_pos 			        = {0.30, 0, 0} --L-R,U-D,F-B
BAYXR.init_rot 			        = {0, 0, 0}
BAYXR.element_params 		    = {"MFD_OPACITY","CMFD_BAY_PAGE","FLARE_LIGHT"}--this may not be bneeded check when more pages done for backlight on page 7 SMS fc3 bs
BAYXR.controllers			    = {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1},{"parameter_in_range",2,0.1,1.1}}--MENU PAGE = 1
BAYXR.level 				    = 2
BAYXR.h_clip_relation           = h_clip_relations.COMPARE
vertices(BAYXR,2)
Add(BAYXR)
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
BAYL                            = CreateElement "ceTexPoly"
BAYL.name    			        = "BG"
BAYL.material			        = BAY_L
BAYL.change_opacity 		    = false
BAYL.collimated 			    = false
BAYL.isvisible 			        = true
BAYL.init_pos 			        = {0, 0, 0} --L-R,U-D,F-B
BAYL.init_rot 			        = {0, 0, 0}
BAYL.element_params 		    = {"MFD_OPACITY","CMFD_BAY_PAGE","BAY_L_ARG"}--this may not be bneeded check when more pages done for backlight on page 7 SMS fc3 bs
BAYL.controllers			    = {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1},{"parameter_in_range",2,-0.2,0.01}}--MENU PAGE = 1
BAYL.level 				        = 2
BAYL.h_clip_relation            = h_clip_relations.COMPARE
vertices(BAYL,2)
Add(BAYL)
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
BAYR                            = CreateElement "ceTexPoly"
BAYR.name    			        = "BG"
BAYR.material			        = BAY_R
BAYR.change_opacity 		    = false
BAYR.collimated 			    = false
BAYR.isvisible 			        = true
BAYR.init_pos 			        = {0, 0, 0} --L-R,U-D,F-B
BAYR.init_rot 			        = {0, 0, 0}
BAYR.element_params 		    = {"MFD_OPACITY","CMFD_BAY_PAGE","BAY_R_ARG"}--this may not be bneeded check when more pages done for backlight on page 7 SMS fc3 bs
BAYR.controllers			    = {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1},{"parameter_in_range",2,-0.2,0.01}}--MENU PAGE = 1
BAYR.level 				        = 2
BAYR.h_clip_relation            = h_clip_relations.COMPARE
vertices(BAYR,2)
Add(BAYR)
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
BAYC                            = CreateElement "ceTexPoly"
BAYC.name    			        = "BG"
BAYC.material			        = BAY_C
BAYC.change_opacity 		    = false
BAYC.collimated 			    = false
BAYC.isvisible 			        = true
BAYC.init_pos 			        = {0, 0, 0} --L-R,U-D,F-B
BAYC.init_rot 			        = {0, 0, 0}
BAYC.element_params 		    = {"MFD_OPACITY","CMFD_BAY_PAGE","BAY_C_ARG"}--this may not be bneeded check when more pages done for backlight on page 7 SMS fc3 bs
BAYC.controllers			    = {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1},{"parameter_in_range",2,-0.2,0.01}}--MENU PAGE = 1
BAYC.level 				        = 2
BAYC.h_clip_relation            = h_clip_relations.COMPARE
vertices(BAYC,2)
Add(BAYC)
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
BAYLOPEN                            = CreateElement "ceTexPoly"
BAYLOPEN.name    			        = "BG"
BAYLOPEN.material			        = BAY_L_OPEN
BAYLOPEN.change_opacity 		    = false
BAYLOPEN.collimated 			    = false
BAYLOPEN.isvisible 			        = true
BAYLOPEN.init_pos 			        = {0, 0, 0} --L-R,U-D,F-B
BAYLOPEN.init_rot 			        = {0, 0, 0}
BAYLOPEN.element_params 		    = {"MFD_OPACITY","CMFD_BAY_PAGE","BAY_L_ARG"}--this may not be bneeded check when more pages done for backlight on page 7 SMS fc3 bs
BAYLOPEN.controllers			    = {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1},{"parameter_in_range",2,0.01,1.2}}--MENU PAGE = 1
BAYLOPEN.level 				        = 2
BAYLOPEN.h_clip_relation            = h_clip_relations.COMPARE
vertices(BAYLOPEN,2)
Add(BAYLOPEN)
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
BAYROPEN                            = CreateElement "ceTexPoly"
BAYROPEN.name    			        = "BG"
BAYROPEN.material			        = BAY_R_OPEN
BAYROPEN.change_opacity 		    = false
BAYROPEN.collimated 			    = false
BAYROPEN.isvisible 			        = true
BAYROPEN.init_pos 			        = {0, 0, 0} --L-R,U-D,F-B
BAYROPEN.init_rot 			        = {0, 0, 0}
BAYROPEN.element_params 		    = {"MFD_OPACITY","CMFD_BAY_PAGE","BAY_R_ARG"}--this may not be bneeded check when more pages done for backlight on page 7 SMS fc3 bs
BAYROPEN.controllers			    = {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1},{"parameter_in_range",2,0.01,1.2}}--MENU PAGE = 1
BAYROPEN.level 				        = 2
BAYROPEN.h_clip_relation            = h_clip_relations.COMPARE
vertices(BAYROPEN,2)
Add(BAYROPEN)
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
BAYCOPEN                            = CreateElement "ceTexPoly"
BAYCOPEN.name    			        = "BG"
BAYCOPEN.material			        = BAY_C_OPEN
BAYCOPEN.change_opacity 		    = false
BAYCOPEN.collimated 			    = false
BAYCOPEN.isvisible 			        = true
BAYCOPEN.init_pos 			        = {0, 0, 0} --L-R,U-D,F-B
BAYCOPEN.init_rot 			        = {0, 0, 0}
BAYCOPEN.element_params 		    = {"MFD_OPACITY","CMFD_BAY_PAGE","BAY_C_ARG"}--this may not be bneeded check when more pages done for backlight on page 7 SMS fc3 bs
BAYCOPEN.controllers			    = {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1},{"parameter_in_range",2,0.01,1.2}}--MENU PAGE = 1
BAYCOPEN.level 				        = 2
BAYCOPEN.h_clip_relation            = h_clip_relations.COMPARE
vertices(BAYCOPEN,2)
Add(BAYCOPEN)
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
BAYLSEL                             = CreateElement "ceTexPoly"
BAYLSEL.name    			        = "BG"
BAYLSEL.material			        = BAY_L_SEL
BAYLSEL.change_opacity 		        = false
BAYLSEL.collimated 			        = false
BAYLSEL.isvisible 			        = true
BAYLSEL.init_pos 			        = {0, 0, 0} --L-R,U-D,F-B
BAYLSEL.init_rot 			        = {0, 0, 0}
BAYLSEL.element_params 		        = {"MFD_OPACITY","CMFD_BAY_PAGE","BAY_STATION"}--this may not be bneeded check when more pages done for backlight on page 7 SMS fc3 bs
BAYLSEL.controllers			        = {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1},{"parameter_in_range",2,0.9,1.1} }
BAYLSEL.level 				        = 2
BAYLSEL.h_clip_relation             = h_clip_relations.COMPARE
vertices(BAYLSEL,2)
Add(BAYLSEL)
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
BAYRSEL                             = CreateElement "ceTexPoly"
BAYRSEL.name    			        = "BG"
BAYRSEL.material			        = BAY_R_SEL
BAYRSEL.change_opacity 		        = false
BAYRSEL.collimated 			        = false
BAYRSEL.isvisible 			        = true
BAYRSEL.init_pos 			        = {0, 0, 0} --L-R,U-D,F-B
BAYRSEL.init_rot 			        = {0, 0, 0}
BAYRSEL.element_params 		        = {"MFD_OPACITY","CMFD_BAY_PAGE","BAY_STATION"}--this may not be bneeded check when more pages done for backlight on page 7 SMS fc3 bs
BAYRSEL.controllers			        = {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1},{"parameter_in_range",2,2.9,3.1}}
BAYRSEL.level 				        = 2
BAYRSEL.h_clip_relation             = h_clip_relations.COMPARE
vertices(BAYRSEL,2)
Add(BAYRSEL)
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
BAYCSEL                             = CreateElement "ceTexPoly"
BAYCSEL.name    			        = "BG"
BAYCSEL.material			        = BAY_C_SEL
BAYCSEL.change_opacity 		        = false
BAYCSEL.collimated 			        = false
BAYCSEL.isvisible 			        = true
BAYCSEL.init_pos 			        = {0, 0, 0} --L-R,U-D,F-B
BAYCSEL.init_rot 			        = {0, 0, 0}
BAYCSEL.element_params 		        = {"MFD_OPACITY","CMFD_BAY_PAGE","BAY_STATION"}--this may not be bneeded check when more pages done for backlight on page 7 SMS fc3 bs
BAYCSEL.controllers			        = {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1},{"parameter_in_range",2,1.9,2.1}}
BAYCSEL.level 				        = 2
BAYCSEL.h_clip_relation             = h_clip_relations.COMPARE
vertices(BAYCSEL,2)
Add(BAYCSEL)
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
BAYASEL                             = CreateElement "ceTexPoly"
BAYASEL.name    			        = "BG"
BAYASEL.material			        = BAY_A_SEL
BAYASEL.change_opacity 		        = false
BAYASEL.collimated 			        = false
BAYASEL.isvisible 			        = true
BAYASEL.init_pos 			        = {0, 0, 0} --L-R,U-D,F-B
BAYASEL.init_rot 			        = {0, 0, 0}
BAYASEL.element_params 		        = {"MFD_OPACITY","CMFD_BAY_PAGE","BAY_STATION"}--this may not be bneeded check when more pages done for backlight on page 7 SMS fc3 bs
BAYASEL.controllers			        = {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1},{"parameter_in_range",2,3.9,4.1}}
BAYASEL.level 				        = 2
BAYASEL.h_clip_relation             = h_clip_relations.COMPARE
vertices(BAYASEL,2)
Add(BAYASEL)
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
ORIDE                           = CreateElement "ceTexPoly"
ORIDE.name    			        = "BG"
ORIDE.material			        = BAY_ORIDE
ORIDE.change_opacity 		    = false
ORIDE.collimated 			    = false
ORIDE.isvisible 			    = true
ORIDE.init_pos 			        = {0, 0, 0} --L-R,U-D,F-B
ORIDE.init_rot 			        = {0, 0, 0}
ORIDE.element_params 		    = {"MFD_OPACITY","CMFD_BAY_PAGE","ARM_STATUS"}--this may not be bneeded check when more pages done for backlight on page 7 SMS fc3 bs
ORIDE.controllers			    = {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1},{"parameter_in_range",2,1.9,2.1}}
ORIDE.level 				        = 2
ORIDE.h_clip_relation            = h_clip_relations.COMPARE
vertices(ORIDE,2)
Add(ORIDE)
---------------------------------------------------------------------------------------------------GROUND OVERRIDE TEXT GREEN
GORIDE_GRN 					            = CreateElement "ceStringPoly"
GORIDE_GRN.name 				        = "menu"
GORIDE_GRN.material 			        = UFD_GRN
GORIDE_GRN.value 				        = "GROUND"
GORIDE_GRN.stringdefs 		            = {0.005, 0.005, 0.0004, 0.001}
GORIDE_GRN.alignment 			        = "CenterCenter"
GORIDE_GRN.formats 			            = {"%s"}
GORIDE_GRN.h_clip_relation              = h_clip_relations.COMPARE
GORIDE_GRN.level 				        = 2
GORIDE_GRN.init_pos 			        = {-0.775, -0.345, 0}
GORIDE_GRN.init_rot 			        = {0, 0, 0}
GORIDE_GRN.element_params 	            = {"MFD_OPACITY","CMFD_BAY_PAGE","ORIDE_TEXT","ARM_STATUS"}
GORIDE_GRN.controllers		            =   {
                                                {"opacity_using_parameter",0},
                                                {"parameter_in_range",1,0.9,1.1},
                                                {"parameter_in_range",2,-0.1,0.1},
                                                {"parameter_in_range",3,1.9,2.1},
						                    }
Add(GORIDE_GRN)
---------------------------------------------------------------------------------------------------GROUND OVERRIDE TEXT YELLOW
GORIDE_YEL 					            = CreateElement "ceStringPoly"
GORIDE_YEL.name 				        = "menu"
GORIDE_YEL.material 			        = UFD_YEL
GORIDE_YEL.value 				        = "GROUND"
GORIDE_YEL.stringdefs 		            = {0.005, 0.005, 0.0004, 0.001}
GORIDE_YEL.alignment 			        = "CenterCenter"
GORIDE_YEL.formats 			            = {"%s"}
GORIDE_YEL.h_clip_relation              = h_clip_relations.COMPARE
GORIDE_YEL.level 				        = 2
GORIDE_YEL.init_pos 			        = {-0.775, -0.345, 0}
GORIDE_YEL.init_rot 			        = {0, 0, 0}
GORIDE_YEL.element_params 	            = {"MFD_OPACITY","CMFD_BAY_PAGE","ORIDE_TEXT","ARM_STATUS"}
GORIDE_YEL.controllers		            =   {
                                                {"opacity_using_parameter",0},
                                                {"parameter_in_range",1,0.9,1.1},
                                                {"parameter_in_range",2,0.9,1.1},
                                                {"parameter_in_range",3,1.9,2.1},
						                    }
Add(GORIDE_YEL)
---------------------------------------------------------------------------------------------------GROUND OVERRIDE TEXT GREEN
GORIDE_GRN1 					            = CreateElement "ceStringPoly"
GORIDE_GRN1.name 				        = "menu"
GORIDE_GRN1.material 			        = UFD_GRN
GORIDE_GRN1.value 				        = "OVRIDE"
GORIDE_GRN1.stringdefs 		            = {0.005, 0.005, 0.0004, 0.001}
GORIDE_GRN1.alignment 			        = "CenterCenter"
GORIDE_GRN1.formats 			            = {"%s"}
GORIDE_GRN1.h_clip_relation              = h_clip_relations.COMPARE
GORIDE_GRN1.level 				        = 2
GORIDE_GRN1.init_pos 			        = {-0.775, -0.415, 0}
GORIDE_GRN1.init_rot 			        = {0, 0, 0}
GORIDE_GRN1.element_params 	            = {"MFD_OPACITY","CMFD_BAY_PAGE","ORIDE_TEXT","ARM_STATUS"}
GORIDE_GRN1.controllers		            =   {
                                                {"opacity_using_parameter",0},
                                                {"parameter_in_range",1,0.9,1.1},
                                                {"parameter_in_range",2,-0.1,0.1},
                                                {"parameter_in_range",3,1.9,2.1},
						                    }
Add(GORIDE_GRN1)
---------------------------------------------------------------------------------------------------GROUND OVERRIDE TEXT YELLOW
GORIDE_YEL1 					            = CreateElement "ceStringPoly"
GORIDE_YEL1.name 				        = "menu"
GORIDE_YEL1.material 			        = UFD_YEL
GORIDE_YEL1.value 				        = "OVRIDE"
GORIDE_YEL1.stringdefs 		            = {0.005, 0.005, 0.0004, 0.001}
GORIDE_YEL1.alignment 			        = "CenterCenter"
GORIDE_YEL1.formats 			            = {"%s"}
GORIDE_YEL1.h_clip_relation              = h_clip_relations.COMPARE
GORIDE_YEL1.level 				        = 2
GORIDE_YEL1.init_pos 			        = {-0.775, -0.415, 0}
GORIDE_YEL1.init_rot 			        = {0, 0, 0}
GORIDE_YEL1.element_params 	            = {"MFD_OPACITY","CMFD_BAY_PAGE","ORIDE_TEXT","ARM_STATUS"}
GORIDE_YEL1.controllers		            =   {
                                                {"opacity_using_parameter",0},
                                                {"parameter_in_range",1,0.9,1.1},
                                                {"parameter_in_range",2,0.9,1.1},
                                                {"parameter_in_range",3,1.9,2.1},
						                    }
Add(GORIDE_YEL1)
------------------------------------------------------------------------------------------------------------------------------------------------------THRUST SHIT
R_RING_EGT_G                    = CreateElement "ceTexPoly"
R_RING_EGT_G.name    			= "ring green"
R_RING_EGT_G.material			= RING_EGT_G
R_RING_EGT_G.change_opacity 	= false
R_RING_EGT_G.collimated 		= false
R_RING_EGT_G.isvisible 			= true
R_RING_EGT_G.init_pos 			= {0.28, 0.66, 0} --L-R,U-D,F-B
R_RING_EGT_G.init_rot 			= {0, 0, 0}
R_RING_EGT_G.element_params 	= {"MFD_OPACITY","CMFD_BAY_PAGE"} 
R_RING_EGT_G.controllers		= {
                                    {"opacity_using_parameter",0},
                                    {"parameter_in_range",1,0.9,1.1},--ENGINE PAGE = 1
                                }
R_RING_EGT_G.level 				    = 2
R_RING_EGT_G.h_clip_relation        = h_clip_relations.COMPARE
vertices(R_RING_EGT_G,0.3)
Add(R_RING_EGT_G)
------------------------------------------------------------------------------------------------THRUST SHIT
R_NEEDLE_EGT_G                      = CreateElement "ceTexPoly"
R_NEEDLE_EGT_G .name    			= "needle g"
R_NEEDLE_EGT_G .material			= RING_NEEDLE_G
R_NEEDLE_EGT_G .change_opacity 	    = false
R_NEEDLE_EGT_G .collimated 		    = false
R_NEEDLE_EGT_G .isvisible 	        = true
R_NEEDLE_EGT_G .init_pos 			= {0.28, 0.66, 0} --L-R,U-D,F-B
R_NEEDLE_EGT_G .init_rot 			= {0, 0, 0}
R_NEEDLE_EGT_G .element_params 	    = {"MFD_OPACITY","CMFD_BAY_PAGE","RPM_R"} 
R_NEEDLE_EGT_G .controllers		    = {
                                        {"opacity_using_parameter",0},
                                        {"parameter_in_range",1, 0.9,1.1},--ENGINE PAGE = 1
                                        {"rotate_using_parameter",2, -0.04280,0}
                                    }
R_NEEDLE_EGT_G .level 				= 2
R_NEEDLE_EGT_G .h_clip_relation     = h_clip_relations.COMPARE
vertices(R_NEEDLE_EGT_G,0.3)
Add(R_NEEDLE_EGT_G)
------------------------------------------------------------------------------------------------THRUST SHIT
L_RING_EGT_G                    = CreateElement "ceTexPoly"
L_RING_EGT_G.name    			= "ring green"
L_RING_EGT_G.material			= RING_EGT_G
L_RING_EGT_G.change_opacity 	= false
L_RING_EGT_G.collimated 		= false
L_RING_EGT_G.isvisible 			= true
L_RING_EGT_G.init_pos 			= {-0.28, 0.66, 0} --L-R,U-D,F-B
L_RING_EGT_G.init_rot 			= {0, 0, 0}
L_RING_EGT_G.element_params 	= {"MFD_OPACITY","CMFD_BAY_PAGE"} 
L_RING_EGT_G.controllers		= {
                                    {"opacity_using_parameter",0},
                                    {"parameter_in_range",1,0.9,1.1},--ENGINE PAGE = 1
                                   
                                }
L_RING_EGT_G.level 				    = 2
L_RING_EGT_G.h_clip_relation        = h_clip_relations.COMPARE
vertices(L_RING_EGT_G,0.3)
Add(L_RING_EGT_G)
------------------------------------------------------------------------------------------------THRUST SHIT
L_NEEDLE_EGT_G                      = CreateElement "ceTexPoly"
L_NEEDLE_EGT_G .name    			= "needle g"
L_NEEDLE_EGT_G .material			= RING_NEEDLE_G
L_NEEDLE_EGT_G .change_opacity 	    = false
L_NEEDLE_EGT_G .collimated 		    = false
L_NEEDLE_EGT_G .isvisible 	        = true
L_NEEDLE_EGT_G .init_pos 			= {-0.28, 0.66, 0} --L-R,U-D,F-B
L_NEEDLE_EGT_G .init_rot 			= {0, 0, 0}
L_NEEDLE_EGT_G .element_params 	    = {"MFD_OPACITY","CMFD_BAY_PAGE","RPM_L"} 
L_NEEDLE_EGT_G .controllers		    = {
                                        {"opacity_using_parameter",0},
                                        {"parameter_in_range",1, 0.9,1.1},--ENGINE PAGE = 1
                                        {"rotate_using_parameter",2, -0.04280,0}
                                    }
L_NEEDLE_EGT_G .level 				= 2
L_NEEDLE_EGT_G .h_clip_relation     = h_clip_relations.COMPARE
vertices(L_NEEDLE_EGT_G,0.3)
Add(L_NEEDLE_EGT_G)
-----------------------------------------------------------------------------------------------------------THRUST SHIT
R_RPM_NUM_G				        = CreateElement "ceStringPoly"
R_RPM_NUM_G.name				= "rad Alt"
R_RPM_NUM_G.material			= UFD_GRN
R_RPM_NUM_G.init_pos			= {0.20, 0.75, 0} --L-R,U-D,F-B
R_RPM_NUM_G.alignment			= "RightCenter"
R_RPM_NUM_G.stringdefs			= {0.005, 0.005, 0, 0.0} --either 004 or 005
R_RPM_NUM_G.additive_alpha		= true
R_RPM_NUM_G.collimated			= false
R_RPM_NUM_G.isdraw				= true	
R_RPM_NUM_G.use_mipfilter		= true
R_RPM_NUM_G.h_clip_relation	    = h_clip_relations.COMPARE
R_RPM_NUM_G.level				= 2
R_RPM_NUM_G.element_params		= {"MFD_OPACITY","RPM_R","CMFD_BAY_PAGE"}
R_RPM_NUM_G.formats			    = {"%.0f"}--= {"%02.0f"}
R_RPM_NUM_G.controllers		    =   {
                                        {"opacity_using_parameter",0},
                                        {"text_using_parameter",1,0},
                                        {"parameter_in_range",2,0.9,1.1},--ENGINE PAGE = 1
                                    }
                                
Add(R_RPM_NUM_G)
-----------------------------------------------------------------------------------------------------------THRUST SHIT
L_RPM_NUM_G				        = CreateElement "ceStringPoly"
L_RPM_NUM_G.name				= "rad Alt"
L_RPM_NUM_G.material			= UFD_GRN
L_RPM_NUM_G.init_pos			= {-0.36, 0.75, 0} --L-R,U-D,F-B
L_RPM_NUM_G.alignment			= "RightCenter"
L_RPM_NUM_G.stringdefs			= {0.005, 0.005, 0, 0.0} --either 004 or 005
L_RPM_NUM_G.additive_alpha		= true
L_RPM_NUM_G.collimated			= false
L_RPM_NUM_G.isdraw				= true	
L_RPM_NUM_G.use_mipfilter		= true
L_RPM_NUM_G.h_clip_relation	    = h_clip_relations.COMPARE
L_RPM_NUM_G.level				= 2
L_RPM_NUM_G.element_params		= {"MFD_OPACITY","RPM_L","CMFD_BAY_PAGE"}
L_RPM_NUM_G.formats			    = {"%.0f"}--= {"%02.0f"}
L_RPM_NUM_G.controllers		    =   {
                                        {"opacity_using_parameter",0},
                                        {"text_using_parameter",1,0},
                                        {"parameter_in_range",2,0.9,1.1},--ENGINE PAGE = 1
                                    }
                                
Add(L_RPM_NUM_G)
--------------------------------------------------------------------------------------------------- NAV
MENU_TEXT 					        = CreateElement "ceStringPoly"
MENU_TEXT.name 				        = "menu"
MENU_TEXT.material 			        = UFD_FONT
MENU_TEXT.value 				    = "MENU"
MENU_TEXT.stringdefs 		        = {0.0050, 0.0050, 0.0004, 0.001}
MENU_TEXT.alignment 			    = "CenterCenter"
MENU_TEXT.formats 			        = {"%s"}
MENU_TEXT.h_clip_relation           = h_clip_relations.COMPARE
MENU_TEXT.level 				    = 2
MENU_TEXT.init_pos 			        = {-0.565, 0.92, 0}
MENU_TEXT.init_rot 			        = {0, 0, 0}
MENU_TEXT.element_params 	        = {"MFD_OPACITY","CMFD_BAY_PAGE"}
MENU_TEXT.controllers		        =   {
                                            {"opacity_using_parameter",0},
                                            {"parameter_in_range",1,0.9,1.1},
						                }
Add(MENU_TEXT)
--------------------------------------------------------------------------------------------------- NAV
MENU_TEXT1 					        = CreateElement "ceStringPoly"
MENU_TEXT1.name 				    = "menu"
MENU_TEXT1.material 			    = UFD_GRN
MENU_TEXT1.value 				    = "FCS"
MENU_TEXT1.stringdefs 		        = {0.0050, 0.0050, 0.0004, 0.001}
MENU_TEXT1.alignment 			    = "CenterCenter"
MENU_TEXT1.formats 			        = {"%s"}
MENU_TEXT1.h_clip_relation          = h_clip_relations.COMPARE
MENU_TEXT1.level 				    = 2
MENU_TEXT1.init_pos 			        = {0,0.92, 0}
MENU_TEXT1.init_rot 			        = {0, 0, 0}
MENU_TEXT1.element_params 	        = {"MFD_OPACITY","CMFD_BAY_PAGE"}
MENU_TEXT1.controllers		        =   {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1},}
Add(MENU_TEXT1)
--------------------------------------------------------------------------------------------------- NAV
MENU_TEXT2 					        = CreateElement "ceStringPoly"
MENU_TEXT2.name 				        = "menu"
MENU_TEXT2.material 			        = UFD_GRN
MENU_TEXT2.value 				    = "ENG"
MENU_TEXT2.stringdefs 		        = {0.0050, 0.0050, 0.0004, 0.001}
MENU_TEXT2.alignment 			    = "CenterCenter"
MENU_TEXT2.formats 			        = {"%s"}
MENU_TEXT2.h_clip_relation           = h_clip_relations.COMPARE
MENU_TEXT2.level 				    = 2
MENU_TEXT2.init_pos 			        = {-0.265,0.92, 0}
MENU_TEXT2.init_rot 			        = {0, 0, 0}
MENU_TEXT2.element_params 	        = {"MFD_OPACITY","CMFD_BAY_PAGE"}
MENU_TEXT2.controllers		        =   {
                                            {"opacity_using_parameter",0},
                                            {"parameter_in_range",1,0.9,1.1},
						                }
Add(MENU_TEXT2)
--------------------------------------------------------------------------------------------------- NAV
MENU_TEXT4 					        = CreateElement "ceStringPoly"
MENU_TEXT4.name 				        = "menu"
MENU_TEXT4.material 			        = UFD_GRN
MENU_TEXT4.value 				    = "FUEL"
MENU_TEXT4.stringdefs 		        = {0.0050, 0.0050, 0.0004, 0.001}
MENU_TEXT4.alignment 			    = "CenterCenter"
MENU_TEXT4.formats 			        = {"%s"}
MENU_TEXT4.h_clip_relation           = h_clip_relations.COMPARE
MENU_TEXT4.level 				    = 2
MENU_TEXT4.init_pos 			        = {0.265,0.92, 0}
MENU_TEXT4.init_rot 			        = {0, 0, 0}
MENU_TEXT4.element_params 	        = {"MFD_OPACITY","CMFD_BAY_PAGE"}
MENU_TEXT4.controllers		        =   {
                                            {"opacity_using_parameter",0},
                                            {"parameter_in_range",1,0.9,1.1},
						                }
Add(MENU_TEXT4)
--------------------------------------------------------------------------------------------------- NAV
MENU_TEXT44 					        = CreateElement "ceStringPoly"
MENU_TEXT44.name 				        = "menu"
MENU_TEXT44.material 			        = UFD_GRN
MENU_TEXT44.value 				        = "HSI"
MENU_TEXT44.stringdefs 		            = {0.0050, 0.0050, 0.0004, 0.001}
MENU_TEXT44.alignment 			        = "CenterCenter"
MENU_TEXT44.formats 			        = {"%s"}
MENU_TEXT44.h_clip_relation             = h_clip_relations.COMPARE
MENU_TEXT44.level 				        = 2
MENU_TEXT44.init_pos 			        = {0.565,0.92, 0}
MENU_TEXT44.init_rot 			        = {0, 0, 0}
MENU_TEXT44.element_params 	            = {"MFD_OPACITY","CMFD_BAY_PAGE"}
MENU_TEXT44.controllers		            =   {
                                            {"opacity_using_parameter",0},
                                            {"parameter_in_range",1,0.9,1.1},
						                    }
Add(MENU_TEXT44)
--------------------------------------------------------------------------------------------------- NAV
THRUST_TEXT 					    = CreateElement "ceStringPoly"
THRUST_TEXT.name 				    = "menu"
THRUST_TEXT.material 			    = UFD_GRN
THRUST_TEXT.value 				    = "THRUST"
THRUST_TEXT.stringdefs 		        = {0.0050, 0.0050, 0.0004, 0.001}
THRUST_TEXT.alignment 			    = "CenterCenter"
THRUST_TEXT.formats 			    = {"%s"}
THRUST_TEXT.h_clip_relation         = h_clip_relations.COMPARE
THRUST_TEXT.level 				    = 2
THRUST_TEXT.init_pos 			     = {0, 0.66, 0}
THRUST_TEXT.init_rot 			    = {0, 0, 0}
THRUST_TEXT.element_params 	        = {"MFD_OPACITY","CMFD_BAY_PAGE"}
THRUST_TEXT.controllers		        =   {
                                            {"opacity_using_parameter",0},
                                            {"parameter_in_range",1,0.9,1.1},
						                }
Add(THRUST_TEXT)
--------------------------------------------------------------------------------------------------- NAV
CENTER_TEXT 					    = CreateElement "ceStringPoly"
CENTER_TEXT.name 				    = "menu"
CENTER_TEXT.material 			    = UFD_GRN
CENTER_TEXT.value 				    = "CENTER"
CENTER_TEXT.stringdefs 		        = {0.0050, 0.0050, 0.0004, 0.001}
CENTER_TEXT.alignment 			    = "CenterCenter"
CENTER_TEXT.formats 			    = {"%s"}
CENTER_TEXT.h_clip_relation         = h_clip_relations.COMPARE
CENTER_TEXT.level 				    = 2
CENTER_TEXT.init_pos 			     = {0, 0.1675, 0}
CENTER_TEXT.init_rot 			    = {0, 0, 0}
CENTER_TEXT.element_params 	        = {"MFD_OPACITY","CMFD_BAY_PAGE","BAY_STATION"}
CENTER_TEXT.controllers		        = {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1},{"parameter_in_range",2,1.9,2.1}}
Add(CENTER_TEXT)
--------------------------------------------------------------------------------------------------- NAV
LEFT_TEXT 					        = CreateElement "ceStringPoly"
LEFT_TEXT.name 				        = "menu"
LEFT_TEXT.material 			        = UFD_GRN
LEFT_TEXT.value 				    = "LEFT"
LEFT_TEXT.stringdefs 		        = {0.0050, 0.0050, 0.0004, 0.001}
LEFT_TEXT.alignment 			    = "CenterCenter"
LEFT_TEXT.formats 			        = {"%s"}
LEFT_TEXT.h_clip_relation           = h_clip_relations.COMPARE
LEFT_TEXT.level 				    = 2
LEFT_TEXT.init_pos 			        = {0, 0.1675, 0}
LEFT_TEXT.init_rot 			        = {0, 0, 0}
LEFT_TEXT.element_params 	        = {"MFD_OPACITY","CMFD_BAY_PAGE","BAY_STATION"}
LEFT_TEXT.controllers		        = {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1},{"parameter_in_range",2,0.9,1.1}}
Add(LEFT_TEXT)
--------------------------------------------------------------------------------------------------- NAV
RIGHT_TEXT 					            = CreateElement "ceStringPoly"
RIGHT_TEXT.name 				        = "menu"
RIGHT_TEXT.material 			        = UFD_GRN
RIGHT_TEXT.value 				        = "RIGHT"
RIGHT_TEXT.stringdefs 		            = {0.0050, 0.0050, 0.0004, 0.001}
RIGHT_TEXT.alignment 			        = "CenterCenter"
RIGHT_TEXT.formats 			            = {"%s"}
RIGHT_TEXT.h_clip_relation              = h_clip_relations.COMPARE
RIGHT_TEXT.level 				        = 2
RIGHT_TEXT.init_pos 			        = {0, 0.1675, 0}
RIGHT_TEXT.init_rot 			        = {0, 0, 0}
RIGHT_TEXT.element_params 	            = {"MFD_OPACITY","CMFD_BAY_PAGE","BAY_STATION"}
RIGHT_TEXT.controllers		            = {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1},{"parameter_in_range",2,2.9,3.1}}
Add(RIGHT_TEXT)
--------------------------------------------------------------------------------------------------- NAV
ALL_TEXT 					            = CreateElement "ceStringPoly"
ALL_TEXT.name 				            = "menu"
ALL_TEXT.material 			            = UFD_GRN
ALL_TEXT.value 				            = "ALL"
ALL_TEXT.stringdefs 		            = {0.0050, 0.0050, 0.0004, 0.001}
ALL_TEXT.alignment 			            = "CenterCenter"
ALL_TEXT.formats 			            = {"%s"}
ALL_TEXT.h_clip_relation                = h_clip_relations.COMPARE
ALL_TEXT.level 				            = 2
ALL_TEXT.init_pos 			            = {0, 0.1675, 0}
ALL_TEXT.init_rot 			            = {0, 0, 0}
ALL_TEXT.element_params 	            = {"MFD_OPACITY","CMFD_BAY_PAGE","BAY_STATION"}
ALL_TEXT.controllers		            = {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1},{"parameter_in_range",2,3.9,4.1}}
Add(ALL_TEXT)
--------------------------------------------------------------------------------------------------- NAV
AORIDE_TEXT 					            = CreateElement "ceStringPoly"
AORIDE_TEXT.name 				            = "menu"
AORIDE_TEXT.material 			            = UFD_RED
AORIDE_TEXT.value 				            = "AIR OVERRIDE"
AORIDE_TEXT.stringdefs 		                = {0.0050, 0.0050, 0.0004, 0.001}
AORIDE_TEXT.alignment 			            = "CenterCenter"
AORIDE_TEXT.formats 			            = {"%s"}
AORIDE_TEXT.h_clip_relation                 = h_clip_relations.COMPARE
AORIDE_TEXT.level 				            = 2
AORIDE_TEXT.init_pos 			            = {0, -0.30, 0}
AORIDE_TEXT.init_rot 			            = {0, 0, 0}
AORIDE_TEXT.element_params 	                = {"MFD_OPACITY","CMFD_BAY_PAGE","AIR_ORIDE"}
AORIDE_TEXT.controllers		                =   {
                                                {"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1},{"parameter_in_range",2,0.9,1.1}}
Add(AORIDE_TEXT)
--------------------------------------------------------------------------------------------------- NAV
ECM_TEXT 					            = CreateElement "ceStringPoly"
ECM_TEXT.name 				            = "menu"
ECM_TEXT.material 			            = UFD_YEL
ECM_TEXT.value 				            = "ECM"
ECM_TEXT.stringdefs 		            = {0.0040, 0.0040, 0.0004, 0.001}
ECM_TEXT.alignment 			            = "CenterCenter"
ECM_TEXT.formats 			            = {"%s"}
ECM_TEXT.h_clip_relation                = h_clip_relations.COMPARE
ECM_TEXT.level 				            = 2
ECM_TEXT.init_pos 			            = {0, -0.45, 0}
ECM_TEXT.init_rot 			            = {0, 0, 0}
ECM_TEXT.element_params 	            = {"MFD_OPACITY","CMFD_BAY_PAGE"}
ECM_TEXT.controllers		            =   {
                                                {"opacity_using_parameter",0},
                                                {"parameter_in_range",1,0.9,1.1},
						                    }
Add(ECM_TEXT)
--------------------------------------------------------------------------------------------------- NAV
CHAFF_TEXT 					            = CreateElement "ceStringPoly"
CHAFF_TEXT.name 				        = "menu"
CHAFF_TEXT.material 			        = UFD_GRN
CHAFF_TEXT.value 				        = "CHAFF"
CHAFF_TEXT.stringdefs 		            = {0.0040, 0.0040, 0.0004, 0.001}
CHAFF_TEXT.alignment 			        = "CenterCenter"
CHAFF_TEXT.formats 			            = {"%s"}
CHAFF_TEXT.h_clip_relation              = h_clip_relations.COMPARE
CHAFF_TEXT.level 				        = 2
CHAFF_TEXT.init_pos 			        = {-0.30, -0.75, 0}
CHAFF_TEXT.init_rot 			        = {0, 0, 0}
CHAFF_TEXT.element_params 	            = {"MFD_OPACITY","CMFD_BAY_PAGE"}
CHAFF_TEXT.controllers		            =   {
                                                {"opacity_using_parameter",0},
                                                {"parameter_in_range",1,0.9,1.1},
						                    }
Add(CHAFF_TEXT)
--------------------------------------------------------------------------------------------------- NAV
FLARE_TEXT 					            = CreateElement "ceStringPoly"
FLARE_TEXT.name 				        = "menu"
FLARE_TEXT.material 			        = UFD_GRN
FLARE_TEXT.value 				        = "FLARE"
FLARE_TEXT.stringdefs 		            = {0.0040, 0.0040, 0.0004, 0.001}
FLARE_TEXT.alignment 			        = "CenterCenter"
FLARE_TEXT.formats 			            = {"%s"}
FLARE_TEXT.h_clip_relation              = h_clip_relations.COMPARE
FLARE_TEXT.level 				        = 2
FLARE_TEXT.init_pos 			        = {0.30, -0.75, 0}
FLARE_TEXT.init_rot 			        = {0, 0, 0}
FLARE_TEXT.element_params 	            = {"MFD_OPACITY","CMFD_BAY_PAGE"}
FLARE_TEXT.controllers		            =   {
                                                {"opacity_using_parameter",0},
                                                {"parameter_in_range",1,0.9,1.1},
						                    }
Add(FLARE_TEXT)
--------------------------------------------------------------------------------------------------- NAV
WEAPONSARM_TEXT 					            = CreateElement "ceStringPoly"
WEAPONSARM_TEXT.name 				            = "menu"
WEAPONSARM_TEXT.material 			            = UFD_GRN
WEAPONSARM_TEXT.value 				            = "WEAPONS ARMED"
WEAPONSARM_TEXT.stringdefs 		            = {0.0080, 0.0080, 0.0004, 0.001}
WEAPONSARM_TEXT.alignment 			            = "CenterCenter"
WEAPONSARM_TEXT.formats 			            = {"%s"}
WEAPONSARM_TEXT.h_clip_relation                = h_clip_relations.COMPARE
WEAPONSARM_TEXT.level 				            = 2
WEAPONSARM_TEXT.init_pos 			            = {0, 0.40, 0}
WEAPONSARM_TEXT.init_rot 			            = {0, 0, 0}
WEAPONSARM_TEXT.element_params 	            = {"MFD_OPACITY","CMFD_BAY_PAGE","ARM_STATUS"}
WEAPONSARM_TEXT.controllers		            =   {
                                                    {"opacity_using_parameter",0},
                                                    {"parameter_in_range",1,0.9,1.1},
                                                    {"parameter_in_range",2,0.9,1.1},
						                        }
Add(WEAPONSARM_TEXT)
--------------------------------------------------------------------------------------------------- NAV
WEAPONSSAFE_TEXT 					            = CreateElement "ceStringPoly"
WEAPONSSAFE_TEXT.name 				            = "menu"
WEAPONSSAFE_TEXT.material 			            = UFD_FONT
WEAPONSSAFE_TEXT.value 				        = "WEAPONS SAFE"
WEAPONSSAFE_TEXT.stringdefs 		            = {0.0080, 0.0080, 0.0004, 0.001}
WEAPONSSAFE_TEXT.alignment 			        = "CenterCenter"
WEAPONSSAFE_TEXT.formats 			            = {"%s"}
WEAPONSSAFE_TEXT.h_clip_relation               = h_clip_relations.COMPARE
WEAPONSSAFE_TEXT.level 				        = 2
WEAPONSSAFE_TEXT.init_pos 			            = {0, 0.40, 0}
WEAPONSSAFE_TEXT.init_rot 			            = {0, 0, 0}
WEAPONSSAFE_TEXT.element_params 	            = {"MFD_OPACITY","CMFD_BAY_PAGE","ARM_STATUS"}
WEAPONSSAFE_TEXT.controllers		            =   {
                                                {"opacity_using_parameter",0},
                                                {"parameter_in_range",1,0.9,1.1},
                                                {"parameter_in_range",2,-0.1,0.1},
						                    }
Add(WEAPONSSAFE_TEXT)
--------------------------------------------------------------------------------------------------- NAV
GROUNDSAFE_TEXT 					        = CreateElement "ceStringPoly"
GROUNDSAFE_TEXT.name 				        = "menu"
GROUNDSAFE_TEXT.material 			        = UFD_YEL
GROUNDSAFE_TEXT.value 				        = "GROUND SAFE"
GROUNDSAFE_TEXT.stringdefs 		            = {0.0080, 0.0080, 0.0004, 0.001}
GROUNDSAFE_TEXT.alignment 			        = "CenterCenter"
GROUNDSAFE_TEXT.formats 			        = {"%s"}
GROUNDSAFE_TEXT.h_clip_relation             = h_clip_relations.COMPARE
GROUNDSAFE_TEXT.level 				        = 2
GROUNDSAFE_TEXT.init_pos 			        = {0, 0.40, 0}
GROUNDSAFE_TEXT.init_rot 			        = {0, 0, 0}
GROUNDSAFE_TEXT.element_params 	            = {"MFD_OPACITY","CMFD_BAY_PAGE","ARM_STATUS"}
GROUNDSAFE_TEXT.controllers		            =   {
                                                {"opacity_using_parameter",0},
                                                {"parameter_in_range",1,0.9,1.1},
                                                {"parameter_in_range",2,1.9,2.1},
						                    }
Add(GROUNDSAFE_TEXT)
--------------------------------------------------------------------------------------------------------
-- DOORBOX                     = CreateElement "ceTexPoly"
-- DOORBOX.name    			= "LMFD_PAGE"
-- DOORBOX.material			= BAY_DOOR_BOX
-- DOORBOX.change_opacity 		= false
-- DOORBOX.collimated 			= false
-- DOORBOX.isvisible 			= true
-- DOORBOX.init_pos 			= {0, 0, 0} --L-R,U-D,F-B
-- DOORBOX.init_rot 			= {0, 0, 0}
-- DOORBOX.element_params 		= {"MFD_OPACITY","CMFD_BAY_PAGE"}--this may not be bneeded check when more pages done for backlight on page 7 SMS fc3 bs
-- DOORBOX.controllers			= {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1}}--MENU PAGE = 1
-- DOORBOX.level 				= 2
-- DOORBOX.h_clip_relation     = h_clip_relations.COMPARE
-- vertices(DOORBOX,2)
-- Add(DOORBOX)
-------------------
-- --BAY PLACEHOLDER
-- BAYPLACEHOLD 					    = CreateElement "ceStringPoly"
-- BAYPLACEHOLD.name 				    = "menu"
-- BAYPLACEHOLD.material 			    = UFD_GRN
-- BAYPLACEHOLD.value 				    = "BAY PLACEHOLDER"
-- BAYPLACEHOLD.stringdefs 		    = {0.0090, 0.0090, 0.0004, 0.001}
-- BAYPLACEHOLD.alignment 			    = "CenterCenter"
-- BAYPLACEHOLD.formats 			    = {"%s"}
-- BAYPLACEHOLD.h_clip_relation        = h_clip_relations.COMPARE
-- BAYPLACEHOLD.level 				    = 2
-- BAYPLACEHOLD.init_pos 			    = {0, 0, 0}
-- BAYPLACEHOLD.init_rot 			    = {0, 0, 0}
-- BAYPLACEHOLD.element_params 	    = {"MFD_OPACITY","CMFD_BAY_PAGE"}
-- BAYPLACEHOLD.controllers		    =   {
--                                             {"opacity_using_parameter",0},
--                                             {"parameter_in_range",1,0.9,1.1},--MENU PAGE = 0
-- 						                }
-- Add(BAYPLACEHOLD)
