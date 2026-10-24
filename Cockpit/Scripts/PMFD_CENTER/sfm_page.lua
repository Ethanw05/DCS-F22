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

local LOGO       = MakeMaterial(LockOn_Options.script_path.."../Scripts/IndicationTextures/22_logo.dds", BlueColor)--SYSTEM TEST
local MASK_BOX	 = MakeMaterial(LockOn_Options.script_path.."../Scripts/IndicationTextures/mask_box.dds", ScreenColor)--SYSTEM TEST
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
total_field_of_view.init_pos        = {0, 0, -0.2}
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
clipPoly.init_pos            = {0, 0, -0.2}
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
BGROUND.element_params 		= {"MFD_OPACITY","PMFD_SFM_PAGE"}--this may not be bneeded check when more pages done for backlight on page 7 SMS fc3 bs
BGROUND.controllers			= {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1}}--MENU PAGE = 1
BGROUND.level 				= 2
BGROUND.h_clip_relation     = h_clip_relations.COMPARE
vertices(BGROUND,3)
Add(BGROUND)
----------------------------------------------------------------------------------------------------------------
BLOG                    = CreateElement "ceTexPoly"
BLOG.name    			= "BG"
BLOG.material			= LOGO
BLOG.change_opacity 		= false
BLOG.collimated 			= false
BLOG.isvisible 			= true
BLOG.init_pos 			= {0, 0, 0} --L-R,U-D,F-B
BLOG.init_rot 			= {0, 0, 0}
BLOG.element_params 		= {"MFD_OPACITY","PMFD_SFM_PAGE"}--this may not be bneeded check when more pages done for backlight on page 7 SMS fc3 bs
BLOG.controllers			= {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1}}--MENU PAGE = 1
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
MENUTEXT.element_params 	        = {"MFD_OPACITY","PMFD_SFM_PAGE"}
MENUTEXT.controllers		        =   {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1}}
Add(MENUTEXT)
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
TITLE 					    = CreateElement "ceStringPoly"
TITLE.name 				    = "menu"
TITLE.material 			    = UFD_FONT
TITLE.value 				    = "F-22A SFM DATA LOG"
TITLE.stringdefs 		        = {0.0090, 0.0090, 0.0004, 0.001}
TITLE.alignment 			    = "CenterCenter"
TITLE.formats 			    = {"%s"}
TITLE.h_clip_relation         = h_clip_relations.COMPARE
TITLE.level 				    = 2
TITLE.init_pos 			    = {-0.5, 0.8, 0}
TITLE.init_rot 			    = {0, 0, 0}
TITLE.element_params 	        = {"MFD_OPACITY","PMFD_SFM_PAGE"}
TITLE.controllers		        = {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1}}
Add(TITLE)
------------------CENTER ROW
ROLL_TXT 					    = CreateElement "ceStringPoly"
ROLL_TXT.name 				    = "ROLL_TXT"
ROLL_TXT.material 			    = UFD_GRN
ROLL_TXT.value 				    = "ROLL"
ROLL_TXT.stringdefs 		        = {0.0070, 0.0070, 0.0004, 0.001}
ROLL_TXT.alignment 			    = "CenterCenter"
ROLL_TXT.formats 			    = {"%s"}
ROLL_TXT.h_clip_relation         = h_clip_relations.COMPARE
ROLL_TXT.level 				    = 2
ROLL_TXT.init_pos 			    = {0, -0.5, 0}
ROLL_TXT.init_rot 			    = {0, 0, 0}
ROLL_TXT.element_params 	        = {"MFD_OPACITY","PMFD_SFM_PAGE"}
ROLL_TXT.controllers		        = {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1}}
Add(ROLL_TXT)
----------------------------------
ROLL_NUM				        = CreateElement "ceStringPoly"
ROLL_NUM.name				    = "ROLL_NUM"
ROLL_NUM.material			    = UFD_FONT
ROLL_NUM.init_pos			    = {0, -0.7, 0} --L-R,U-D,F-B
ROLL_NUM.alignment			    = "CenterCenter"
ROLL_NUM.stringdefs			= {0.009, 0.009, 0, 0.0} --either 004 or 005
ROLL_NUM.additive_alpha		= true
ROLL_NUM.collimated			= false
ROLL_NUM.isdraw				= true	
ROLL_NUM.use_mipfilter		    = true
ROLL_NUM.h_clip_relation	    = h_clip_relations.COMPARE
ROLL_NUM.level				    = 2
--M_NUM.parent_element        = G_NUM.name
ROLL_NUM.element_params		= {"MFD_OPACITY","ROLLRATE","PMFD_SFM_PAGE"}
ROLL_NUM.formats			    = {"%02.2f"}--= {"%02.0f"}
ROLL_NUM.controllers		    =   {
                                        {"opacity_using_parameter",0},
                                        {"text_using_parameter",1,0},
                                        {"parameter_in_range",2,0.9,1.1}
                                    }
                                
