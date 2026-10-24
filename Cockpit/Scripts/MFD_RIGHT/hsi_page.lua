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


dofile(LockOn_Options.script_path.."MFD_RIGHT/definitions.lua")
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
local BlueColor             = {23, 100, 255, 255}--RGBA
--------------------------------------------------------------------------------------------------------------------------------------------
-- local FCS_PAGE      = MakeMaterial(LockOn_Options.script_path.."../Scripts/IndicationTextures/fcs_page.dds", GreenColor)--SYSTEM TEST
-- local ENG_PAGE      = MakeMaterial(LockOn_Options.script_path.."../Scripts/IndicationTextures/engine_page.dds", BlackColor)--SYSTEM TEST
local HSI_COMPASS       = MakeMaterial(LockOn_Options.script_path.."../Scripts/IndicationTextures/hsi_compass.dds", WhiteColor)--SYSTEM TEST
local HSI_HASH          = MakeMaterial(LockOn_Options.script_path.."../Scripts/IndicationTextures/hsi_hash.dds", WhiteColor)--SYSTEM TEST
local HSI_BP            = MakeMaterial(LockOn_Options.script_path.."../Scripts/IndicationTextures/hsi_bp.dds", BlueColor)--SYSTEM TEST
local HSI_CP            = MakeMaterial(LockOn_Options.script_path.."../Scripts/IndicationTextures/hsi_cp.dds", BlueColor)--SYSTEM TEST
local HSI_DL            = MakeMaterial(LockOn_Options.script_path.."../Scripts/IndicationTextures/hsi_dl.dds", BlueColor)--SYSTEM TEST
local HSI_DOT           = MakeMaterial(LockOn_Options.script_path.."../Scripts/IndicationTextures/hsi_dot.dds", WhiteColor)--SYSTEM TEST
local HSI_TF            = MakeMaterial(LockOn_Options.script_path.."../Scripts/IndicationTextures/hsi_tf.dds", WhiteColor)--SYSTEM TEST
local HSI_FLAG          = MakeMaterial(LockOn_Options.script_path.."../Scripts/IndicationTextures/hsi_flag.dds", RedColor)--SYSTEM TEST

local HSI_FRAME       = MakeMaterial(LockOn_Options.script_path.."../Scripts/IndicationTextures/hsi_frame.dds", WhiteColor)--SYSTEM TEST

local MASK_BOX	    = MakeMaterial(LockOn_Options.script_path.."../Scripts/IndicationTextures/mask_box.dds", ScreenColor)--SYSTEM TEST
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
BGROUND.name    			= "BG"
BGROUND.material			= MASK_BOX
BGROUND.change_opacity 		= false
BGROUND.collimated 			= false
BGROUND.isvisible 			= true
BGROUND.init_pos 			= {0, 0, 0} --L-R,U-D,F-B
BGROUND.init_rot 			= {0, 0, 0}
BGROUND.element_params 		= {"MFD_OPACITY","RMFD_HSI_PAGE"}--this may not be bneeded check when more pages done for backlight on page 7 SMS fc3 bs
BGROUND.controllers			= {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1}}--MENU PAGE = 1
BGROUND.level 				= 2
BGROUND.h_clip_relation     = h_clip_relations.COMPARE
vertices(BGROUND,3)
Add(BGROUND)
------------------------------------------------------------------------------------------------------------------------------------------------------------
HSIFLAG                         = CreateElement "ceTexPoly"
HSIFLAG.name    			    = "HSIFLAG"
HSIFLAG.material			    = HSI_FLAG
HSIFLAG.change_opacity 		    = false
HSIFLAG.collimated 			    = false
HSIFLAG.isvisible 			    = true
HSIFLAG.init_pos 			    = {-0.10, 0, 0} --L-R,U-D,F-B
HSIFLAG.init_rot 			    = {0, 0, 0}
HSIFLAG.element_params 		    = {"MFD_OPACITY","RMFD_HSI_PAGE","ILS_FLAG"}--this may not be bneeded check when more pages done for backlight on page 7 SMS fc3 bs
HSIFLAG.controllers			    = {
                                    {"opacity_using_parameter",0},
                                    {"parameter_in_range",1,0.9,1.1},
                                    {"parameter_in_range",2,0.79,1.1},
                                    --{"rotate_using_parameter", 2, -6.2819, 0} -- -6.2819
                                }--MENU PAGE = 1
HSIFLAG.level 				    = 2
--HSIFLAG.parent_element        = HSICP.name
HSIFLAG.h_clip_relation         = h_clip_relations.COMPARE
vertices(HSIFLAG,2)
Add(HSIFLAG)
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
COMPASS                    = CreateElement "ceTexPoly"
COMPASS.name    			= "BG"
COMPASS.material			= HSI_COMPASS
COMPASS.change_opacity 		= false
COMPASS.collimated 			= false
COMPASS.isvisible 			= true
COMPASS.init_pos 			= {0, 0, 0} --L-R,U-D,F-B
COMPASS.init_rot 			= {0, 0, 0}
COMPASS.element_params 		= {"MFD_OPACITY","RMFD_HSI_PAGE","HSI_COMPASS"}--this may not be bneeded check when more pages done for backlight on page 7 SMS fc3 bs
COMPASS.controllers			= {
                                {"opacity_using_parameter",0},
                                {"parameter_in_range",1,0.9,1.1},
                                {"rotate_using_parameter", 2, -6.2819, 0} -- -6.2819
                            }--MENU PAGE = 1
COMPASS.level 				= 2
COMPASS.h_clip_relation     = h_clip_relations.COMPARE
vertices(COMPASS,2)
Add(COMPASS)
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
HSICP                       = CreateElement "ceTexPoly"
HSICP.name    			    = "HSICP"
HSICP.material			    = HSI_CP
HSICP.change_opacity 		= false
HSICP.collimated 			= false
HSICP.isvisible 			= true
HSICP.init_pos 			    = {0, 0, 0} --L-R,U-D,F-B
HSICP.init_rot 			    = {0, 0, 0}
HSICP.element_params 		= {"MFD_OPACITY","RMFD_HSI_PAGE","HSI_CRS_POINTER"}--this may not be bneeded check when more pages done for backlight on page 7 SMS fc3 bs
HSICP.controllers			= {
                                    {"opacity_using_parameter",0},
                                    {"parameter_in_range",1,0.9,1.1},
                                    {"rotate_using_parameter", 2, -6.2819, 0} -- -6.2819
                                }--MENU PAGE = 1
HSICP.level 				= 2
HSICP.h_clip_relation       = h_clip_relations.COMPARE
vertices(HSICP,2)
Add(HSICP)
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
HSIDOT                      = CreateElement "ceTexPoly"
HSIDOT.name    			    = "HSIDOT"
HSIDOT.material			    = HSI_DOT
HSIDOT.change_opacity 		= false
HSIDOT.collimated 			= false
HSIDOT.isvisible 			= true
HSIDOT.init_pos 			= {0, 0, 0} --L-R,U-D,F-B
HSIDOT.init_rot 			= {0, 0, 0}
HSIDOT.element_params 		= {"MFD_OPACITY","RMFD_HSI_PAGE"}--this may not be bneeded check when more pages done for backlight on page 7 SMS fc3 bs
HSIDOT.controllers			= {
                                    {"opacity_using_parameter",0},
                                    {"parameter_in_range",1,0.9,1.1},
                                    --{"rotate_using_parameter", 2, -6.2819, 0} -- -6.2819
                                }--MENU PAGE = 1
HSIDOT.level 				= 2
HSIDOT.parent_element       = HSICP.name
HSIDOT.h_clip_relation      = h_clip_relations.COMPARE
vertices(HSIDOT,2)
Add(HSIDOT)
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
HSIDL                       = CreateElement "ceTexPoly"
HSIDL.name    			    = "BG"
HSIDL.material			    = HSI_DL
HSIDL.change_opacity 		= false
HSIDL.collimated 			= false
HSIDL.isvisible 			= true
HSIDL.init_pos 			    = {0, 0, 0} --L-R,U-D,F-B
HSIDL.init_rot 			    = {0, 0, 0}
HSIDL.element_params 		= {"MFD_OPACITY","RMFD_HSI_PAGE","HSI_DEVIATION"}--this may not be bneeded check when more pages done for backlight on page 7 SMS fc3 bs
HSIDL.controllers			= {
                                    {"opacity_using_parameter",0},
                                    {"parameter_in_range",1,0.9,1.1},
                                    {"move_left_right_using_parameter",2,0.031,0}
                                }--MENU PAGE = 1
HSIDL.level 				= 2
HSIDL.parent_element        = HSICP.name
HSIDL.h_clip_relation       = h_clip_relations.COMPARE
vertices(HSIDL,2)
Add(HSIDL)
----------------------------------------------------------------------------------------------HASH-MARKSR-------------------------------------------------------------------------------------------------
HASHMARKS                       = CreateElement "ceTexPoly"
HASHMARKS.name    			    = "BG"
HASHMARKS.material			    = HSI_HASH
HASHMARKS.change_opacity 		= false
HASHMARKS.collimated 			= false
HASHMARKS.isvisible 			= true
HASHMARKS.init_pos 			    = {0, 0, 0} --L-R,U-D,F-B
HASHMARKS.init_rot 			    = {0, 0, 0}
HASHMARKS.element_params 		= {"MFD_OPACITY","RMFD_HSI_PAGE"}--this may not be bneeded check when more pages done for backlight on page 7 SMS fc3 bs
HASHMARKS.controllers			= {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1}}--MENU PAGE = 1
HASHMARKS.level 				= 2
HASHMARKS.h_clip_relation       = h_clip_relations.COMPARE
vertices(HASHMARKS,2)
Add(HASHMARKS)
-------------------
TEST                    = CreateElement "ceTexPoly"
TEST.name    			= "BG"
TEST.material			= HSI_FRAME
TEST.change_opacity 		= false
TEST.collimated 			= false
TEST.isvisible 			= true
TEST.init_pos 			= {0, 0, 0} --L-R,U-D,F-B
TEST.init_rot 			= {0, 0, 0}
TEST.element_params 	= {"MFD_OPACITY","RMFD_HSI_PAGE"}--this may not be bneeded check when more pages done for backlight on page 7 SMS fc3 bs
TEST.controllers			= {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1}}--MENU PAGE = 1
TEST.level 				= 2
TEST.h_clip_relation    = h_clip_relations.COMPARE
vertices(TEST,2 )
Add(TEST)
-------------------
-------------------------------------------------------------------------------------BEARING-POINTER----------------------------------------------------------------------------------------------------------
HSIBP                       = CreateElement "ceTexPoly"
HSIBP.name    			    = "BG"
HSIBP.material			    = HSI_BP
HSIBP.change_opacity 		= false
HSIBP.collimated 			= false
HSIBP.isvisible 			= true
HSIBP.init_pos 			    = {0, 0, 0} --L-R,U-D,F-B
HSIBP.init_rot 			    = {0, 0, 0}
HSIBP.element_params 		= {"MFD_OPACITY","RMFD_HSI_PAGE","HSI_WP_POINTER"}--this may not be bneeded check when more pages done for backlight on page 7 SMS fc3 bs
HSIBP.controllers			= {
                                {"opacity_using_parameter",0},
                                {"parameter_in_range",1,0.9,1.1},
                                {"rotate_using_parameter", 2, -6.2819, 0} -- -6.2819
                            }--MENU PAGE = 1
