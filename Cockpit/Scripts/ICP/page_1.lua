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


dofile(LockOn_Options.script_path.."ICP/definitions.lua")
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
local MASK_BOX	    = MakeMaterial(LockOn_Options.script_path.."../Scripts/IndicationTextures/mask_box.dds", RedColor)--SYSTEM TEST
--------------------------------------------------------------------------------------------------------------------------------------------
local ClippingPlaneSize = 1.7 --Clipping Masks
local ClippingWidth 	= 2.7   --Clipping Masks
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
total_field_of_view.init_pos        = {-1.1, 0, 0}
total_field_of_view.init_rot        = { 0, 0, 0} -- degree NOT rad
total_field_of_view.h_clip_relation = h_clip_relations.REWRITE_LEVEL
total_field_of_view.level           = 20
total_field_of_view.collimated      = false
total_field_of_view.isvisible       = false
Add(total_field_of_view)
--Clipping Masks
local clipPoly               = CreateElement "ceMeshPoly"
clipPoly.name                = "clipPoly-1"
clipPoly.primitivetype       = "triangles"
clipPoly.init_pos            = {-1.1, 0, 0}
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
clipPoly.level               = 20
clipPoly.collimated          = false
clipPoly.isvisible           = false
Add(clipPoly)
------------------------------------------------------------------------------------------------CLIPPING-END----------------------------------------------------------------------------------------------
--HUD MENU
    NAV 					    = CreateElement "ceStringPoly"
    NAV.name 				    = "menu"
    NAV.material 			    = UFD_GRN
    NAV.value 				    = "NAV MODE"
    NAV.stringdefs 		    = {0.0060, 0.0060, 0.0004, 0.001}
    NAV.alignment 			    = "LeftCenter"
    NAV.formats 			    = {"%s"}
    NAV.h_clip_relation        = h_clip_relations.COMPARE
    NAV.level 				    = 21
    NAV.init_pos 			    = {-1, 1.2, 0}
    NAV.init_rot 			    = {0, 0, 0}
    NAV.element_params 	    = {"ICP_OPACITY","ICP_HUD_MENU"}
    NAV.controllers		    =   {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1}}
    Add(NAV)
    ----------------------------------------------------------------------------------------------------------------
    BVR 					    = CreateElement "ceStringPoly"
    BVR.name 				    = "menu"
    BVR.material 			    = UFD_GRN
    BVR.value 				    = "BVR MODE"
    BVR.stringdefs 		    = {0.0060, 0.0060, 0.0004, 0.001}
    BVR.alignment 			    = "LeftCenter"
    BVR.formats 			    = {"%s"}
    BVR.h_clip_relation        = h_clip_relations.COMPARE
    BVR.level 				    = 21
    BVR.init_pos 			    = {-1, 0.6, 0}
    BVR.init_rot 			    = {0, 0, 0}
    BVR.element_params 	    = {"ICP_OPACITY","ICP_HUD_MENU"}
    BVR.controllers		    =   {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1}}
    Add(BVR)
    ----------------
    VERTSCAN 					    = CreateElement "ceStringPoly"
    VERTSCAN.name 				    = "menu"
    VERTSCAN.material 			    = UFD_GRN
    VERTSCAN.value 				    = "VERTICAL SCAN"
    VERTSCAN.stringdefs 		    = {0.0060, 0.0060, 0.0004, 0.001}
    VERTSCAN.alignment 			    = "LeftCenter"
    VERTSCAN.formats 			    = {"%s"}
    VERTSCAN.h_clip_relation        = h_clip_relations.COMPARE
    VERTSCAN.level 				    = 21
    VERTSCAN.init_pos 			    = {-1, 0, 0}
    VERTSCAN.init_rot 			    = {0, 0, 0}
    VERTSCAN.element_params 	    = {"ICP_OPACITY","ICP_HUD_MENU"}
    VERTSCAN.controllers		    =   {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1}}
    Add(VERTSCAN)
    ----------------
    BORE 					    = CreateElement "ceStringPoly"
    BORE.name 				    = "menu"
    BORE.material 			    = UFD_GRN
    BORE.value 				    = "BORE SIGHT"
    BORE.stringdefs 		    = {0.0060, 0.0060, 0.0004, 0.001}
    BORE.alignment 			    = "LeftCenter"
    BORE.formats 			    = {"%s"}
    BORE.h_clip_relation        = h_clip_relations.COMPARE
    BORE.level 				    = 21
    BORE.init_pos 			    = {-1, -0.6, 0}
    BORE.init_rot 			    = {0, 0, 0}
    BORE.element_params 	    = {"ICP_OPACITY","ICP_HUD_MENU"}
    BORE.controllers		    =   {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1}}
    Add(BORE)
    ----------------
    FLOOD 					    = CreateElement "ceStringPoly"
    FLOOD.name 				    = "menu"
    FLOOD.material 			    = UFD_GRN
    FLOOD.value 				    = "FLOOD MODE"
    FLOOD.stringdefs 		    = {0.0060, 0.0060, 0.0004, 0.001}
    FLOOD.alignment 			    = "LeftCenter"
    FLOOD.formats 			    = {"%s"}
    FLOOD.h_clip_relation        = h_clip_relations.COMPARE
    FLOOD.level 				    = 21
    FLOOD.init_pos 			    = {-1, -1.2, 0}
    FLOOD.init_rot 			    = {0, 0, 0}
    FLOOD.element_params 	    = {"ICP_OPACITY","ICP_HUD_MENU"}
    FLOOD.controllers		    =   {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1}}
    Add(FLOOD)
