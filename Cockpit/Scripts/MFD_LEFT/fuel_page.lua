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
        width = 0.98
    end

    if half_or_double == false then
        width = 0.12 --change this 
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
local TealColor 			= {0, 255, 255, 255}--RGBA
local ScreenColor			= {3, 3, 12, 255}--RGBA DO NOT TOUCH 3-3-12-255 is good for on screen
--------------------------------------------------------------------------------------------------------------------------------------------
local FUEL_MASK     = MakeMaterial(LockOn_Options.script_path.."../Scripts/IndicationTextures/fuel_mask.dds", BlackColor)--SYSTEM TEST
local FUEL_BOX      = MakeMaterial(LockOn_Options.script_path.."../Scripts/IndicationTextures/fuel_box.dds", BlackColor)--SYSTEM TEST
local FUEL_IND      = MakeMaterial(LockOn_Options.script_path.."../Scripts/IndicationTextures/fuel_ind.dds", WhiteColor)--SYSTEM TEST
local FUEL_PAGE     = MakeMaterial(LockOn_Options.script_path.."../Scripts/IndicationTextures/fuel_frame.dds", GreenColor)--SYSTEM TEST

local FUEL_BOX_BL   = MakeMaterial(LockOn_Options.script_path.."../Scripts/IndicationTextures/fuel_box.dds", ScreenColor)--SYSTEM TEST
local FUEL_MASK_BL  = MakeMaterial(LockOn_Options.script_path.."../Scripts/IndicationTextures/fuel_mask.dds", ScreenColor)--SYSTEM TEST
local MASK_BOX	    = MakeMaterial(LockOn_Options.script_path.."../Scripts/IndicationTextures/mask_box.dds", ScreenColor)--SYSTEM TEST
--local TOP_MASK	    = MakeMaterial(LockOn_Options.script_path.."../Scripts/IndicationTextures/fuel_mask_top.dds", ScreenColor)--SYSTEM TEST
local TEAL  	    = MakeMaterial(LockOn_Options.script_path.."../Scripts/IndicationTextures/mask_box.dds", TealColor)--SYSTEM TEST
local FUEL_IQT  	= MakeMaterial(LockOn_Options.script_path.."../Scripts/IndicationTextures/fuel_iqt.dds", TealColor)--SYSTEM TEST
local FUEL_TQT  	= MakeMaterial(LockOn_Options.script_path.."../Scripts/IndicationTextures/fuel_tqt.dds", TealColor)--SYSTEM TEST
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
-----------------------------------------------------------------------------------------BASE BACKLIGHT
BGROUND                    = CreateElement "ceTexPoly"
BGROUND.name    			= "BG"
BGROUND.material			= MASK_BOX
BGROUND.change_opacity 		= false
BGROUND.collimated 			= false
BGROUND.isvisible 			= true
BGROUND.init_pos 			= {0, 0, 0} --L-R,U-D,F-B
BGROUND.init_rot 			= {0, 0, 0}
BGROUND.element_params 		= {"MFD_OPACITY","LMFD_FUEL_PAGE"}--this may not be bneeded check when more pages done for backlight on page 7 RWR fc3 bs
BGROUND.controllers			= {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1}}--MENU PAGE = 1
BGROUND.level 				= 2
BGROUND.h_clip_relation     = h_clip_relations.COMPARE
vertices(BGROUND,2)
Add(BGROUND)
-----------------------------------------------------------------------------------------------TEAL FUEL QUANT------------------------------------------------------------------------------------------------
FUELQTY                    = CreateElement "ceTexPoly"
FUELQTY.name    			= "BG"
FUELQTY.material			= FUEL_IQT
FUELQTY.change_opacity 		= false
FUELQTY.collimated 			= false
FUELQTY.isvisible 			= true
FUELQTY.init_pos 			= {0, -1.359, 0} --L-R,U-D,F-B
FUELQTY.init_rot 			= {0, 0, 0}
--FUELQTY.element_params 		= {"MFD_OPACITY","LMFD_FUEL_PAGE"}--this may not be bneeded check when more pages done for backlight on page 7 RWR fc3 bs
FUELQTY.element_params 		= {"MFD_OPACITY","LMFD_FUEL_PAGE","FUEL"}--this may not be bneeded check when more pages done for backlight on page 7 RWR fc3 bs
FUELQTY.controllers			= {
                                {"opacity_using_parameter",0},
                                {"parameter_in_range",1,0.9,1.1},
                                {"move_up_down_using_parameter",2,0.00000780,0} --{"move_up_down_using_parameter",2,0.00000601,0} 
                            }