Add(ROLL_NUM)
--------------
PITCH_TXT 					    = CreateElement "ceStringPoly"
PITCH_TXT.name 				    = "pitch"
PITCH_TXT.material 			    = UFD_GRN
PITCH_TXT.value 				    = "PITCH"
PITCH_TXT.stringdefs 		        = {0.0070, 0.0070, 0.0004, 0.001}
PITCH_TXT.alignment 			    = "CenterCenter"
PITCH_TXT.formats 			    = {"%s"}
PITCH_TXT.h_clip_relation         = h_clip_relations.COMPARE
PITCH_TXT.level 				    = 2
PITCH_TXT.init_pos 			    = {-0.5, 0, 0}
PITCH_TXT.init_rot 			    = {0, 0, 0}
PITCH_TXT.element_params 	        = {"MFD_OPACITY","PMFD_SFM_PAGE"}
PITCH_TXT.controllers		        = {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1}}
PITCH_TXT.parent_element            = ROLL_TXT.name
Add(PITCH_TXT)
--------------
PI_NUM				        = CreateElement "ceStringPoly"
PI_NUM.name				    = "PI_NUM"
PI_NUM.material			    = UFD_FONT
PI_NUM.init_pos			    = {-0.5, 0, 0} --L-R,U-D,F-B
PI_NUM.alignment			= "CenterCenter"
PI_NUM.stringdefs			= {0.009, 0.009, 0, 0.0} --either 004 or 005
PI_NUM.additive_alpha		= true
PI_NUM.collimated			= false
PI_NUM.isdraw				= true	
PI_NUM.use_mipfilter		= true
PI_NUM.h_clip_relation	    = h_clip_relations.COMPARE
PI_NUM.level				= 2
PI_NUM.parent_element       = ROLL_NUM.name
PI_NUM.element_params		= {"MFD_OPACITY","PITCHRATE","PMFD_SFM_PAGE"}
PI_NUM.formats			    = {"%02.2f"}--= {"%02.0f"}
PI_NUM.controllers		    =   {
                                        {"opacity_using_parameter",0},
                                        {"text_using_parameter",1,0},
                                        {"parameter_in_range",2,0.9,1.1}
                                    }
                                
Add(PI_NUM)
-------------------------------------------------
YAW_TXT 					    = CreateElement "ceStringPoly"
YAW_TXT.name 				    = "yaw"
YAW_TXT.material 			    = UFD_GRN
YAW_TXT.value 				    = "YAW"
YAW_TXT.stringdefs 		        = {0.0070, 0.0070, 0.0004, 0.001}
YAW_TXT.alignment 			    = "CenterCenter"
YAW_TXT.formats 			    = {"%s"}
YAW_TXT.h_clip_relation         = h_clip_relations.COMPARE
YAW_TXT.level 				    = 2
YAW_TXT.init_pos 			    = {0.5, 0, 0}
YAW_TXT.init_rot 			    = {0, 0, 0}
YAW_TXT.element_params 	        = {"MFD_OPACITY","PMFD_SFM_PAGE"}
YAW_TXT.controllers		        = {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1}}
YAW_TXT.parent_element            = ROLL_TXT.name
Add(YAW_TXT)
-----------------------------
Y_NUM				        = CreateElement "ceStringPoly"
Y_NUM.name				    = "Y_NUM"
Y_NUM.material			    = UFD_FONT
Y_NUM.init_pos			    = {0.5, 0, 0} --L-R,U-D,F-B
Y_NUM.alignment			    = "CenterCenter"
Y_NUM.stringdefs			= {0.009, 0.009, 0, 0.0} --either 004 or 005
Y_NUM.additive_alpha		= true
Y_NUM.collimated			= false
Y_NUM.isdraw				= true	
Y_NUM.use_mipfilter		    = true
Y_NUM.h_clip_relation	    = h_clip_relations.COMPARE
Y_NUM.level				    = 2
Y_NUM.parent_element       = ROLL_NUM.name
Y_NUM.element_params		= {"MFD_OPACITY","YAWRATE","PMFD_SFM_PAGE"}
Y_NUM.formats			    = {"%02.2f"}--= {"%02.0f"}
Y_NUM.controllers		    =   {
                                        {"opacity_using_parameter",0},
                                        {"text_using_parameter",1,0},
                                        {"parameter_in_range",2,0.9,1.1}
                                    }
                                
