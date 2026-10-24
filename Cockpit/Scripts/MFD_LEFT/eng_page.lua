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
local FCS_PAGE      = MakeMaterial(LockOn_Options.script_path.."../Scripts/IndicationTextures/fcs_page.dds", GreenColor)
local ENG_PAGE      = MakeMaterial(LockOn_Options.script_path.."../Scripts/IndicationTextures/engine_page.dds", WhiteColor)
local FUEL_PAGE     = MakeMaterial(LockOn_Options.script_path.."../Scripts/IndicationTextures/fuel_frame.dds", GreenColor)

local RING_EGT_G      = MakeMaterial(LockOn_Options.script_path.."../Scripts/IndicationTextures/ring_egt.dds", GreenColor)
local RING_EGT_Y      = MakeMaterial(LockOn_Options.script_path.."../Scripts/IndicationTextures/ring_egt.dds", YellowColor)
local RING_EGT_R      = MakeMaterial(LockOn_Options.script_path.."../Scripts/IndicationTextures/ring_egt.dds", RedColor)

local RING_NEEDLE_G   = MakeMaterial(LockOn_Options.script_path.."../Scripts/IndicationTextures/ring_needle.dds", GreenColor)
local RING_NEEDLE_Y   = MakeMaterial(LockOn_Options.script_path.."../Scripts/IndicationTextures/ring_needle.dds", YellowColor)
local RING_NEEDLE_R   = MakeMaterial(LockOn_Options.script_path.."../Scripts/IndicationTextures/ring_needle.dds", RedColor)
local RING_NEEDLE_O   = MakeMaterial(LockOn_Options.script_path.."../Scripts/IndicationTextures/ring_needle.dds", OrangeColor)

local RING_RPM_G      = MakeMaterial(LockOn_Options.script_path.."../Scripts/IndicationTextures/ring_rpm.dds", GreenColor)
local RING_RPM_O      = MakeMaterial(LockOn_Options.script_path.."../Scripts/IndicationTextures/ring_rpm.dds", OrangeColor)

local RING_OIL_R      = MakeMaterial(LockOn_Options.script_path.."../Scripts/IndicationTextures/ring_oil.dds", RedColor)   
local RING_OIL_G      = MakeMaterial(LockOn_Options.script_path.."../Scripts/IndicationTextures/ring_oil.dds", GreenColor) 

local RING_HYD_G       = MakeMaterial(LockOn_Options.script_path.."../Scripts/IndicationTextures/ring_hyd.dds", GreenColor)
local RING_HYD_R       = MakeMaterial(LockOn_Options.script_path.."../Scripts/IndicationTextures/ring_hyd.dds", RedColor)  

local RING_LINE      = MakeMaterial(LockOn_Options.script_path.."../Scripts/IndicationTextures/ring_line.dds", GreenColor)
local RING_BOX       = MakeMaterial(LockOn_Options.script_path.."../Scripts/IndicationTextures/ring_box.dds", GreenColor)
local RING_CABIN     = MakeMaterial(LockOn_Options.script_path.."../Scripts/IndicationTextures/ring_cabin.dds", GreenColor)
local BOX_CABIN      = MakeMaterial(LockOn_Options.script_path.."../Scripts/IndicationTextures/mask_box.dds", GreenColor)
local MASK_BOX	     = MakeMaterial(LockOn_Options.script_path.."../Scripts/IndicationTextures/mask_box.dds", ScreenColor)
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
BGROUND.element_params 		= {"MFD_OPACITY","LMFD_ENG_PAGE"} --HOPE THIS WORKS G_OP_BACK
BGROUND.controllers			= {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1}}--ENGINE PAGE = 1}
BGROUND.level 				= 2
BGROUND.h_clip_relation     = h_clip_relations.COMPARE
vertices(BGROUND,3)
Add(BGROUND)
------------------------------------------------------------------------------------------------TEMPLATE
-- TEMPLATEENG                  = CreateElement "ceTexPoly"
-- TEMPLATEENG.name    			= "fuel"
-- TEMPLATEENG.material			= ENG_PAGE
-- TEMPLATEENG.change_opacity 	= false
-- TEMPLATEENG.collimated 		= false
-- TEMPLATEENG.isvisible 		= true
-- TEMPLATEENG.init_pos 		= {-4, 0, 0} --L-R,U-D,F-B
-- TEMPLATEENG.init_rot 	    = {0, 0, 0}
-- TEMPLATEENG.element_params 	= {"MFD_OPACITY","LMFD_ENG_PAGE"} --HOPE THIS WORKS G_OP_BACK
-- TEMPLATEENG.controllers		= {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1}}--ENGINE PAGE = 1}
-- TEMPLATEENG.level 		    = 2
-- TEMPLATEENG.h_clip_relation  = h_clip_relations.COMPARE
-- vertices(TEMPLATEENG,200)
-- Add(TEMPLATEENG)
------------------------------------------------------------------------------------------------RPM-RING-YELLOW-R
R_RING_RPM_G                    = CreateElement "ceTexPoly"
R_RING_RPM_G.name    			= "ring green"
R_RING_RPM_G.material			= RING_RPM_G
R_RING_RPM_G.change_opacity 	= false
R_RING_RPM_G.collimated 		= false
R_RING_RPM_G.isvisible 			= true
R_RING_RPM_G.init_pos 			= {0.35, 0.6, 0} --L-R,U-D,F-B
R_RING_RPM_G.init_rot 			= {0, 0, 0}
R_RING_RPM_G.element_params 	= {"MFD_OPACITY","R_RPM_COLOR","LMFD_ENG_PAGE"} 
R_RING_RPM_G.controllers		= {
                                    {"opacity_using_parameter",0},
                                    {"parameter_in_range",1,0.4,0.6},--
                                    {"parameter_in_range",2,0.9,1.1},--
                                   
                                }
R_RING_RPM_G.level 				    = 2
R_RING_RPM_G.h_clip_relation        = h_clip_relations.COMPARE
vertices(R_RING_RPM_G,0.3)
Add(R_RING_RPM_G)
------------------------------------------------------------------------------------------------RPM-RING-ORANGE-R
R_RING_RPM_O                    = CreateElement "ceTexPoly"
R_RING_RPM_O.name    			= "ring green"
R_RING_RPM_O.material			= RING_RPM_O
R_RING_RPM_O.change_opacity 	= false
R_RING_RPM_O.collimated 		= false
R_RING_RPM_O.isvisible 			= true
R_RING_RPM_O.init_pos 			= {0.35, 0.6, 0} --L-R,U-D,F-B
R_RING_RPM_O.init_rot 			= {0, 0, 0}
R_RING_RPM_O.element_params 	= {"MFD_OPACITY","R_RPM_COLOR","LMFD_ENG_PAGE"} 
R_RING_RPM_O.controllers		= {
                                    {"opacity_using_parameter",0},
                                    {"parameter_in_range",1,0.9,1.1},--
                                    {"parameter_in_range",2,0.9,1.1},--
                                   
                                }
R_RING_RPM_O.level 				    = 2
R_RING_RPM_O.h_clip_relation        = h_clip_relations.COMPARE
vertices(R_RING_RPM_O,0.3)
Add(R_RING_RPM_O)
------------------------------------------------------------------------------------------------RPM-NEEDLE-YELLOW-R
R_NEEDLE_RPM_G                     = CreateElement "ceTexPoly"
R_NEEDLE_RPM_G.name    			= "needle y"
R_NEEDLE_RPM_G.material			= RING_NEEDLE_G
R_NEEDLE_RPM_G.change_opacity 	    = false
R_NEEDLE_RPM_G.collimated 		    = false
R_NEEDLE_RPM_G.isvisible 	        = true
R_NEEDLE_RPM_G.init_pos 			= {0.35, 0.6, 0} --L-R,U-D,F-B
R_NEEDLE_RPM_G.init_rot 			= {0, 0, 0}
R_NEEDLE_RPM_G.element_params 	    = {"MFD_OPACITY","R_RPM_COLOR","LMFD_ENG_PAGE","RPM_R"} 
R_NEEDLE_RPM_G.controllers		    = {
                                        {"opacity_using_parameter",0},
                                        {"parameter_in_range",1,0.4,0.6},--Yellow
                                        {"parameter_in_range",2,0.9,1.1},--ENGINE PAGE = 1
                                        {"rotate_using_parameter",3, -0.04280,0}
                                    }
R_NEEDLE_RPM_G.level 				= 2
R_NEEDLE_RPM_G.h_clip_relation     = h_clip_relations.COMPARE
vertices(R_NEEDLE_RPM_G ,0.3)
Add(R_NEEDLE_RPM_G )
------------------------------------------------------------------------------------------------RPM-NEEDLE-ORANGE-R
R_NEEDLE_RPM_O                      = CreateElement "ceTexPoly"
R_NEEDLE_RPM_O .name    			= "needle y"
R_NEEDLE_RPM_O .material			= RING_NEEDLE_O
R_NEEDLE_RPM_O .change_opacity 	    = false
R_NEEDLE_RPM_O .collimated 		    = false
R_NEEDLE_RPM_O .isvisible 	        = true
R_NEEDLE_RPM_O .init_pos 			= {0.35, 0.6, 0} --L-R,U-D,F-B
R_NEEDLE_RPM_O .init_rot 			= {0, 0, 0}
R_NEEDLE_RPM_O .element_params 	    = {"MFD_OPACITY","R_RPM_COLOR","LMFD_ENG_PAGE","RPM_R"} 
R_NEEDLE_RPM_O .controllers		    = {
                                        {"opacity_using_parameter",0},
                                        {"parameter_in_range",1,0.9,1.1},--ORANGE
                                        {"parameter_in_range",2,0.9,1.1},--ENGINE PAGE = 1
                                        {"rotate_using_parameter",3, -0.04280,0}
                                    }
R_NEEDLE_RPM_O .level 				= 2
R_NEEDLE_RPM_O .h_clip_relation     = h_clip_relations.COMPARE
vertices(R_NEEDLE_RPM_O ,0.3)
Add(R_NEEDLE_RPM_O)
------------------------------------------------------------------------------------------------EGT-RING-GREEN
R_RING_EGT_G                    = CreateElement "ceTexPoly"
R_RING_EGT_G.name    			= "ring green"
R_RING_EGT_G.material			= RING_EGT_G
R_RING_EGT_G.change_opacity 	= false
R_RING_EGT_G.collimated 		= false
R_RING_EGT_G.isvisible 			= true
R_RING_EGT_G.init_pos 			= {0.35, 0.3, 0} --L-R,U-D,F-B
R_RING_EGT_G.init_rot 			= {0, 0, 0}
R_RING_EGT_G.element_params 	= {"MFD_OPACITY","R_EGT_COLOR","LMFD_ENG_PAGE"} 
R_RING_EGT_G.controllers		= {
                                    {"opacity_using_parameter",0},
                                    {"parameter_in_range",1,-0.1,0.1},--Green
                                    {"parameter_in_range",2,0.9,1.1},--ENGINE PAGE = 1
                                   
                                }
R_RING_EGT_G.level 				    = 2
R_RING_EGT_G.h_clip_relation        = h_clip_relations.COMPARE
vertices(R_RING_EGT_G,0.3)
Add(R_RING_EGT_G)
------------------------------------------------------------------------------------------------EGT-NEEDLE-GREEN
R_NEEDLE_EGT_G                      = CreateElement "ceTexPoly"
R_NEEDLE_EGT_G .name    			= "needle g"
R_NEEDLE_EGT_G .material			= RING_NEEDLE_G
R_NEEDLE_EGT_G .change_opacity 	    = false
R_NEEDLE_EGT_G .collimated 		    = false
R_NEEDLE_EGT_G .isvisible 	        = true
R_NEEDLE_EGT_G .init_pos 			= {0.35, 0.3, 0} --L-R,U-D,F-B
R_NEEDLE_EGT_G .init_rot 			= {0, 0, 0}
R_NEEDLE_EGT_G .element_params 	    = {"MFD_OPACITY","R_EGT_COLOR","LMFD_ENG_PAGE","EGT_R"} 
R_NEEDLE_EGT_G .controllers		    = {
                                        {"opacity_using_parameter",0},
                                        {"parameter_in_range",1,-0.1,0.1},--Green
                                        {"parameter_in_range",2, 0.9,1.1},--ENGINE PAGE = 1
                                        {"rotate_using_parameter",3, -0.00427,0}
                                    }
R_NEEDLE_EGT_G .level 				= 2
R_NEEDLE_EGT_G .h_clip_relation     = h_clip_relations.COMPARE
vertices(R_NEEDLE_EGT_G ,0.3)
Add(R_NEEDLE_EGT_G )
------------------------------------------------------------------------------------------------EGT-RING-YELLOW
R_RING_EGT_Y                    = CreateElement "ceTexPoly"
R_RING_EGT_Y.name    			= "ring y"
R_RING_EGT_Y.material			= RING_EGT_Y
R_RING_EGT_Y.change_opacity 	= false
R_RING_EGT_Y.collimated 		= false
R_RING_EGT_Y.isvisible 		    = true
R_RING_EGT_Y.init_pos 		    = {0.35, 0.3, 0} --L-R,U-D,F-B
R_RING_EGT_Y.init_rot 		    = {0, 0, 0}
R_RING_EGT_Y.element_params 	= {"MFD_OPACITY","R_EGT_COLOR","LMFD_ENG_PAGE"} 
R_RING_EGT_Y.controllers		= {
                                    {"opacity_using_parameter",0},
                                    {"parameter_in_range",1,0.4,0.6},--Green
                                    {"parameter_in_range",2,0.9,1.1},--ENGINE PAGE = 1
                                   
                                }