HSIBP.level 				= 2
HSIBP.h_clip_relation       = h_clip_relations.COMPARE
vertices(HSIBP,2)
Add(HSIBP)
---------------------------------------------------------------------------------------------------DIGITAL NAV NUMBER
HEADINGNUM		                    = CreateElement "ceStringPoly"
HEADINGNUM.name				        = "rad Alt"
HEADINGNUM.material			        = UFD_FONT
HEADINGNUM.init_pos			        = {0, 0.86, 0} --L-R,U-D,F-B
HEADINGNUM.alignment			    = "CenterCenter"
HEADINGNUM.stringdefs			    = {0.008, 0.008, 0, 0.0} --either 004 or 005
HEADINGNUM.additive_alpha		    = true
HEADINGNUM.collimated			    = false
HEADINGNUM.isdraw				    = true	
HEADINGNUM.use_mipfilter		    = true
HEADINGNUM.h_clip_relation		    = h_clip_relations.COMPARE
HEADINGNUM.level				    = 2
HEADINGNUM.element_params		    = {"MFD_OPACITY","NAV","RMFD_HSI_PAGE"}
HEADINGNUM.formats				    = {"%03.0f"}--= {"%02.0f"}
HEADINGNUM.controllers			    = {{"opacity_using_parameter",0},{"text_using_parameter",1,0},{"parameter_in_range",2,0.9,1.1}}
Add(HEADINGNUM)      
-----------------------------------------------------------------------------------------------------------------------------------MILES_ONES_0              
--COURSE 0
ONES_MILE_0 					    = CreateElement "ceStringPoly"
ONES_MILE_0.name 				    = "menu"
ONES_MILE_0.material 			    = UFD_FONT
ONES_MILE_0.value 			        = "0"
ONES_MILE_0.stringdefs 		        = {0.0080, 0.0080, 0.0004, 0.001}
ONES_MILE_0.alignment 			    = "CenterCenter"
ONES_MILE_0.formats 			    = {"%s"}
ONES_MILE_0.h_clip_relation         = h_clip_relations.COMPARE
ONES_MILE_0.level 				    = 2
ONES_MILE_0.init_pos 			    = {-0.55, 0.75, 0}
ONES_MILE_0.init_rot 			    = {0, 0, 0}
ONES_MILE_0.element_params 	        = {"MFD_OPACITY","RMFD_HSI_PAGE","MILE_1"}--
ONES_MILE_0.controllers		        =   {
                                            {"opacity_using_parameter",0},
                                            {"parameter_in_range",1,0.9,1.1},
                                            {"parameter_in_range",2,0.0,0.05}--MENU PAGE = 0
                                        }
Add(ONES_MILE_0)
-----------------------------------------------------------------------------------------------------------------------------------MILE_ONES_1          
--COURSE 1
ONES_MILE_1 					    = CreateElement "ceStringPoly"
ONES_MILE_1.name 				    = "menu"
ONES_MILE_1.material 			    = UFD_FONT
ONES_MILE_1.value 			        = "1"
ONES_MILE_1.stringdefs 		        = {0.0080, 0.0080, 0.0004, 0.001}
ONES_MILE_1.alignment 			    = "CenterCenter"
ONES_MILE_1.formats 			    = {"%s"}
ONES_MILE_1.h_clip_relation         = h_clip_relations.COMPARE
ONES_MILE_1.level 				    = 2
ONES_MILE_1.init_pos 			    = {-0.55, 0.75, 0}
ONES_MILE_1.init_rot 			    = {0, 0, 0}
ONES_MILE_1.element_params 	        = {"MFD_OPACITY","RMFD_HSI_PAGE","MILE_1"}
ONES_MILE_1.controllers		        =   {
                                            {"opacity_using_parameter",0},
                                            {"parameter_in_range",1,0.9,1.1},
                                            {"parameter_in_range",2,0.05,0.15}--MENU PAGE = 0
                                        }                                       
Add(ONES_MILE_1)
-----------------------------------------------------------------------------------------------------------------------------------
--COURSE 2
ONES_MILE_2 					    = CreateElement "ceStringPoly"
ONES_MILE_2.name 				    = "menu"
ONES_MILE_2.material 			    = UFD_FONT
ONES_MILE_2.value 			        = "2"
ONES_MILE_2.stringdefs 		        = {0.0080, 0.0080, 0.0004, 0.001}
ONES_MILE_2.alignment 			    = "CenterCenter"
ONES_MILE_2.formats 			    = {"%s"}
ONES_MILE_2.h_clip_relation         = h_clip_relations.COMPARE
ONES_MILE_2.level 				    = 2
ONES_MILE_2.init_pos 			    = {-0.55, 0.75, 0}
ONES_MILE_2.init_rot 			    = {0, 0, 0}
ONES_MILE_2.element_params 	        = {"MFD_OPACITY","RMFD_HSI_PAGE","MILE_1"}
ONES_MILE_2.controllers		        =   {
                                            {"opacity_using_parameter",0},
                                            {"parameter_in_range",1,0.9,1.1},
                                            {"parameter_in_range",2,0.15,0.25}--MENU PAGE = 0
						                }
Add(ONES_MILE_2)
-----------------------------------------------------------------------------------------------------------------------------------COURSE_ONES_1          
--COURSE 3
ONES_MILE_3 					    = CreateElement "ceStringPoly"
ONES_MILE_3.name 				    = "menu"
ONES_MILE_3.material 			    = UFD_FONT
ONES_MILE_3.value 			        = "3"
ONES_MILE_3.stringdefs 		        = {0.0080, 0.0080, 0.0004, 0.001}
ONES_MILE_3.alignment 			    = "CenterCenter"
ONES_MILE_3.formats 			    = {"%s"}
ONES_MILE_3.h_clip_relation         = h_clip_relations.COMPARE
ONES_MILE_3.level 				    = 2
ONES_MILE_3.init_pos 			    = {-0.55, 0.75, 0}
ONES_MILE_3.init_rot 			    = {0, 0, 0}
ONES_MILE_3.element_params 	        = {"MFD_OPACITY","RMFD_HSI_PAGE","MILE_1"}
ONES_MILE_3.controllers		        =   {
                                            {"opacity_using_parameter",0},
                                            {"parameter_in_range",1,0.9,1.1},
                                            {"parameter_in_range",2,0.25,0.35}--MENU PAGE = 0
						                }
Add(ONES_MILE_3)
-----------------------------------------------------------------------------------------------------------------------------------MILES_ONES_0              
--COURSE 4
ONES_MILE_4 					    = CreateElement "ceStringPoly"
ONES_MILE_4.name 				    = "menu"
ONES_MILE_4.material 			    = UFD_FONT
ONES_MILE_4.value 			        = "4"
ONES_MILE_4.stringdefs 		        = {0.0080, 0.0080, 0.0004, 0.001}
ONES_MILE_4.alignment 			    = "CenterCenter"
ONES_MILE_4.formats 			    = {"%s"}
ONES_MILE_4.h_clip_relation         = h_clip_relations.COMPARE
ONES_MILE_4.level 				    = 2
ONES_MILE_4.init_pos 			    = {-0.55, 0.75, 0}
ONES_MILE_4.init_rot 			    = {0, 0, 0}
ONES_MILE_4.element_params 	        = {"MFD_OPACITY","RMFD_HSI_PAGE","MILE_1"}
ONES_MILE_4.controllers		        =   {
                                            {"opacity_using_parameter",0},
                                            {"parameter_in_range",1,0.9,1.1},
                                            {"parameter_in_range",2,0.35,0.45}--MENU PAGE = 0
						                }
Add(ONES_MILE_4)
-----------------------------------------------------------------------------------------------------------------------------------MILE_ONES_1          
--COURSE 5
ONES_MILE_5 					    = CreateElement "ceStringPoly"
ONES_MILE_5.name 				    = "menu"
ONES_MILE_5.material 			    = UFD_FONT
ONES_MILE_5.value 			        = "5"
ONES_MILE_5.stringdefs 		        = {0.0080, 0.0080, 0.0004, 0.001}
ONES_MILE_5.alignment 			    = "CenterCenter"
ONES_MILE_5.formats 			    = {"%s"}
ONES_MILE_5.h_clip_relation         = h_clip_relations.COMPARE
ONES_MILE_5.level 				    = 2
ONES_MILE_5.init_pos 			    = {-0.55, 0.75, 0}
ONES_MILE_5.init_rot 			    = {0, 0, 0}
ONES_MILE_5.element_params 	        = {"MFD_OPACITY","RMFD_HSI_PAGE","MILE_1"}
ONES_MILE_5.controllers		        =   {
                                            {"opacity_using_parameter",0},
                                            {"parameter_in_range",1,0.9,1.1},
                                            {"parameter_in_range",2,0.45,0.55}--MENU PAGE = 0
						                }
Add(ONES_MILE_5)
-----------------------------------------------------------------------------------------------------------------------------------
--COURSE 6
ONES_MILE_6 					    = CreateElement "ceStringPoly"
ONES_MILE_6.name 				    = "menu"
ONES_MILE_6.material 			    = UFD_FONT
ONES_MILE_6.value 			        = "6"
ONES_MILE_6.stringdefs 		        = {0.0080, 0.0080, 0.0004, 0.001}
ONES_MILE_6.alignment 			    = "CenterCenter"
ONES_MILE_6.formats 			    = {"%s"}
ONES_MILE_6.h_clip_relation         = h_clip_relations.COMPARE
ONES_MILE_6.level 				    = 2
ONES_MILE_6.init_pos 			    = {-0.55, 0.75, 0}
ONES_MILE_6.init_rot 			    = {0, 0, 0}
ONES_MILE_6.element_params 	        = {"MFD_OPACITY","RMFD_HSI_PAGE","MILE_1"}
ONES_MILE_6.controllers		        =   {
                                            {"opacity_using_parameter",0},
                                            {"parameter_in_range",1,0.9,1.1},
                                            {"parameter_in_range",2,0.55,0.65}--MENU PAGE = 0
						                }
Add(ONES_MILE_6)
-----------------------------------------------------------------------------------------------------------------------------------COURSE_ONES_1          
--COURSE 7
ONES_MILE_7 					    = CreateElement "ceStringPoly"
ONES_MILE_7.name 				    = "menu"
ONES_MILE_7.material 			    = UFD_FONT
ONES_MILE_7.value 			        = "7"
ONES_MILE_7.stringdefs 		        = {0.0080, 0.0080, 0.0004, 0.001}
ONES_MILE_7.alignment 			    = "CenterCenter"
ONES_MILE_7.formats 			    = {"%s"}
ONES_MILE_7.h_clip_relation         = h_clip_relations.COMPARE
ONES_MILE_7.level 				    = 2
ONES_MILE_7.init_pos 			    = {-0.55, 0.75, 0}
ONES_MILE_7.init_rot 			    = {0, 0, 0}
ONES_MILE_7.element_params 	        = {"MFD_OPACITY","RMFD_HSI_PAGE","MILE_1"}
ONES_MILE_7.controllers		        =   {
                                            {"opacity_using_parameter",0},
                                            {"parameter_in_range",1,0.9,1.1},
                                            {"parameter_in_range",2,0.65,0.75}--MENU PAGE = 0
						                }