Add(Y_NUM)
------------------CENTER ROW
MACH_TXT 					    = CreateElement "ceStringPoly"
MACH_TXT.name 				    = "MACH_TXT"
MACH_TXT.material 			    = UFD_GRN
MACH_TXT.value 				    = "MACH"
MACH_TXT.stringdefs 		        = {0.0070, 0.0070, 0.0004, 0.001}
MACH_TXT.alignment 			    = "CenterCenter"
MACH_TXT.formats 			    = {"%s"}
MACH_TXT.h_clip_relation         = h_clip_relations.COMPARE
MACH_TXT.level 				    = 2
MACH_TXT.init_pos 			    = {0, 0, 0}
MACH_TXT.init_rot 			    = {0, 0, 0}
MACH_TXT.element_params 	        = {"MFD_OPACITY","PMFD_SFM_PAGE"}
MACH_TXT.controllers		        = {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1}}
Add(MACH_TXT)
----------------------------------
M_NUM				        = CreateElement "ceStringPoly"
M_NUM.name				    = "M_NUM"
M_NUM.material			    = UFD_FONT
M_NUM.init_pos			    = {0, -0.2, 0} --L-R,U-D,F-B
M_NUM.alignment			    = "CenterCenter"
M_NUM.stringdefs			= {0.009, 0.009, 0, 0.0} --either 004 or 005
M_NUM.additive_alpha		= true
M_NUM.collimated			= false
M_NUM.isdraw				= true	
M_NUM.use_mipfilter		    = true
M_NUM.h_clip_relation	    = h_clip_relations.COMPARE
M_NUM.level				    = 2
--M_NUM.parent_element        = G_NUM.name
M_NUM.element_params		= {"MFD_OPACITY","MACH","PMFD_SFM_PAGE"}
M_NUM.formats			    = {"%02.2f"}--= {"%02.0f"}
M_NUM.controllers		    =   {
                                        {"opacity_using_parameter",0},
                                        {"text_using_parameter",1,0},
                                        {"parameter_in_range",2,0.9,1.1}
                                    }
                                
Add(M_NUM)
--------------
IAS_TXT 					    = CreateElement "ceStringPoly"
IAS_TXT.name 				    = "pitch"
IAS_TXT.material 			    = UFD_GRN
IAS_TXT.value 				    = "IAS"
IAS_TXT.stringdefs 		        = {0.0070, 0.0070, 0.0004, 0.001}
IAS_TXT.alignment 			    = "CenterCenter"
IAS_TXT.formats 			    = {"%s"}
IAS_TXT.h_clip_relation         = h_clip_relations.COMPARE
IAS_TXT.level 				    = 2
IAS_TXT.init_pos 			    = {-0.5, 0, 0}
IAS_TXT.init_rot 			    = {0, 0, 0}
IAS_TXT.element_params 	        = {"MFD_OPACITY","PMFD_SFM_PAGE"}
IAS_TXT.controllers		        = {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1}}
IAS_TXT.parent_element            = MACH_TXT.name
Add(IAS_TXT)
----------------------------------
I_NUM				        = CreateElement "ceStringPoly"
I_NUM.name				    = "I_NUM"
I_NUM.material			    = UFD_FONT
I_NUM.init_pos			    = {-0.5, 0, 0} --L-R,U-D,F-B
I_NUM.alignment			    = "CenterCenter"
I_NUM.stringdefs			= {0.009, 0.009, 0, 0.0} --either 004 or 005
I_NUM.additive_alpha		= true
I_NUM.collimated			= false
I_NUM.isdraw				= true	
I_NUM.use_mipfilter		    = true
I_NUM.h_clip_relation	    = h_clip_relations.COMPARE
I_NUM.level				    = 2
I_NUM.parent_element        = M_NUM.name
I_NUM.element_params		= {"MFD_OPACITY","IAS","PMFD_SFM_PAGE"}
I_NUM.formats			    = {"%02.2f"}--= {"%02.0f"}
I_NUM.controllers		    =   {
                                        {"opacity_using_parameter",0},
                                        {"text_using_parameter",1,0},
                                        {"parameter_in_range",2,0.9,1.1}
                                    }
                                