FUELQTY.level 				= 2
FUELQTY.h_clip_relation     = h_clip_relations.COMPARE
vertices(FUELQTY,2)
Add(FUELQTY)
-----------------------------------------------------------------------------------------------TEAL FUEL QUANT2------------------------------------------------------------------------------------------------
FUELQTY2                    = CreateElement "ceTexPoly"
FUELQTY2.name    			= "BG"
FUELQTY2.material			= FUEL_IQT
FUELQTY2.change_opacity 		= false
FUELQTY2.collimated 			= false
FUELQTY2.isvisible 			= true
FUELQTY2.init_pos 			= {0, -2.715, 0} --L-R,U-D,F-B {0, -2.7166, 0} --L-R,U-D,F-B
FUELQTY2.init_rot 			= {0, 0, 0}
--FUELQTY.element_params 		= {"MFD_OPACITY","LMFD_FUEL_PAGE"}--this may not be bneeded check when more pages done for backlight on page 7 RWR fc3 bs
FUELQTY2.element_params 		= {"MFD_OPACITY","LMFD_FUEL_PAGE","FUEL"}--this may not be bneeded check when more pages done for backlight on page 7 RWR fc3 bs
FUELQTY2.controllers			= {
                                {"opacity_using_parameter",0},
                                {"parameter_in_range",1,0.9,1.1},
                                {"move_up_down_using_parameter",2,0.00000780,0}
                            }
FUELQTY2.level 				= 2
FUELQTY2.h_clip_relation     = h_clip_relations.COMPARE
vertices(FUELQTY2,2)
Add(FUELQTY2)
-----------------------------------------------------------------------------------------------TEAL-FUEL-TANK-QUANT------------------------------------------------------------------------------------------------
FUELQTY_TANK                        = CreateElement "ceTexPoly"
FUELQTY_TANK.name    			    = "BG"
FUELQTY_TANK.material			    = FUEL_TQT
FUELQTY_TANK.change_opacity 	    = false
FUELQTY_TANK.collimated 		    = false
FUELQTY_TANK.isvisible 		        = true
FUELQTY_TANK.init_pos 			    = {0, -0.475, 0} --L-R,U-D,F-B
FUELQTY_TANK.init_rot 			    = {0, 0, 0}
--FUELQTY_TANK.element_params 	    = {"MFD_OPACITY","LMFD_FUEL_PAGE"}--this may not be bneeded check when more pages done for backlight on page 7 RWR fc3 bs
FUELQTY_TANK.element_params 	    = {"MFD_OPACITY","LMFD_FUEL_PAGE","FUELT"}--this may not be bneeded check when more pages done for backlight on page 7 RWR fc3 bs
FUELQTY_TANK.controllers		    =   {
                                            {"opacity_using_parameter",0},
                                            {"parameter_in_range",1,0.9,1.1},
                                            {"move_up_down_using_parameter",2,0.00000445,0}--{"move_up_down_using_parameter",2,0.00000445,0} was 870
                                        }