Add(ONES_MILE_7)
-----------------------------------------------------------------------------------------------------------------------------------
--COURSE 8
ONES_MILE_8 					    = CreateElement "ceStringPoly"
ONES_MILE_8.name 				    = "menu"
ONES_MILE_8.material 			    = UFD_FONT
ONES_MILE_8.value 			        = "8"
ONES_MILE_8.stringdefs 		        = {0.0080, 0.0080, 0.0004, 0.001}
ONES_MILE_8.alignment 			    = "CenterCenter"
ONES_MILE_8.formats 			    = {"%s"}
ONES_MILE_8.h_clip_relation         = h_clip_relations.COMPARE
ONES_MILE_8.level 				    = 2
ONES_MILE_8.init_pos 			    = {-0.55, 0.75, 0}
ONES_MILE_8.init_rot 			    = {0, 0, 0}
ONES_MILE_8.element_params 	        = {"MFD_OPACITY","RMFD_HSI_PAGE","MILE_1"}
ONES_MILE_8.controllers		        =   {
                                            {"opacity_using_parameter",0},
                                            {"parameter_in_range",1,0.9,1.1},
                                            {"parameter_in_range",2,0.75,0.85}--MENU PAGE = 0
						                }
Add(ONES_MILE_8)
-----------------------------------------------------------------------------------------------------------------------------------MILE          
--COURSE 9
ONES_MILE_9 					    = CreateElement "ceStringPoly"
ONES_MILE_9.name 				    = "menu"
ONES_MILE_9.material 			    = UFD_FONT
ONES_MILE_9.value 			        = "9"
ONES_MILE_9.stringdefs 		        = {0.0080, 0.0080, 0.0004, 0.001}
ONES_MILE_9.alignment 			    = "CenterCenter"
ONES_MILE_9.formats 			    = {"%s"}
ONES_MILE_9.h_clip_relation         = h_clip_relations.COMPARE
ONES_MILE_9.level 				    = 2
ONES_MILE_9.init_pos 			    = {-0.55, 0.75, 0}
ONES_MILE_9.init_rot 			    = {0, 0, 0}
ONES_MILE_9.element_params 	        = {"MFD_OPACITY","RMFD_HSI_PAGE","MILE_1"}
ONES_MILE_9.controllers		        =   {
                                            {"opacity_using_parameter",0},
                                            {"parameter_in_range",1,0.9,1.1},
                                            {"parameter_in_range",2,0.85,1.0}--MENU PAGE = 0
						                }
Add(ONES_MILE_9)
-----------------------------------------------------------------------------------------------------------------------------------MILE TENS              
--MILE 0
TENS_MILE_0 					    = CreateElement "ceStringPoly"
TENS_MILE_0.name 				    = "menu"
TENS_MILE_0.material 			    = UFD_FONT
TENS_MILE_0.value 			        = "0"
TENS_MILE_0.stringdefs 		        = {0.0080, 0.0080, 0.0004, 0.001}
TENS_MILE_0.alignment 			    = "CenterCenter"
TENS_MILE_0.formats 			    = {"%s"}
TENS_MILE_0.h_clip_relation         = h_clip_relations.COMPARE
TENS_MILE_0.level 				    = 2
TENS_MILE_0.init_pos 			    = {-0.62, 0.75, 0}
TENS_MILE_0.init_rot 			    = {0, 0, 0}
TENS_MILE_0.element_params 	        = {"MFD_OPACITY","RMFD_HSI_PAGE","MILE_2"}
TENS_MILE_0.controllers		        =   {
                                            {"opacity_using_parameter",0},
                                            {"parameter_in_range",1,0.9,1.1},
                                            {"parameter_in_range",2,-0.001,0.05}--MENU PAGE = 0
						                }
Add(TENS_MILE_0)
-- -----------------------------------------------------------------------------------------------------------------------------------       
--MILE 1
TENS_MILE_1 					    = CreateElement "ceStringPoly"
TENS_MILE_1.name 				    = "menu"
TENS_MILE_1.material 			    = UFD_FONT
TENS_MILE_1.value 			        = "1"
TENS_MILE_1.stringdefs 		        = {0.0080, 0.0080, 0.0004, 0.001}
TENS_MILE_1.alignment 			    = "CenterCenter"
TENS_MILE_1.formats 			    = {"%s"}
TENS_MILE_1.h_clip_relation         = h_clip_relations.COMPARE
TENS_MILE_1.level 				    = 2
TENS_MILE_1.init_pos 			    = {-0.62, 0.75, 0}
TENS_MILE_1.init_rot 			    = {0, 0, 0}
TENS_MILE_1.element_params 	        = {"MFD_OPACITY","RMFD_HSI_PAGE","MILE_2"}
TENS_MILE_1.controllers		        =   {
                                            {"opacity_using_parameter",0},
                                            {"parameter_in_range",1,0.9,1.1},
                                            {"parameter_in_range",2,0.05,0.15}--MENU PAGE = 0
						                }
Add(TENS_MILE_1)
-- -----------------------------------------------------------------------------------------------------------------------------------
--MILE 2
TENS_MILE_2 					    = CreateElement "ceStringPoly"
TENS_MILE_2.name 				    = "menu"
TENS_MILE_2.material 			    = UFD_FONT
TENS_MILE_2.value 			        = "2"
TENS_MILE_2.stringdefs 		        = {0.0080, 0.0080, 0.0004, 0.001}
TENS_MILE_2.alignment 			    = "CenterCenter"
TENS_MILE_2.formats 			    = {"%s"}
TENS_MILE_2.h_clip_relation         = h_clip_relations.COMPARE
TENS_MILE_2.level 				    = 2
TENS_MILE_2.init_pos 			    = {-0.62, 0.75, 0}
TENS_MILE_2.init_rot 			    = {0, 0, 0}
TENS_MILE_2.element_params 	        = {"MFD_OPACITY","RMFD_HSI_PAGE","MILE_2"}
TENS_MILE_2.controllers		        =   {
                                            {"opacity_using_parameter",0},
                                            {"parameter_in_range",1,0.9,1.1},
                                            {"parameter_in_range",2,0.15,0.25}--MENU PAGE = 0
						                }
Add(TENS_MILE_2)
-- -----------------------------------------------------------------------------------------------------------------------------------MILES          
--MILE 3
TENS_MILE_3 					    = CreateElement "ceStringPoly"
TENS_MILE_3.name 				    = "menu"
TENS_MILE_3.material 			    = UFD_FONT
TENS_MILE_3.value 			        = "3"
TENS_MILE_3.stringdefs 		        = {0.0080, 0.0080, 0.0004, 0.001}
TENS_MILE_3.alignment 			    = "CenterCenter"
TENS_MILE_3.formats 			    = {"%s"}
TENS_MILE_3.h_clip_relation         = h_clip_relations.COMPARE
TENS_MILE_3.level 				    = 2
TENS_MILE_3.init_pos 			    = {-0.62, 0.75, 0}
TENS_MILE_3.init_rot 			    = {0, 0, 0}
TENS_MILE_3.element_params 	        = {"MFD_OPACITY","RMFD_HSI_PAGE","MILE_2"}
TENS_MILE_3.controllers		        =   {
                                            {"opacity_using_parameter",0},
                                            {"parameter_in_range",1,0.9,1.1},
                                            {"parameter_in_range",2,0.25,0.35}--MENU PAGE = 0
						                }
Add(TENS_MILE_3)
-- -----------------------------------------------------------------------------------------------------------------------------------MILES_ONES_0              
--MILE 4
TENS_MILE_4 					    = CreateElement "ceStringPoly"
TENS_MILE_4.name 				    = "menu"
TENS_MILE_4.material 			    = UFD_FONT
TENS_MILE_4.value 			        = "4"
TENS_MILE_4.stringdefs 		        = {0.0080, 0.0080, 0.0004, 0.001}
TENS_MILE_4.alignment 			    = "CenterCenter"
TENS_MILE_4.formats 			    = {"%s"}
TENS_MILE_4.h_clip_relation         = h_clip_relations.COMPARE
TENS_MILE_4.level 				    = 2
TENS_MILE_4.init_pos 			    = {-0.62, 0.75, 0}
TENS_MILE_4.init_rot 			    = {0, 0, 0}
TENS_MILE_4.element_params 	        = {"MFD_OPACITY","RMFD_HSI_PAGE","MILE_2"}
TENS_MILE_4.controllers		        =   {
                                            {"opacity_using_parameter",0},
                                            {"parameter_in_range",1,0.9,1.1},
                                            {"parameter_in_range",2,0.35,0.45}--MENU PAGE = 0
						                }
Add(TENS_MILE_4)
-- -----------------------------------------------------------------------------------------------------------------------------------MILE_ONES_1          
--MILE 5
TENS_MILE_5 					    = CreateElement "ceStringPoly"
TENS_MILE_5.name 				    = "menu"
TENS_MILE_5.material 			    = UFD_FONT
TENS_MILE_5.value 			        = "5"
TENS_MILE_5.stringdefs 		        = {0.0080, 0.0080, 0.0004, 0.001}
TENS_MILE_5.alignment 			    = "CenterCenter"
TENS_MILE_5.formats 			    = {"%s"}
TENS_MILE_5.h_clip_relation         = h_clip_relations.COMPARE
TENS_MILE_5.level 				    = 2
TENS_MILE_5.init_pos 			    = {-0.62, 0.75, 0}
TENS_MILE_5.init_rot 			    = {0, 0, 0}
TENS_MILE_5.element_params 	        = {"MFD_OPACITY","RMFD_HSI_PAGE","MILE_2"}
TENS_MILE_5.controllers		        =   {
                                            {"opacity_using_parameter",0},
                                            {"parameter_in_range",1,0.9,1.1},
                                            {"parameter_in_range",2,0.45,0.55}--MENU PAGE = 0
						                }
Add(TENS_MILE_5)
-- -----------------------------------------------------------------------------------------------------------------------------------
-- --MILE 6
TENS_MILE_6 					    = CreateElement "ceStringPoly"
TENS_MILE_6.name 				    = "menu"
TENS_MILE_6.material 			    = UFD_FONT
TENS_MILE_6.value 			        = "6"
TENS_MILE_6.stringdefs 		        = {0.0080, 0.0080, 0.0004, 0.001}
TENS_MILE_6.alignment 			    = "CenterCenter"
TENS_MILE_6.formats 			    = {"%s"}
TENS_MILE_6.h_clip_relation         = h_clip_relations.COMPARE
TENS_MILE_6.level 				    = 2
TENS_MILE_6.init_pos 			    = {-0.62, 0.75, 0}
TENS_MILE_6.init_rot 			    = {0, 0, 0}
TENS_MILE_6.element_params 	        = {"MFD_OPACITY","RMFD_HSI_PAGE","MILE_2"}
TENS_MILE_6.controllers		        =   {
                                            {"opacity_using_parameter",0},
                                            {"parameter_in_range",1,0.9,1.1},
                                            {"parameter_in_range",2,0.55,0.65}--MENU PAGE = 0
						                }