Add(I_NUM)
--------------
--------------
TAS_TXT 					    = CreateElement "ceStringPoly"
TAS_TXT.name 				    = "yaw"
TAS_TXT.material 			    = UFD_GRN
TAS_TXT.value 				    = "TAS"
TAS_TXT.stringdefs 		        = {0.0070, 0.0070, 0.0004, 0.001}
TAS_TXT.alignment 			    = "CenterCenter"
TAS_TXT.formats 			    = {"%s"}
TAS_TXT.h_clip_relation         = h_clip_relations.COMPARE
TAS_TXT.level 				    = 2
TAS_TXT.init_pos 			    = {0.5, 0, 0}
TAS_TXT.init_rot 			    = {0, 0, 0}
TAS_TXT.element_params 	        = {"MFD_OPACITY","PMFD_SFM_PAGE"}
TAS_TXT.controllers		        = {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1}}
TAS_TXT.parent_element          = MACH_TXT.name
Add(TAS_TXT)
-------------------
T_NUM				        = CreateElement "ceStringPoly"
T_NUM.name				    = "I_NUM"
T_NUM.material			    = UFD_FONT
T_NUM.init_pos			    = {0.5, 0, 0} --L-R,U-D,F-B
T_NUM.alignment			    = "CenterCenter"
T_NUM.stringdefs			= {0.009, 0.009, 0, 0.0} --either 004 or 005
T_NUM.additive_alpha		= true
T_NUM.collimated			= false
T_NUM.isdraw				= true	
T_NUM.use_mipfilter		    = true
T_NUM.h_clip_relation	    = h_clip_relations.COMPARE
T_NUM.level				    = 2
T_NUM.parent_element        = M_NUM.name
T_NUM.element_params		= {"MFD_OPACITY","TAS","PMFD_SFM_PAGE"}
T_NUM.formats			    = {"%02.2f"}--= {"%02.0f"}
T_NUM.controllers		    =   {
                                        {"opacity_using_parameter",0},
                                        {"text_using_parameter",1,0},
                                        {"parameter_in_range",2,0.9,1.1}
                                    }
                                
Add(T_NUM)
------------------CENTER ROW
G_TXT 					    = CreateElement "ceStringPoly"
G_TXT.name 				    = "G_TXT"
G_TXT.material 			    = UFD_GRN
G_TXT.value 				    = "G FORCE"
G_TXT.stringdefs 		        = {0.0070, 0.0070, 0.0004, 0.001}
G_TXT.alignment 			    = "CenterCenter"
G_TXT.formats 			    = {"%s"}
G_TXT.h_clip_relation         = h_clip_relations.COMPARE
G_TXT.level 				    = 2
G_TXT.init_pos 			    = {0, 0.5, 0}
G_TXT.init_rot 			    = {0, 0, 0}
G_TXT.element_params 	        = {"MFD_OPACITY","PMFD_SFM_PAGE"}
G_TXT.controllers		        = {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1}}
Add(G_TXT)
--------------
G_NUM				    = CreateElement "ceStringPoly"
G_NUM.name				= "G_NUM"
G_NUM.material			= UFD_FONT
G_NUM.init_pos			= {0, 0.3, 0} --L-R,U-D,F-B
G_NUM.alignment			= "CenterCenter"
G_NUM.stringdefs			= {0.009, 0.009, 0, 0.0} --either 004 or 005
G_NUM.additive_alpha		= true
G_NUM.collimated			= false
G_NUM.isdraw				= true	
G_NUM.use_mipfilter		= true
G_NUM.h_clip_relation	= h_clip_relations.COMPARE
G_NUM.level				= 2
G_NUM.element_params	= {"MFD_OPACITY","GFORCE","PMFD_SFM_PAGE"}
G_NUM.formats			= {"%02.2f"}--= {"%02.0f"}
G_NUM.controllers		=   {
                                        {"opacity_using_parameter",0},
                                        {"text_using_parameter",1,0},
                                        {"parameter_in_range",2,0.9,1.1}
                                    }
                                