FUELQTY_TANK.level 			        = 2
FUELQTY_TANK.h_clip_relation        = h_clip_relations.COMPARE
vertices(FUELQTY_TANK,2)
Add(FUELQTY_TANK)
--------------------------------------------------------------------------------------------------ALL-BLACK-MASK-NO-OPACITY-----------------------
FUEL_BLK                    = CreateElement "ceTexPoly"
FUEL_BLK.name    			= "BG"
FUEL_BLK.material			= FUEL_MASK
FUEL_BLK.change_opacity 	= false
FUEL_BLK.collimated 		= false
FUEL_BLK.isvisible 			= true
FUEL_BLK.init_pos 			= {0, 0, 0} --L-R,U-D,F-B
FUEL_BLK.init_rot 			= {0, 0, 0}
FUEL_BLK.element_params 	= {"LMFD_FUEL_PAGE","MAIN_POWER"}--this may not be bneeded check when more pages done for backlight on page 7 RWR fc3 bs
FUEL_BLK.controllers		= {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1}}--MENU PAGE = 1
FUEL_BLK.level 				= 2
FUEL_BLK.h_clip_relation    = h_clip_relations.COMPARE
vertices(FUEL_BLK,2)
Add(FUEL_BLK)
--------------------------------------------------------------------------------------ALL-BLACK-MASK-WITH-BACKLIGHT-MATERIAL
BGROUND1                    = CreateElement "ceTexPoly"
BGROUND1.name    			= "BG"
BGROUND1.material			= FUEL_MASK_BL
BGROUND1.change_opacity 	= false
BGROUND1.collimated 		= false
BGROUND1.isvisible 			= true
BGROUND1.init_pos 			= {0, 0, 0} --L-R,U-D,F-B
BGROUND1.init_rot 			= {0, 0, 0}
BGROUND1.element_params 	= {"MFD_OPACITY","LMFD_FUEL_PAGE"}
BGROUND1.controllers		= {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1}}--MENU PAGE = 1
BGROUND1.level 				= 2
BGROUND1.h_clip_relation    = h_clip_relations.COMPARE
vertices(BGROUND1,2)
Add(BGROUND1)
-------------------------------------------------------------------------FUEL PAGE GREEN LINES
FUELFRAME                    = CreateElement "ceTexPoly"
FUELFRAME.name    			= "BG"
FUELFRAME.material			= FUEL_PAGE
FUELFRAME.change_opacity 		= false
FUELFRAME.collimated 			= false
FUELFRAME.isvisible 			= true
FUELFRAME.init_pos 			= {0, 0, 0} --L-R,U-D,F-B
FUELFRAME.init_rot 			= {0, 0, 0}
FUELFRAME.element_params 		= {"MFD_OPACITY","LMFD_FUEL_PAGE"}--this may not be bneeded check when more pages done for backlight on page 7 RWR fc3 bs
FUELFRAME.controllers			= {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1}}--MENU PAGE = 1
FUELFRAME.level 				= 2
FUELFRAME.h_clip_relation     = h_clip_relations.COMPARE
vertices(FUELFRAME,2)
Add(FUELFRAME)
--------------------------------------------------------------------------------------------------ALL-BLACK-MASK-NO-OPACITY-----------------------
FUEL_BX                    = CreateElement "ceTexPoly"
FUEL_BX.name    			= "BG"
FUEL_BX.material			= FUEL_BOX
FUEL_BX.change_opacity 		= false
FUEL_BX.collimated 			= false
FUEL_BX.isvisible 			= true
FUEL_BX.init_pos 			= {0, 0, 0} --L-R,U-D,F-B
FUEL_BX.init_rot 			= {0, 0, 0}
FUEL_BX.element_params 		= {"LMFD_FUEL_PAGE","MAIN_POWER"}--this may not be bneeded check when more pages done for backlight on page 7 RWR fc3 bs
FUEL_BX.controllers			= {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1}}--MENU PAGE = 1
FUEL_BX.level 				= 2
FUEL_BX.h_clip_relation     = h_clip_relations.COMPARE
vertices(FUEL_BX,2)
Add(FUEL_BX)
--------------------------------------------------------------------------------------------------ALL-BLACK-MASK-NO-OPACITY-----------------------
FUEL_BX_BL                    = CreateElement "ceTexPoly"
FUEL_BX_BL.name    			= "BG"
FUEL_BX_BL.material			= FUEL_BOX_BL
FUEL_BX_BL.change_opacity 		= false
FUEL_BX_BL.collimated 			= false
FUEL_BX_BL.isvisible 			= true
FUEL_BX_BL.init_pos 			= {0, 0, 0} --L-R,U-D,F-B
FUEL_BX_BL.init_rot 			= {0, 0, 0}
FUEL_BX_BL.element_params 		= {"MFD_OPACITY","LMFD_FUEL_PAGE"}
FUEL_BX_BL.controllers			= {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1}}--MENU PAGE = 1
FUEL_BX_BL.level 				= 2
FUEL_BX_BL.h_clip_relation     = h_clip_relations.COMPARE
vertices(FUEL_BX_BL,2)
Add(FUEL_BX_BL)
--------------------------------------------------------------------------------------------------FUEL-PAGE-TINY-NUMBERS
TINYSHIT                    = CreateElement "ceTexPoly"
TINYSHIT.name    			= "BG"
TINYSHIT.material			= FUEL_IND
TINYSHIT.change_opacity 	= false
TINYSHIT.collimated 		= false
TINYSHIT.isvisible 			= true
TINYSHIT.init_pos 			= {0, 0, 0} --L-R,U-D,F-B
TINYSHIT.init_rot 			= {0, 0, 0}
TINYSHIT.element_params 	= {"MFD_OPACITY","LMFD_FUEL_PAGE"}--this may not be bneeded check when more pages done for backlight on page 7 RWR fc3 bs
TINYSHIT.controllers		= {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1}}--MENU PAGE = 1
TINYSHIT.level 				= 2
TINYSHIT.h_clip_relation    = h_clip_relations.COMPARE
vertices(TINYSHIT,2)
Add(TINYSHIT)
--------------------------------------------------------------------------------------------------------------------INTERNAL TEXT
--INT TEXT
INTERNAL_TEXT 					    = CreateElement "ceStringPoly"
INTERNAL_TEXT.name 				    = "menu"
INTERNAL_TEXT.material 			    = UFD_GRN
INTERNAL_TEXT.value 				= "TOTAL:"
INTERNAL_TEXT.stringdefs 		    = {0.004, 0.004, 0.0004, 0.001}
INTERNAL_TEXT.alignment 			= "LeftCenter"
INTERNAL_TEXT.formats 			    = {"%s"}
INTERNAL_TEXT.h_clip_relation       = h_clip_relations.COMPARE
INTERNAL_TEXT.level 				= 2
INTERNAL_TEXT.init_pos 			    = {0.40, 0.65, 0}
INTERNAL_TEXT.init_rot 			    = {0, 0, 0}
INTERNAL_TEXT.element_params 	    = {"MFD_OPACITY","LMFD_FUEL_PAGE"}
INTERNAL_TEXT.controllers		    =   {
                                            {"opacity_using_parameter",0},
                                            {"parameter_in_range",1,0.9,1.1},--ENGINE PAGE = 0
						                }