R_RING_EGT_Y.level 			     = 2
R_RING_EGT_Y.h_clip_relation     = h_clip_relations.COMPARE
vertices(R_RING_EGT_Y,0.3)
Add(R_RING_EGT_Y)
------------------------------------------------------------------------------------------------EGT-NEEDLE-YELLOW
R_NEEDLE_EGT_Y                      = CreateElement "ceTexPoly"
R_NEEDLE_EGT_Y .name    			= "needle y"
R_NEEDLE_EGT_Y .material			= RING_NEEDLE_Y
R_NEEDLE_EGT_Y .change_opacity 	    = false
R_NEEDLE_EGT_Y .collimated 		    = false
R_NEEDLE_EGT_Y .isvisible 	        = true
R_NEEDLE_EGT_Y .init_pos 			= {0.35, 0.3, 0} --L-R,U-D,F-B
R_NEEDLE_EGT_Y .init_rot 			= {0, 0, 0}
R_NEEDLE_EGT_Y .element_params 	    = {"MFD_OPACITY","R_EGT_COLOR","LMFD_ENG_PAGE","EGT_R"} 
R_NEEDLE_EGT_Y .controllers		    = {
                                        {"opacity_using_parameter",0},
                                        {"parameter_in_range",1,0.4,0.6},--Yellow
                                        {"parameter_in_range",2,0.9,1.1},--ENGINE PAGE = 1
                                        {"rotate_using_parameter",3, -0.00427,0}
                                    }
R_NEEDLE_EGT_Y .level 				= 2
R_NEEDLE_EGT_Y .h_clip_relation     = h_clip_relations.COMPARE
vertices(R_NEEDLE_EGT_Y ,0.3)
Add(R_NEEDLE_EGT_Y)
------------------------------------------------------------------------------------------------EGT-RING-RED
R_RING_EGT_R                    = CreateElement "ceTexPoly"
R_RING_EGT_R.name    			= "ring r"
R_RING_EGT_R.material			= RING_EGT_R
R_RING_EGT_R.change_opacity 	= false
R_RING_EGT_R.collimated 		= false
R_RING_EGT_R.isvisible 		    = true
R_RING_EGT_R.init_pos 		    = {0.35, 0.3, 0} --L-R,U-D,F-B
R_RING_EGT_R.init_rot 		    = {0, 0, 0}
R_RING_EGT_R.element_params 	= {"MFD_OPACITY","R_EGT_COLOR","LMFD_ENG_PAGE"} 
R_RING_EGT_R.controllers		= {
                                    {"opacity_using_parameter",0},
                                    {"parameter_in_range",1,0.9,1.1},-- RED
                                    {"parameter_in_range",2,0.9,1.1},--ENGINE PAGE = 1
                                   
                                }
R_RING_EGT_R.level 			     = 2
R_RING_EGT_R.h_clip_relation     = h_clip_relations.COMPARE
vertices(R_RING_EGT_R,0.3)
Add(R_RING_EGT_R)
------------------------------------------------------------------------------------------------EGT-NEEDLE-RED
R_NEEDLE_EGT_R                      = CreateElement "ceTexPoly"
R_NEEDLE_EGT_R.name    			    = "needle r"
R_NEEDLE_EGT_R.material			    = RING_NEEDLE_R
R_NEEDLE_EGT_R.change_opacity 	    = false
R_NEEDLE_EGT_R.collimated 		    = false
R_NEEDLE_EGT_R.isvisible 	        = true
R_NEEDLE_EGT_R.init_pos 			= {0.35, 0.3, 0} --L-R,U-D,F-B
R_NEEDLE_EGT_R.init_rot 			= {0, 0, 0}
R_NEEDLE_EGT_R.element_params 	    = {"MFD_OPACITY","R_EGT_COLOR","LMFD_ENG_PAGE","EGT_R"} 
R_NEEDLE_EGT_R.controllers		    = {
                                        {"opacity_using_parameter",0},
                                        {"parameter_in_range",1,0.9,1.1},--RED
                                        {"parameter_in_range",2,0.9,1.1},--ENGINE PAGE = 1
                                        {"rotate_using_parameter",3, -0.00427,0}
                                    }
R_NEEDLE_EGT_R.level 				= 2
R_NEEDLE_EGT_R.h_clip_relation      = h_clip_relations.COMPARE
vertices(R_NEEDLE_EGT_R ,0.3)
Add(R_NEEDLE_EGT_R)
------------------------------------------------------------------------------------------------OIL-RING-RED
R_RING_OIL_R                    = CreateElement "ceTexPoly"
R_RING_OIL_R.name    			= "ring green"
R_RING_OIL_R.material			= RING_OIL_R
R_RING_OIL_R.change_opacity 	= false
R_RING_OIL_R.collimated 		= false
R_RING_OIL_R.isvisible 			= true
R_RING_OIL_R.init_pos 			= {0.33, 0.03, 0} --L-R,U-D,F-B
R_RING_OIL_R.init_rot 			= {0, 0, 0}
R_RING_OIL_R.element_params 	= {"MFD_OPACITY","R_OIL_COLOR","LMFD_ENG_PAGE"} 
R_RING_OIL_R.controllers		= {
                                    {"opacity_using_parameter",0},
                                    {"parameter_in_range",1,0.9,1.1},
                                    {"parameter_in_range",2,0.9,1.1},--ENGINE PAGE = 1
                                   
                                }
R_RING_OIL_R.level 				    = 2
R_RING_OIL_R.h_clip_relation        = h_clip_relations.COMPARE
vertices(R_RING_OIL_R,0.20)
Add(R_RING_OIL_R)
------------------------------------------------------------------------------------------------OIL-NEEDLE-RED
R_NEEDLE_OIL_R                      = CreateElement "ceTexPoly"
R_NEEDLE_OIL_R.name    			    = "needle r"
R_NEEDLE_OIL_R.material			    = RING_NEEDLE_R
R_NEEDLE_OIL_R.change_opacity 	    = false
R_NEEDLE_OIL_R.collimated 		    = false
R_NEEDLE_OIL_R.isvisible 	        = true
R_NEEDLE_OIL_R.init_pos 			= {0.33, 0.03, 0} --L-R,U-D,F-B
R_NEEDLE_OIL_R.init_rot 			= {0, 0, 0}
R_NEEDLE_OIL_R.element_params 	    = {"MFD_OPACITY","R_OIL_COLOR","LMFD_ENG_PAGE","RPM_R"} 
R_NEEDLE_OIL_R.controllers		    = {
                                        {"opacity_using_parameter",0},
                                        {"parameter_in_range",1,0.9,1.1},--RED
                                        {"parameter_in_range",2,0.9,1.1},--ENGINE PAGE = 1
                                        {"rotate_using_parameter",3, -0.03926,0}
                                    }
R_NEEDLE_OIL_R.level 				= 2
R_NEEDLE_OIL_R.h_clip_relation      = h_clip_relations.COMPARE
vertices(R_NEEDLE_OIL_R,0.20)
Add(R_NEEDLE_OIL_R)
-------------------------------------------------------------------------------------------------OIL-RING-GREEN
R_RING_OIL_G                    = CreateElement "ceTexPoly"
R_RING_OIL_G.name    			= "ring green"
R_RING_OIL_G.material			= RING_OIL_G
R_RING_OIL_G.change_opacity 	= false
R_RING_OIL_G.collimated 		= false
R_RING_OIL_G.isvisible 			= true
R_RING_OIL_G.init_pos 			= {0.33, 0.03, 0} --L-R,U-D,F-B
R_RING_OIL_G.init_rot 			= {0, 0, 0}
R_RING_OIL_G.element_params 	= {"MFD_OPACITY","R_OIL_COLOR","LMFD_ENG_PAGE"} 
R_RING_OIL_G.controllers		= {
                                    {"opacity_using_parameter",0},
                                    {"parameter_in_range",1,-0.1,0.1},--Green
                                    {"parameter_in_range",2,0.9,1.1},--ENGINE PAGE = 1
                                   
                                }
R_RING_OIL_G.level 				    = 2
R_RING_OIL_G.h_clip_relation        = h_clip_relations.COMPARE
vertices(R_RING_OIL_G,0.20)
Add(R_RING_OIL_G)
------------------------------------------------------------------------------------------------OIL-NEEDLE-GREEN--RIGHT
R_NEEDLE_OIL_G                      = CreateElement "ceTexPoly"
R_NEEDLE_OIL_G.name    			    = "needle r"
R_NEEDLE_OIL_G.material			    = RING_NEEDLE_G
R_NEEDLE_OIL_G.change_opacity 	    = false
R_NEEDLE_OIL_G.collimated 		    = false
R_NEEDLE_OIL_G.isvisible 	        = true
R_NEEDLE_OIL_G.init_pos 			= {0.33, 0.03, 0} --L-R,U-D,F-B
R_NEEDLE_OIL_G.init_rot 			= {0, 0, 0}
R_NEEDLE_OIL_G.element_params 	    = {"MFD_OPACITY","R_OIL_COLOR","LMFD_ENG_PAGE","RPM_R"} 
R_NEEDLE_OIL_G.controllers		    = {
                                        {"opacity_using_parameter",0},
                                        {"parameter_in_range",1,-0.1,0.1},--green
                                        {"parameter_in_range",2,0.9,1.1},--ENGINE PAGE = 1
                                        {"rotate_using_parameter",3, -0.03926,0}
                                    }
R_NEEDLE_OIL_G.level 				= 2
R_NEEDLE_OIL_G.h_clip_relation      = h_clip_relations.COMPARE
vertices(R_NEEDLE_OIL_G ,0.20)
Add(R_NEEDLE_OIL_G)-----END RIGHT
------------------------------------------------------------------------------------------------RPM-RING-YELLOW-R
L_RING_RPM_G                    = CreateElement "ceTexPoly"
L_RING_RPM_G.name    			= "ring green"
L_RING_RPM_G.material			= RING_RPM_G
L_RING_RPM_G.change_opacity 	= false
L_RING_RPM_G.collimated 		= false
L_RING_RPM_G.isvisible 			= true
L_RING_RPM_G.init_pos 			= {-0.35, 0.6, 0} --L-R,U-D,F-B
L_RING_RPM_G.init_rot 			= {0, 0, 0}
L_RING_RPM_G.element_params 	= {"MFD_OPACITY","L_RPM_COLOR","LMFD_ENG_PAGE"} 
L_RING_RPM_G.controllers		= {
                                    {"opacity_using_parameter",0},
                                    {"parameter_in_range",1,0.4,0.6},--
                                    {"parameter_in_range",2,0.9,1.1},--
                                   
                                }
L_RING_RPM_G.level 				    = 2
L_RING_RPM_G.h_clip_relation        = h_clip_relations.COMPARE
vertices(L_RING_RPM_G,0.3)
Add(L_RING_RPM_G)
------------------------------------------------------------------------------------------------RPM-RING-ORANGE-R
L_RING_RPM_O                    = CreateElement "ceTexPoly"
L_RING_RPM_O.name    			= "ring green"
L_RING_RPM_O.material			= RING_RPM_O
L_RING_RPM_O.change_opacity 	= false
L_RING_RPM_O.collimated 		= false
L_RING_RPM_O.isvisible 			= true
L_RING_RPM_O.init_pos 			= {-0.35, 0.6, 0} --L-R,U-D,F-B
L_RING_RPM_O.init_rot 			= {0, 0, 0}
L_RING_RPM_O.element_params 	= {"MFD_OPACITY","L_RPM_COLOR","LMFD_ENG_PAGE"} 
L_RING_RPM_O.controllers		= {
                                    {"opacity_using_parameter",0},
                                    {"parameter_in_range",1,0.9,1.1},--
                                    {"parameter_in_range",2,0.9,1.1},--
                                   
                                }
L_RING_RPM_O.level 				    = 2
L_RING_RPM_O.h_clip_relation        = h_clip_relations.COMPARE
vertices(L_RING_RPM_O,0.3)
Add(L_RING_RPM_O)
------------------------------------------------------------------------------------------------RPM-NEEDLE-YELLOW-R
L_NEEDLE_RPM_G                     = CreateElement "ceTexPoly"
L_NEEDLE_RPM_G.name    			= "needle y"
L_NEEDLE_RPM_G.material			= RING_NEEDLE_G
L_NEEDLE_RPM_G.change_opacity 	    = false
L_NEEDLE_RPM_G.collimated 		    = false
L_NEEDLE_RPM_G.isvisible 	        = true
L_NEEDLE_RPM_G.init_pos 			= {-0.35, 0.6, 0} --L-R,U-D,F-B
L_NEEDLE_RPM_G.init_rot 			= {0, 0, 0}
L_NEEDLE_RPM_G.element_params 	    = {"MFD_OPACITY","L_RPM_COLOR","LMFD_ENG_PAGE","RPM_L"} 
L_NEEDLE_RPM_G.controllers		    = {
                                        {"opacity_using_parameter",0},
                                        {"parameter_in_range",1,0.4,0.6},--Yellow
                                        {"parameter_in_range",2,0.9,1.1},--ENGINE PAGE = 1
                                        {"rotate_using_parameter",3, -0.04280,0}
                                    }