Add(TENS_MILE_6)
-- -----------------------------------------------------------------------------------------------------------------------------------MILE_ONES_7    
-- --MILE 7
TENS_MILE_7 					    = CreateElement "ceStringPoly"
TENS_MILE_7.name 				    = "menu"
TENS_MILE_7.material 			    = UFD_FONT
TENS_MILE_7.value 			        = "7"
TENS_MILE_7.stringdefs 		        = {0.0080, 0.0080, 0.0004, 0.001}
TENS_MILE_7.alignment 			    = "CenterCenter"
TENS_MILE_7.formats 			    = {"%s"}
TENS_MILE_7.h_clip_relation         = h_clip_relations.COMPARE
TENS_MILE_7.level 				    = 2
TENS_MILE_7.init_pos 			    = {-0.62, 0.75, 0}
TENS_MILE_7.init_rot 			    = {0, 0, 0}
TENS_MILE_7.element_params 	        = {"MFD_OPACITY","RMFD_HSI_PAGE","MILE_2"}
TENS_MILE_7.controllers		        =   {
                                            {"opacity_using_parameter",0},
                                            {"parameter_in_range",1,0.9,1.1},
                                            {"parameter_in_range",2,0.65,0.75}--MENU PAGE = 0
						                }
Add(TENS_MILE_7)
-- -----------------------------------------------------------------------------------------------------------------------------------MILE 8
-- --MILE 8
TENS_MILE_8 					    = CreateElement "ceStringPoly"
TENS_MILE_8.name 				    = "menu"
TENS_MILE_8.material 			    = UFD_FONT
TENS_MILE_8.value 			        = "8"
TENS_MILE_8.stringdefs 		        = {0.0080, 0.0080, 0.0004, 0.001}
TENS_MILE_8.alignment 			    = "CenterCenter"
TENS_MILE_8.formats 			    = {"%s"}
TENS_MILE_8.h_clip_relation         = h_clip_relations.COMPARE
TENS_MILE_8.level 				    = 2
TENS_MILE_8.init_pos 			    = {-0.62, 0.75, 0}
TENS_MILE_8.init_rot 			    = {0, 0, 0}
TENS_MILE_8.element_params 	        = {"MFD_OPACITY","RMFD_HSI_PAGE","MILE_2"}
TENS_MILE_8.controllers		        =   {
                                            {"opacity_using_parameter",0},
                                            {"parameter_in_range",1,0.9,1.1},
                                            {"parameter_in_range",2,0.75,0.85}--MENU PAGE = 0
						                }
Add(TENS_MILE_8)
-- -----------------------------------------------------------------------------------------------------------------------------------MILE_9          
-- --MILE 9
TENS_MILE_9 					    = CreateElement "ceStringPoly"
TENS_MILE_9.name 				    = "menu"
TENS_MILE_9.material 			    = UFD_FONT
TENS_MILE_9.value 			        = "9"
TENS_MILE_9.stringdefs 		        = {0.0080, 0.0080, 0.0004, 0.001}
TENS_MILE_9.alignment 			    = "CenterCenter"
TENS_MILE_9.formats 			    = {"%s"}
TENS_MILE_9.h_clip_relation         = h_clip_relations.COMPARE
TENS_MILE_9.level 				    = 2
TENS_MILE_9.init_pos 			    = {-0.62, 0.75, 0}
TENS_MILE_9.init_rot 			    = {0, 0, 0}
TENS_MILE_9.element_params 	        = {"MFD_OPACITY","RMFD_HSI_PAGE","MILE_2"}
TENS_MILE_9.controllers		        =   {
                                            {"opacity_using_parameter",0},
                                            {"parameter_in_range",1,0.9,1.1},
                                            {"parameter_in_range",2,0.85,1.0}--MENU PAGE = 0
						                }
Add(TENS_MILE_9)
-----------------------------------------------------------------------------------------------------------------------------------MILE TENS              
--MILE 0
HUNS_MILE_0 					    = CreateElement "ceStringPoly"
HUNS_MILE_0.name 				    = "menu"
HUNS_MILE_0.material 			    = UFD_FONT
HUNS_MILE_0.value 			        = "0"
HUNS_MILE_0.stringdefs 		        = {0.0080, 0.0080, 0.0004, 0.001}
HUNS_MILE_0.alignment 			    = "CenterCenter"
HUNS_MILE_0.formats 			    = {"%s"}
HUNS_MILE_0.h_clip_relation         = h_clip_relations.COMPARE
HUNS_MILE_0.level 				    = 2
HUNS_MILE_0.init_pos 			    = {-0.69, 0.75, 0}
HUNS_MILE_0.init_rot 			    = {0, 0, 0}
HUNS_MILE_0.element_params 	        = {"MFD_OPACITY","RMFD_HSI_PAGE","MILE_3"}
HUNS_MILE_0.controllers		        =   {
                                            {"opacity_using_parameter",0},
                                            {"parameter_in_range",1,0.9,1.1},
                                            {"parameter_in_range",2,-0.001,0.05}--MENU PAGE = 0
						                }
Add(HUNS_MILE_0)
-- -----------------------------------------------------------------------------------------------------------------------------------       
--MILE 1
HUNS_MILE_1 					    = CreateElement "ceStringPoly"
HUNS_MILE_1.name 				    = "menu"
HUNS_MILE_1.material 			    = UFD_FONT
HUNS_MILE_1.value 			        = "1"
HUNS_MILE_1.stringdefs 		        = {0.0080, 0.0080, 0.0004, 0.001}
HUNS_MILE_1.alignment 			    = "CenterCenter"
HUNS_MILE_1.formats 			    = {"%s"}
HUNS_MILE_1.h_clip_relation         = h_clip_relations.COMPARE
HUNS_MILE_1.level 				    = 2
HUNS_MILE_1.init_pos 			    = {-0.69, 0.75, 0}
HUNS_MILE_1.init_rot 			    = {0, 0, 0}
HUNS_MILE_1.element_params 	        = {"MFD_OPACITY","RMFD_HSI_PAGE","MILE_3"}
HUNS_MILE_1.controllers		        =   {
                                            {"opacity_using_parameter",0},
                                            {"parameter_in_range",1,0.9,1.1},
                                            {"parameter_in_range",2,0.05,0.15}--MENU PAGE = 0
						                }
Add(HUNS_MILE_1)
-- -----------------------------------------------------------------------------------------------------------------------------------
--MILE 2
HUNS_MILE_2 					    = CreateElement "ceStringPoly"
HUNS_MILE_2.name 				    = "menu"
HUNS_MILE_2.material 			    = UFD_FONT
HUNS_MILE_2.value 			        = "2"
HUNS_MILE_2.stringdefs 		        = {0.0080, 0.0080, 0.0004, 0.001}
HUNS_MILE_2.alignment 			    = "CenterCenter"
HUNS_MILE_2.formats 			    = {"%s"}
HUNS_MILE_2.h_clip_relation         = h_clip_relations.COMPARE
HUNS_MILE_2.level 				    = 2
HUNS_MILE_2.init_pos 			    = {-0.69, 0.75, 0}
HUNS_MILE_2.init_rot 			    = {0, 0, 0}
HUNS_MILE_2.element_params 	        = {"MFD_OPACITY","RMFD_HSI_PAGE","MILE_3"}
HUNS_MILE_2.controllers		        =   {
                                            {"opacity_using_parameter",0},
                                            {"parameter_in_range",1,0.9,1.1},
                                            {"parameter_in_range",2,0.15,0.25}--MENU PAGE = 0
						                }
Add(HUNS_MILE_2)
-- -----------------------------------------------------------------------------------------------------------------------------------MILES          
--MILE 3
HUNS_MILE_3 					    = CreateElement "ceStringPoly"
HUNS_MILE_3.name 				    = "menu"
HUNS_MILE_3.material 			    = UFD_FONT
HUNS_MILE_3.value 			        = "3"
HUNS_MILE_3.stringdefs 		        = {0.0080, 0.0080, 0.0004, 0.001}
HUNS_MILE_3.alignment 			    = "CenterCenter"
HUNS_MILE_3.formats 			    = {"%s"}
HUNS_MILE_3.h_clip_relation         = h_clip_relations.COMPARE
HUNS_MILE_3.level 				    = 2
HUNS_MILE_3.init_pos 			    = {-0.69, 0.75, 0}
HUNS_MILE_3.init_rot 			    = {0, 0, 0}
HUNS_MILE_3.element_params 	        = {"MFD_OPACITY","RMFD_HSI_PAGE","MILE_3"}
HUNS_MILE_3.controllers		        =   {
                                            {"opacity_using_parameter",0},
                                            {"parameter_in_range",1,0.9,1.1},
                                            {"parameter_in_range",2,0.25,0.35}--MENU PAGE = 0
						                }
Add(HUNS_MILE_3)
-- -----------------------------------------------------------------------------------------------------------------------------------MILES_ONES_0              
--MILE 4
HUNS_MILE_4 					    = CreateElement "ceStringPoly"
HUNS_MILE_4.name 				    = "menu"
HUNS_MILE_4.material 			    = UFD_FONT
HUNS_MILE_4.value 			        = "4"
HUNS_MILE_4.stringdefs 		        = {0.0080, 0.0080, 0.0004, 0.001}
HUNS_MILE_4.alignment 			    = "CenterCenter"
HUNS_MILE_4.formats 			    = {"%s"}
HUNS_MILE_4.h_clip_relation         = h_clip_relations.COMPARE
HUNS_MILE_4.level 				    = 2
HUNS_MILE_4.init_pos 			    = {-0.69, 0.75, 0}
HUNS_MILE_4.init_rot 			    = {0, 0, 0}
HUNS_MILE_4.element_params 	        = {"MFD_OPACITY","RMFD_HSI_PAGE","MILE_3"}
HUNS_MILE_4.controllers		        =   {
                                            {"opacity_using_parameter",0},
                                            {"parameter_in_range",1,0.9,1.1},
                                            {"parameter_in_range",2,0.35,0.45}--MENU PAGE = 0
						                }