--AP MENU
AP1 					    = CreateElement "ceStringPoly"
AP1.name 				    = "menu"
AP1.material 			    = UFD_GRN
AP1.value 				    = "ALTITUDE HOLD"
AP1.stringdefs 		        = {0.0060, 0.0060, 0.0004, 0.001}
AP1.alignment 			    = "LeftCenter"
AP1.formats 			    = {"%s"}
AP1.h_clip_relation        = h_clip_relations.COMPARE
AP1.level 				    = 21
AP1.init_pos 			    = {-0.95, 1.2, 0}
AP1.init_rot 			    = {0, 0, 0}
AP1.element_params 	        = {"ICP_OPACITY","ICP_AP_MENU"}
AP1.controllers		        =   {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1}}
Add(AP1)
----------------------------------------------------------------------------------------------------------------
AP2 					    = CreateElement "ceStringPoly"
AP2.name 				    = "menu"
AP2.material 			    = UFD_GRN
AP2.value 				    = "ROUTE FOLLOW"
AP2.stringdefs 		        = {0.0060, 0.0060, 0.0004, 0.001}
AP2.alignment 			    = "LeftCenter"
AP2.formats 			    = {"%s"}
AP2.h_clip_relation        = h_clip_relations.COMPARE
AP2.level 				    = 21
AP2.init_pos 			    = {-0.95, 0.6, 0}
AP2.init_rot 			    = {0, 0, 0}
AP2.element_params 	        = {"ICP_OPACITY","ICP_AP_MENU"}
AP2.controllers		        =   {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1}}
Add(AP2)
----------------
AP3 					    = CreateElement "ceStringPoly"
AP3.name 				    = "menu"
AP3.material 			    = UFD_GRN
AP3.value 				    = "AP DISENGAGE"
AP3.stringdefs 		        = {0.0060, 0.0060, 0.0004, 0.001}
AP3.alignment 			    = "LeftCenter"
AP3.formats 			    = {"%s"}
AP3.h_clip_relation         = h_clip_relations.COMPARE
AP3.level 				    = 21
AP3.init_pos 			    = {-0.95, 0, 0}
AP3.init_rot 			    = {0, 0, 0}
AP3.element_params 	        = {"ICP_OPACITY","ICP_AP_MENU"}
AP3.controllers		        =   {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1}}
Add(AP3)
----------------
