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


dofile(LockOn_Options.script_path.."PMFD_CENTER/definitions.lua")
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

local BGColor  				= {255, 255, 255, 180}--RGBA
local MainColor 			= {255, 255, 255, 255}--RGBA
local GreenColor 		    = {0, 255, 0, 255}--RGBA
local WhiteColor 			= {255, 255, 255, 255}--RGBA
local RedColor 				= {255, 0, 0, 255}--RGBA
local ScreenColor			= {3, 3, 12, 255}--RGBA 5-5-5
--------------------------------------------------------------------------------------------------------------------------------------------
local MASK_BOX	 = MakeMaterial(LockOn_Options.script_path.."../Scripts/IndicationTextures/mask_box.dds", ScreenColor)
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
total_field_of_view.init_rot        = { 0, 0,0} -- degree NOT rad
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
BGROUND.element_params 		= {"MFD_OPACITY","PMFD_MENU_PAGE"}--this may not be bneeded check when more pages done for backlight on page 7 SMS fc3 bs
BGROUND.controllers			= {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1}}--MENU PAGE = 1
BGROUND.level 				= 2
BGROUND.h_clip_relation     = h_clip_relations.COMPARE
vertices(BGROUND,3)
Add(BGROUND)
----------------------------------------------------------------------------------------------------------------
MENU_TEXT 					        = CreateElement "ceStringPoly"
MENU_TEXT.name 				        = "menu"
MENU_TEXT.material 			        = UFD_GRN
MENU_TEXT.value 				    = "PMFD MAIN MENU"
MENU_TEXT.stringdefs 		        = {0.0050, 0.0050, 0.0004, 0.001}
MENU_TEXT.alignment 			    = "CenterCenter"
MENU_TEXT.formats 			        = {"%s"}
MENU_TEXT.h_clip_relation           = h_clip_relations.COMPARE
MENU_TEXT.level 				    = 2
MENU_TEXT.init_pos 			        = {0, 0, 0}
MENU_TEXT.init_rot 			        = {0, 0, 0}
MENU_TEXT.element_params 	        = {"MFD_OPACITY","PMFD_MENU_PAGE"}
MENU_TEXT.controllers		        = {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1}}
Add(MENU_TEXT)
----------------------------------------------------------------------------------------------------------------
GD 					        = CreateElement "ceStringPoly"
GD.name 				    = "menu"
GD.material 			    = UFD_GRN
GD.value 				    = "GRINNELLIDESIGNS F22 RAPTOR V3.0"
GD.stringdefs 		        = {0.0050, 0.0050, 0.0004, 0.001}
GD.alignment 			    = "CenterCenter"
GD.formats 			        = {"%s"}
GD.h_clip_relation          = h_clip_relations.COMPARE
GD.level 				    = 2
GD.init_pos 			    = {0, -0.1, 0}
GD.init_rot 			    = {0, 0, 0}
GD.element_params 	        = {"MFD_OPACITY","PMFD_MENU_PAGE"}
GD.controllers		        = {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1}}
Add(GD)
----------------------------------------------------------------------------------------------------------------
MOD 					        = CreateElement "ceStringPoly"
MOD.name 				    = "menu"
MOD.material 			    = UFD_GRN
MOD.value 				    = "WWW.GRINNELLIDESIGNS.COM"
MOD.stringdefs 		        = {0.0050, 0.0050, 0.0004, 0.001}
MOD.alignment 			    = "CenterCenter"
MOD.formats 			        = {"%s"}
MOD.h_clip_relation          = h_clip_relations.COMPARE
MOD.level 				    = 2
MOD.init_pos 			    = {0, -0.2, 0}
MOD.init_rot 			    = {0, 0, 0}
MOD.element_params 	        = {"MFD_OPACITY","PMFD_MENU_PAGE"}
MOD.controllers		        = {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1}}
Add(MOD)
----------------------------------------------------------------------------------------------------------------
RDRTEXT 					    = CreateElement "ceStringPoly"
RDRTEXT.name 				    = "menu"
RDRTEXT.material 			    = UFD_YEL
RDRTEXT.value 				    = "RDR"
RDRTEXT.stringdefs 		        = {0.0050, 0.0050, 0.0004, 0.001}
RDRTEXT.alignment 			    = "CenterCenter"
RDRTEXT.formats 			    = {"%s"}
RDRTEXT.h_clip_relation         = h_clip_relations.COMPARE
RDRTEXT.level 				    = 2
RDRTEXT.init_pos 			    = {0.01,-0.975, 0}
RDRTEXT.init_rot 			    = {0, 0, 0}
RDRTEXT.element_params 	        = {"MFD_OPACITY","PMFD_MENU_PAGE"}
RDRTEXT.controllers		        =   {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1}}
Add(RDRTEXT)
----------------------------------------------------------------------------------------------------------------
SFMTEXT 					    = CreateElement "ceStringPoly"
SFMTEXT.name 				    = "menu"
SFMTEXT.material 			    = UFD_YEL
SFMTEXT.value 				    = "SFM"
SFMTEXT.stringdefs 		        = {0.0050, 0.0050, 0.0004, 0.001}
SFMTEXT.alignment 			    = "CenterCenter"
SFMTEXT.formats 			    = {"%s"}
SFMTEXT.h_clip_relation         = h_clip_relations.COMPARE
SFMTEXT.level 				    = 2
SFMTEXT.init_pos 			    = {0.62,-0.975, 0}
SFMTEXT.init_rot 			    = {0, 0, 0}
SFMTEXT.element_params 	        = {"MFD_OPACITY","PMFD_MENU_PAGE"}
SFMTEXT.controllers		        =   {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1}}
Add(SFMTEXT)
----------------------------------------------------------------------------------------------------------------
MENUTEXT 					    = CreateElement "ceStringPoly"
MENUTEXT.name 				    = "menu"
MENUTEXT.material 			    = UFD_FONT
MENUTEXT.value 				    = "MENU"
MENUTEXT.stringdefs 		    = {0.0050, 0.0050, 0.0004, 0.001}
MENUTEXT.alignment 			    = "CenterCenter"
MENUTEXT.formats 			    = {"%s"}
MENUTEXT.h_clip_relation        = h_clip_relations.COMPARE
MENUTEXT.level 				    = 2
MENUTEXT.init_pos 			    = {-0.61,-0.975, 0}
MENUTEXT.init_rot 			    = {0, 0, 0}
MENUTEXT.element_params 	        = {"MFD_OPACITY","PMFD_MENU_PAGE"}
MENUTEXT.controllers		        =   {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1}}
Add(MENUTEXT)
----------------------------------------------------------------------------------------------------------------
MAPTEXT 					    = CreateElement "ceStringPoly"
MAPTEXT.name 				    = "menu"
MAPTEXT.material 			    = UFD_YEL
MAPTEXT.value 				    = "TID" --changed it for a meme
MAPTEXT.stringdefs 		        = {0.0050, 0.0050, 0.0004, 0.001}
MAPTEXT.alignment 			    = "CenterCenter"
MAPTEXT.formats 			    = {"%s"}
MAPTEXT.h_clip_relation         = h_clip_relations.COMPARE
MAPTEXT.level 				    = 2
MAPTEXT.init_pos 			    = {-0.30,-0.975, 0}
MAPTEXT.init_rot 			    = {0, 0, 0}
MAPTEXT.element_params 	        = {"MFD_OPACITY","PMFD_MENU_PAGE"}
MAPTEXT.controllers		        =   {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1}}
Add(MAPTEXT)
----------------------------------------------------------------------------------------------------------------
SYSTEXT 					    = CreateElement "ceStringPoly"
SYSTEXT.name 				    = "menu"
SYSTEXT.material 			    = UFD_YEL
SYSTEXT.value 				    = "SYS"
SYSTEXT.stringdefs 		        = {0.0050, 0.0050, 0.0004, 0.001}
SYSTEXT.alignment 			    = "CenterCenter"
SYSTEXT.formats 			    = {"%s"}
SYSTEXT.h_clip_relation         = h_clip_relations.COMPARE
SYSTEXT.level 				    = 2
SYSTEXT.init_pos 			    = {0.31,-0.975, 0}
SYSTEXT.init_rot 			    = {0, 0, 0}
SYSTEXT.element_params 	        = {"MFD_OPACITY","PMFD_MENU_PAGE"}
SYSTEXT.controllers		        =   {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1}}
Add(SYSTEXT)
-------------------------------------------------------------------------------------------------------------------
CONFIG_TXT 					        = CreateElement "ceStringPoly"
CONFIG_TXT.name 				    = "menu"
CONFIG_TXT.material 			    = UFD_YEL
CONFIG_TXT.value 				    = "CONFIG"
CONFIG_TXT.stringdefs 		        = {0.0050, 0.0050, 0.0004, 0.001}
CONFIG_TXT.alignment 			    = "CenterCenter"
CONFIG_TXT.formats 			        = {"%s"}
CONFIG_TXT.h_clip_relation          = h_clip_relations.COMPARE
CONFIG_TXT.level 				    = 2
CONFIG_TXT.init_pos 			    = {-0.92,-0.70, 0}
CONFIG_TXT.init_rot 			    = {0, 0, 0}
CONFIG_TXT.element_params 	        = {"MFD_OPACITY","PMFD_MENU_PAGE"}
CONFIG_TXT.controllers		        =   {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1}}
Add(CONFIG_TXT)