Add(HUNS_MILE_4)
-- -----------------------------------------------------------------------------------------------------------------------------------MILE_ONES_1          
--MILE 5
HUNS_MILE_5 					    = CreateElement "ceStringPoly"
HUNS_MILE_5.name 				    = "menu"
HUNS_MILE_5.material 			    = UFD_FONT
HUNS_MILE_5.value 			        = "5"
HUNS_MILE_5.stringdefs 		        = {0.0080, 0.0080, 0.0004, 0.001}
HUNS_MILE_5.alignment 			    = "CenterCenter"
HUNS_MILE_5.formats 			    = {"%s"}
HUNS_MILE_5.h_clip_relation         = h_clip_relations.COMPARE
HUNS_MILE_5.level 				    = 2
HUNS_MILE_5.init_pos 			    = {-69, 0.75, 0}
HUNS_MILE_5.init_rot 			    = {0, 0, 0}
HUNS_MILE_5.element_params 	        = {"MFD_OPACITY","RMFD_HSI_PAGE","MILE_3"}
HUNS_MILE_5.controllers		        =   {
                                            {"opacity_using_parameter",0},
                                            {"parameter_in_range",1,0.9,1.1},
                                            {"parameter_in_range",2,0.45,0.55}--MENU PAGE = 0
						                }
Add(HUNS_MILE_5)
-- -----------------------------------------------------------------------------------------------------------------------------------
-- --MILE 6
HUNS_MILE_6 					    = CreateElement "ceStringPoly"
HUNS_MILE_6.name 				    = "menu"
HUNS_MILE_6.material 			    = UFD_FONT
HUNS_MILE_6.value 			        = "6"
HUNS_MILE_6.stringdefs 		        = {0.0080, 0.0080, 0.0004, 0.001}
HUNS_MILE_6.alignment 			    = "CenterCenter"
HUNS_MILE_6.formats 			    = {"%s"}
HUNS_MILE_6.h_clip_relation         = h_clip_relations.COMPARE
HUNS_MILE_6.level 				    = 2
HUNS_MILE_6.init_pos 			    = {-0.69, 0.75, 0}
HUNS_MILE_6.init_rot 			    = {0, 0, 0}
HUNS_MILE_6.element_params 	        = {"MFD_OPACITY","RMFD_HSI_PAGE","MILE_3"}
HUNS_MILE_6.controllers		        =   {
                                            {"opacity_using_parameter",0},
                                            {"parameter_in_range",1,0.9,1.1},
                                            {"parameter_in_range",2,0.55,0.65}--MENU PAGE = 0
						                }
Add(HUNS_MILE_6)
-- -----------------------------------------------------------------------------------------------------------------------------------MILE_ONES_7    
-- --MILE 7
HUNS_MILE_7 					    = CreateElement "ceStringPoly"
HUNS_MILE_7.name 				    = "menu"
HUNS_MILE_7.material 			    = UFD_FONT
HUNS_MILE_7.value 			        = "7"
HUNS_MILE_7.stringdefs 		        = {0.0080, 0.0080, 0.0004, 0.001}
HUNS_MILE_7.alignment 			    = "CenterCenter"
HUNS_MILE_7.formats 			    = {"%s"}
HUNS_MILE_7.h_clip_relation         = h_clip_relations.COMPARE
HUNS_MILE_7.level 				    = 2
HUNS_MILE_7.init_pos 			    = {-0.69, 0.75, 0}
HUNS_MILE_7.init_rot 			    = {0, 0, 0}
HUNS_MILE_7.element_params 	        = {"MFD_OPACITY","RMFD_HSI_PAGE","MILE_3"}
HUNS_MILE_7.controllers		        =   {
                                            {"opacity_using_parameter",0},
                                            {"parameter_in_range",1,0.9,1.1},
                                            {"parameter_in_range",2,0.65,0.75}--MENU PAGE = 0
						                }
Add(HUNS_MILE_7)
-- -----------------------------------------------------------------------------------------------------------------------------------MILE 8
-- --MILE 8
HUNS_MILE_8 					    = CreateElement "ceStringPoly"
HUNS_MILE_8.name 				    = "menu"
HUNS_MILE_8.material 			    = UFD_FONT
HUNS_MILE_8.value 			        = "8"
HUNS_MILE_8.stringdefs 		        = {0.0080, 0.0080, 0.0004, 0.001}
HUNS_MILE_8.alignment 			    = "CenterCenter"
HUNS_MILE_8.formats 			    = {"%s"}
HUNS_MILE_8.h_clip_relation         = h_clip_relations.COMPARE
HUNS_MILE_8.level 				    = 2
HUNS_MILE_8.init_pos 			    = {-0.69, 0.75, 0}
HUNS_MILE_8.init_rot 			    = {0, 0, 0}
HUNS_MILE_8.element_params 	        = {"MFD_OPACITY","RMFD_HSI_PAGE","MILE_3"}
HUNS_MILE_8.controllers		        =   {
                                            {"opacity_using_parameter",0},
                                            {"parameter_in_range",1,0.9,1.1},
                                            {"parameter_in_range",2,0.75,0.85}--MENU PAGE = 0
						                }
Add(HUNS_MILE_8)
-- -----------------------------------------------------------------------------------------------------------------------------------MILE_9          
-- --MILE 9
HUNS_MILE_9 					    = CreateElement "ceStringPoly"
HUNS_MILE_9.name 				    = "menu"
HUNS_MILE_9.material 			    = UFD_FONT
HUNS_MILE_9.value 			        = "9"
HUNS_MILE_9.stringdefs 		        = {0.0080, 0.0080, 0.0004, 0.001}
HUNS_MILE_9.alignment 			    = "CenterCenter"
HUNS_MILE_9.formats 			    = {"%s"}
HUNS_MILE_9.h_clip_relation         = h_clip_relations.COMPARE
HUNS_MILE_9.level 				    = 2
HUNS_MILE_9.init_pos 			    = {-0.69, 0.75, 0}
HUNS_MILE_9.init_rot 			    = {0, 0, 0}
HUNS_MILE_9.element_params 	        = {"MFD_OPACITY","RMFD_HSI_PAGE","MILE_3"}
HUNS_MILE_9.controllers		        =   {
                                            {"opacity_using_parameter",0},
                                            {"parameter_in_range",1,0.9,1.1},
                                            {"parameter_in_range",2,0.85,1.0}--MENU PAGE = 0
						                }
Add(HUNS_MILE_9)        
-----------------------------------------------------------------------------------------------------------------------------------MILE_9  -- {-0.76, 75, 0}        
--MILE 0
THOS_MILE_0 					    = CreateElement "ceStringPoly"
THOS_MILE_0.name 				    = "menu"
THOS_MILE_0.material 			    = UFD_FONT
THOS_MILE_0.value 			        = "0"
THOS_MILE_0.stringdefs 		        = {0.0080, 0.0080, 0.0004, 0.001}
THOS_MILE_0.alignment 			    = "CenterCenter"
THOS_MILE_0.formats 			    = {"%s"}
THOS_MILE_0.h_clip_relation         = h_clip_relations.COMPARE
THOS_MILE_0.level 				    = 2
THOS_MILE_0.init_pos 			    = {-0.76, 0.75, 0}
THOS_MILE_0.init_rot 			    = {0, 0, 0}
THOS_MILE_0.element_params 	        = {"MFD_OPACITY","RMFD_HSI_PAGE","MILE_4"}
THOS_MILE_0.controllers		        =   {
                                            {"opacity_using_parameter",0},
                                            {"parameter_in_range",1,0.9,1.1},
                                            {"parameter_in_range",2,-0.001,0.05}
						                }
Add(THOS_MILE_0)
-----------------------------------------------------------------------------------------------------------------------------------MILE_9  -- {-0.76, 75, 0}        
--MILE 0
THOS_MILE_1 					    = CreateElement "ceStringPoly"
THOS_MILE_1.name 				    = "menu"
THOS_MILE_1.material 			    = UFD_FONT
THOS_MILE_1.value 			        = "1"
THOS_MILE_1.stringdefs 		        = {0.0080, 0.0080, 0.0004, 0.001}
THOS_MILE_1.alignment 			    = "CenterCenter"
THOS_MILE_1.formats 			    = {"%s"}
THOS_MILE_1.h_clip_relation         = h_clip_relations.COMPARE
THOS_MILE_1.level 				    = 2
THOS_MILE_1.init_pos 			    = {-0.76, 75, 0}
THOS_MILE_1.init_rot 			    = {0, 0, 0}
THOS_MILE_1.element_params 	        = {"MFD_OPACITY","RMFD_HSI_PAGE","MILE_4"}
THOS_MILE_1.controllers		        =   {
                                            {"opacity_using_parameter",0},
                                            {"parameter_in_range",1,0.9,1.1},
                                            {"parameter_in_range",2,0.05,0.15}--MENU PAGE = 0
						                }
Add(THOS_MILE_1)
-----------------------------------------------------------------------------------------------------------------------------------COURSE_0          
--COURSE 0
ONES_CRS_0 					        = CreateElement "ceStringPoly"
ONES_CRS_0.name 				    = "CRS0"
ONES_CRS_0.material 			    = UFD_FONT
ONES_CRS_0.value 			        = "0"
ONES_CRS_0.stringdefs 		        = {0.0080, 0.0080, 0.0004, 0.001}
ONES_CRS_0.alignment 			    = "CenterCenter"
ONES_CRS_0.formats 			        = {"%s"}
ONES_CRS_0.h_clip_relation          = h_clip_relations.COMPARE
ONES_CRS_0.level 				    = 2
ONES_CRS_0.init_pos 			    = {0.69, 0.75, 0}
ONES_CRS_0.init_rot 			    = {0, 0, 0}
ONES_CRS_0.element_params 	        = {"MFD_OPACITY","RMFD_HSI_PAGE","COURSE_1"}
ONES_CRS_0.controllers		        =   {
                                            {"opacity_using_parameter",0},
                                            {"parameter_in_range",1,0.9,1.1},
                                            {"parameter_in_range",2,-0.001,0.05}--MENU PAGE = 0
						                }
Add(ONES_CRS_0)
-----------------------------------------------------------------------------------------------------------------------------------COURSE_0          
--COURSE 0
ONES_CRS_1 					        = CreateElement "ceStringPoly"
ONES_CRS_1.name 				    = "CRS0"
ONES_CRS_1.material 			    = UFD_FONT
ONES_CRS_1.value 			        = "1"
ONES_CRS_1.stringdefs 		        = {0.0080, 0.0080, 0.0004, 0.001}
ONES_CRS_1.alignment 			    = "CenterCenter"
ONES_CRS_1.formats 			        = {"%s"}
ONES_CRS_1.h_clip_relation          = h_clip_relations.COMPARE
ONES_CRS_1.level 				    = 2
ONES_CRS_1.init_pos 			    = {0.69, 0.75, 0}
ONES_CRS_1.init_rot 			    = {0, 0, 0}
ONES_CRS_1.element_params 	        = {"MFD_OPACITY","RMFD_HSI_PAGE","COURSE_1"}
ONES_CRS_1.controllers		        =   {
                                            {"opacity_using_parameter",0},
                                            {"parameter_in_range",1,0.9,1.1},
                                            {"parameter_in_range",2,0.05,0.15}--MENU PAGE = 0
						                }