Add(INTERNAL_TEXT)
--------------------------------------------------------------------------------------------------------------------INTERNAL NUMBER
INTERNAL_NUMBER				        = CreateElement "ceStringPoly"
INTERNAL_NUMBER.name				= "INT NUM"
INTERNAL_NUMBER.material			= UFD_GRN
INTERNAL_NUMBER.init_pos			= {0.80, 0.65, 0} --L-R,U-D,F-B
INTERNAL_NUMBER.alignment			= "RightCenter"
INTERNAL_NUMBER.stringdefs			= {0.004, 0.004, 0, 0.0} --either 004 or 005
INTERNAL_NUMBER.additive_alpha		= true
INTERNAL_NUMBER.collimated			= false
INTERNAL_NUMBER.isdraw				= true	
INTERNAL_NUMBER.use_mipfilter		= true
INTERNAL_NUMBER.h_clip_relation		= h_clip_relations.COMPARE
INTERNAL_NUMBER.level				= 2
INTERNAL_NUMBER.element_params		= {"MFD_OPACITY","FUEL","LMFD_FUEL_PAGE"}
INTERNAL_NUMBER.formats				= {"%.0f"}--= {"%02.0f"}
INTERNAL_NUMBER.controllers			= {{"opacity_using_parameter",0},{"text_using_parameter",1,0},{"parameter_in_range",2,0.9,1.1}}
Add(INTERNAL_NUMBER)
--------------------------------------------------------------------------------------------------------------------TANK TEXT
--TANK TEXT
TANK_TEXT 					        = CreateElement "ceStringPoly"
TANK_TEXT.name 				        = "menu"
TANK_TEXT.material 			        = UFD_FONT
TANK_TEXT.value 				    = "TANKS:"
TANK_TEXT.stringdefs 		        = {0.004, 0.004, 0.0004, 0.001}
TANK_TEXT.alignment 			    = "LeftCenter"
TANK_TEXT.formats 			        = {"%s"}
TANK_TEXT.h_clip_relation           = h_clip_relations.COMPARE
TANK_TEXT.level 				    = 2
TANK_TEXT.init_pos 			        = {0.40, 0.58, 0}
TANK_TEXT.init_rot 			        = {0, 0, 0}
TANK_TEXT.element_params 	        = {"MFD_OPACITY","LMFD_FUEL_PAGE"}
TANK_TEXT.controllers		        =   {
                                            {"opacity_using_parameter",0},
                                            {"parameter_in_range",1,0.9,1.1},--ENGINE PAGE = 0
						                }