L_NEEDLE_RPM_G.level 				= 2
L_NEEDLE_RPM_G.h_clip_relation     = h_clip_relations.COMPARE
vertices(L_NEEDLE_RPM_G ,0.3)
Add(L_NEEDLE_RPM_G )
------------------------------------------------------------------------------------------------RPM-NEEDLE-ORANGE-R
L_NEEDLE_RPM_O                      = CreateElement "ceTexPoly"
L_NEEDLE_RPM_O .name    			= "needle y"
L_NEEDLE_RPM_O .material			= RING_NEEDLE_O
L_NEEDLE_RPM_O .change_opacity 	    = false
L_NEEDLE_RPM_O .collimated 		    = false
L_NEEDLE_RPM_O .isvisible 	        = true
L_NEEDLE_RPM_O .init_pos 			= {-0.35, 0.6, 0} --L-R,U-D,F-B
L_NEEDLE_RPM_O .init_rot 			= {0, 0, 0}
L_NEEDLE_RPM_O .element_params 	    = {"MFD_OPACITY","L_RPM_COLOR","LMFD_ENG_PAGE","RPM_L"} 
L_NEEDLE_RPM_O .controllers		    = {
                                        {"opacity_using_parameter",0},
                                        {"parameter_in_range",1,0.9,1.1},--ORANGE
                                        {"parameter_in_range",2,0.9,1.1},--ENGINE PAGE = 1
                                        {"rotate_using_parameter",3, -0.04280,0}
                                    }
L_NEEDLE_RPM_O .level 				= 2
L_NEEDLE_RPM_O .h_clip_relation     = h_clip_relations.COMPARE
vertices(L_NEEDLE_RPM_O ,0.3)
Add(L_NEEDLE_RPM_O)
------------------------------------------------------------------------------------------------OIL-RING-RED--LEF
L_RING_OIL_R                    = CreateElement "ceTexPoly"
L_RING_OIL_R.name    			= "ring green"
L_RING_OIL_R.material			= RING_OIL_R
L_RING_OIL_R.change_opacity 	= false
L_RING_OIL_R.collimated 		= false
L_RING_OIL_R.isvisible 			= true
L_RING_OIL_R.init_pos 			= {-0.33, 0.03, 0} --L-R,U-D,F-B
L_RING_OIL_R.init_rot 			= {0, 0, 0}
L_RING_OIL_R.element_params 	= {"MFD_OPACITY","L_OIL_COLOR","LMFD_ENG_PAGE"} 
L_RING_OIL_R.controllers		= {
                                    {"opacity_using_parameter",0},
                                    {"parameter_in_range",1,0.9,1.1},
                                    {"parameter_in_range",2,0.9,1.1},--ENGINE PAGE = 1
                                   
                                }
L_RING_OIL_R.level 				    = 2
L_RING_OIL_R.h_clip_relation        = h_clip_relations.COMPARE
vertices(L_RING_OIL_R,0.2)
Add(L_RING_OIL_R)
------------------------------------------------------------------------------------------------OIL-NEEDLE-RED--LEFT
L_NEEDLE_OIL_L                      = CreateElement "ceTexPoly"
L_NEEDLE_OIL_L.name    			    = "needle r"
L_NEEDLE_OIL_L.material			    = RING_NEEDLE_R
L_NEEDLE_OIL_L.change_opacity 	    = false
L_NEEDLE_OIL_L.collimated 		    = false
L_NEEDLE_OIL_L.isvisible 	        = true
L_NEEDLE_OIL_L.init_pos 			= {-0.33, 0.03, 0} --L-R,U-D,F-B
L_NEEDLE_OIL_L.init_rot 			= {0, 0, 0}
L_NEEDLE_OIL_L.element_params 	    = {"MFD_OPACITY","L_OIL_COLOR","LMFD_ENG_PAGE","RPM_L"} 
L_NEEDLE_OIL_L.controllers		    = {
                                        {"opacity_using_parameter",0},
                                        {"parameter_in_range",1,0.9,1.1},--RED
                                        {"parameter_in_range",2,0.9,1.1},--ENGINE PAGE = 1
                                        {"rotate_using_parameter",3, -0.03926,0}
                                    }
L_NEEDLE_OIL_L.level 				= 2
L_NEEDLE_OIL_L.h_clip_relation      = h_clip_relations.COMPARE
vertices(L_NEEDLE_OIL_L,0.2)
Add(L_NEEDLE_OIL_L)
-------------------------------------------------------------------------------------------------OIL-RING-GREEN--LEFT
L_RING_OIL_G                    = CreateElement "ceTexPoly"
L_RING_OIL_G.name    			= "ring green"
L_RING_OIL_G.material			= RING_OIL_G
L_RING_OIL_G.change_opacity 	= false
L_RING_OIL_G.collimated 		= false
L_RING_OIL_G.isvisible 			= true
L_RING_OIL_G.init_pos 			= {-0.33, 0.03, 0} --L-R,U-D,F-B
L_RING_OIL_G.init_rot 			= {0, 0, 0}
L_RING_OIL_G.element_params 	= {"MFD_OPACITY","L_OIL_COLOR","LMFD_ENG_PAGE"} 
L_RING_OIL_G.controllers		= {
                                    {"opacity_using_parameter",0},
                                    {"parameter_in_range",1,-0.1,0.1},--Green
                                    {"parameter_in_range",2,0.9,1.1},--ENGINE PAGE = 1
                                   
                                }
L_RING_OIL_G.level 				    = 2
L_RING_OIL_G.h_clip_relation        = h_clip_relations.COMPARE
vertices(L_RING_OIL_G,0.2)
Add(L_RING_OIL_G)
------------------------------------------------------------------------------------------------OIL-NEEDLE-GREEN--LEFT
L_NEEDLE_OIL_G                      = CreateElement "ceTexPoly"
L_NEEDLE_OIL_G.name    			    = "needle r"
L_NEEDLE_OIL_G.material			    = RING_NEEDLE_G
L_NEEDLE_OIL_G.change_opacity 	    = false
L_NEEDLE_OIL_G.collimated 		    = false
L_NEEDLE_OIL_G.isvisible 	        = true
L_NEEDLE_OIL_G.init_pos 			= {-0.33, 0.03, 0} --L-R,U-D,F-B
L_NEEDLE_OIL_G.init_rot 			= {0, 0, 0}
L_NEEDLE_OIL_G.element_params 	    = {"MFD_OPACITY","L_OIL_COLOR","LMFD_ENG_PAGE","RPM_L"} 
L_NEEDLE_OIL_G.controllers		    = {
                                        {"opacity_using_parameter",0},
                                        {"parameter_in_range",1,-0.1,0.1},--green
                                        {"parameter_in_range",2,0.9,1.1},--ENGINE PAGE = 1
                                        {"rotate_using_parameter",3, -0.03926,0}
                                    }
L_NEEDLE_OIL_G.level 				= 2
L_NEEDLE_OIL_G.h_clip_relation      = h_clip_relations.COMPARE
vertices(L_NEEDLE_OIL_G ,0.2)
Add(L_NEEDLE_OIL_G)
------------------------------------------------------------------------------------------------EGT-RING-GREEN--LEFT
L_RING_EGT_G                    = CreateElement "ceTexPoly"
L_RING_EGT_G.name    			= "ring green"
L_RING_EGT_G.material			= RING_EGT_G
L_RING_EGT_G.change_opacity 	= false
L_RING_EGT_G.collimated 		= false
L_RING_EGT_G.isvisible 			= true
L_RING_EGT_G.init_pos 			= {-0.35, 0.3, 0} --L-R,U-D,F-B
L_RING_EGT_G.init_rot 			= {0, 0, 0}
L_RING_EGT_G.element_params 	= {"MFD_OPACITY","L_EGT_COLOR","LMFD_ENG_PAGE"} 
L_RING_EGT_G.controllers		= {
                                    {"opacity_using_parameter",0},
                                    {"parameter_in_range",1,-0.1,0.1},--Green
                                    {"parameter_in_range",2,0.9,1.1},--ENGINE PAGE = 1
                                   
                                }
L_RING_EGT_G.level 				    = 2
L_RING_EGT_G.h_clip_relation        = h_clip_relations.COMPARE
vertices(L_RING_EGT_G,0.3)
Add(L_RING_EGT_G)
------------------------------------------------------------------------------------------------EGT-NEEDLE-GREEN
L_NEEDLE_EGT_G                      = CreateElement "ceTexPoly"
L_NEEDLE_EGT_G .name    			= "needle g"
L_NEEDLE_EGT_G .material			= RING_NEEDLE_G
L_NEEDLE_EGT_G .change_opacity 	    = false
L_NEEDLE_EGT_G .collimated 		    = false
L_NEEDLE_EGT_G .isvisible 	        = true
L_NEEDLE_EGT_G .init_pos 			= {-0.35, 0.3, 0} --L-R,U-D,F-B
L_NEEDLE_EGT_G .init_rot 			= {0, 0, 0}
L_NEEDLE_EGT_G .element_params 	    = {"MFD_OPACITY","L_EGT_COLOR","LMFD_ENG_PAGE","EGT_L"} 
L_NEEDLE_EGT_G .controllers		    = {
                                        {"opacity_using_parameter",0},
                                        {"parameter_in_range",1,-0.1,0.1},--Green
                                        {"parameter_in_range",2, 0.9,1.1},--ENGINE PAGE = 1
                                        {"rotate_using_parameter",3, -0.00427,0}
                                    }
L_NEEDLE_EGT_G .level 				= 2
L_NEEDLE_EGT_G .h_clip_relation     = h_clip_relations.COMPARE
vertices(L_NEEDLE_EGT_G ,0.3)
Add(L_NEEDLE_EGT_G )
------------------------------------------------------------------------------------------------EGT-RING-YELLOW
L_RING_EGT_Y                    = CreateElement "ceTexPoly"
L_RING_EGT_Y.name    			= "ring y"
L_RING_EGT_Y.material			= RING_EGT_Y
L_RING_EGT_Y.change_opacity 	= false
L_RING_EGT_Y.collimated 		= false
L_RING_EGT_Y.isvisible 		    = true
L_RING_EGT_Y.init_pos 		    = {-0.35, 0.3, 0} --L-R,U-D,F-B
L_RING_EGT_Y.init_rot 		    = {0, 0, 0}
L_RING_EGT_Y.element_params 	= {"MFD_OPACITY","L_EGT_COLOR","LMFD_ENG_PAGE"} 
L_RING_EGT_Y.controllers		= {
                                    {"opacity_using_parameter",0},
                                    {"parameter_in_range",1,0.4,0.6},--Green
                                    {"parameter_in_range",2,0.9,1.1},--ENGINE PAGE = 1
                                   
                                }
L_RING_EGT_Y.level 			     = 2
L_RING_EGT_Y.h_clip_relation     = h_clip_relations.COMPARE
vertices(L_RING_EGT_Y,0.3)
Add(L_RING_EGT_Y)
------------------------------------------------------------------------------------------------EGT-NEEDLE-YELLOW
L_NEEDLE_EGT_Y                      = CreateElement "ceTexPoly"
L_NEEDLE_EGT_Y .name    			= "needle y"
L_NEEDLE_EGT_Y .material			= RING_NEEDLE_Y
L_NEEDLE_EGT_Y .change_opacity 	    = false
L_NEEDLE_EGT_Y .collimated 		    = false
L_NEEDLE_EGT_Y .isvisible 	        = true
L_NEEDLE_EGT_Y .init_pos 			= {-0.35, 0.3, 0} --L-R,U-D,F-B
L_NEEDLE_EGT_Y .init_rot 			= {0, 0, 0}
L_NEEDLE_EGT_Y .element_params 	    = {"MFD_OPACITY","L_EGT_COLOR","LMFD_ENG_PAGE","EGT_L"} 
L_NEEDLE_EGT_Y .controllers		    = {
                                        {"opacity_using_parameter",0},
                                        {"parameter_in_range",1,0.4,0.6},--Yellow
                                        {"parameter_in_range",2,0.9,1.1},--ENGINE PAGE = 1
                                        {"rotate_using_parameter",3, -0.00427,0}
                                    }
L_NEEDLE_EGT_Y .level 				= 2
L_NEEDLE_EGT_Y .h_clip_relation     = h_clip_relations.COMPARE
vertices(L_NEEDLE_EGT_Y ,0.3)
Add(L_NEEDLE_EGT_Y)
------------------------------------------------------------------------------------------------EGT-RING-RED
L_RING_EGT_R                    = CreateElement "ceTexPoly"
L_RING_EGT_R.name    			= "ring r"
L_RING_EGT_R.material			= RING_EGT_R
L_RING_EGT_R.change_opacity 	= false
L_RING_EGT_R.collimated 		= false
L_RING_EGT_R.isvisible 		    = true
L_RING_EGT_R.init_pos 		    = {-0.35, 0.3, 0} --L-R,U-D,F-B
L_RING_EGT_R.init_rot 		    = {0, 0, 0}
L_RING_EGT_R.element_params 	= {"MFD_OPACITY","L_EGT_COLOR","LMFD_ENG_PAGE"} 
L_RING_EGT_R.controllers		= {
                                    {"opacity_using_parameter",0},
                                    {"parameter_in_range",1,0.9,1.1},-- RED
                                    {"parameter_in_range",2,0.9,1.1},--ENGINE PAGE = 1
                                   
                                }
L_RING_EGT_R.level 			     = 2
L_RING_EGT_R.h_clip_relation     = h_clip_relations.COMPARE
vertices(L_RING_EGT_R,0.3)
Add(L_RING_EGT_R)
------------------------------------------------------------------------------------------------EGT-NEEDLE-RED
L_NEEDLE_EGT_R                      = CreateElement "ceTexPoly"
L_NEEDLE_EGT_R.name    			    = "needle r"
L_NEEDLE_EGT_R.material			    = RING_NEEDLE_R
L_NEEDLE_EGT_R.change_opacity 	    = false
L_NEEDLE_EGT_R.collimated 		    = false
L_NEEDLE_EGT_R.isvisible 	        = true
L_NEEDLE_EGT_R.init_pos 			= {-0.35, 0.3, 0} --L-R,U-D,F-B
L_NEEDLE_EGT_R.init_rot 			= {0, 0, 0}
L_NEEDLE_EGT_R.element_params 	    = {"MFD_OPACITY","L_EGT_COLOR","LMFD_ENG_PAGE","EGT_L"} 
L_NEEDLE_EGT_R.controllers		    = {
                                        {"opacity_using_parameter",0},
                                        {"parameter_in_range",1,0.9,1.1},--RED
                                        {"parameter_in_range",2,0.9,1.1},--ENGINE PAGE = 1
                                        {"rotate_using_parameter",3, -0.00427,0}
                                    }