Add(ONES_CRS_1)
-----------------------------------------------------------------------------------------------------------------------------------COURSE_0          
--COURSE 0
ONES_CRS_2 					        = CreateElement "ceStringPoly"
ONES_CRS_2.name 				    = "CRS0"
ONES_CRS_2.material 			    = UFD_FONT
ONES_CRS_2.value 			        = "2"
ONES_CRS_2.stringdefs 		        = {0.0080, 0.0080, 0.0004, 0.001}
ONES_CRS_2.alignment 			    = "CenterCenter"
ONES_CRS_2.formats 			        = {"%s"}
ONES_CRS_2.h_clip_relation          = h_clip_relations.COMPARE
ONES_CRS_2.level 				    = 2
ONES_CRS_2.init_pos 			    = {0.69, 0.75, 0}
ONES_CRS_2.init_rot 			    = {0, 0, 0}
ONES_CRS_2.element_params 	        = {"MFD_OPACITY","RMFD_HSI_PAGE","COURSE_1"}
ONES_CRS_2.controllers		        =   {
                                            {"opacity_using_parameter",0},
                                            {"parameter_in_range",1,0.9,1.1},
                                            {"parameter_in_range",2,0.15,0.25}--MENU PAGE = 0
						                }
Add(ONES_CRS_2)
-----------------------------------------------------------------------------------------------------------------------------------COURSE_0          
--COURSE 0
ONES_CRS_3 					        = CreateElement "ceStringPoly"
ONES_CRS_3.name 				    = "CRS0"
ONES_CRS_3.material 			    = UFD_FONT
ONES_CRS_3.value 			        = "3"
ONES_CRS_3.stringdefs 		        = {0.0080, 0.0080, 0.0004, 0.001}
ONES_CRS_3.alignment 			    = "CenterCenter"
ONES_CRS_3.formats 			        = {"%s"}
ONES_CRS_3.h_clip_relation          = h_clip_relations.COMPARE
ONES_CRS_3.level 				    = 2
ONES_CRS_3.init_pos 			    = {0.69, 0.75, 0}
ONES_CRS_3.init_rot 			    = {0, 0, 0}
ONES_CRS_3.element_params 	        = {"MFD_OPACITY","RMFD_HSI_PAGE","COURSE_1"}
ONES_CRS_3.controllers		        =   {
                                            {"opacity_using_parameter",0},
                                            {"parameter_in_range",1,0.9,1.1},
                                            {"parameter_in_range",2,0.25,0.35}--MENU PAGE = 0
						                }
Add(ONES_CRS_3)
-----------------------------------------------------------------------------------------------------------------------------------COURSE_0          
--COURSE 0
ONES_CRS_4 					        = CreateElement "ceStringPoly"
ONES_CRS_4.name 				    = "CRS0"
ONES_CRS_4.material 			    = UFD_FONT
ONES_CRS_4.value 			        = "4"
ONES_CRS_4.stringdefs 		        = {0.0080, 0.0080, 0.0004, 0.001}
ONES_CRS_4.alignment 			    = "CenterCenter"
ONES_CRS_4.formats 			        = {"%s"}
ONES_CRS_4.h_clip_relation          = h_clip_relations.COMPARE
ONES_CRS_4.level 				    = 2
ONES_CRS_4.init_pos 			    = {0.69, 0.75, 0}
ONES_CRS_4.init_rot 			    = {0, 0, 0}
ONES_CRS_4.element_params 	        = {"MFD_OPACITY","RMFD_HSI_PAGE","COURSE_1"}
ONES_CRS_4.controllers		        =   {
                                            {"opacity_using_parameter",0},
                                            {"parameter_in_range",1,0.9,1.1},
                                            {"parameter_in_range",2,0.35,0.45}--MENU PAGE = 0
						                }
Add(ONES_CRS_4)
-----------------------------------------------------------------------------------------------------------------------------------COURSE_0          
--COURSE 0
ONES_CRS_5 					        = CreateElement "ceStringPoly"
ONES_CRS_5.name 				    = "CRS0"
ONES_CRS_5.material 			    = UFD_FONT
ONES_CRS_5.value 			        = "5"
ONES_CRS_5.stringdefs 		        = {0.0080, 0.0080, 0.0004, 0.001}
ONES_CRS_5.alignment 			    = "CenterCenter"
ONES_CRS_5.formats 			        = {"%s"}
ONES_CRS_5.h_clip_relation          = h_clip_relations.COMPARE
ONES_CRS_5.level 				    = 2
ONES_CRS_5.init_pos 			    = {0.69, 0.75, 0}
ONES_CRS_5.init_rot 			    = {0, 0, 0}
ONES_CRS_5.element_params 	        = {"MFD_OPACITY","RMFD_HSI_PAGE","COURSE_1"}
ONES_CRS_5.controllers		        =   {
                                            {"opacity_using_parameter",0},
                                            {"parameter_in_range",1,0.9,1.1},
                                            {"parameter_in_range",2,0.45,0.55}--MENU PAGE = 0
						                }
Add(ONES_CRS_5)
-----------------------------------------------------------------------------------------------------------------------------------COURSE_0          
--COURSE 0
ONES_CRS_6 					        = CreateElement "ceStringPoly"
ONES_CRS_6.name 				    = "CRS0"
ONES_CRS_6.material 			    = UFD_FONT
ONES_CRS_6.value 			        = "6"
ONES_CRS_6.stringdefs 		        = {0.0080, 0.0080, 0.0004, 0.001}
ONES_CRS_6.alignment 			    = "CenterCenter"
ONES_CRS_6.formats 			        = {"%s"}
ONES_CRS_6.h_clip_relation          = h_clip_relations.COMPARE
ONES_CRS_6.level 				    = 2
ONES_CRS_6.init_pos 			    = {0.69, 0.75, 0}
ONES_CRS_6.init_rot 			    = {0, 0, 0}
ONES_CRS_6.element_params 	        = {"MFD_OPACITY","RMFD_HSI_PAGE","COURSE_1"}
ONES_CRS_6.controllers		        =   {
                                            {"opacity_using_parameter",0},
                                            {"parameter_in_range",1,0.9,1.1},
                                            {"parameter_in_range",2,0.55,0.65}--MENU PAGE = 0
						                }
Add(ONES_CRS_6)
-----------------------------------------------------------------------------------------------------------------------------------COURSE_0          
--COURSE 0
ONES_CRS_7 					        = CreateElement "ceStringPoly"
ONES_CRS_7.name 				    = "CRS0"
ONES_CRS_7.material 			    = UFD_FONT
ONES_CRS_7.value 			        = "7"
ONES_CRS_7.stringdefs 		        = {0.0080, 0.0080, 0.0004, 0.001}
ONES_CRS_7.alignment 			    = "CenterCenter"
ONES_CRS_7.formats 			        = {"%s"}
ONES_CRS_7.h_clip_relation          = h_clip_relations.COMPARE
ONES_CRS_7.level 				    = 2
ONES_CRS_7.init_pos 			    = {0.69, 0.75, 0}
ONES_CRS_7.init_rot 			    = {0, 0, 0}
ONES_CRS_7.element_params 	        = {"MFD_OPACITY","RMFD_HSI_PAGE","COURSE_1"}
ONES_CRS_7.controllers		        =   {
                                            {"opacity_using_parameter",0},
                                            {"parameter_in_range",1,0.9,1.1},
                                            {"parameter_in_range",2,0.65,0.75}--MENU PAGE = 0
						                }
Add(ONES_CRS_7)
-----------------------------------------------------------------------------------------------------------------------------------COURSE_0          
--COURSE 0
ONES_CRS_8 					        = CreateElement "ceStringPoly"
ONES_CRS_8.name 				    = "CRS0"
ONES_CRS_8.material 			    = UFD_FONT
ONES_CRS_8.value 			        = "8"
ONES_CRS_8.stringdefs 		        = {0.0080, 0.0080, 0.0004, 0.001}
ONES_CRS_8.alignment 			    = "CenterCenter"
ONES_CRS_8.formats 			        = {"%s"}
ONES_CRS_8.h_clip_relation          = h_clip_relations.COMPARE
ONES_CRS_8.level 				    = 2
ONES_CRS_8.init_pos 			    = {0.69, 0.75, 0}
ONES_CRS_8.init_rot 			    = {0, 0, 0}
ONES_CRS_8.element_params 	        = {"MFD_OPACITY","RMFD_HSI_PAGE","COURSE_1"}
ONES_CRS_8.controllers		        =   {
                                            {"opacity_using_parameter",0},
                                            {"parameter_in_range",1,0.9,1.1},
                                            {"parameter_in_range",2,0.75,0.85}--MENU PAGE = 0
						                }
Add(ONES_CRS_8)
-----------------------------------------------------------------------------------------------------------------------------------COURSE_0          
--COURSE 0
ONES_CRS_9 					        = CreateElement "ceStringPoly"
ONES_CRS_9.name 				    = "CRS0"
ONES_CRS_9.material 			    = UFD_FONT
ONES_CRS_9.value 			        = "9"
ONES_CRS_9.stringdefs 		        = {0.0080, 0.0080, 0.0004, 0.001}
ONES_CRS_9.alignment 			    = "CenterCenter"
ONES_CRS_9.formats 			        = {"%s"}
ONES_CRS_9.h_clip_relation          = h_clip_relations.COMPARE
ONES_CRS_9.level 				    = 2
ONES_CRS_9.init_pos 			    = {0.69, 0.75, 0}
ONES_CRS_9.init_rot 			    = {0, 0, 0}
ONES_CRS_9.element_params 	        = {"MFD_OPACITY","RMFD_HSI_PAGE","COURSE_1"}
ONES_CRS_9.controllers		        =   {
                                            {"opacity_using_parameter",0},
                                            {"parameter_in_range",1,0.9,1.1},
                                            {"parameter_in_range",2,0.85,1.0}--MENU PAGE = 0
						                }
Add(ONES_CRS_9)
-----------------------------------------------------------------------------------------------------------------------------------COURSE_0          
--COURSE 0
ONES_CRS_00 					        = CreateElement "ceStringPoly"
ONES_CRS_00.name 				    = "CRS0"
ONES_CRS_00.material 			    = UFD_FONT
ONES_CRS_00.value 			        = "0"
ONES_CRS_00.stringdefs 		        = {0.0080, 0.0080, 0.0004, 0.001}
ONES_CRS_00.alignment 			    = "CenterCenter"
ONES_CRS_00.formats 			        = {"%s"}
ONES_CRS_00.h_clip_relation          = h_clip_relations.COMPARE
ONES_CRS_00.level 				    = 2
ONES_CRS_00.init_pos 			    = {0.69, 0.75, 0}
ONES_CRS_00.init_rot 			    = {0, 0, 0}
ONES_CRS_00.element_params 	        = {"MFD_OPACITY","RMFD_HSI_PAGE","COURSE_1"}
ONES_CRS_00.controllers		        =   {
                                            {"opacity_using_parameter",0},
                                            {"parameter_in_range",1,0.9,1.1},
                                            {"parameter_in_range",2,0.95,1.1}--MENU PAGE = 0
						                }