Add(TANK_TEXT)
--------------------------------------------------------------------------------------------------------------------TANK NUMBER
TANK_NUMBER				        = CreateElement "ceStringPoly"
TANK_NUMBER.name				= "INT NUM"
TANK_NUMBER.material			= UFD_FONT
TANK_NUMBER.init_pos			= {0.80, 0.58, 0} --L-R,U-D,F-B
TANK_NUMBER.alignment			= "RightCenter"
TANK_NUMBER.stringdefs			= {0.004, 0.004, 0, 0.0} --either 004 or 005
TANK_NUMBER.additive_alpha		= true
TANK_NUMBER.collimated			= false
TANK_NUMBER.isdraw				= true	
TANK_NUMBER.use_mipfilter		= true
TANK_NUMBER.h_clip_relation		= h_clip_relations.COMPARE
TANK_NUMBER.level				= 2
TANK_NUMBER.element_params		= {"MFD_OPACITY","FUELTANK","LMFD_FUEL_PAGE"}
TANK_NUMBER.formats				= {"%.0f"}--= {"%02.0f"}
TANK_NUMBER.controllers			= {{"opacity_using_parameter",0},{"text_using_parameter",1,0},{"parameter_in_range",2,0.9,1.1}}
Add(TANK_NUMBER)
--------------------------------------------------------------------------------------------------------------------LEFT FF TEXT
L_EFF_TEXT 					        = CreateElement "ceStringPoly"
L_EFF_TEXT.name 				        = "menu"
L_EFF_TEXT.material 			        = UFD_GRN
L_EFF_TEXT.value 				    = "L EFF:"
L_EFF_TEXT.stringdefs 		        = {0.004, 0.004, 0.0004, 0.001}
L_EFF_TEXT.alignment 			    = "LeftCenter"
L_EFF_TEXT.formats 			        = {"%s"}
L_EFF_TEXT.h_clip_relation           = h_clip_relations.COMPARE
L_EFF_TEXT.level 				    = 2
L_EFF_TEXT.init_pos 			        = {-0.85, -0.75, 0}
L_EFF_TEXT.init_rot 			        = {0, 0, 0}
L_EFF_TEXT.element_params 	        = {"MFD_OPACITY","LMFD_FUEL_PAGE"}
L_EFF_TEXT.controllers		        =   {
                                            {"opacity_using_parameter",0},
                                            {"parameter_in_range",1,0.9,1.1},--ENGINE PAGE = 0
						                }
Add(L_EFF_TEXT)
--------------------------------------------------------------------------------------------------------------------LEFT EGT TEXT
L_EGT_TEXT 					            = CreateElement "ceStringPoly"
L_EGT_TEXT.name 				        = "menu"
L_EGT_TEXT.material 			        = UFD_GRN
L_EGT_TEXT.value 				        = "L EGT:"
L_EGT_TEXT.stringdefs 		            = {0.004, 0.004, 0.0004, 0.001}
L_EGT_TEXT.alignment 			        = "LeftCenter"
L_EGT_TEXT.formats 			            = {"%s"}
L_EGT_TEXT.h_clip_relation              = h_clip_relations.COMPARE
L_EGT_TEXT.level 				        = 2
L_EGT_TEXT.init_pos 			        = {-0.85, -0.82, 0}
L_EGT_TEXT.init_rot 			        = {0, 0, 0}
L_EGT_TEXT.element_params 	            = {"MFD_OPACITY","LMFD_FUEL_PAGE"}
L_EGT_TEXT.controllers		            =   {
                                                {"opacity_using_parameter",0},
                                                {"parameter_in_range",1,0.9,1.1},--ENGINE PAGE = 0
						                    }