L_NEEDLE_EGT_R.level 				= 2
L_NEEDLE_EGT_R.h_clip_relation      = h_clip_relations.COMPARE
vertices(L_NEEDLE_EGT_R ,0.3)
Add(L_NEEDLE_EGT_R)
------------------------------------------------------------------------------------------------NOZ-BOX-L
NOZBOXL                       = CreateElement "ceTexPoly"
NOZBOXL.name    			    = "box"
NOZBOXL.material			    = RING_BOX
NOZBOXL.change_opacity 	    = false
NOZBOXL.collimated 		    = false
NOZBOXL.isvisible 	        = true
NOZBOXL.init_pos 			    = {-0.34, -0.26, 0} --L-R,U-D,F-B
NOZBOXL.init_rot 			    = {0, 0, 0}
NOZBOXL.element_params 	    = {"MFD_OPACITY","LMFD_ENG_PAGE"} --HOPE THIS WORKS G_OP_BACK
NOZBOXL.controllers		    =   {
                                    {"opacity_using_parameter",0},
                                    {"parameter_in_range",1,0.9,1.1},--ENGINE PAGE = 1
                                }
NOZBOXL.level 				= 2
NOZBOXL.h_clip_relation       = h_clip_relations.COMPARE
vertices(NOZBOXL,0.2)
Add(NOZBOXL)
------------------------------------------------------------------------------------------------NOZ-BOX-R
NOZBOXR                       = CreateElement "ceTexPoly"
NOZBOXR.name    			    = "box"
NOZBOXR.material			    = RING_BOX
NOZBOXR.change_opacity 	    = false
NOZBOXR.collimated 		    = false
NOZBOXR.isvisible 	        = true
NOZBOXR.init_pos 			    = {0.34, -0.26, 0} --L-R,U-D,F-B
NOZBOXR.init_rot 			    = {0, 0, 0}
NOZBOXR.element_params 	    = {"MFD_OPACITY","LMFD_ENG_PAGE"} --HOPE THIS WORKS G_OP_BACK
NOZBOXR.controllers		    =   {
                                    {"opacity_using_parameter",0},
                                    {"parameter_in_range",1,0.9,1.1},--ENGINE PAGE = 1
                                }
NOZBOXR.level 				= 2
NOZBOXR.h_clip_relation       = h_clip_relations.COMPARE
vertices(NOZBOXR,0.2)
Add(NOZBOXR)
------------------------------------------------------------------------------------------------NOZ-BOX-R-LINE
NOZBOXRL                       = CreateElement "ceTexPoly"
NOZBOXRL.name    			    = "box"
NOZBOXRL.material			    = RING_LINE
NOZBOXRL.change_opacity 	    = false
NOZBOXRL.collimated 		    = false
NOZBOXRL.isvisible 	        = true
NOZBOXRL.init_pos 			    = {0.35, -0.18, 0} --L-R,U-D,F-B
NOZBOXRL.init_rot 			    = {180, 0, 0}
NOZBOXRL.element_params 	    = {"MFD_OPACITY","LMFD_ENG_PAGE"} --HOPE THIS WORKS G_OP_BACK
NOZBOXRL.controllers		    =   {
                                    {"opacity_using_parameter",0},
                                    {"parameter_in_range",1,0.9,1.1},--ENGINE PAGE = 1
                                }
NOZBOXRL.level 				= 2
NOZBOXRL.h_clip_relation       = h_clip_relations.COMPARE
vertices(NOZBOXRL,0.225)
Add(NOZBOXRL)
------------------------------------------------------------------------------------------------NOZ-BOX-L-LINE
NOZBOXLL                       = CreateElement "ceTexPoly"
NOZBOXLL.name    			    = "box"
NOZBOXLL.material			    = RING_LINE
NOZBOXLL.change_opacity 	    = false
NOZBOXLL.collimated 		    = false
NOZBOXLL.isvisible 	        = true
NOZBOXLL.init_pos 			    = {-0.35, -0.18, 0} --L-R,U-D,F-B
NOZBOXLL.init_rot 			    = {0, 0, 0}
NOZBOXLL.element_params 	    = {"MFD_OPACITY","LMFD_ENG_PAGE"} --HOPE THIS WORKS G_OP_BACK
NOZBOXLL.controllers		    =   {
                                    {"opacity_using_parameter",0},
                                    {"parameter_in_range",1,0.9,1.1},--ENGINE PAGE = 1
                                }
NOZBOXLL.level 				= 2
NOZBOXLL.h_clip_relation       = h_clip_relations.COMPARE
vertices(NOZBOXLL,0.225)
Add(NOZBOXLL)
----------------------------------------------------------------------------------------------------------------FUEL FLOW NUMBERS RIGHT
NOZR		                = CreateElement "ceStringPoly"
NOZR.name				    = "rad Alt"
NOZR.material			    = UFD_GRN
NOZR.init_pos			    = {0.40,-0.29, 0} --L-R,U-D,F-B
NOZR.alignment			    = "RightCenter"
NOZR.stringdefs			    = {0.005, 0.005, 0, 0.0} --either 004 or 005
NOZR.additive_alpha		    = true
NOZR.collimated			    = false
NOZR.isdraw				    = true	
NOZR.use_mipfilter		    = true
NOZR.h_clip_relation		= h_clip_relations.COMPARE
NOZR.level				    = 2
NOZR.element_params		    = {"MFD_OPACITY","R_NOZZLE_POS","LMFD_ENG_PAGE"}
NOZR.formats				= {"%02.0f"}--= {"%02.0f"}
NOZR.controllers			= {{"opacity_using_parameter",0},{"text_using_parameter",1,0},{"parameter_in_range",2,0.9,1.1}}
Add(NOZR)
----------------------------------------------------------------------------------------------------------------FUEL FLOW NUMBERS RIGHT
NOZL		                = CreateElement "ceStringPoly"
NOZL.name				    = "rad Alt"
NOZL.material			    = UFD_GRN
NOZL.init_pos			    = {-0.28,-0.29, 0} --L-R,U-D,F-B
NOZL.alignment			    = "RightCenter"
NOZL.stringdefs			    = {0.005, 0.005, 0, 0.0} --either 004 or 005
NOZL.additive_alpha		    = true
NOZL.collimated			    = false
NOZL.isdraw				    = true	
NOZL.use_mipfilter		    = true
NOZL.h_clip_relation		= h_clip_relations.COMPARE
NOZL.level				    = 2
NOZL.element_params		    = {"MFD_OPACITY","L_NOZZLE_POS","LMFD_ENG_PAGE"}
NOZL.formats				= {"%02.0f"}--= {"%02.0f"}
NOZL.controllers			= {{"opacity_using_parameter",0},{"text_using_parameter",1,0},{"parameter_in_range",2,0.9,1.1}}
Add(NOZL)
----------------------------------------------------------------------------------------------------------------FUEL FLOW NUMBERS RIGHT
FUELFR		                = CreateElement "ceStringPoly"
FUELFR.name				    = "rad Alt"
FUELFR.material			    = UFD_GRN
FUELFR.init_pos			    = {0.34, -0.43, 0} --L-R,U-D,F-B
FUELFR.alignment			= "CenterCenter"
FUELFR.stringdefs			= {0.005, 0.005, 0, 0.0} --either 004 or 005
FUELFR.additive_alpha		= true
FUELFR.collimated			= false
FUELFR.isdraw				= true	
FUELFR.use_mipfilter		= true
FUELFR.h_clip_relation		= h_clip_relations.COMPARE
FUELFR.level				= 2
FUELFR.element_params		= {"MFD_OPACITY","R_FF_VALUE","LMFD_ENG_PAGE"}
FUELFR.formats				= {"%02.0f"}--= {"%02.0f"}
FUELFR.controllers			= {{"opacity_using_parameter",0},{"text_using_parameter",1,0},{"parameter_in_range",2,0.9,1.1}}
Add(FUELFR)
----------------------------------------------------------------------------------------------------------------FUEL FLOW NUMBERS LEFT
FUELFL		                = CreateElement "ceStringPoly"
FUELFL.name				    = "rad Alt"
FUELFL.material			    = UFD_GRN
FUELFL.init_pos			    = {-0.34, -0.43, 0} --L-R,U-D,F-B
FUELFL.alignment			= "CenterCenter"
FUELFL.stringdefs			= {0.005, 0.005, 0, 0.0} --either 004 or 005
FUELFL.additive_alpha		= true
FUELFL.collimated			= false
FUELFL.isdraw				= true	
FUELFL.use_mipfilter		= true
FUELFL.h_clip_relation		= h_clip_relations.COMPARE
FUELFL.level				= 2
FUELFL.element_params		= {"MFD_OPACITY","L_FF_VALUE","LMFD_ENG_PAGE"}
FUELFL.formats				= {"%02.0f"}--= {"%02.0f"}
FUELFL.controllers			= {{"opacity_using_parameter",0},{"text_using_parameter",1,0},{"parameter_in_range",2,0.9,1.1}}
Add(FUELFL)
----------------------------------------------------------------------------------------------------------------CHK
----RPM YELLOW TEXT
    --RPM_Y 					    = CreateElement "ceStringPoly"
    --RPM_Y.name 				    = "menu"
    --RPM_Y.material 			    = UFD_YEL
    --RPM_Y.value 				= "RPM"
    --RPM_Y.stringdefs 		    = {0.0050, 0.0050, 0.0004, 0.001}
    --RPM_Y.alignment 			= "CenterCenter"
    --RPM_Y.formats 			    = {"%s"}
    --RPM_Y.h_clip_relation       = h_clip_relations.COMPARE
    --RPM_Y.level 				= 2
    --RPM_Y.init_pos 			    = {0, 0.6, 0}
    --RPM_Y.init_rot 			    = {0, 0, 0}
    --RPM_Y.element_params 	    = {"MFD_OPACITY","LMFD_ENG_PAGE","L_RPM_COLOR"}
    --RPM_Y.controllers		    =   {
    --                                    {"opacity_using_parameter",0},
    --                                    {"parameter_in_range",1,0.9,1.1},--ENGINE PAGE = 0
    --                                    {"parameter_in_range",2,0.4,0.6},
    --                                }
    --Add(RPM_Y)
--RPM ORANGE TEXT
RPM_O 					    = CreateElement "ceStringPoly"
RPM_O.name 				    = "menu"
RPM_O.material 			    = UFD_GRN
RPM_O.value 				= "RPM"
RPM_O.stringdefs 		    = {0.0050, 0.0050, 0.0004, 0.001}
RPM_O.alignment 			= "CenterCenter"
RPM_O.formats 			    = {"%s"}
RPM_O.h_clip_relation       = h_clip_relations.COMPARE
RPM_O.level 				= 2
RPM_O.init_pos 			    = {0, 0.6, 0}
RPM_O.init_rot 			    = {0, 0, 0}
RPM_O.element_params 	    = {"MFD_OPACITY","LMFD_ENG_PAGE"} --"L_RPM_COLOR"
RPM_O.controllers		    =   {
                                    {"opacity_using_parameter",0},
                                    {"parameter_in_range",1,0.9,1.1},--ENGINE PAGE = 0
                                }
Add(RPM_O)
--EGT GREEN TEXT
EGT_G 					    = CreateElement "ceStringPoly"
EGT_G.name 				    = "menu"
EGT_G.material 			    = UFD_GRN
EGT_G.value 				= "EGT"
EGT_G.stringdefs 		    = {0.0050, 0.0050, 0.0004, 0.001}
EGT_G.alignment 			= "CenterCenter"
EGT_G.formats 			    = {"%s"}
EGT_G.h_clip_relation       = h_clip_relations.COMPARE
EGT_G.level 				= 2
EGT_G.init_pos 			    = {0, 0.3, 0}
EGT_G.init_rot 			    = {0, 0, 0}
EGT_G.element_params 	    = {"MFD_OPACITY","LMFD_ENG_PAGE"} -- "L_EGT_COLOR"
EGT_G.controllers		    =   {
                                    {"opacity_using_parameter",0},
                                    {"parameter_in_range",1,0.9,1.1},--ENGINE PAGE = 0
                                }