Add(G_NUM)
----------------------------------
AOA_TXT 					    = CreateElement "ceStringPoly"
AOA_TXT.name 				    = "pitch"
AOA_TXT.material 			    = UFD_GRN
AOA_TXT.value 				    = "AOA"
AOA_TXT.stringdefs 		        = {0.0070, 0.0070, 0.0004, 0.001}
AOA_TXT.alignment 			    = "CenterCenter"
AOA_TXT.formats 			    = {"%s"}
AOA_TXT.h_clip_relation         = h_clip_relations.COMPARE
AOA_TXT.level 				    = 2
AOA_TXT.init_pos 			    = {-0.5, 0, 0}
AOA_TXT.init_rot 			    = {0, 0, 0}
AOA_TXT.element_params 	        = {"MFD_OPACITY","PMFD_SFM_PAGE"}
AOA_TXT.controllers		        = {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1}}
AOA_TXT.parent_element            = G_TXT.name
Add(AOA_TXT)
----------------------------------
AOA_NUM				    = CreateElement "ceStringPoly"
AOA_NUM.name				= "AOA_NUM"
AOA_NUM.material			= UFD_FONT
AOA_NUM.init_pos			= {-0.5, 0, 0} --L-R,U-D,F-B
AOA_NUM.alignment			= "CenterCenter"
AOA_NUM.stringdefs			= {0.009, 0.009, 0, 0.0} --either 004 or 005
AOA_NUM.additive_alpha		= true
AOA_NUM.collimated			= false
AOA_NUM.isdraw				= true	
AOA_NUM.use_mipfilter		= true
AOA_NUM.h_clip_relation	    = h_clip_relations.COMPARE
AOA_NUM.level				= 2
AOA_NUM.parent_element      = G_NUM.name
AOA_NUM.element_params		= {"MFD_OPACITY","AOA","PMFD_SFM_PAGE"}
AOA_NUM.formats			    = {"%02.2f"}--= {"%02.0f"}
AOA_NUM.controllers		    =   {
                                        {"opacity_using_parameter",0},
                                        {"text_using_parameter",1,0},
                                        {"parameter_in_range",2,0.9,1.1}
                                    }
                                
Add(AOA_NUM)
--------------
VV_TXT 					    = CreateElement "ceStringPoly"
VV_TXT.name 				    = "yaw"
VV_TXT.material 			    = UFD_GRN
VV_TXT.value 				    = "VERT VEL"
VV_TXT.stringdefs 		        = {0.0070, 0.0070, 0.0004, 0.001}
VV_TXT.alignment 			    = "CenterCenter"
VV_TXT.formats 			        = {"%s"}
VV_TXT.h_clip_relation         = h_clip_relations.COMPARE
VV_TXT.level 				    = 2
VV_TXT.init_pos 			    = {0.5, 0, 0}
VV_TXT.init_rot 			    = {0, 0, 0}
VV_TXT.element_params 	        = {"MFD_OPACITY","PMFD_SFM_PAGE"}
VV_TXT.controllers		        = {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1}}
VV_TXT.parent_element          = G_TXT.name
Add(VV_TXT)
----------------------------------
VV_NUM				        = CreateElement "ceStringPoly"
VV_NUM.name				    = "VV_NUM"
VV_NUM.material			    = UFD_FONT
VV_NUM.init_pos			    = {0.5, 0, 0} --L-R,U-D,F-B
VV_NUM.alignment			= "CenterCenter"
VV_NUM.stringdefs			= {0.009, 0.009, 0, 0.0} --either 004 or 005
VV_NUM.additive_alpha		= true
VV_NUM.collimated			= false
VV_NUM.isdraw				= true	
VV_NUM.use_mipfilter		= true
VV_NUM.h_clip_relation	    = h_clip_relations.COMPARE
VV_NUM.level				= 2
VV_NUM.parent_element       = G_NUM.name
VV_NUM.element_params		= {"MFD_OPACITY","VV","PMFD_SFM_PAGE"}
VV_NUM.formats			    = {"%.0f"}--= {"%02.0f"}
VV_NUM.controllers		    =   {
                                        {"opacity_using_parameter",0},
                                        {"text_using_parameter",1,0},
                                        {"parameter_in_range",2,0.9,1.1}
                                    }
                                
Add(VV_NUM)
