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
local BlueColor 			= {6, 6, 15, 255}--RGBA

--local PFD_PAGE_1 = MakeMaterial(LockOn_Options.script_path.."../Scripts/IndicationTextures/pfd_page_1.dds", GreenColor)--SYSTEM TEST
--------------------------------------------------------------------------------------------------------------------------------------------
local MASK_BOX	 = MakeMaterial(LockOn_Options.script_path.."../Scripts/IndicationTextures/mask_box.dds", ScreenColor)
local LOGO       = MakeMaterial(LockOn_Options.script_path.."../Scripts/IndicationTextures/22_logo.dds", BlueColor)--SYSTEM TEST
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
BGROUND.element_params 		= {"MFD_OPACITY","PMFD_CONFIG_PAGE"}--this may not be bneeded check when more pages done for backlight on page 7 SMS fc3 bs
BGROUND.controllers			= {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1}}--MENU PAGE = 1
BGROUND.level 				= 2
BGROUND.h_clip_relation     = h_clip_relations.COMPARE
vertices(BGROUND,3)
Add(BGROUND)
-------------------------------------------------------------------------------------------------------------------------------------------------
BLOG                    = CreateElement "ceTexPoly"
BLOG.name    			= "BG"
BLOG.material			= LOGO
BLOG.change_opacity 	= false
BLOG.collimated 		= false
BLOG.isvisible 			= true
BLOG.init_pos 			= {0, 0, 0} --L-R,U-D,F-B
BLOG.init_rot 			= {0, 0, 0}
BLOG.element_params 	= {"MFD_OPACITY","PMFD_CONFIG_PAGE"}--this may not be bneeded check when more pages done for backlight on page 7 SMS fc3 bs
BLOG.controllers		= {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1}}--MENU PAGE = 1
BLOG.level 				= 2
BLOG.h_clip_relation     = h_clip_relations.COMPARE
vertices(BLOG,2.2)
Add(BLOG)
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
MENUTEXT.element_params 	    = {"MFD_OPACITY","PMFD_CONFIG_PAGE"}
MENUTEXT.controllers		    =   {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1}}
Add(MENUTEXT)
----------------------------------------------------------------------------------------------------------------
PH_TEXT 					    = CreateElement "ceStringPoly"
PH_TEXT.name 				    = "menu"
PH_TEXT.material 			    = UFD_GRN
PH_TEXT.value 				    = "CONFIG MENU"
PH_TEXT.stringdefs 		        = {0.0050, 0.0050, 0.0004, 0.001}
PH_TEXT.alignment 			    = "CenterCenter"
PH_TEXT.formats 			    = {"%s"}
PH_TEXT.h_clip_relation         = h_clip_relations.COMPARE
PH_TEXT.level 				    = 2
PH_TEXT.init_pos 			    = {0, 0.8, 0}
PH_TEXT.init_rot 			    = {0, 0, 0}
PH_TEXT.element_params 	        = {"MFD_OPACITY","PMFD_CONFIG_PAGE","WoW"}
PH_TEXT.controllers		        = {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1},{"parameter_in_range",2,0.9,1.1}}
Add(PH_TEXT)
----------------------------------------------------------------------------------------------------------------
PH1_TEXT 					    = CreateElement "ceStringPoly"
PH1_TEXT.name 				    = "menu"
PH1_TEXT.material 			    = UFD_RED
PH1_TEXT.value 				    = "WEIGHT ON WHEELS REQUIRED TO USE CONFIG MENU"
PH1_TEXT.stringdefs 		    = {0.0050, 0.0050, 0.0004, 0.001}
PH1_TEXT.alignment 			    = "CenterCenter"
PH1_TEXT.formats 			    = {"%s"}
PH1_TEXT.h_clip_relation        = h_clip_relations.COMPARE
PH1_TEXT.level 				    = 2
PH1_TEXT.init_pos 			    = {0, 0, 0}
PH1_TEXT.init_rot 			    = {0, 0, 0}
PH1_TEXT.element_params 	    = {"MFD_OPACITY","PMFD_CONFIG_PAGE","WoW"}
PH1_TEXT.controllers		    = {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1},{"parameter_in_range",2,-0.1,0.1}}
Add(PH1_TEXT)
----------------------------------------------------------------------------------------------------------------
C1_TXT 					        = CreateElement "ceStringPoly"
C1_TXT.name 				    = "menu"
C1_TXT.material 			    = UFD_GRN
C1_TXT.value 				    = "CANOPY GOLD TINT "
--C1_TXT.value 				    = "CANOPY NO TINT   "
--C1_TXT.value 				    = "CANOPY BLACK TINT"
C1_TXT.stringdefs 		        = {0.0050, 0.0050, 0.0004, 0.001}
C1_TXT.alignment 			    = "CenterCenter"
C1_TXT.formats 			        = {"%s"}
C1_TXT.h_clip_relation          = h_clip_relations.COMPARE
C1_TXT.level 				    = 2
C1_TXT.init_pos 			    = {-0.74,0.535, 0}
C1_TXT.init_rot 			    = {0, 0, 0}
C1_TXT.element_params 	        = {"MFD_OPACITY","PMFD_CONFIG_PAGE","WoW","TINT"}
C1_TXT.controllers		        = {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1},{"parameter_in_range",2,0.9,1.1},{"parameter_in_range",3,-0.1,0.1}}
Add(C1_TXT)
----------------------------------------------------------------------------------------------------------------
C5_TXT 					        = CreateElement "ceStringPoly"
C5_TXT.name 				    = "menu"
C5_TXT.material 			    = UFD_GRN
C5_TXT.value 				    = "CANOPY BLACK TINT"
C5_TXT.stringdefs 		        = {0.0050, 0.0050, 0.0004, 0.001}
C5_TXT.alignment 			    = "CenterCenter"
C5_TXT.formats 			        = {"%s"}
C5_TXT.h_clip_relation          = h_clip_relations.COMPARE
C5_TXT.level 				    = 2
C5_TXT.init_pos 			    = {-0.74,0.535, 0}
C5_TXT.init_rot 			    = {0, 0, 0}
C5_TXT.element_params 	        = {"MFD_OPACITY","PMFD_CONFIG_PAGE","WoW","TINT"}
C5_TXT.controllers		        = {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1},{"parameter_in_range",2,0.9,1.1},{"parameter_in_range",3,0.4,0.6}}
Add(C5_TXT)
----------------------------------------------------------------------------------------------------------------
C6_TXT 					        = CreateElement "ceStringPoly"
C6_TXT.name 				    = "menu"
C6_TXT.material 			    = UFD_GRN
--C6_TXT.value 				    = "CANOPY BLACK TINT"
C6_TXT.value 				    = "CANOPY NO TINT   "
C6_TXT.stringdefs 		        = {0.0050, 0.0050, 0.0004, 0.001}
C6_TXT.alignment 			    = "CenterCenter"
C6_TXT.formats 			        = {"%s"}
C6_TXT.h_clip_relation          = h_clip_relations.COMPARE
C6_TXT.level 				    = 2
C6_TXT.init_pos 			    = {-0.74,0.535, 0}
C6_TXT.init_rot 			    = {0, 0, 0}
C6_TXT.element_params 	        = {"MFD_OPACITY","PMFD_CONFIG_PAGE","WoW","TINT"}
C6_TXT.controllers		        = {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1},{"parameter_in_range",2,0.9,1.1},{"parameter_in_range",3,0.9,1.1}}
Add(C6_TXT)
----------------------------------------------------------------------------------------------------------------
V1_TXT 					        = CreateElement "ceStringPoly"
V1_TXT.name 				    = "menu"
V1_TXT.material 			    = UFD_GRN
V1_TXT.value 				    = "VISOR MIRROR TINT" --= "FLOOD COLOR GREEN"
V1_TXT.stringdefs 		        = {0.0050, 0.0050, 0.0004, 0.001}
V1_TXT.alignment 			    = "CenterCenter"
V1_TXT.formats 			        = {"%s"}
V1_TXT.h_clip_relation          = h_clip_relations.COMPARE
V1_TXT.level 				    = 2
V1_TXT.init_pos 			    = {-0.74,0.225, 0} --= {-0.75,0.225, 0}
V1_TXT.init_rot 			    = {0, 0, 0}
V1_TXT.element_params 	        = {"MFD_OPACITY","PMFD_CONFIG_PAGE","WoW","VISOR"}
V1_TXT.controllers		        = {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1},{"parameter_in_range",2,0.9,1.1},{"parameter_in_range",3,-0.1,0.05}}
Add(V1_TXT)
----------------------------------------------------------------------------------------------------------------
V2_TXT 					        = CreateElement "ceStringPoly"
V2_TXT.name 				    = "menu"
V2_TXT.material 			    = UFD_GRN
V2_TXT.value 				    = "VISOR GOLD TINT  " --= "FLOOD COLOR GREEN"
V2_TXT.stringdefs 		        = {0.0050, 0.0050, 0.0004, 0.001}
V2_TXT.alignment 			    = "CenterCenter"
V2_TXT.formats 			        = {"%s"}
V2_TXT.h_clip_relation          = h_clip_relations.COMPARE
V2_TXT.level 				    = 2
V2_TXT.init_pos 			    = {-0.74,0.225, 0} --= {-0.75,0.225, 0}
V2_TXT.init_rot 			    = {0, 0, 0}
V2_TXT.element_params 	        = {"MFD_OPACITY","PMFD_CONFIG_PAGE","WoW","VISOR"}
V2_TXT.controllers		        = {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1},{"parameter_in_range",2,0.9,1.1},{"parameter_in_range",3,0.05,0.15}}
Add(V2_TXT)
----------------------------------------------------------------------------------------------------------------
V3_TXT 					        = CreateElement "ceStringPoly"
V3_TXT.name 				    = "menu"
V3_TXT.material 			    = UFD_GRN
V3_TXT.value 				    = "VISOR BLACK TINT " --= "FLOOD COLOR GREEN"
V3_TXT.stringdefs 		        = {0.0050, 0.0050, 0.0004, 0.001}
V3_TXT.alignment 			    = "CenterCenter"
V3_TXT.formats 			        = {"%s"}
V3_TXT.h_clip_relation          = h_clip_relations.COMPARE
V3_TXT.level 				    = 2
V3_TXT.init_pos 			    = {-0.74,0.225, 0} --= {-0.75,0.225, 0}
V3_TXT.init_rot 			    = {0, 0, 0}
V3_TXT.element_params 	        = {"MFD_OPACITY","PMFD_CONFIG_PAGE","WoW","VISOR"}
V3_TXT.controllers		        = {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1},{"parameter_in_range",2,0.9,1.1},{"parameter_in_range",3,0.15,0.25}}
Add(V3_TXT)
----------------------------------------------------------------------------------------------------------------
V4_TXT 					        = CreateElement "ceStringPoly"
V4_TXT.name 				    = "menu"
V4_TXT.material 			    = UFD_GRN
V4_TXT.value 				    = "VISOR CLEAR GLASS" --= "FLOOD COLOR GREEN"
V4_TXT.stringdefs 		        = {0.0050, 0.0050, 0.0004, 0.001}
V4_TXT.alignment 			    = "CenterCenter"
V4_TXT.formats 			        = {"%s"}
V4_TXT.h_clip_relation          = h_clip_relations.COMPARE
V4_TXT.level 				    = 2
V4_TXT.init_pos 			    = {-0.74,0.225, 0} --= {-0.75,0.225, 0}
V4_TXT.init_rot 			    = {0, 0, 0}
V4_TXT.element_params 	        = {"MFD_OPACITY","PMFD_CONFIG_PAGE","WoW","VISOR"}
V4_TXT.controllers		        = {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1},{"parameter_in_range",2,0.9,1.1},{"parameter_in_range",3,0.25,0.35}}
Add(V4_TXT)
----------------------------------------------------------------------------------------------------------------
V5_TXT 					        = CreateElement "ceStringPoly"
V5_TXT.name 				    = "menu"
V5_TXT.material 			    = UFD_GRN
V5_TXT.value 				    = "AVIATOR GLASSES  " --= "FLOOD COLOR GREEN"  VISOR CLEAR GLASS AVIATOR GLASSES
V5_TXT.stringdefs 		        = {0.0050, 0.0050, 0.0004, 0.001}
V5_TXT.alignment 			    = "CenterCenter"
V5_TXT.formats 			        = {"%s"}
V5_TXT.h_clip_relation          = h_clip_relations.COMPARE
V5_TXT.level 				    = 2
V5_TXT.init_pos 			    = {-0.74,0.225, 0} --= {-0.75,0.225, 0}
V5_TXT.init_rot 			    = {0, 0, 0}
V5_TXT.element_params 	        = {"MFD_OPACITY","PMFD_CONFIG_PAGE","WoW","VISOR"}
V5_TXT.controllers		        = {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1},{"parameter_in_range",2,0.9,1.1},{"parameter_in_range",3,0.35,0.45}}
Add(V5_TXT)
----------------------------------------------------------------------------------------------------------------
F1_TXT 					        = CreateElement "ceStringPoly"
F1_TXT.name 				    = "menu"
F1_TXT.material 			    = UFD_GRN
F1_TXT.value 				    = "FLOOD COLOR GREEN"
F1_TXT.stringdefs 		        = {0.0050, 0.0050, 0.0004, 0.001}
F1_TXT.alignment 			    = "CenterCenter"
F1_TXT.formats 			        = {"%s"}
F1_TXT.h_clip_relation          = h_clip_relations.COMPARE
F1_TXT.level 				    = 2
F1_TXT.init_pos 			    = {-0.74,-0.080, 0} --= {-0.75,0.225, 0}
F1_TXT.init_rot 			    = {0, 0, 0}
F1_TXT.element_params 	        = {"MFD_OPACITY","PMFD_CONFIG_PAGE","WoW","FLOOD_COLOR"}
F1_TXT.controllers		        = {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1},{"parameter_in_range",2,0.9,1.1},{"parameter_in_range",3,-0.1,0.1}}
Add(F1_TXT)
----------------------------------------------------------------------------------------------------------------
F2_TXT 					        = CreateElement "ceStringPoly"
F2_TXT.name 				    = "menu"
F2_TXT.material 			    = UFD_BLUE
F2_TXT.value 				    = "FLOOD COLOR BLUE "
F2_TXT.stringdefs 		        = {0.0050, 0.0050, 0.0004, 0.001}
F2_TXT.alignment 			    = "CenterCenter"
F2_TXT.formats 			        = {"%s"}
F2_TXT.h_clip_relation          = h_clip_relations.COMPARE
F2_TXT.level 				    = 2
F2_TXT.init_pos 			    = {-0.74,-0.080, 0} --= {-0.75,0.225, 0}
F2_TXT.init_rot 			    = {0, 0, 0}
F2_TXT.element_params 	        = {"MFD_OPACITY","PMFD_CONFIG_PAGE","WoW","FLOOD_COLOR"}
F2_TXT.controllers		        = {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1},{"parameter_in_range",2,0.9,1.1},{"parameter_in_range",3,0.1,0.3}}
Add(F2_TXT)
----------------------------------------------------------------------------------------------------------------
F3_TXT 					        = CreateElement "ceStringPoly"
F3_TXT.name 				    = "menu"
F3_TXT.material 			    = UFD_RED
F3_TXT.value 				    = "FLOOD COLOR RED  "
F3_TXT.stringdefs 		        = {0.0050, 0.0050, 0.0004, 0.001}
F3_TXT.alignment 			    = "CenterCenter"
F3_TXT.formats 			        = {"%s"}
F3_TXT.h_clip_relation          = h_clip_relations.COMPARE
F3_TXT.level 				    = 2
F3_TXT.init_pos 			    = {-0.74,-0.080, 0} 
F3_TXT.init_rot 			    = {0, 0, 0}
F3_TXT.element_params 	        = {"MFD_OPACITY","PMFD_CONFIG_PAGE","WoW","FLOOD_COLOR"}
F3_TXT.controllers		        = {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1},{"parameter_in_range",2,0.9,1.1},{"parameter_in_range",3,0.3,0.5}}
Add(F3_TXT)
----------------------------------------------------------------------------------------------------------------
F4_TXT 					        = CreateElement "ceStringPoly"
F4_TXT.name 				    = "menu"
F4_TXT.material 			    = UFD_FONT
F4_TXT.value 				    = "FLOOD COLOR WHITE"
F4_TXT.stringdefs 		        = {0.0050, 0.0050, 0.0004, 0.001}
F4_TXT.alignment 			    = "CenterCenter"
F4_TXT.formats 			        = {"%s"}
F4_TXT.h_clip_relation          = h_clip_relations.COMPARE
F4_TXT.level 				    = 2
F4_TXT.init_pos 			    = {-0.74,-0.080, 0} 
F4_TXT.init_rot 			    = {0, 0, 0}
F4_TXT.element_params 	        = {"MFD_OPACITY","PMFD_CONFIG_PAGE","WoW","FLOOD_COLOR"}
F4_TXT.controllers		        = {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1},{"parameter_in_range",2,0.9,1.1},{"parameter_in_range",3,0.5,0.7}}
Add(F4_TXT)