Add(EGT_G)
----EGT YELLOW TEXT
    --EGT_Y 					    = CreateElement "ceStringPoly"
    --EGT_Y.name 				    = "menu"
    --EGT_Y.material 			    = UFD_YEL
    --EGT_Y.value 				= "EGT"
    --EGT_Y.stringdefs 		    = {0.0050, 0.0050, 0.0004, 0.001}
    --EGT_Y.alignment 			= "CenterCenter"
    --EGT_Y.formats 			    = {"%s"}
    --EGT_Y.h_clip_relation       = h_clip_relations.COMPARE
    --EGT_Y.level 				= 2
    --EGT_Y.init_pos 			    = {0, 0.3, 0}
    --EGT_Y.init_rot 			    = {0, 0, 0}
    --EGT_Y.element_params 	    = {"MFD_OPACITY","LMFD_ENG_PAGE","L_EGT_COLOR"}
    --EGT_Y.controllers		    =   {
    --                                    {"opacity_using_parameter",0},
    --                                    {"parameter_in_range",1,0.9,1.1},--ENGINE PAGE = 0
    --                                    {"parameter_in_range",2,0.4,0.6},
    --                                }
    --Add(EGT_Y)
    ----EGT RED TEXT
    --EGT_R 					    = CreateElement "ceStringPoly"
    --EGT_R.name 				    = "menu"
    --EGT_R.material 			    = UFD_RED
    --EGT_R.value 				= "EGT"
    --EGT_R.stringdefs 		    = {0.0050, 0.0050, 0.0004, 0.001}
    --EGT_R.alignment 			= "CenterCenter"
    --EGT_R.formats 			    = {"%s"}
    --EGT_R.h_clip_relation       = h_clip_relations.COMPARE
    --EGT_R.level 				= 2
    --EGT_R.init_pos 			    = {0, 0.3, 0}
    --EGT_R.init_rot 			    = {0, 0, 0}
    --EGT_R.element_params 	    = {"MFD_OPACITY","LMFD_ENG_PAGE","L_EGT_COLOR"}
    --EGT_R.controllers		    =   {
    --                                    {"opacity_using_parameter",0},
    --                                    {"parameter_in_range",1,0.9,1.1},--ENGINE PAGE = 0
    --                                    {"parameter_in_range",2,0.9,1.1},
    --                                }
    --Add(EGT_R)
--OIL GREEN TEXT
OIL_G_L 					    = CreateElement "ceStringPoly"
OIL_G_L.name 				    = "menu"
OIL_G_L.material 			    = UFD_GRN
OIL_G_L.value 				    = "OIL"
OIL_G_L.stringdefs 		         = {0.0050, 0.0050, 0.0004, 0.001}
OIL_G_L.alignment 			    = "CenterCenter"
OIL_G_L.formats 			    = {"%s"}
OIL_G_L.h_clip_relation         = h_clip_relations.COMPARE
OIL_G_L.level 				    = 2
OIL_G_L.init_pos 			    = {0, 0.03, 0}
OIL_G_L.init_rot 			    = {0, 0, 0}
OIL_G_L.element_params 	        = {"MFD_OPACITY","LMFD_ENG_PAGE"}
OIL_G_L.controllers		        =   {
                                    {"opacity_using_parameter",0},
                                    {"parameter_in_range",1,0.9,1.1},--ENGINE PAGE = 0
                                    --{"parameter_in_range",2,-0.1,0.1},
                                }
Add(OIL_G_L)
--[[
    --OIL RED TEXT
    OIL_R_L 					    = CreateElement "ceStringPoly"
    OIL_R_L.name 				    = "menu"
    OIL_R_L.material 			    = UFD_RED
    OIL_R_L.value 				= "OIL"
    OIL_R_L.stringdefs 		    = {0.0050, 0.0050, 0.0004, 0.001}
    OIL_R_L.alignment 			= "CenterCenter"
    OIL_R_L.formats 			    = {"%s"}
    OIL_R_L.h_clip_relation       = h_clip_relations.COMPARE
    OIL_R_L.level 				= 2
    OIL_R_L.init_pos 			    = {0, 3, 0}
    OIL_R_L.init_rot 			    = {0, 0, 0}
    OIL_R_L.element_params 	    = {"MFD_OPACITY","LMFD_ENG_PAGE","L_OIL_COLOR"}
    OIL_R_L.controllers		    =   {
                                        {"opacity_using_parameter",0},
                                        {"parameter_in_range",1,0.9,1.1},--ENGINE PAGE = 0
                                        {"parameter_in_range",2,0.9,1.1},
                                    }
    Add(OIL_R_L)--end left side
    --OIL GREEN TEXT
    OIL_G_R 					    = CreateElement "ceStringPoly"
    OIL_G_R.name 				    = "menu"
    OIL_G_R.material 			    = UFD_GRN
    OIL_G_R.value 				= "OIL"
    OIL_G_R.stringdefs 		    = {0.0050, 0.0050, 0.0004, 0.001}
    OIL_G_R.alignment 			= "CenterCenter"
    OIL_G_R.formats 			    = {"%s"}
    OIL_G_R.h_clip_relation       = h_clip_relations.COMPARE
    OIL_G_R.level 				= 2
    OIL_G_R.init_pos 			    = {0, 3, 0}
    OIL_G_R.init_rot 			    = {0, 0, 0}
    OIL_G_R.element_params 	    = {"MFD_OPACITY","LMFD_ENG_PAGE","R_OIL_COLOR"}
    OIL_G_R.controllers		    =   {
                                        {"opacity_using_parameter",0},
                                        {"parameter_in_range",1,0.9,1.1},--ENGINE PAGE = 0
                                        {"parameter_in_range",2,-0.1,0.1},
                                    }
    Add(OIL_G_R)
    --OIL RED TEXT
    OIL_R_R 					    = CreateElement "ceStringPoly"
    OIL_R_R.name 				    = "menu"
    OIL_R_R.material 			    = UFD_RED
    OIL_R_R.value 				    = "OIL"
    OIL_R_R.stringdefs 		        = {0.0050, 0.0050, 0.0004, 0.001}
    OIL_R_R.alignment 			    = "CenterCenter"
    OIL_R_R.formats 			    = {"%s"}
    OIL_R_R.h_clip_relation         = h_clip_relations.COMPARE
    OIL_R_R.level 				    = 2
    OIL_R_R.init_pos 			    = {0, 3, 0}
    OIL_R_R.init_rot 			    = {0, 0, 0}
    OIL_R_R.element_params 	        = {"MFD_OPACITY","LMFD_ENG_PAGE","R_OIL_COLOR"}
    OIL_R_R.controllers		        =   {
                                        {"opacity_using_parameter",0},
                                        {"parameter_in_range",1,0.9,1.1},--ENGINE PAGE = 0
                                        {"parameter_in_range",2,0.9,1.1},
                                    }
    Add(OIL_R_R)
]]
--NOZ TEXT
NOZ 					    = CreateElement "ceStringPoly"
NOZ.name 				    = "menu"
NOZ.material 			    = UFD_GRN
NOZ.value 				    = "NOZ"
NOZ.stringdefs 		        = {0.0050, 0.0050, 0.0004, 0.001}
NOZ.alignment 			    = "CenterCenter"
NOZ.formats 			    = {"%s"}
NOZ.h_clip_relation          = h_clip_relations.COMPARE
NOZ.level 				    = 2
NOZ.init_pos 			    = {0,-0.26, 0}
NOZ.init_rot 			    = {0, 0, 0}
NOZ.element_params 	        = {"MFD_OPACITY","LMFD_ENG_PAGE"}
NOZ.controllers		        =   {
                                            {"opacity_using_parameter",0},
                                            {"parameter_in_range",1,0.9,1.1},--ENGINE PAGE = 0
						                }
Add(NOZ)
--FF TEXT
FF 					    = CreateElement "ceStringPoly"
FF.name 				    = "menu"
FF.material 			    = UFD_GRN
FF.value 				    = "FF"
FF.stringdefs 		        = {0.0050, 0.0050, 0.0004, 0.001}
FF.alignment 			    = "CenterCenter"
FF.formats 			        = {"%s"}
FF.h_clip_relation          = h_clip_relations.COMPARE
FF.level 				    = 2
FF.init_pos 			    = {0,-0.43, 0}
FF.init_rot 			    = {0, 0, 0}
FF.element_params 	        = {"MFD_OPACITY","LMFD_ENG_PAGE"}
FF.controllers		        =   {
                                            {"opacity_using_parameter",0},
                                            {"parameter_in_range",1,0.9,1.1},--ENGINE PAGE = 0
						                }
Add(FF)
--CABIN PRESS TEXT
CABIN 					    = CreateElement "ceStringPoly"
CABIN.name 				    = "menu"
CABIN.material 			    = UFD_GRN
CABIN.value 				    = "CABIN PRESS"
CABIN.stringdefs 		        = {0.0050, 0.0050, 0.0004, 0.001}
CABIN.alignment 			    = "CenterCenter"
CABIN.formats 			        = {"%s"}
CABIN.h_clip_relation          = h_clip_relations.COMPARE
CABIN.level 				    = 2
CABIN.init_pos 			    = {0.45,-0.63, 0}
CABIN.init_rot 			    = {0, 0, 0}
CABIN.element_params 	        = {"MFD_OPACITY","LMFD_ENG_PAGE"}
CABIN.controllers		        =   {
                                            {"opacity_using_parameter",0},
                                            {"parameter_in_range",1,0.9,1.1},--ENGINE PAGE = 0
						                }
Add(CABIN)
--HYD TEXT
HYD 					    = CreateElement "ceStringPoly"
HYD.name 				    = "menu"
HYD.material 			    = UFD_GRN
HYD.value 				    = "HYD"
HYD.stringdefs 		        = {0.0050, 0.0050, 0.0004, 0.001}
HYD.alignment 			    = "CenterCenter"
HYD.formats 			    = {"%s"}
HYD.h_clip_relation         = h_clip_relations.COMPARE
HYD.level 				    = 2
HYD.init_pos 			    = {-0.43,-0.68, 0}
HYD.init_rot 			    = {0, 0, 0}
HYD.element_params 	        = {"MFD_OPACITY","LMFD_ENG_PAGE"}
HYD.controllers		        =   {
                                    {"opacity_using_parameter",0},
                                    {"parameter_in_range",1,0.9,1.1},--ENGINE PAGE = 0
						        }
Add(HYD)
--MENU TEXT
MENUTEXT 					    = CreateElement "ceStringPoly"
MENUTEXT.name 				    = "menu"
MENUTEXT.material 			    = UFD_FONT
MENUTEXT.value 				    = "MENU"
MENUTEXT.stringdefs 		        = {0.0050, 0.0050, 0.0004, 0.001}
MENUTEXT.alignment 			    = "CenterCenter"
MENUTEXT.formats 			    = {"%s"}
MENUTEXT.h_clip_relation         = h_clip_relations.COMPARE
MENUTEXT.level 				    = 2
MENUTEXT.init_pos 			    = {-0.565, 0.92, 0}
MENUTEXT.init_rot 			    = {0, 0, 0}
MENUTEXT.element_params 	        = {"MFD_OPACITY","LMFD_ENG_PAGE"}
MENUTEXT.controllers		        =   {
                                            {"opacity_using_parameter",0},
                                            {"parameter_in_range",1,0.9,1.1},--ENGINE PAGE = 0
						                }
Add(MENUTEXT)
------------------------------------------------------------------------------------------------HYD-RING-RED--LEFT
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
MENU_TEXT1.element_params 	        = {"MFD_OPACITY","LMFD_ENG_PAGE"}
MENU_TEXT1.controllers		        =   {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1},}
Add(MENU_TEXT1)
--------------------------------------------------------------------------------------------------- NAV
MENU_TEXT2 					        = CreateElement "ceStringPoly"
MENU_TEXT2.name 				    = "menu"
MENU_TEXT2.material 			    = UFD_GRN
MENU_TEXT2.value 				    = "FCS"
MENU_TEXT2.stringdefs 		        = {0.0050, 0.0050, 0.0004, 0.001}
MENU_TEXT2.alignment 			    = "CenterCenter"
MENU_TEXT2.formats 			        = {"%s"}
MENU_TEXT2.h_clip_relation          = h_clip_relations.COMPARE
MENU_TEXT2.level 				    = 2
MENU_TEXT2.init_pos 			        = {0.265, 0.92, 0}
MENU_TEXT2.init_rot 			        = {0, 0, 0}
MENU_TEXT2.element_params 	        = {"MFD_OPACITY","LMFD_ENG_PAGE"}
MENU_TEXT2.controllers		        =   {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1},}
Add(MENU_TEXT2)
--------------------------------------------------------------------------------------------------- NAV
MENU_TEXT3 					        = CreateElement "ceStringPoly"
MENU_TEXT3.name 				    = "menu"
MENU_TEXT3.material 			    = UFD_GRN
MENU_TEXT3.value 				    = "BAY"
MENU_TEXT3.stringdefs 		        = {0.0050, 0.0050, 0.0004, 0.001}
MENU_TEXT3.alignment 			    = "CenterCenter"
MENU_TEXT3.formats 			        = {"%s"}
MENU_TEXT3.h_clip_relation          = h_clip_relations.COMPARE
MENU_TEXT3.level 				    = 2
MENU_TEXT3.init_pos 			        = {0, 0.92, 0}
MENU_TEXT3.init_rot 			        = {0, 0, 0}
MENU_TEXT3.element_params 	        = {"MFD_OPACITY","LMFD_ENG_PAGE"}
MENU_TEXT3.controllers		        =   {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1},}
Add(MENU_TEXT3)
-----------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------- NAV
MENU_TEXT4 					        = CreateElement "ceStringPoly"
MENU_TEXT4.name 				    = "menu"
MENU_TEXT4.material 			    = UFD_GRN
MENU_TEXT4.value 				    = "FUEL"
MENU_TEXT4.stringdefs 		        = {0.0050, 0.0050, 0.0004, 0.001}
MENU_TEXT4.alignment 			    = "CenterCenter"
MENU_TEXT4.formats 			        = {"%s"}
MENU_TEXT4.h_clip_relation          = h_clip_relations.COMPARE
MENU_TEXT4.level 				    = 2
MENU_TEXT4.init_pos 			        = {0.565, 0.92, 0}
MENU_TEXT4.init_rot 			        = {0, 0, 0}
MENU_TEXT4.element_params 	        = {"MFD_OPACITY","LMFD_ENG_PAGE"}
MENU_TEXT4.controllers		        =   {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1},}
Add(MENU_TEXT4)
----------------------------------------------------------------------------------------------------------
L_RING_HYD_R                    = CreateElement "ceTexPoly"
L_RING_HYD_R.name    			= "ring green"
L_RING_HYD_R.material			= RING_HYD_R
L_RING_HYD_R.change_opacity 	= false
L_RING_HYD_R.collimated 		= false
L_RING_HYD_R.isvisible 			= true
L_RING_HYD_R.init_pos 			= {-0.66, -0.68, 0} --L-R,U-D,F-B
L_RING_HYD_R.init_rot 			= {0, 0, 0}
L_RING_HYD_R.element_params 	= {"MFD_OPACITY","L_HYD_COLOR","LMFD_ENG_PAGE"} 
L_RING_HYD_R.controllers		= {
                                    {"opacity_using_parameter",0},
                                    {"parameter_in_range",1,0.9,1.1},
                                    {"parameter_in_range",2,0.9,1.1},--ENGINE PAGE = 1
                                   
                                }