Add(L_EGT_TEXT)
--------------------------------------------------------------------------------------------------------------------LEFT FF NUMBER
L_EFF_NUMBER				        = CreateElement "ceStringPoly"
L_EFF_NUMBER.name				= "INT NUM"
L_EFF_NUMBER.material			= UFD_GRN
L_EFF_NUMBER.init_pos			= {-0.45, -0.75, 0} --L-R,U-D,F-B
L_EFF_NUMBER.alignment			= "RightCenter"
L_EFF_NUMBER.stringdefs			= {0.004, 0.004, 0, 0.0} --either 004 or 005
L_EFF_NUMBER.additive_alpha		= true
L_EFF_NUMBER.collimated			= false
L_EFF_NUMBER.isdraw				= true	
L_EFF_NUMBER.use_mipfilter		= true
L_EFF_NUMBER.h_clip_relation		= h_clip_relations.COMPARE
L_EFF_NUMBER.level				= 2
L_EFF_NUMBER.element_params		= {"MFD_OPACITY","L_FF_VALUE","LMFD_FUEL_PAGE"}
L_EFF_NUMBER.formats				= {"%.0f"}--= {"%02.0f"}
L_EFF_NUMBER.controllers			= {{"opacity_using_parameter",0},{"text_using_parameter",1,0},{"parameter_in_range",2,0.9,1.1}}
Add(L_EFF_NUMBER)
--------------------------------------------------------------------------------------------------------------------LEFT FF NUMBER
L_EGT_NUMBER				        = CreateElement "ceStringPoly"
L_EGT_NUMBER.name				    = "INT NUM"
L_EGT_NUMBER.material			    = UFD_GRN
L_EGT_NUMBER.init_pos			    = {-0.45, -0.82, 0} --L-R,U-D,F-B
L_EGT_NUMBER.alignment			    = "RightCenter"
L_EGT_NUMBER.stringdefs			    = {0.004, 0.004, 0, 0.0} --either 004 or 005
L_EGT_NUMBER.additive_alpha		    = true
L_EGT_NUMBER.collimated			    = false
L_EGT_NUMBER.isdraw				    = true	
L_EGT_NUMBER.use_mipfilter		    = true
L_EGT_NUMBER.h_clip_relation		= h_clip_relations.COMPARE
L_EGT_NUMBER.level				    = 2
L_EGT_NUMBER.element_params		    = {"MFD_OPACITY","EGT_L","LMFD_FUEL_PAGE"}
L_EGT_NUMBER.formats				= {"%.0f"}--= {"%02.0f"}
L_EGT_NUMBER.controllers			= {{"opacity_using_parameter",0},{"text_using_parameter",1,0},{"parameter_in_range",2,0.9,1.1}}
Add(L_EGT_NUMBER)
--------------------------------------------------------------------------------------------------------------------LEFT FF TEXT
R_EFF_TEXT 					        = CreateElement "ceStringPoly"
R_EFF_TEXT.name 				        = "menu"
R_EFF_TEXT.material 			        = UFD_GRN
R_EFF_TEXT.value 				    = ":R EFF"
R_EFF_TEXT.stringdefs 		        = {0.004, 0.004, 0.0004, 0.001}
R_EFF_TEXT.alignment 			    = "RightCenter"
R_EFF_TEXT.formats 			        = {"%s"}
R_EFF_TEXT.h_clip_relation           = h_clip_relations.COMPARE
R_EFF_TEXT.level 				    = 2
R_EFF_TEXT.init_pos 			        = {0.85, -0.75, 0}
R_EFF_TEXT.init_rot 			        = {0, 0, 0}
R_EFF_TEXT.element_params 	        = {"MFD_OPACITY","LMFD_FUEL_PAGE"}
R_EFF_TEXT.controllers		        =   {
                                            {"opacity_using_parameter",0},
                                            {"parameter_in_range",1,0.9,1.1},--ENGINE PAGE = 0
						                }