Add(ONES_CRS_00)
-----------------------------------------------------------------------------------------------------------------------------------COURSE_0         
--COURSE 0
TENS_CRS_0 					        = CreateElement "ceStringPoly"
TENS_CRS_0.name 				    = "CRS0"
TENS_CRS_0.material 			    = UFD_FONT
TENS_CRS_0.value 			        = "0"
TENS_CRS_0.stringdefs 		        = {0.0080, 0.0080, 0.0004, 0.001}
TENS_CRS_0.alignment 			    = "CenterCenter"
TENS_CRS_0.formats 			        = {"%s"}
TENS_CRS_0.h_clip_relation          = h_clip_relations.COMPARE
TENS_CRS_0.level 				    = 2
TENS_CRS_0.init_pos 			    = {0.62, 0.75, 0}
TENS_CRS_0.init_rot 			    = {0, 0, 0}
TENS_CRS_0.element_params 	        = {"MFD_OPACITY","RMFD_HSI_PAGE","COURSE_2"}
TENS_CRS_0.controllers		        =   {
                                            {"opacity_using_parameter",0},
                                            {"parameter_in_range",1,0.9,1.1},
                                            {"parameter_in_range",2,-0.001,0.05}--MENU PAGE = 0
						                }
Add(TENS_CRS_0)
-----------------------------------------------------------------------------------------------------------------------------------COURSE_0          
--COURSE 0
TENS_CRS_1 					        = CreateElement "ceStringPoly"
TENS_CRS_1.name 				    = "CRS0"
TENS_CRS_1.material 			    = UFD_FONT
TENS_CRS_1.value 			        = "1"
TENS_CRS_1.stringdefs 		        = {0.0080, 0.0080, 0.0004, 0.001}
TENS_CRS_1.alignment 			    = "CenterCenter"
TENS_CRS_1.formats 			        = {"%s"}
TENS_CRS_1.h_clip_relation          = h_clip_relations.COMPARE
TENS_CRS_1.level 				    = 2
TENS_CRS_1.init_pos 			    = {0.62, 0.75, 0}
TENS_CRS_1.init_rot 			    = {0, 0, 0}
TENS_CRS_1.element_params 	        = {"MFD_OPACITY","RMFD_HSI_PAGE","COURSE_2"}
TENS_CRS_1.controllers		        =   {
                                            {"opacity_using_parameter",0},
                                            {"parameter_in_range",1,0.9,1.1},
                                            {"parameter_in_range",2,0.05,0.15}--MENU PAGE = 0
						                }
Add(TENS_CRS_1)
-----------------------------------------------------------------------------------------------------------------------------------COURSE_0          
--COURSE 0
TENS_CRS_2 					        = CreateElement "ceStringPoly"
TENS_CRS_2.name 				    = "CRS0"
TENS_CRS_2.material 			    = UFD_FONT
TENS_CRS_2.value 			        = "2"
TENS_CRS_2.stringdefs 		        = {0.0080, 0.0080, 0.0004, 0.001}
TENS_CRS_2.alignment 			    = "CenterCenter"
TENS_CRS_2.formats 			        = {"%s"}
TENS_CRS_2.h_clip_relation          = h_clip_relations.COMPARE
TENS_CRS_2.level 				    = 2
TENS_CRS_2.init_pos 			    = {0.62, 0.75, 0}
TENS_CRS_2.init_rot 			    = {0, 0, 0}
TENS_CRS_2.element_params 	        = {"MFD_OPACITY","RMFD_HSI_PAGE","COURSE_2"}
TENS_CRS_2.controllers		        =   {
                                            {"opacity_using_parameter",0},
                                            {"parameter_in_range",1,0.9,1.1},
                                            {"parameter_in_range",2,0.15,0.25}--MENU PAGE = 0
						                }
Add(TENS_CRS_2)
-----------------------------------------------------------------------------------------------------------------------------------COURSE_0          
--COURSE 0
TENS_CRS_3 					        = CreateElement "ceStringPoly"
TENS_CRS_3.name 				    = "CRS0"
TENS_CRS_3.material 			    = UFD_FONT
TENS_CRS_3.value 			        = "3"
TENS_CRS_3.stringdefs 		        = {0.0080, 0.0080, 0.0004, 0.001}
TENS_CRS_3.alignment 			    = "CenterCenter"
TENS_CRS_3.formats 			        = {"%s"}
TENS_CRS_3.h_clip_relation          = h_clip_relations.COMPARE
TENS_CRS_3.level 				    = 2
TENS_CRS_3.init_pos 			    = {0.62, 0.75, 0}
TENS_CRS_3.init_rot 			    = {0, 0, 0}
TENS_CRS_3.element_params 	        = {"MFD_OPACITY","RMFD_HSI_PAGE","COURSE_2"}
TENS_CRS_3.controllers		        =   {
                                            {"opacity_using_parameter",0},
                                            {"parameter_in_range",1,0.9,1.1},
                                            {"parameter_in_range",2,0.25,0.35}--MENU PAGE = 0
						                }
Add(TENS_CRS_3)
-----------------------------------------------------------------------------------------------------------------------------------COURSE_0          
--COURSE 0
TENS_CRS_4 					        = CreateElement "ceStringPoly"
TENS_CRS_4.name 				    = "CRS0"
TENS_CRS_4.material 			    = UFD_FONT
TENS_CRS_4.value 			        = "4"
TENS_CRS_4.stringdefs 		        = {0.0080, 0.0080, 0.0004, 0.001}
TENS_CRS_4.alignment 			    = "CenterCenter"
TENS_CRS_4.formats 			        = {"%s"}
TENS_CRS_4.h_clip_relation          = h_clip_relations.COMPARE
TENS_CRS_4.level 				    = 2
TENS_CRS_4.init_pos 			    = {0.62, 0.75, 0}
TENS_CRS_4.init_rot 			    = {0, 0, 0}
TENS_CRS_4.element_params 	        = {"MFD_OPACITY","RMFD_HSI_PAGE","COURSE_2"}
TENS_CRS_4.controllers		        =   {
                                            {"opacity_using_parameter",0},
                                            {"parameter_in_range",1,0.9,1.1},
                                            {"parameter_in_range",2,0.35,0.45}--MENU PAGE = 0
						                }
Add(TENS_CRS_4)
-----------------------------------------------------------------------------------------------------------------------------------COURSE_0          
--COURSE 0
TENS_CRS_5 					        = CreateElement "ceStringPoly"
TENS_CRS_5.name 				    = "CRS0"
TENS_CRS_5.material 			    = UFD_FONT
TENS_CRS_5.value 			        = "5"
TENS_CRS_5.stringdefs 		        = {0.0080, 0.0080, 0.0004, 0.001}
TENS_CRS_5.alignment 			    = "CenterCenter"
TENS_CRS_5.formats 			        = {"%s"}
TENS_CRS_5.h_clip_relation          = h_clip_relations.COMPARE
TENS_CRS_5.level 				    = 2
TENS_CRS_5.init_pos 			    = {0.62, 0.75, 0}
TENS_CRS_5.init_rot 			    = {0, 0, 0}
TENS_CRS_5.element_params 	        = {"MFD_OPACITY","RMFD_HSI_PAGE","COURSE_2"}
TENS_CRS_5.controllers		        =   {
                                            {"opacity_using_parameter",0},
                                            {"parameter_in_range",1,0.9,1.1},
                                            {"parameter_in_range",2,0.45,0.55}--MENU PAGE = 0
						                }
Add(TENS_CRS_5)
-----------------------------------------------------------------------------------------------------------------------------------COURSE_0          
--COURSE 0
TENS_CRS_6 					        = CreateElement "ceStringPoly"
TENS_CRS_6.name 				    = "CRS0"
TENS_CRS_6.material 			    = UFD_FONT
TENS_CRS_6.value 			        = "6"
TENS_CRS_6.stringdefs 		        = {0.0080, 0.0080, 0.0004, 0.001}
TENS_CRS_6.alignment 			    = "CenterCenter"
TENS_CRS_6.formats 			        = {"%s"}
TENS_CRS_6.h_clip_relation          = h_clip_relations.COMPARE
TENS_CRS_6.level 				    = 2
TENS_CRS_6.init_pos 			    = {0.62, 0.75, 0}
TENS_CRS_6.init_rot 			    = {0, 0, 0}
TENS_CRS_6.element_params 	        = {"MFD_OPACITY","RMFD_HSI_PAGE","COURSE_2"}
TENS_CRS_6.controllers		        =   {
                                            {"opacity_using_parameter",0},
                                            {"parameter_in_range",1,0.9,1.1},
                                            {"parameter_in_range",2,0.55,0.65}--MENU PAGE = 0
						                }
Add(TENS_CRS_6)
-----------------------------------------------------------------------------------------------------------------------------------COURSE_0
TENS_CRS_00 					        = CreateElement "ceStringPoly"
TENS_CRS_00.name 				    = "CRS0"
TENS_CRS_00.material 			    = UFD_FONT
TENS_CRS_00.value 			        = "0"
TENS_CRS_00.stringdefs 		        = {0.0080, 0.0080, 0.0004, 0.001}
TENS_CRS_00.alignment 			    = "CenterCenter"
TENS_CRS_00.formats 			        = {"%s"}
TENS_CRS_00.h_clip_relation          = h_clip_relations.COMPARE
TENS_CRS_00.level 				    = 2
TENS_CRS_00.init_pos 			    = {0.62, 0.75, 0}
TENS_CRS_00.init_rot 			    = {0, 0, 0}
TENS_CRS_00.element_params 	        = {"MFD_OPACITY","RMFD_HSI_PAGE","COURSE_2"}
TENS_CRS_00.controllers		        =   {
                                            {"opacity_using_parameter",0},
                                            {"parameter_in_range",1,0.9,1.1},
                                            {"parameter_in_range",2,0.65,1.1}--MENU PAGE = 0
						                }
Add(TENS_CRS_00)          
----------------------------------------------------------------------------------------------------------------------------------------------STOP---------here
-----------------------------------------------------------------------------------------------------------------------------------COURSE_0         
--COURSE 0
HUNS_CRS_0 					        = CreateElement "ceStringPoly"
HUNS_CRS_0.name 				    = "CRS0"
HUNS_CRS_0.material 			    = UFD_FONT
HUNS_CRS_0.value 			        = "0"
HUNS_CRS_0.stringdefs 		        = {0.0080, 0.0080, 0.0004, 0.001}
HUNS_CRS_0.alignment 			    = "CenterCenter"
HUNS_CRS_0.formats 			        = {"%s"}
HUNS_CRS_0.h_clip_relation          = h_clip_relations.COMPARE
HUNS_CRS_0.level 				    = 2
HUNS_CRS_0.init_pos 			    = {0.55, 0.75, 0}
HUNS_CRS_0.init_rot 			    = {0, 0, 0}
HUNS_CRS_0.element_params 	        = {"MFD_OPACITY","RMFD_HSI_PAGE","COURSE_3"}
HUNS_CRS_0.controllers		        =   {
                                            {"opacity_using_parameter",0},
                                            {"parameter_in_range",1,0.9,1.1},
                                            {"parameter_in_range",2,-0.001,0.05}--MENU PAGE = 0
						                }