L_RING_HYD_R.level 				    = 2
L_RING_HYD_R.h_clip_relation        = h_clip_relations.COMPARE
vertices(L_RING_HYD_R,0.20)
Add(L_RING_HYD_R)
------------------------------------------------------------------------------------------------OIL-NEEDLE-RED--LEFT
L_NEEDLE_HYD_R                      = CreateElement "ceTexPoly"
L_NEEDLE_HYD_R.name    			    = "needle r"
L_NEEDLE_HYD_R.material			    = RING_NEEDLE_R
L_NEEDLE_HYD_R.change_opacity 	    = false
L_NEEDLE_HYD_R.collimated 		    = false
L_NEEDLE_HYD_R.isvisible 	        = true
L_NEEDLE_HYD_R.init_pos 			= {-0.66, -0.68, 0} --L-R,U-D,F-B
L_NEEDLE_HYD_R.init_rot 			= {0, 0, 0}
L_NEEDLE_HYD_R.element_params 	    = {"MFD_OPACITY","L_HYD_COLOR","LMFD_ENG_PAGE","L_HYD_VALUE"} 
L_NEEDLE_HYD_R.controllers		    = {
                                        {"opacity_using_parameter",0},
                                        {"parameter_in_range",1,0.9,1.1},--RED
                                        {"parameter_in_range",2,0.9,1.1},--ENGINE PAGE = 1
                                        {"rotate_using_parameter",3, -0.00094,0}
                                    }
L_NEEDLE_HYD_R.level 				= 2
L_NEEDLE_HYD_R.h_clip_relation      = h_clip_relations.COMPARE
vertices(L_NEEDLE_HYD_R,0.2)
Add(L_NEEDLE_HYD_R)
-------------------------------------------------------------------------------------------------HDY-RING-GREEN--LEFT
L_RING_HYD_G                    = CreateElement "ceTexPoly"
L_RING_HYD_G.name    			= "ring green"
L_RING_HYD_G.material			= RING_HYD_G
L_RING_HYD_G.change_opacity 	= false
L_RING_HYD_G.collimated 		= false
L_RING_HYD_G.isvisible 			= true
L_RING_HYD_G.init_pos 			= {-0.66, -0.68, 0} --L-R,U-D,F-B
L_RING_HYD_G.init_rot 			= {0, 0, 0}
L_RING_HYD_G.element_params 	= {"MFD_OPACITY","L_HYD_COLOR","LMFD_ENG_PAGE"} 
L_RING_HYD_G.controllers		= {
                                    {"opacity_using_parameter",0},
                                    {"parameter_in_range",1,-0.1,0.1},--Green
                                    {"parameter_in_range",2,0.9,1.1},--ENGINE PAGE = 1
                                   
                                }
L_RING_HYD_G.level 				    = 2
L_RING_HYD_G.h_clip_relation        = h_clip_relations.COMPARE
vertices(L_RING_HYD_G,0.20)
Add(L_RING_HYD_G)
------------------------------------------------------------------------------------------------HDY-NEEDLE-GREEN--LEFT
L_NEEDLE_HYD_G                      = CreateElement "ceTexPoly"
L_NEEDLE_HYD_G.name    			    = "needle r"
L_NEEDLE_HYD_G.material			    = RING_NEEDLE_G
L_NEEDLE_HYD_G.change_opacity 	    = false
L_NEEDLE_HYD_G.collimated 		    = false
L_NEEDLE_HYD_G.isvisible 	        = true
L_NEEDLE_HYD_G.init_pos 			= {-0.66, -0.68, 0} --L-R,U-D,F-B
L_NEEDLE_HYD_G.init_rot 			= {0, 0, 0}
L_NEEDLE_HYD_G.element_params 	    = {"MFD_OPACITY","L_HYD_COLOR","LMFD_ENG_PAGE","L_HYD_VALUE"} 
L_NEEDLE_HYD_G.controllers		    = {
                                        {"opacity_using_parameter",0},
                                        {"parameter_in_range",1,-0.1,0.1},--green
                                        {"parameter_in_range",2,0.9,1.1},--ENGINE PAGE = 1
                                        {"rotate_using_parameter",3, -0.00094,0}
                                    }
L_NEEDLE_HYD_G.level 				= 2
L_NEEDLE_HYD_G.h_clip_relation      = h_clip_relations.COMPARE
vertices(L_NEEDLE_HYD_G ,0.20)
Add(L_NEEDLE_HYD_G)
-------------------------------------------------------------------------------------------------HDY-RING-GREEN--RIGHT
R_RING_HYD_G                    = CreateElement "ceTexPoly"
R_RING_HYD_G.name    			= "ring green"
R_RING_HYD_G.material			= RING_HYD_G
R_RING_HYD_G.change_opacity 	= false
R_RING_HYD_G.collimated 		= false
R_RING_HYD_G.isvisible 			= true
R_RING_HYD_G.init_pos 			= {-0.21, -0.68, 0} --L-R,U-D,F-B
R_RING_HYD_G.init_rot 			= {0, 0, 0}
R_RING_HYD_G.element_params 	= {"MFD_OPACITY","R_HYD_COLOR","LMFD_ENG_PAGE"} 
R_RING_HYD_G.controllers		= {
                                    {"opacity_using_parameter",0},
                                    {"parameter_in_range",1,-0.1,0.1},--Green
                                    {"parameter_in_range",2,0.9,1.1},--ENGINE PAGE = 1
                                   
                                }
R_RING_HYD_G.level 				    = 2
R_RING_HYD_G.h_clip_relation        = h_clip_relations.COMPARE
vertices(R_RING_HYD_G,0.20)
Add(R_RING_HYD_G)
------------------------------------------------------------------------------------------------HDY-NEEDLE-GREEN--RIGHT
R_NEEDLE_HYD_G                      = CreateElement "ceTexPoly"
R_NEEDLE_HYD_G.name    			    = "needle r"
R_NEEDLE_HYD_G.material			    = RING_NEEDLE_G
R_NEEDLE_HYD_G.change_opacity 	    = false
R_NEEDLE_HYD_G.collimated 		    = false
R_NEEDLE_HYD_G.isvisible 	        = true
R_NEEDLE_HYD_G.init_pos 			= {-0.21, -0.68, 0} --L-R,U-D,F-B
R_NEEDLE_HYD_G.init_rot 			= {0, 0, 0}
R_NEEDLE_HYD_G.element_params 	    = {"MFD_OPACITY","R_HYD_COLOR","LMFD_ENG_PAGE","R_HYD_VALUE"} 
R_NEEDLE_HYD_G.controllers		    = {
                                        {"opacity_using_parameter",0},
                                        {"parameter_in_range",1,-0.1,0.1},--green
                                        {"parameter_in_range",2,0.9,1.1},--ENGINE PAGE = 1
                                        {"rotate_using_parameter",3, -0.00094,0}
                                    }
R_NEEDLE_HYD_G.level 				= 2
R_NEEDLE_HYD_G.h_clip_relation      = h_clip_relations.COMPARE
vertices(R_NEEDLE_HYD_G ,0.20)
Add(R_NEEDLE_HYD_G)
------------------------------------------------------------------------------------------------HDY-NEEDLE-RED--RIGHT
R_RING_HYD_R                    = CreateElement "ceTexPoly"
R_RING_HYD_R.name    			= "ring red"
R_RING_HYD_R.material			= RING_HYD_R
R_RING_HYD_R.change_opacity 	= false
R_RING_HYD_R.collimated 		= false
R_RING_HYD_R.isvisible 			= true
R_RING_HYD_R.init_pos 			= {-0.21, -0.68, 0} --L-R,U-D,F-B
R_RING_HYD_R.init_rot 			= {0, 0, 0}
R_RING_HYD_R.element_params 	= {"MFD_OPACITY","R_HYD_COLOR","LMFD_ENG_PAGE"} 
R_RING_HYD_R.controllers		= {
                                    {"opacity_using_parameter",0},
                                    {"parameter_in_range",1,0.9,1.1},--red
                                    {"parameter_in_range",2,0.9,1.1},--ENGINE PAGE = 1
                                   
                                }
R_RING_HYD_R.level 				    = 2
R_RING_HYD_R.h_clip_relation        = h_clip_relations.COMPARE
vertices(R_RING_HYD_R,0.20)
Add(R_RING_HYD_R)
------------------------------------------------------------------------------------------------HDY-NEEDLE-RED--RIGHT
R_NEEDLE_HYD_R                      = CreateElement "ceTexPoly"
R_NEEDLE_HYD_R.name    			    = "needle r"
R_NEEDLE_HYD_R.material			    = RING_NEEDLE_R
R_NEEDLE_HYD_R.change_opacity 	    = false
R_NEEDLE_HYD_R.collimated 		    = false
R_NEEDLE_HYD_R.isvisible 	        = true
R_NEEDLE_HYD_R.init_pos 			= {-0.21, -0.68, 0} --L-R,U-D,F-B
R_NEEDLE_HYD_R.init_rot 			= {0, 0, 0}
R_NEEDLE_HYD_R.element_params 	    = {"MFD_OPACITY","R_HYD_COLOR","LMFD_ENG_PAGE","R_HYD_VALUE"} 
R_NEEDLE_HYD_R.controllers		    = {
                                        {"opacity_using_parameter",0},
                                        {"parameter_in_range",1,0.9,1.1},--red
                                        {"parameter_in_range",2,0.9,1.1},--ENGINE PAGE = 1
                                        {"rotate_using_parameter",3, -0.00094,0}
                                    }
R_NEEDLE_HYD_R.level 				= 2
R_NEEDLE_HYD_R.h_clip_relation      = h_clip_relations.COMPARE
vertices(R_NEEDLE_HYD_R ,0.20)
Add(R_NEEDLE_HYD_R)
-----------------------------------------------------------------------------------------------------------TEXT NUMBERS R RPM YEL
R_RPM_TEXT_G				    = CreateElement "ceStringPoly"
R_RPM_TEXT_G.name				= "rad Alt"
R_RPM_TEXT_G.material			= UFD_GRN
R_RPM_TEXT_G.init_pos			= {0.28, 0.69, 0} --L-R,U-D,F-B
R_RPM_TEXT_G.alignment			= "RightCenter"
R_RPM_TEXT_G.stringdefs			= {0.005, 0.005, 0, 0.0} --either 004 or 005
R_RPM_TEXT_G.additive_alpha		= true
R_RPM_TEXT_G.collimated			= false
R_RPM_TEXT_G.isdraw				= true	
R_RPM_TEXT_G.use_mipfilter		= true
R_RPM_TEXT_G.h_clip_relation	= h_clip_relations.COMPARE
R_RPM_TEXT_G.level				= 2
R_RPM_TEXT_G.element_params		= {"MFD_OPACITY","RPM_R","LMFD_ENG_PAGE","R_RPM_COLOR"}
R_RPM_TEXT_G.formats			= {"%.0f"}--= {"%02.0f"}
R_RPM_TEXT_G.controllers		=   {
                                        {"opacity_using_parameter",0},
                                        {"text_using_parameter",1,0},
                                        {"parameter_in_range",2,0.9,1.1},--ENGINE PAGE = 1
                                        {"parameter_in_range",3,0.4,0.6}
                                    }
                                
Add(R_RPM_TEXT_G)
-----------------------------------------------------------------------------------------------------------R RPM ORANGE
R_RPM_TEXT_O				    = CreateElement "ceStringPoly"
R_RPM_TEXT_O.name				= "rad Alt"
R_RPM_TEXT_O.material			= UFD_ORG
R_RPM_TEXT_O.init_pos			= {0.28, 0.69, 0} --L-R,U-D,F-B
R_RPM_TEXT_O.alignment			= "RightCenter"
R_RPM_TEXT_O.stringdefs			= {0.005, 0.005, 0, 0.0} --either 004 or 005
R_RPM_TEXT_O.additive_alpha		= true
R_RPM_TEXT_O.collimated			= false
R_RPM_TEXT_O.isdraw				= true	
R_RPM_TEXT_O.use_mipfilter		= true
R_RPM_TEXT_O.h_clip_relation	= h_clip_relations.COMPARE
R_RPM_TEXT_O.level				= 2
R_RPM_TEXT_O.element_params		= {"MFD_OPACITY","RPM_R","LMFD_ENG_PAGE","R_RPM_COLOR"}
R_RPM_TEXT_O.formats			= {"%.0f"}--= {"%02.0f"}
R_RPM_TEXT_O.controllers		=   {
                                        {"opacity_using_parameter",0},
                                        {"text_using_parameter",1,0},
                                        {"parameter_in_range",2,0.9,1.1},--ENGINE PAGE = 1
                                        {"parameter_in_range",3,0.9,1.1}
                                    }
                                