Add(R_EFF_TEXT)
--------------------------------------------------------------------------------------------------------------------LEFT EGT TEXT
R_EGT_TEXT 					            = CreateElement "ceStringPoly"
R_EGT_TEXT.name 				        = "menu"
R_EGT_TEXT.material 			        = UFD_GRN
R_EGT_TEXT.value 				        = ":R EGT"
R_EGT_TEXT.stringdefs 		            = {0.004, 0.004, 0.0004, 0.001}
R_EGT_TEXT.alignment 			        = "RightCenter"
R_EGT_TEXT.formats 			            = {"%s"}
R_EGT_TEXT.h_clip_relation              = h_clip_relations.COMPARE
R_EGT_TEXT.level 				        = 2
R_EGT_TEXT.init_pos 			        = {0.85, -0.82, 0}
R_EGT_TEXT.init_rot 			        = {0, 0, 0}
R_EGT_TEXT.element_params 	            = {"MFD_OPACITY","LMFD_FUEL_PAGE"}
R_EGT_TEXT.controllers		            =   {
                                                {"opacity_using_parameter",0},
                                                {"parameter_in_range",1,0.9,1.1},--ENGINE PAGE = 0
						                    }
Add(R_EGT_TEXT)
--------------------------------------------------------------------------------------------------------------------LEFT FF NUMBER
R_EFF_NUMBER				        = CreateElement "ceStringPoly"
R_EFF_NUMBER.name				= "INT NUM"
R_EFF_NUMBER.material			= UFD_GRN
R_EFF_NUMBER.init_pos			= {0.45, -0.75, 0} --L-R,U-D,F-B
R_EFF_NUMBER.alignment			= "LeftCenter"
R_EFF_NUMBER.stringdefs			= {0.004, 0.004, 0, 0.0} --either 004 or 005
R_EFF_NUMBER.additive_alpha		= true
R_EFF_NUMBER.collimated			= false
R_EFF_NUMBER.isdraw				= true	
R_EFF_NUMBER.use_mipfilter		= true
R_EFF_NUMBER.h_clip_relation		= h_clip_relations.COMPARE
R_EFF_NUMBER.level				= 2
R_EFF_NUMBER.element_params		= {"MFD_OPACITY","R_FF_VALUE","LMFD_FUEL_PAGE"}
R_EFF_NUMBER.formats				= {"%.0f"}--= {"%02.0f"}
R_EFF_NUMBER.controllers			= {{"opacity_using_parameter",0},{"text_using_parameter",1,0},{"parameter_in_range",2,0.9,1.1}}
Add(R_EFF_NUMBER)
--------------------------------------------------------------------------------------------------------------------LEFT FF NUMBER
R_EGT_NUMBER				        = CreateElement "ceStringPoly"
R_EGT_NUMBER.name				    = "INT NUM"
R_EGT_NUMBER.material			    = UFD_GRN
R_EGT_NUMBER.init_pos			    = {0.45, -0.82, 0} --L-R,U-D,F-B
R_EGT_NUMBER.alignment			    = "LeftCenter"
R_EGT_NUMBER.stringdefs			    = {0.004, 0.004, 0, 0.0} --either 004 or 005
R_EGT_NUMBER.additive_alpha		    = true
R_EGT_NUMBER.collimated			    = false
R_EGT_NUMBER.isdraw				    = true	
R_EGT_NUMBER.use_mipfilter		    = true
R_EGT_NUMBER.h_clip_relation		= h_clip_relations.COMPARE
R_EGT_NUMBER.level				    = 2
R_EGT_NUMBER.element_params		    = {"MFD_OPACITY","EGT_R","LMFD_FUEL_PAGE"}
R_EGT_NUMBER.formats				= {"%.0f"}--= {"%02.0f"}
R_EGT_NUMBER.controllers			= {{"opacity_using_parameter",0},{"text_using_parameter",1,0},{"parameter_in_range",2,0.9,1.1}}
Add(R_EGT_NUMBER)
--------------------------------------------------------------------------------------------------------------------MENU-BUTTON
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
MENU_CHK_TEXT.element_params 	    = {"MFD_OPACITY","LMFD_FUEL_PAGE"}
MENU_CHK_TEXT.controllers		    =   {
                                        {"opacity_using_parameter",0},
                                        {"parameter_in_range",1,0.9,1.1},--ENGINE PAGE = 0
						            }