----------------------------------------------------------------------------------------------------------------
P1_TXT 					        = CreateElement "ceStringPoly"
P1_TXT.name 				    = "menu"
P1_TXT.material 			    = UFD_YEL
P1_TXT.value 				    = "FAMILY PHOTO OFF"
P1_TXT.stringdefs 		        = {0.0050, 0.0050, 0.0004, 0.001}
P1_TXT.alignment 			    = "CenterCenter"
P1_TXT.formats 			        = {"%s"}
P1_TXT.h_clip_relation          = h_clip_relations.COMPARE
P1_TXT.level 				    = 2
P1_TXT.init_pos 			    = {-0.75,-0.39, 0}
P1_TXT.init_rot 			    = {0, 0, 0}
P1_TXT.element_params 	        = {"MFD_OPACITY","PMFD_CONFIG_PAGE","WoW","PHOTO"}
P1_TXT.controllers		        = {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1},{"parameter_in_range",2,0.9,1.1},{"parameter_in_range",3,-0.1,0.1}}
Add(P1_TXT)
----------------------------------------------------------------------------------------------------------------
P2_TXT 					        = CreateElement "ceStringPoly"
P2_TXT.name 				    = "menu"
P2_TXT.material 			    = UFD_GRN
P2_TXT.value 				    = "FAMILY PHOTO ON "
P2_TXT.stringdefs 		        = {0.0050, 0.0050, 0.0004, 0.001}
P2_TXT.alignment 			    = "CenterCenter"
P2_TXT.formats 			        = {"%s"}
P2_TXT.h_clip_relation          = h_clip_relations.COMPARE
P2_TXT.level 				    = 2
P2_TXT.init_pos 			    = {-0.75,-0.39, 0}--= {-0.75,-0.080, 0}
P2_TXT.init_rot 			    = {0, 0, 0}
P2_TXT.element_params 	        = {"MFD_OPACITY","PMFD_CONFIG_PAGE","WoW","PHOTO"}
P2_TXT.controllers		        = {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1},{"parameter_in_range",2,0.9,1.1},{"parameter_in_range",3,0.9,1.1}}
Add(P2_TXT)
----------------------------------------------------------------------------------------------------------------
C2_TXT 					        = CreateElement "ceStringPoly"
C2_TXT.name 				    = "menu"
C2_TXT.material 			    = UFD_YEL
C2_TXT.value 				    = "WINDOW CLING OFF"
C2_TXT.stringdefs 		        = {0.0050, 0.0050, 0.0004, 0.001}
C2_TXT.alignment 			    = "CenterCenter"
C2_TXT.formats 			        = {"%s"}
C2_TXT.h_clip_relation          = h_clip_relations.COMPARE
C2_TXT.level 				    = 2
C2_TXT.init_pos 			    = {-0.75,-0.70, 0}
C2_TXT.init_rot 			    = {0, 0, 0}
C2_TXT.element_params 	        = {"MFD_OPACITY","PMFD_CONFIG_PAGE","WoW","GARFIELD"}
C2_TXT.controllers		        = {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1},{"parameter_in_range",2,0.9,1.1},{"parameter_in_range",3,-0.1,0.1}}
Add(C2_TXT)
----------------------------------------------------------------------------------------------------------------
C3_TXT 					        = CreateElement "ceStringPoly"
C3_TXT.name 				    = "menu"
C3_TXT.material 			    = UFD_GRN
C3_TXT.value 				    = "WINDOW CLING ON "
C3_TXT.stringdefs 		        = {0.0050, 0.0050, 0.0004, 0.001}
C3_TXT.alignment 			    = "CenterCenter"
C3_TXT.formats 			        = {"%s"}
C3_TXT.h_clip_relation          = h_clip_relations.COMPARE
C3_TXT.level 				    = 2
C3_TXT.init_pos 			    = {-0.75,-0.70, 0}--C3_TXT.init_pos 			    = {-0.75,-0.39, 0}
C3_TXT.init_rot 			    = {0, 0, 0}
C3_TXT.element_params 	        = {"MFD_OPACITY","PMFD_CONFIG_PAGE","WoW","GARFIELD"}
C3_TXT.controllers		        = {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1},{"parameter_in_range",2,0.9,1.1},{"parameter_in_range",3,0.9,1.1}}
Add(C3_TXT)