Add(R_RPM_TEXT_O)
-----------------------------------------------------------------------------------------------------------L RPM YEL
L_RPM_TEXT_G				    = CreateElement "ceStringPoly"
L_RPM_TEXT_G.name				= "rad Alt"
L_RPM_TEXT_G.material			= UFD_GRN
L_RPM_TEXT_G.init_pos			= {-0.41, 0.69, 0} --L-R,U-D,F-B
L_RPM_TEXT_G.alignment			= "RightCenter"
L_RPM_TEXT_G.stringdefs			= {0.005, 0.005, 0, 0.0} --either 004 or 005
L_RPM_TEXT_G.additive_alpha		= true
L_RPM_TEXT_G.collimated			= false
L_RPM_TEXT_G.isdraw				= true	
L_RPM_TEXT_G.use_mipfilter		= true
L_RPM_TEXT_G.h_clip_relation	= h_clip_relations.COMPARE
L_RPM_TEXT_G.level				= 2
L_RPM_TEXT_G.element_params		= {"MFD_OPACITY","RPM_L","LMFD_ENG_PAGE","L_RPM_COLOR"}
L_RPM_TEXT_G.formats			= {"%.0f"}--= {"%02.0f"}
L_RPM_TEXT_G.controllers		=   {
                                        {"opacity_using_parameter",0},
                                        {"text_using_parameter",1,0},
                                        {"parameter_in_range",2,0.9,1.1},--ENGINE PAGE = 1
                                        {"parameter_in_range",3,0.4,0.6}
                                    }
                                
Add(L_RPM_TEXT_G)
-----------------------------------------------------------------------------------------------------------L RPM ORANGE
L_RPM_TEXT_O				    = CreateElement "ceStringPoly"
L_RPM_TEXT_O.name				= "rad Alt"
L_RPM_TEXT_O.material			= UFD_ORG
L_RPM_TEXT_O.init_pos			= {-0.41, 0.69, 0} --L-R,U-D,F-B
L_RPM_TEXT_O.alignment			= "RightCenter"
L_RPM_TEXT_O.stringdefs			= {0.005, 0.005, 0, 0.0} --either 004 or 005
L_RPM_TEXT_O.additive_alpha		= true
L_RPM_TEXT_O.collimated			= false
L_RPM_TEXT_O.isdraw				= true	
L_RPM_TEXT_O.use_mipfilter		= true
L_RPM_TEXT_O.h_clip_relation	= h_clip_relations.COMPARE
L_RPM_TEXT_O.level				= 2
L_RPM_TEXT_O.element_params		= {"MFD_OPACITY","RPM_L","LMFD_ENG_PAGE","L_RPM_COLOR"}
L_RPM_TEXT_O.formats			= {"%.0f"}--= {"%02.0f"}
L_RPM_TEXT_O.controllers		=   {
                                        {"opacity_using_parameter",0},
                                        {"text_using_parameter",1,0},
                                        {"parameter_in_range",2,0.9,1.1},--ENGINE PAGE = 1
                                        {"parameter_in_range",3,0.9,1.1}
                                    }
                                
Add(L_RPM_TEXT_O)
-----------------------------------------------------------------------------------------------------------TEXT NUMBERS R EGT YEL
R_EGT_TEXT_G				    = CreateElement "ceStringPoly"
R_EGT_TEXT_G.name				= "rad Alt"
R_EGT_TEXT_G.material			= UFD_GRN
R_EGT_TEXT_G.init_pos			= {0.28, 0.39, 0} --L-R,U-D,F-B
R_EGT_TEXT_G.alignment			= "RightCenter"
R_EGT_TEXT_G.stringdefs			= {0.005, 0.005, 0, 0.0} --either 004 or 005
R_EGT_TEXT_G.additive_alpha		= true
R_EGT_TEXT_G.collimated			= false
R_EGT_TEXT_G.isdraw				= true	
R_EGT_TEXT_G.use_mipfilter		= true
R_EGT_TEXT_G.h_clip_relation	= h_clip_relations.COMPARE
R_EGT_TEXT_G.level				= 2
R_EGT_TEXT_G.element_params		= {"MFD_OPACITY","EGT_R","LMFD_ENG_PAGE","R_EGT_COLOR"}
R_EGT_TEXT_G.formats			= {"%.0f"}--= {"%02.0f"}
R_EGT_TEXT_G.controllers		=   {
                                        {"opacity_using_parameter",0},
                                        {"text_using_parameter",1,0},
                                        {"parameter_in_range",2,0.9,1.1},--ENGINE PAGE = 1
                                        {"parameter_in_range",3,-0.1,0.1}
                                    }
                                
Add(R_EGT_TEXT_G)
-----------------------------------------------------------------------------------------------------------R EGT YELLOW
R_EGT_TEXT_Y				    = CreateElement "ceStringPoly"
R_EGT_TEXT_Y.name				= "rad Alt"
R_EGT_TEXT_Y.material			= UFD_YEL
R_EGT_TEXT_Y.init_pos			= {0.28, 0.39, 0} --L-R,U-D,F-B
R_EGT_TEXT_Y.alignment			= "RightCenter"
R_EGT_TEXT_Y.stringdefs			= {0.005, 0.005, 0, 0.0} --either 004 or 005
R_EGT_TEXT_Y.additive_alpha		= true
R_EGT_TEXT_Y.collimated			= false
R_EGT_TEXT_Y.isdraw				= true	
R_EGT_TEXT_Y.use_mipfilter		= true
R_EGT_TEXT_Y.h_clip_relation	= h_clip_relations.COMPARE
R_EGT_TEXT_Y.level				= 2
R_EGT_TEXT_Y.element_params		= {"MFD_OPACITY","EGT_R","LMFD_ENG_PAGE","R_EGT_COLOR"}
R_EGT_TEXT_Y.formats			= {"%.0f"}--= {"%02.0f"}
R_EGT_TEXT_Y.controllers		=   {
                                        {"opacity_using_parameter",0},
                                        {"text_using_parameter",1,0},
                                        {"parameter_in_range",2,0.9,1.1},--ENGINE PAGE = 1
                                        {"parameter_in_range",3,0.4,0.6}
                                    }
                                
Add(R_EGT_TEXT_Y)
-----------------------------------------------------------------------------------------------------------R EGT RED
R_EGT_TEXT_R				    = CreateElement "ceStringPoly"
R_EGT_TEXT_R.name				= "rad Alt"
R_EGT_TEXT_R.material			= UFD_RED
R_EGT_TEXT_R.init_pos			= {0.28, 0.39, 0} --L-R,U-D,F-B
R_EGT_TEXT_R.alignment			= "RightCenter"
R_EGT_TEXT_R.stringdefs			= {0.005, 0.005, 0, 0.0} --either 004 or 005
R_EGT_TEXT_R.additive_alpha		= true
R_EGT_TEXT_R.collimated			= false
R_EGT_TEXT_R.isdraw				= true	
R_EGT_TEXT_R.use_mipfilter		= true
R_EGT_TEXT_R.h_clip_relation	= h_clip_relations.COMPARE
R_EGT_TEXT_R.level				= 2
R_EGT_TEXT_R.element_params		= {"MFD_OPACITY","EGT_R","LMFD_ENG_PAGE","R_EGT_COLOR"}
R_EGT_TEXT_R.formats			= {"%.0f"}--= {"%02.0f"}
R_EGT_TEXT_R.controllers		=   {
                                        {"opacity_using_parameter",0},
                                        {"text_using_parameter",1,0},
                                        {"parameter_in_range",2,0.9,1.1},--ENGINE PAGE = 1
                                        {"parameter_in_range",3,0.9,1.1}
                                    }
                                
Add(R_EGT_TEXT_R)
-----------------------------------------------------------------------------------------------------------L EGT YEL
L_EGT_TEXT_G				    = CreateElement "ceStringPoly"
L_EGT_TEXT_G.name				= "rad Alt"
L_EGT_TEXT_G.material			= UFD_GRN
L_EGT_TEXT_G.init_pos			= {-0.41, 0.39, 0} --L-R,U-D,F-B
L_EGT_TEXT_G.alignment			= "RightCenter"
L_EGT_TEXT_G.stringdefs			= {0.005, 0.005, 0, 0.0} --either 004 or 005
L_EGT_TEXT_G.additive_alpha		= true
L_EGT_TEXT_G.collimated			= false
L_EGT_TEXT_G.isdraw				= true	
L_EGT_TEXT_G.use_mipfilter		= true
L_EGT_TEXT_G.h_clip_relation	= h_clip_relations.COMPARE
L_EGT_TEXT_G.level				= 2
L_EGT_TEXT_G.element_params		= {"MFD_OPACITY","EGT_L","LMFD_ENG_PAGE","L_EGT_COLOR"}
L_EGT_TEXT_G.formats			= {"%.0f"}--= {"%02.0f"}
L_EGT_TEXT_G.controllers		=   {
                                        {"opacity_using_parameter",0},
                                        {"text_using_parameter",1,0},
                                        {"parameter_in_range",2,0.9,1.1},--ENGINE PAGE = 1
                                        {"parameter_in_range",3,-0.1,0.1}
                                    }
                                
Add(L_EGT_TEXT_G)
-----------------------------------------------------------------------------------------------------------R EGT YELLOW
L_EGT_TEXT_Y				    = CreateElement "ceStringPoly"
L_EGT_TEXT_Y.name				= "rad Alt"
L_EGT_TEXT_Y.material			= UFD_YEL
L_EGT_TEXT_Y.init_pos			= {-0.41, 0.39, 0} --L-R,U-D,F-B
L_EGT_TEXT_Y.alignment			= "RightCenter"
L_EGT_TEXT_Y.stringdefs			= {0.005, 0.005, 0, 0.0} --either 004 or 005
L_EGT_TEXT_Y.additive_alpha		= true
L_EGT_TEXT_Y.collimated			= false
L_EGT_TEXT_Y.isdraw				= true	
L_EGT_TEXT_Y.use_mipfilter		= true
L_EGT_TEXT_Y.h_clip_relation	= h_clip_relations.COMPARE
L_EGT_TEXT_Y.level				= 2
L_EGT_TEXT_Y.element_params		= {"MFD_OPACITY","EGT_L","LMFD_ENG_PAGE","L_EGT_COLOR"}
L_EGT_TEXT_Y.formats			= {"%.0f"}--= {"%02.0f"}
L_EGT_TEXT_Y.controllers		=   {
                                        {"opacity_using_parameter",0},
                                        {"text_using_parameter",1,0},
                                        {"parameter_in_range",2,0.9,1.1},--ENGINE PAGE = 1
                                        {"parameter_in_range",3,0.4,0.6}
                                    }
                                
Add(L_EGT_TEXT_Y)
-----------------------------------------------------------------------------------------------------------L EGT RED
L_EGT_TEXT_R				    = CreateElement "ceStringPoly"
L_EGT_TEXT_R.name				= "rad Alt"
L_EGT_TEXT_R.material			= UFD_RED
L_EGT_TEXT_R.init_pos			= {-0.41, 0.39, 0} --L-R,U-D,F-B
L_EGT_TEXT_R.alignment			= "RightCenter"
L_EGT_TEXT_R.stringdefs			= {0.005, 0.005, 0, 0.0} --either 004 or 005
L_EGT_TEXT_R.additive_alpha		= true
L_EGT_TEXT_R.collimated			= false
L_EGT_TEXT_R.isdraw				= true	
L_EGT_TEXT_R.use_mipfilter		= true
L_EGT_TEXT_R.h_clip_relation	= h_clip_relations.COMPARE
L_EGT_TEXT_R.level				= 2
L_EGT_TEXT_R.element_params		= {"MFD_OPACITY","EGT_L","LMFD_ENG_PAGE","L_EGT_COLOR"}
L_EGT_TEXT_R.formats			= {"%.0f"}--= {"%02.0f"}
L_EGT_TEXT_R.controllers		=   {
                                        {"opacity_using_parameter",0},
                                        {"text_using_parameter",1,0},
                                        {"parameter_in_range",2,0.9,1.1},--ENGINE PAGE = 1
                                        {"parameter_in_range",3,0.9,1.1}
                                    }
                                
Add(L_EGT_TEXT_R)
-----------------------------------------------------------------------------------------------------------L OIL GRN
L_OIL_TEXT_G				    = CreateElement "ceStringPoly"
L_OIL_TEXT_G.name				= "rad Alt"
L_OIL_TEXT_G.material			= UFD_GRN
L_OIL_TEXT_G.init_pos			= {-0.40, 0.10, 0} --L-R,U-D,F-B
L_OIL_TEXT_G.alignment			= "RightCenter"
L_OIL_TEXT_G.stringdefs			= {0.004, 0.004, 0, 0.0} --either 004 or 005
L_OIL_TEXT_G.additive_alpha		= true
L_OIL_TEXT_G.collimated			= false
L_OIL_TEXT_G.isdraw				= true	
L_OIL_TEXT_G.use_mipfilter		= true
L_OIL_TEXT_G.h_clip_relation	= h_clip_relations.COMPARE
L_OIL_TEXT_G.level				= 2
L_OIL_TEXT_G.element_params		= {"MFD_OPACITY","OIL_L","LMFD_ENG_PAGE","L_OIL_COLOR"}
L_OIL_TEXT_G.formats			= {"%.0f"}--= {"%02.0f"}
L_OIL_TEXT_G.controllers		=   {
                                        {"opacity_using_parameter",0},
                                        {"text_using_parameter",1,0},
                                        {"parameter_in_range",2,0.9,1.1},--ENGINE PAGE = 1
                                        {"parameter_in_range",3,-0.1,0.1}
                                    }
                                