Add(MENU_CHK_TEXT)
--------------------------------------------------------------------------------------------------- NAV
MENU_TEXT1 					        = CreateElement "ceStringPoly"
MENU_TEXT1.name 				    = "menu"
MENU_TEXT1.material 			    = UFD_GRN
MENU_TEXT1.value 				    = "RWR"
MENU_TEXT1.stringdefs 		        = {0.0050, 0.0050, 0.0004, 0.001}
MENU_TEXT1.alignment 			    = "CenterCenter"
MENU_TEXT1.formats 			        = {"%s"}
MENU_TEXT1.h_clip_relation          = h_clip_relations.COMPARE
MENU_TEXT1.level 				    = 2
MENU_TEXT1.init_pos 			        = {-0.265, 0.92, 0}
MENU_TEXT1.init_rot 			        = {0, 0, 0}
MENU_TEXT1.element_params 	        = {"MFD_OPACITY","LMFD_FUEL_PAGE"}
MENU_TEXT1.controllers		        =   {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1},}
Add(MENU_TEXT1)
--------------------------------------------------------------------------------------------------- NAV
MENU_TEXT2 					        = CreateElement "ceStringPoly"
MENU_TEXT2.name 				    = "menu"
MENU_TEXT2.material 			    = UFD_GRN
MENU_TEXT2.value 				    = "BAY"
MENU_TEXT2.stringdefs 		        = {0.0050, 0.0050, 0.0004, 0.001}
MENU_TEXT2.alignment 			    = "CenterCenter"
MENU_TEXT2.formats 			        = {"%s"}
MENU_TEXT2.h_clip_relation          = h_clip_relations.COMPARE
MENU_TEXT2.level 				    = 2
MENU_TEXT2.init_pos 			        = {0.265, 0.92, 0}
MENU_TEXT2.init_rot 			        = {0, 0, 0}
MENU_TEXT2.element_params 	        = {"MFD_OPACITY","LMFD_FUEL_PAGE"}
MENU_TEXT2.controllers		        =   {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1},}
Add(MENU_TEXT2)
--------------------------------------------------------------------------------------------------- NAV
MENU_TEXT3 					        = CreateElement "ceStringPoly"
MENU_TEXT3.name 				    = "menu"
MENU_TEXT3.material 			    = UFD_GRN
MENU_TEXT3.value 				    = "ENG"
MENU_TEXT3.stringdefs 		        = {0.0050, 0.0050, 0.0004, 0.001}
MENU_TEXT3.alignment 			    = "CenterCenter"
MENU_TEXT3.formats 			        = {"%s"}
MENU_TEXT3.h_clip_relation          = h_clip_relations.COMPARE
MENU_TEXT3.level 				    = 2
MENU_TEXT3.init_pos 			        = {0, 0.92, 0}
MENU_TEXT3.init_rot 			        = {0, 0, 0}
MENU_TEXT3.element_params 	        = {"MFD_OPACITY","LMFD_FUEL_PAGE"}
MENU_TEXT3.controllers		        =   {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1},}
Add(MENU_TEXT3)
--------------------------------------------------------------------------------------------------- NAV
MENU_TEXT3 					        = CreateElement "ceStringPoly"
MENU_TEXT3.name 				    = "menu"
MENU_TEXT3.material 			    = UFD_GRN
MENU_TEXT3.value 				    = "FCS"
MENU_TEXT3.stringdefs 		        = {0.0050, 0.0050, 0.0004, 0.001}
MENU_TEXT3.alignment 			    = "CenterCenter"
MENU_TEXT3.formats 			        = {"%s"}
MENU_TEXT3.h_clip_relation          = h_clip_relations.COMPARE
MENU_TEXT3.level 				    = 2
MENU_TEXT3.init_pos 			        = {0.565, 0.92, 0}
MENU_TEXT3.init_rot 			        = {0, 0, 0}
MENU_TEXT3.element_params 	        = {"MFD_OPACITY","LMFD_FUEL_PAGE"}
MENU_TEXT3.controllers		        =   {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1},}
Add(MENU_TEXT3)
-----------------------------------------------------------------------------------------------------------------------