Add(HUNS_CRS_0)
-----------------------------------------------------------------------------------------------------------------------------------COURSE_0          
--COURSE 0
HUNS_CRS_1 					        = CreateElement "ceStringPoly"
HUNS_CRS_1.name 				    = "CRS0"
HUNS_CRS_1.material 			    = UFD_FONT
HUNS_CRS_1.value 			        = "1"
HUNS_CRS_1.stringdefs 		        = {0.0080, 0.0080, 0.0004, 0.001}
HUNS_CRS_1.alignment 			    = "CenterCenter"
HUNS_CRS_1.formats 			        = {"%s"}
HUNS_CRS_1.h_clip_relation          = h_clip_relations.COMPARE
HUNS_CRS_1.level 				    = 2
HUNS_CRS_1.init_pos 			    = {0.55, 0.75, 0}
HUNS_CRS_1.init_rot 			    = {0, 0, 0}
HUNS_CRS_1.element_params 	        = {"MFD_OPACITY","RMFD_HSI_PAGE","COURSE_3"}
HUNS_CRS_1.controllers		        =   {
                                            {"opacity_using_parameter",0},
                                            {"parameter_in_range",1,0.9,1.1},
                                            {"parameter_in_range",2,0.05,0.15}--MENU PAGE = 0
						                }
Add(HUNS_CRS_1)
-----------------------------------------------------------------------------------------------------------------------------------COURSE_0          
--COURSE 0
HUNS_CRS_2 					        = CreateElement "ceStringPoly"
HUNS_CRS_2.name 				    = "CRS0"
HUNS_CRS_2.material 			    = UFD_FONT
HUNS_CRS_2.value 			        = "2"
HUNS_CRS_2.stringdefs 		        = {0.0080, 0.0080, 0.0004, 0.001}
HUNS_CRS_2.alignment 			    = "CenterCenter"
HUNS_CRS_2.formats 			        = {"%s"}
HUNS_CRS_2.h_clip_relation          = h_clip_relations.COMPARE
HUNS_CRS_2.level 				    = 2
HUNS_CRS_2.init_pos 			    = {0.55, 0.75, 0}
HUNS_CRS_2.init_rot 			    = {0, 0, 0}
HUNS_CRS_2.element_params 	        = {"MFD_OPACITY","RMFD_HSI_PAGE","COURSE_3"}
HUNS_CRS_2.controllers		        =   {
                                            {"opacity_using_parameter",0},
                                            {"parameter_in_range",1,0.9,1.1},
                                            {"parameter_in_range",2,0.15,0.25}--MENU PAGE = 0
						                }
Add(HUNS_CRS_2)
-----------------------------------------------------------------------------------------------------------------------------------COURSE_0          
--COURSE 0
HUNS_CRS_3 					        = CreateElement "ceStringPoly"
HUNS_CRS_3.name 				    = "CRS0"
HUNS_CRS_3.material 			    = UFD_FONT
HUNS_CRS_3.value 			        = "3"
HUNS_CRS_3.stringdefs 		        = {0.0080, 0.0080, 0.0004, 0.001}
HUNS_CRS_3.alignment 			    = "CenterCenter"
HUNS_CRS_3.formats 			        = {"%s"}
HUNS_CRS_3.h_clip_relation          = h_clip_relations.COMPARE
HUNS_CRS_3.level 				    = 2
HUNS_CRS_3.init_pos 			    = {0.55, 0.75, 0}
HUNS_CRS_3.init_rot 			    = {0, 0, 0}
HUNS_CRS_3.element_params 	        = {"MFD_OPACITY","RMFD_HSI_PAGE","COURSE_3"}
HUNS_CRS_3.controllers		        =   {
                                            {"opacity_using_parameter",0},
                                            {"parameter_in_range",1,0.9,1.1},
                                            {"parameter_in_range",2,0.25,0.35}--MENU PAGE = 0
						                }
Add(HUNS_CRS_3)
-----------------------------------------------------------------------------------------------------------------------------------COURSE_0         
--COURSE 0
HUNS_CRS_00 					        = CreateElement "ceStringPoly"
HUNS_CRS_00.name 				    = "CRS0"
HUNS_CRS_00.material 			    = UFD_FONT
HUNS_CRS_00.value 			        = "0"
HUNS_CRS_00.stringdefs 		        = {0.0080, 0.0080, 0.0004, 0.001}
HUNS_CRS_00.alignment 			    = "CenterCenter"
HUNS_CRS_00.formats 			        = {"%s"}
HUNS_CRS_00.h_clip_relation          = h_clip_relations.COMPARE
HUNS_CRS_00.level 				    = 2
HUNS_CRS_00.init_pos 			    = {0.55, 0.75, 0}
HUNS_CRS_00.init_rot 			    = {0, 0, 0}
HUNS_CRS_00.element_params 	        = {"MFD_OPACITY","RMFD_HSI_PAGE","COURSE_3"}
HUNS_CRS_00.controllers		        =   {
                                            {"opacity_using_parameter",0},
                                            {"parameter_in_range",1,0.9,1.1},
                                            {"parameter_in_range",2,0.35,1.1}--MENU PAGE = 0
						                }
Add(HUNS_CRS_00)          
----------------------------------------------------------------------------------------------------------------------------------------------STOP

--HSI PLACEHOLDER
COURSETXT 					    = CreateElement "ceStringPoly"
COURSETXT.name 				    = "menu"
COURSETXT.material 			    = UFD_FONT
COURSETXT.value 			        = "COURSE"
COURSETXT.stringdefs 		    = {0.0040, 0.0040, 0.0004, 0.001}
COURSETXT.alignment 			    = "CenterCenter"
COURSETXT.formats 			    = {"%s"}
COURSETXT.h_clip_relation        = h_clip_relations.COMPARE
COURSETXT.level 				    = 2
COURSETXT.init_pos 			    = {0.62, 0.65, 0}
COURSETXT.init_rot 			    = {0, 0, 0}
COURSETXT.element_params 	    = {"MFD_OPACITY","RMFD_HSI_PAGE"}
COURSETXT.controllers		    =   {
                                            {"opacity_using_parameter",0},
                                            {"parameter_in_range",1,0.9,1.1},--MENU PAGE = 0
						                }
Add(COURSETXT)
--HSI PLACEHOLDER
MILETXT 					    = CreateElement "ceStringPoly"
MILETXT.name 				    = "MILES"
MILETXT.material 			    = UFD_FONT
MILETXT.value 			        = "MILES"
MILETXT.stringdefs 		    = {0.0040, 0.0040, 0.0004, 0.001}
MILETXT.alignment 			    = "CenterCenter"
MILETXT.formats 			    = {"%s"}
MILETXT.h_clip_relation        = h_clip_relations.COMPARE
MILETXT.level 				    = 2
MILETXT.init_pos 			    = {-0.62, 0.65, 0}
MILETXT.init_rot 			    = {0, 0, 0}
MILETXT.element_params 	    = {"MFD_OPACITY","RMFD_HSI_PAGE"}
MILETXT.controllers		    =   {
                                            {"opacity_using_parameter",0},
                                            {"parameter_in_range",1,0.9,1.1},--MENU PAGE = 0
						                }
Add(MILETXT)
--------------------------------------------------------------------------------------------------- ILS
ILS_TEXT 					    = CreateElement "ceStringPoly"
ILS_TEXT.name 				    = "menu"
ILS_TEXT.material 			    = UFD_FONT
ILS_TEXT.value 				    = "ILSN"
ILS_TEXT.stringdefs 		    = {0.0050, 0.0050, 0.0004, 0.001}
ILS_TEXT.alignment 			    = "CenterCenter"
ILS_TEXT.formats 			    = {"%s"}
ILS_TEXT.h_clip_relation        = h_clip_relations.COMPARE
ILS_TEXT.level 				    = 2
ILS_TEXT.init_pos 			    = {-0.565,-0.92, 0}
ILS_TEXT.init_rot 			    = {0, 0, 0}
ILS_TEXT.element_params 	    = {"MFD_OPACITY","RMFD_HSI_PAGE","ILSN_VIS"}
ILS_TEXT.controllers		    =   {
                                        {"opacity_using_parameter",0},
                                        {"parameter_in_range",1,0.9,1.1},
                                        {"parameter_in_range",2,0.9,1.1},--ENGINE PAGE = 0
						            }
Add(ILS_TEXT)
--------------------------------------------------------------------------------------------------- NAV
NAV_TEXT 					    = CreateElement "ceStringPoly"
NAV_TEXT.name 				    = "menu"
NAV_TEXT.material 			    = UFD_FONT
NAV_TEXT.value 				    = "NAV"
NAV_TEXT.stringdefs 		    = {0.0050, 0.0050, 0.0004, 0.001}
NAV_TEXT.alignment 			    = "CenterCenter"
NAV_TEXT.formats 			    = {"%s"}
NAV_TEXT.h_clip_relation        = h_clip_relations.COMPARE
NAV_TEXT.level 				    = 2
NAV_TEXT.init_pos 			    = {-0.565,-0.92, 0}
NAV_TEXT.init_rot 			    = {0, 0, 0}
NAV_TEXT.element_params 	    = {"MFD_OPACITY","RMFD_HSI_PAGE","NAV_VIS"}
NAV_TEXT.controllers		    =   {
                                        {"opacity_using_parameter",0},
                                        {"parameter_in_range",1,0.9,1.1},
                                        {"parameter_in_range",2,0.9,1.1},--ENGINE PAGE = 0
						            }
Add(NAV_TEXT)
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
MENU_CHK_TEXT.init_pos 			    = {-0.565,0.92, 0}
MENU_CHK_TEXT.init_rot 			    = {0, 0, 0}
MENU_CHK_TEXT.element_params 	    = {"MFD_OPACITY","RMFD_HSI_PAGE"}
MENU_CHK_TEXT.controllers		    =   {
                                        {"opacity_using_parameter",0},
                                        {"parameter_in_range",1,0.9,1.1},--ENGINE PAGE = 0
						            }
Add(MENU_CHK_TEXT)
--MENU TEXT
HSI_TEXT 					    = CreateElement "ceStringPoly"
HSI_TEXT.name 				    = "menu"
HSI_TEXT.material 			    = UFD_FONT
HSI_TEXT.value 				    = "ADI"
HSI_TEXT.stringdefs 		    = {0.0050, 0.0050, 0.0004, 0.001}
HSI_TEXT.alignment 			    = "CenterCenter"
HSI_TEXT.formats 			    = {"%s"}
HSI_TEXT.h_clip_relation        = h_clip_relations.COMPARE
HSI_TEXT.level 				    = 2
HSI_TEXT.init_pos 			    = {0.565,0.92, 0}
HSI_TEXT.init_rot 			    = {0, 0, 0}
HSI_TEXT.element_params 	    = {"MFD_OPACITY","RMFD_HSI_PAGE"}
HSI_TEXT.controllers		    =   {
                                        {"opacity_using_parameter",0},
                                        {"parameter_in_range",1,0.9,1.1},--ENGINE PAGE = 0
						            }
Add(HSI_TEXT)