Add(L_OIL_TEXT_G)
-----------------------------------------------------------------------------------------------------------L OIL RED
L_OIL_TEXT_R				    = CreateElement "ceStringPoly"
L_OIL_TEXT_R.name				= "rad Alt"
L_OIL_TEXT_R.material			= UFD_RED
L_OIL_TEXT_R.init_pos			= {-0.40, 0.10, 0} --L-R,U-D,F-B
L_OIL_TEXT_R.alignment			= "RightCenter"
L_OIL_TEXT_R.stringdefs			= {0.004, 0.004, 0, 0.0} --either 004 or 005
L_OIL_TEXT_R.additive_alpha		= true
L_OIL_TEXT_R.collimated			= false
L_OIL_TEXT_R.isdraw				= true	
L_OIL_TEXT_R.use_mipfilter		= true
L_OIL_TEXT_R.h_clip_relation	= h_clip_relations.COMPARE
L_OIL_TEXT_R.level				= 2
L_OIL_TEXT_R.element_params		= {"MFD_OPACITY","OIL_L","LMFD_ENG_PAGE","L_OIL_COLOR"}
L_OIL_TEXT_R.formats			= {"%.0f"}--= {"%02.0f"}
L_OIL_TEXT_R.controllers		=   {
                                        {"opacity_using_parameter",0},
                                        {"text_using_parameter",1,0},
                                        {"parameter_in_range",2,0.9,1.1},--ENGINE PAGE = 1
                                        {"parameter_in_range",3,0.9,1.1}
                                    }
                                
Add(L_OIL_TEXT_R)
-----------------------------------------------------------------------------------------------------------R OIL GRN
R_OIL_TEXT_G				    = CreateElement "ceStringPoly"
R_OIL_TEXT_G.name				= "rad Alt"
R_OIL_TEXT_G.material			= UFD_GRN
R_OIL_TEXT_G.init_pos			= {0.26, 0.10, 0} --L-R,U-D,F-B
R_OIL_TEXT_G.alignment			= "RightCenter"
R_OIL_TEXT_G.stringdefs			= {0.004, 0.004, 0, 0.0} --either 004 or 005
R_OIL_TEXT_G.additive_alpha		= true
R_OIL_TEXT_G.collimated			= false
R_OIL_TEXT_G.isdraw				= true	
R_OIL_TEXT_G.use_mipfilter		= true
R_OIL_TEXT_G.h_clip_relation	= h_clip_relations.COMPARE
R_OIL_TEXT_G.level				= 2
R_OIL_TEXT_G.element_params		= {"MFD_OPACITY","OIL_R","LMFD_ENG_PAGE","R_OIL_COLOR"}
R_OIL_TEXT_G.formats			= {"%.0f"}--= {"%02.0f"}
R_OIL_TEXT_G.controllers		=   {
                                        {"opacity_using_parameter",0},
                                        {"text_using_parameter",1,0},
                                        {"parameter_in_range",2,0.9,1.1},--ENGINE PAGE = 1
                                        {"parameter_in_range",3,-0.1,0.1}
                                    }
                                
Add(R_OIL_TEXT_G)
-----------------------------------------------------------------------------------------------------------R OIL RED
R_OIL_TEXT_R				    = CreateElement "ceStringPoly"
R_OIL_TEXT_R.name				= "rad Alt"
R_OIL_TEXT_R.material			= UFD_RED
R_OIL_TEXT_R.init_pos			= {0.26, 0.10, 0} --L-R,U-D,F-B
R_OIL_TEXT_R.alignment			= "RightCenter"
R_OIL_TEXT_R.stringdefs			= {0.004, 0.004, 0, 0.0} --either 004 or 005
R_OIL_TEXT_R.additive_alpha		= true
R_OIL_TEXT_R.collimated			= false
R_OIL_TEXT_R.isdraw				= true	
R_OIL_TEXT_R.use_mipfilter		= true
R_OIL_TEXT_R.h_clip_relation	= h_clip_relations.COMPARE
R_OIL_TEXT_R.level				= 2
R_OIL_TEXT_R.element_params		= {"MFD_OPACITY","OIL_R","LMFD_ENG_PAGE","R_OIL_COLOR"}
R_OIL_TEXT_R.formats			= {"%.0f"}--= {"%02.0f"}
R_OIL_TEXT_R.controllers		=   {
                                        {"opacity_using_parameter",0},
                                        {"text_using_parameter",1,0},
                                        {"parameter_in_range",2,0.9,1.1},--ENGINE PAGE = 1
                                        {"parameter_in_range",3,0.9,1.1}
                                    }
                                
Add(R_OIL_TEXT_R)
-------------------------------------------------------------------------------------------------------------L HYD GREEN
L_HYD_TEXT_G				    = CreateElement "ceStringPoly"
L_HYD_TEXT_G.name				= "rad Alt"
L_HYD_TEXT_G.material			= UFD_GRN
L_HYD_TEXT_G.init_pos			= {-0.70, -0.61, 0} --L-R,U-D,F-B
L_HYD_TEXT_G.alignment			= "RightCenter"
L_HYD_TEXT_G.stringdefs			= {0.004, 0.004, 0, 0.0} --either 004 or 005
L_HYD_TEXT_G.additive_alpha		= true
L_HYD_TEXT_G.collimated			= false
L_HYD_TEXT_G.isdraw				= true	
L_HYD_TEXT_G.use_mipfilter		= true
L_HYD_TEXT_G.h_clip_relation	= h_clip_relations.COMPARE
L_HYD_TEXT_G.level				= 2
L_HYD_TEXT_G.element_params		= {"MFD_OPACITY","L_HYD_VALUE","LMFD_ENG_PAGE","L_HYD_COLOR"}
L_HYD_TEXT_G.formats			= {"%.0f"}--= {"%02.0f"}
L_HYD_TEXT_G.controllers		=   {
                                        {"opacity_using_parameter",0},
                                        {"text_using_parameter",1,0},
                                        {"parameter_in_range",2,0.9,1.1},--ENGINE PAGE = 1
                                        {"parameter_in_range",3,-0.1,0.1}
                                    }
                                
Add(L_HYD_TEXT_G)
-----------------------------------------------------------------------------------------------------------L HYD RED
L_HYD_TEXT_R				    = CreateElement "ceStringPoly"
L_HYD_TEXT_R.name				= "rad Alt"
L_HYD_TEXT_R.material			= UFD_RED
L_HYD_TEXT_R.init_pos			= {-0.70, -0.61, 0} --L-R,U-D,F-B
L_HYD_TEXT_R.alignment			= "RightCenter"
L_HYD_TEXT_R.stringdefs			= {0.004, 0.004, 0, 0.0} --either 004 or 005
L_HYD_TEXT_R.additive_alpha		= true
L_HYD_TEXT_R.collimated			= false
L_HYD_TEXT_R.isdraw				= true	
L_HYD_TEXT_R.use_mipfilter		= true
L_HYD_TEXT_R.h_clip_relation	= h_clip_relations.COMPARE
L_HYD_TEXT_R.level				= 2
L_HYD_TEXT_R.element_params		= {"MFD_OPACITY","L_HYD_VALUE","LMFD_ENG_PAGE","L_HYD_COLOR"}
L_HYD_TEXT_R.formats			= {"%.0f"}--= {"%02.0f"}
L_HYD_TEXT_R.controllers		=   {
                                        {"opacity_using_parameter",0},
                                        {"text_using_parameter",1,0},
                                        {"parameter_in_range",2,0.9,1.1},--ENGINE PAGE = 1
                                        {"parameter_in_range",3,0.9,1.1}
                                    }
                                
Add(L_HYD_TEXT_R)
-------------------------------------------------------------------------------------------------------------R HYD GREEN
R_HYD_TEXT_G				    = CreateElement "ceStringPoly"
R_HYD_TEXT_G.name				= "rad Alt"
R_HYD_TEXT_G.material			= UFD_GRN
R_HYD_TEXT_G.init_pos			= {-0.25, -0.61, 0} --L-R,U-D,F-B
R_HYD_TEXT_G.alignment			= "RightCenter"
R_HYD_TEXT_G.stringdefs			= {0.004, 0.004, 0, 0.0} --either 004 or 005
R_HYD_TEXT_G.additive_alpha		= true
R_HYD_TEXT_G.collimated			= false
R_HYD_TEXT_G.isdraw				= true	
R_HYD_TEXT_G.use_mipfilter		= true
R_HYD_TEXT_G.h_clip_relation	= h_clip_relations.COMPARE
R_HYD_TEXT_G.level				= 2
R_HYD_TEXT_G.element_params		= {"MFD_OPACITY","R_HYD_VALUE","LMFD_ENG_PAGE","R_HYD_COLOR"}
R_HYD_TEXT_G.formats			= {"%.0f"}--= {"%02.0f"}
R_HYD_TEXT_G.controllers		=   {
                                        {"opacity_using_parameter",0},
                                        {"text_using_parameter",1,0},
                                        {"parameter_in_range",2,0.9,1.1},--ENGINE PAGE = 1
                                        {"parameter_in_range",3,-0.1,0.1}
                                    }
                                
Add(R_HYD_TEXT_G)
-----------------------------------------------------------------------------------------------------------R HYD RED
R_HYD_TEXT_R				    = CreateElement "ceStringPoly"
R_HYD_TEXT_R.name				= "rad Alt"
R_HYD_TEXT_R.material			= UFD_RED
R_HYD_TEXT_R.init_pos			= {-0.25, -0.61, 0} --L-R,U-D,F-B
R_HYD_TEXT_R.alignment			= "RightCenter"
R_HYD_TEXT_R.stringdefs			= {0.004, 0.004, 0, 0.0} --either 004 or 005
R_HYD_TEXT_R.additive_alpha		= true
R_HYD_TEXT_R.collimated			= false
R_HYD_TEXT_R.isdraw				= true	
R_HYD_TEXT_R.use_mipfilter		= true
R_HYD_TEXT_R.h_clip_relation	= h_clip_relations.COMPARE
R_HYD_TEXT_R.level				= 2
R_HYD_TEXT_R.element_params		= {"MFD_OPACITY","R_HYD_VALUE","LMFD_ENG_PAGE","R_HYD_COLOR"}
R_HYD_TEXT_R.formats			= {"%.0f"}--= {"%02.0f"}
R_HYD_TEXT_R.controllers		=   {
                                        {"opacity_using_parameter",0},
                                        {"text_using_parameter",1,0},
                                        {"parameter_in_range",2,0.9,1.1},--ENGINE PAGE = 1
                                        {"parameter_in_range",3,0.9,1.1}
                                    }
                                
Add(R_HYD_TEXT_R)

-------------------------------------------------------------------------CABIN PRESS SLUT
CABIN_BOX                       = CreateElement "ceTexPoly" --top center box
CABIN_BOX.name    			    = "BG"
CABIN_BOX.material			    = BOX_CABIN
CABIN_BOX.change_opacity 		= false
CABIN_BOX.collimated 			= false
CABIN_BOX.isvisible 			= true
CABIN_BOX.init_pos 			    = {0.19, -0.75, 0}
CABIN_BOX.init_rot 			    = {0, 0, 0}
CABIN_BOX.indices 			    = {0, 1, 2, 2, 3, 0}
CABIN_BOX.element_params 		= {"MFD_OPACITY","LMFD_ENG_PAGE","CABINPRESS"}
CABIN_BOX.controllers			=   {
                                        {"opacity_using_parameter",0},
                                        {"parameter_in_range",1,0.9,1.1},--ENGINE PAGE = 1
                                        {"move_left_right_using_parameter",2,0.1,0}
                                    }
CABIN_BOX.level 				= 2
CABIN_BOX.h_clip_relation       = h_clip_relations.COMPARE

CABIN_BOX.tex_coords =
{
    {0, 0},
    {1, 0},
    {1, 1},
    {0, 1}
}

local levelHeight = 0.0390     
local levelWidth = 	0.0350
local halfWidth = levelWidth / 2
local halfHeight = levelHeight / 2
local xPos = halfWidth
local xNeg = halfWidth * -1.0
local yPos = halfHeight
local yNeg = halfHeight * -1.0

CABIN_BOX.vertices = 
{
    {xNeg, yPos},
    {xPos, yPos},
    {xPos, yNeg},
    {xNeg, yNeg}
}

Add(CABIN_BOX)
-------------------------------------------------------------------------CABIN PRESS SLUT BOTTOM
CABIN_BOTTOM                       = CreateElement "ceTexPoly" --top center box
CABIN_BOTTOM.name    			    = "BG"
CABIN_BOTTOM.material			    = RING_CABIN
CABIN_BOTTOM.change_opacity 		= false
CABIN_BOTTOM.collimated 			= false
CABIN_BOTTOM.isvisible 			= true
CABIN_BOTTOM.init_pos 			    = {0.44, -0.75, 0}
CABIN_BOTTOM.init_rot 			    = {0, 0, 0}
CABIN_BOTTOM.indices 			    = {0, 1, 2, 2, 3, 0}
CABIN_BOTTOM.element_params 		= {"MFD_OPACITY","LMFD_ENG_PAGE"}
CABIN_BOTTOM.controllers			=   {
                                        {"opacity_using_parameter",0},
                                        {"parameter_in_range",1,0.9,1.1},--ENGINE PAGE = 1
                                    }
CABIN_BOTTOM.level 				= 2
CABIN_BOTTOM.h_clip_relation       = h_clip_relations.COMPARE

CABIN_BOTTOM.tex_coords =
{
    {0, 0},
    {1, 0},
    {1, 1},
    {0, 1}
}

local levelHeight = 0.40     
local levelWidth = 	0.65
local halfWidth = levelWidth / 2
local halfHeight = levelHeight / 2
local xPos = halfWidth
local xNeg = halfWidth * -1.0
local yPos = halfHeight
local yNeg = halfHeight * -1.0

CABIN_BOTTOM.vertices = 
{
    {xNeg, yPos},
    {xPos, yPos},
    {xPos, yNeg},
    {xNeg, yNeg}
}

Add(CABIN_BOTTOM)
