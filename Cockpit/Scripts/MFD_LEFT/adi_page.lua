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
        width = 0.025
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
local ADIbottom				= {8, 8, 8, 255}--RGBA
local TealColor				= {0, 255, 255, 255}--RGBA
local TrimColor				= {255, 255, 255, 255}--RGBA
local BOXColor				= {10, 10, 10, 255}--RGBA
local BlueColor				= {0, 0, 150, 255}--RGBA
--------------------------------------------------------------------------------------------------------------------------------------------
local ADI_PAGE       = MakeMaterial(LockOn_Options.script_path.."../Scripts/IndicationTextures/mfd_adi.dds", ScreenColor)--SYSTEM TEST
local ADI_PAGE_DRK   = MakeMaterial(LockOn_Options.script_path.."../Scripts/IndicationTextures/mfd_adi.dds", ADIbottom)--SYSTEM TEST
local ADI_LAD_TOP    = MakeMaterial(LockOn_Options.script_path.."../Scripts/IndicationTextures/mfd_lad_top.dds", WhiteColor)--SYSTEM TEST
local ADI_LAD_BOT    = MakeMaterial(LockOn_Options.script_path.."../Scripts/IndicationTextures/mfd_lad_bot.dds", WhiteColor)--SYSTEM TEST
local MFD_LINE       = MakeMaterial(LockOn_Options.script_path.."../Scripts/IndicationTextures/mfd_line.dds", WhiteColor)--SYSTEM TEST
local MFD_LINE_M     = MakeMaterial(LockOn_Options.script_path.."../Scripts/IndicationTextures/mfd_line.dds", BlackColor)--SYSTEM TEST

local MFD_RING       = MakeMaterial(LockOn_Options.script_path.."../Scripts/IndicationTextures/mfd_ring.dds", WhiteColor)--SYSTEM TEST
local MFD_BOXES       = MakeMaterial(LockOn_Options.script_path.."../Scripts/IndicationTextures/mfd_boxes.dds", WhiteColor)--SYSTEM TEST

local MFD_VV        = MakeMaterial(LockOn_Options.script_path.."../Scripts/IndicationTextures/mfd_vv.dds", WhiteColor)--SYSTEM TEST
local MFD_VV_M       = MakeMaterial(LockOn_Options.script_path.."../Scripts/IndicationTextures/mfd_vv.dds", BlackColor)--SYSTEM TEST

local ADI_SLIP_MASK      = MakeMaterial(LockOn_Options.script_path.."../Scripts/IndicationTextures/mfd_trim_mask.dds", BlackColor)--SYSTEM TEST
local ADI_SLIP_MASK_GLOW      = MakeMaterial(LockOn_Options.script_path.."../Scripts/IndicationTextures/mfd_trim_mask.dds", ScreenColor)--SYSTEM TEST
local SLIP_BALL	    = MakeMaterial(LockOn_Options.script_path.."../Scripts/IndicationTextures/mask_box.dds", WhiteColor)--SYSTEM TEST
local ADI_MASK      = MakeMaterial(LockOn_Options.script_path.."../Scripts/IndicationTextures/mfd_adi.dds", BlackColor)--SYSTEM TEST
local MASK_BOX	    = MakeMaterial(LockOn_Options.script_path.."../Scripts/IndicationTextures/mask_box.dds", ScreenColor)--SYSTEM TEST
local MASK_BOX1	    = MakeMaterial(LockOn_Options.script_path.."../Scripts/IndicationTextures/mask_box.dds", ADIbottom)--SYSTEM TEST
local ADI_TOP	 = MakeMaterial(LockOn_Options.script_path.."../Scripts/IndicationTextures/adi_half.dds", 	BlueColor)
local ADI_BOT	 = MakeMaterial(LockOn_Options.script_path.."../Scripts/IndicationTextures/adi_half.dds", 	ADIbottom)
local ADI_LINE	 = MakeMaterial(LockOn_Options.script_path.."../Scripts/IndicationTextures/adi_line.dds", 	WhiteColor)
local TEST		 = MakeMaterial(LockOn_Options.script_path.."../Scripts/IndicationTextures/test.dds", WhiteColor)

local ILS_H	    = MakeMaterial(LockOn_Options.script_path.."../Scripts/IndicationTextures/mask_box.dds", YellowColor)--SYSTEM TEST
local ILS_V	    = MakeMaterial(LockOn_Options.script_path.."../Scripts/IndicationTextures/mask_box.dds", YellowColor)--SYSTEM TEST
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
total_field_of_view.level           = 10
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
clipPoly.level               = 10
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
BGROUND.element_params 		= {"MFD_OPACITY","LMFD_ADI_PAGE"}--this may not be bneeded check when more pages done for backlight on page 7 SMS fc3 bs
BGROUND.controllers			= {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1}}--MENU PAGE = 1
BGROUND.level 				= 11
BGROUND.h_clip_relation     = h_clip_relations.COMPARE
vertices(BGROUND,3)
Add(BGROUND)
------------------------------------------------------------
--------------
ADIUP                       = CreateElement "ceTexPoly"
ADIUP.name    			    = "up"
ADIUP.material			     = ADI_TOP
ADIUP.change_opacity 		= false
ADIUP.collimated 			= false
ADIUP.isvisible 			= true
ADIUP.init_pos 			    = {0, 0.12, 0} --maybe its x,y,z z being depth.. again who the fuck knows?
ADIUP.init_rot 			    = {0, 0, 0}
--ADIUP.indices 			= {0, 1, 2, 2, 3, 0}
ADIUP.level 				= 11
ADIUP.h_clip_relation     = h_clip_relations.COMPARE
ADIUP.element_params 	  = {"LMFD_ADI_PAGE","ADIROLL","ADIPITCH","MFD_OPACITY"} --HOPE THIS WORKS G_OP_BACK
ADIUP.controllers		  = {
							{"parameter_in_range",0,0.9,1.1},
							{"rotate_using_parameter",1,1,0},
							{"move_up_down_using_parameter",2,-0.182,0},--needs to be checked with a ladder scale
							{"opacity_using_parameter",3},
						  }
vertices(ADIUP,11)

Add(ADIUP)
-- ----------------
ADIDN                       = CreateElement "ceTexPoly"
ADIDN.name    			    = "bot"
ADIDN.material			    = ADI_BOT
ADIDN.change_opacity 		= false
ADIDN.collimated 			= false
ADIDN.isvisible 			= true
ADIDN.init_pos 			    = {0, 0.12, 0} --maybe its x,y,z z being depth.. again who the fuck knows?
ADIDN.init_rot 			    = {180, 0, 0}
ADIDN.level 				= 11
ADIDN.h_clip_relation       = h_clip_relations.COMPARE
ADIDN.element_params 	  = {"LMFD_ADI_PAGE","ADIROLL","ADIPITCH","MFD_OPACITY"} --HOPE THIS WORKS G_OP_BACK
ADIDN.controllers		  = {
							{"parameter_in_range",0,0.9,1.1},
							{"rotate_using_parameter",1,1,0},
							{"move_up_down_using_parameter",2,0.182,0},--needs to be checked with a ladder scale
							{"opacity_using_parameter",3},
						  }
vertices(ADIDN,11)
Add(ADIDN)
-- ----------------
-- -----------------------------------------------------------------------------------------------------------line mask
ADILINEM                         = CreateElement "ceTexPoly"
ADILINEM.name    			    = "bot"
ADILINEM.material			    = MFD_LINE_M
ADILINEM.change_opacity 		    = false
ADILINEM.collimated 			    = false
ADILINEM.isvisible 			    = true
ADILINEM.init_pos 			    = {0, 0.12, 0} --maybe its x,y,z z being depth.. again who the fuck knows?
ADILINEM.init_rot 			    = {0, 0, 0}
ADILINEM.level 				    = 11
ADILINEM.h_clip_relation         = h_clip_relations.COMPARE
ADILINEM.element_params 	        = {"LMFD_ADI_PAGE","ADIROLL","ADIPITCH",} --HOPE THIS WORKS G_OP_BACK
ADILINEM.controllers		                = {
							                {"parameter_in_range",0,0.9,1.1},
							                {"rotate_using_parameter",1,1,0},
							                {"move_up_down_using_parameter",2,-0.182,0},--needs to be checked with a ladder scale
							                --{"opacity_using_parameter",3},
						                }
vertices(ADILINEM,1.5)
Add(ADILINEM)
----------------
ADILINE                         = CreateElement "ceTexPoly"
ADILINE.name    			    = "bot"
ADILINE.material			    = MFD_LINE
ADILINE.change_opacity 		    = false
ADILINE.collimated 			    = false
ADILINE.isvisible 			    = true
ADILINE.init_pos 			    = {0, 0.12, 0} --maybe its x,y,z z being depth.. again who the fuck knows?
ADILINE.init_rot 			    = {0, 0, 0}
ADILINE.level 				    = 11
ADILINE.h_clip_relation         = h_clip_relations.COMPARE
ADILINE.element_params 	        = {"LMFD_ADI_PAGE","ADIROLL","ADIPITCH","MFD_OPACITY",} --HOPE THIS WORKS G_OP_BACK
ADILINE.controllers		                = {
							                {"parameter_in_range",0,0.9,1.1},
							                {"rotate_using_parameter",1,1,0},
							                {"move_up_down_using_parameter",2,-0.182,0},--needs to be checked with a ladder scale
							                {"opacity_using_parameter",3},
						                }
vertices(ADILINE,1.5)
Add(ADILINE)
---------------------------------------------
ADILADDERTOP                       = CreateElement "ceTexPoly"
ADILADDERTOP.name    			    = "bot"
ADILADDERTOP.material			    = ADI_LAD_TOP
ADILADDERTOP.change_opacity 		= false
ADILADDERTOP.collimated 			= false
ADILADDERTOP.isvisible 			    = true
ADILADDERTOP.init_pos 			    = {0, 0.12, 0} --maybe its x,y,z z being depth.. again who the fuck knows?
ADILADDERTOP.init_rot 			    = {0, 0, 0}
ADILADDERTOP.level 				    = 11
ADILADDERTOP.h_clip_relation       = h_clip_relations.COMPARE
ADILADDERTOP.element_params 	  = {"LMFD_ADI_PAGE","ADIROLL","ADIPITCH","MFD_OPACITY"} --HOPE THIS WORKS G_OP_BACK
ADILADDERTOP.controllers		  = {
										{"parameter_in_range",0,0.9,1.1},
										{"rotate_using_parameter",1,1,0},
										{"move_up_down_using_parameter",2,-0.182,0},--needs to be checked with a ladder scale
										{"opacity_using_parameter",3},
						  			}
vertices(ADILADDERTOP,11.1)
Add(ADILADDERTOP)
-- ----------------
ADILADDERBOT                       = CreateElement "ceTexPoly"
ADILADDERBOT.name    			    = "bot"
ADILADDERBOT.material			    = ADI_LAD_BOT
ADILADDERBOT.change_opacity 		= false
ADILADDERBOT.collimated 			= false
ADILADDERBOT.isvisible 			    = true
ADILADDERBOT.init_pos 			    = {0, 0.12, 0} --maybe its x,y,z z being depth.. again who the fuck knows?
ADILADDERBOT.init_rot 			    = {0, 0, 0}
ADILADDERBOT.level 				    = 11
ADILADDERBOT.h_clip_relation       = h_clip_relations.COMPARE
ADILADDERBOT.element_params 	  = {"LMFD_ADI_PAGE","ADIROLL","ADIPITCH","MFD_OPACITY"} --HOPE THIS WORKS G_OP_BACK
ADILADDERBOT.controllers		  = {
							{"parameter_in_range",0,0.9,1.1},
							{"rotate_using_parameter",1,1,0},
							{"move_up_down_using_parameter",2,-0.182,0},--needs to be checked with a ladder scale
							{"opacity_using_parameter",3},
						  }
vertices(ADILADDERBOT,11.1)
Add(ADILADDERBOT)
-- -- ----------------
ADIVVM                         = CreateElement "ceTexPoly"
ADIVVM.name    			    = "bot"
ADIVVM.material			    = MFD_VV_M
ADIVVM.change_opacity 		    = false
ADIVVM.collimated 			    = false
ADIVVM.isvisible 			    = true
ADIVVM.init_pos 			    = {0, 0.12, 0} --maybe its x,y,z z being depth.. again who the fuck knows?
ADIVVM.init_rot 			    = {0, 0, 0}
ADIVVM.level 				    = 11
ADIVVM.h_clip_relation         = h_clip_relations.COMPARE
ADIVVM.element_params 	        = {"LMFD_ADI_PAGE"} --HOPE THIS WORKS G_OP_BACK
ADIVVM.controllers		                = {
							                {"parameter_in_range",0,0.9,1.1},
							                --{"rotate_using_parameter",1,1,0},
							                --{"move_up_down_using_parameter",2,-0.037,0},--needs to be checked with a ladder scale
							                --{"opacity_using_parameter",1},
						                }
vertices(ADIVVM,1)
Add(ADIVVM)
--------------------------
ADIVV                         = CreateElement "ceTexPoly"
ADIVV.name    			    = "bot"
ADIVV.material			    = MFD_VV
ADIVV.change_opacity 		    = false
ADIVV.collimated 			    = false
ADIVV.isvisible 			    = true
ADIVV.init_pos 			    = {0, 0.12, 0} --maybe its x,y,z z being depth.. again who the fuck knows?
ADIVV.init_rot 			    = {0, 0, 0}
ADIVV.level 				    = 11
ADIVV.h_clip_relation         = h_clip_relations.COMPARE
ADIVV.element_params 	        = {"LMFD_ADI_PAGE","MFD_OPACITY",} --HOPE THIS WORKS G_OP_BACK
ADIVV.controllers		                = {
							                {"parameter_in_range",0,0.9,1.1},
							                --{"rotate_using_parameter",1,1,0},
							               -- {"move_up_down_using_parameter",2,-0.037,0},--needs to be checked with a ladder scale
							                {"opacity_using_parameter",1},
						                }
vertices(ADIVV,1)
Add(ADIVV)
--------------------------------------------------------------------------------------------------------------------------------------------------WIP----ILS STUFF
--ILS_VERT   
--ILS_HORIZON
ADIILS_H                    	= CreateElement "ceTexPoly"
ADIILS_H.name    				= "BG"
ADIILS_H.material				= ILS_H
ADIILS_H.change_opacity 		= false
ADIILS_H.collimated 			= false
ADIILS_H.isvisible 				= true
ADIILS_H.init_pos 				= {0, 0.12, 0} --L-R,U-D,F-B
ADIILS_H.init_rot 				= {0, 0, 0}
ADIILS_H.element_params 		= {"MFD_OPACITY","LMFD_ADI_PAGE","ILS_HORIZON","ILSN_VIS"}--this may not be bneeded check when more pages done for backlight on page 7 SMS fc3 bs
ADIILS_H.controllers			= {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1},{"move_left_right_using_parameter",2,0.045,0},{"parameter_in_range",3,0.9,1.1}}
ADIILS_H.level 				    = 11
ADIILS_H.h_clip_relation       = h_clip_relations.COMPARE
vertices(ADIILS_H, 1.3, true)
Add(ADIILS_H)
-- ----------------------------------------------------------------------------------------
ADIILS_V                    	= CreateElement "ceTexPoly"
ADIILS_V.name    				= "BG"
ADIILS_V.material				= ILS_V
ADIILS_V.change_opacity 		= false
ADIILS_V.collimated 			= false
ADIILS_V.isvisible 				= true
ADIILS_V.init_pos 				= {0, 0.12, 0} --L-R,U-D,F-B
ADIILS_V.init_rot 				= {90, 0, 0}
ADIILS_V.element_params 		= {"MFD_OPACITY","LMFD_ADI_PAGE","ILS_VERT","ILSN_VIS"}--this may not be bneeded check when more pages done for backlight on page 7 SMS fc3 bs
ADIILS_V.controllers			= {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1},{"move_left_right_using_parameter",2,0.045,0},{"parameter_in_range",3,0.9,1.1}}
ADIILS_V.level 					= 11
ADIILS_V.h_clip_relation       = h_clip_relations.COMPARE
vertices(ADIILS_V, 1.3, true)
Add(ADIILS_V)
-----------------------------------------------------------------------------------------------------------------------------------MASK--NO OPACITY
ADIMASK                    = CreateElement "ceTexPoly"
ADIMASK.name    			= "BG"
ADIMASK.material			= ADI_MASK
ADIMASK.change_opacity 		= false
ADIMASK.collimated 			= false
ADIMASK.isvisible 			= true
ADIMASK.init_pos 			= {0, 0.12, 0} --L-R,U-D,F-B
ADIMASK.init_rot 			= {0, 0, 0}
ADIMASK.element_params 		= {"LMFD_ADI_PAGE"}--this may not be bneeded check when more pages done for backlight on page 7 SMS fc3 bs
ADIMASK.controllers			= {{"opacity_using_parameter",0}}--MENU PAGE = 1
ADIMASK.level 				= 11
ADIMASK.h_clip_relation     = h_clip_relations.COMPARE
vertices(ADIMASK,2.5)
Add(ADIMASK)
----------------------------------------------------------------------------------------------------------------------------------------------MASK WITH GLOW
ADIMASKGLOW                    = CreateElement "ceTexPoly"
ADIMASKGLOW.name    			= "BG"
ADIMASKGLOW.material			= ADI_PAGE_DRK
ADIMASKGLOW.change_opacity 		= false
ADIMASKGLOW.collimated 			= false
ADIMASKGLOW.isvisible 			= true
ADIMASKGLOW.init_pos 			= {0, 0.12, 0} --L-R,U-D,F-B
ADIMASKGLOW.init_rot 			= {0, 0, 0}
ADIMASKGLOW.element_params 		= {"MFD_OPACITY","LMFD_ADI_PAGE"}--this may not be bneeded check when more pages done for backlight on page 7 SMS fc3 bs
ADIMASKGLOW.controllers			= {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1}}--MENU PAGE = 1
ADIMASKGLOW.level 				= 11
ADIMASKGLOW.h_clip_relation     = h_clip_relations.COMPARE
vertices(ADIMASKGLOW,2.5)
Add(ADIMASKGLOW)
----------------------------------------------------------------------------------------------------------------------------------------------PARAM HERE
SLIPBOX                    = CreateElement "ceTexPoly"
SLIPBOX.name    			= "BG"
SLIPBOX.material			= SLIP_BALL
SLIPBOX.change_opacity 		= false
SLIPBOX.collimated 			= false
SLIPBOX.isvisible 			= true
SLIPBOX.init_pos 			= {0, -0.64, 0} --L-R,U-D,F-B
SLIPBOX.init_rot 			= {0, 0, 0}
SLIPBOX.element_params 		= {"MFD_OPACITY","LMFD_ADI_PAGE","SLIP"}--this may not be bneeded check when more pages done for backlight on page 7 SMS fc3 bs
SLIPBOX.controllers			= {
								{"opacity_using_parameter",0},
								{"parameter_in_range",1,0.9,1.1},
								{"move_left_right_using_parameter",2,0.0010,0}
							}--needs to be checked with a ladder scale}--MENU PAGE = 1
SLIPBOX.level 				= 11
SLIPBOX.h_clip_relation     = h_clip_relations.COMPARE
vertices(SLIPBOX,0.10,false)
Add(SLIPBOX)
-----------------------------------------------------------------------------------------------------------------------------------MASK--NO OPACITY
ADIMASKSLIP                    = CreateElement "ceTexPoly"
ADIMASKSLIP.name    			= "BG"
ADIMASKSLIP.material			= ADI_SLIP_MASK
ADIMASKSLIP.change_opacity 		= false
ADIMASKSLIP.collimated 			= false
ADIMASKSLIP.isvisible 			= true
ADIMASKSLIP.init_pos 			= {0, 0.12, 0} --L-R,U-D,F-B
ADIMASKSLIP.init_rot 			= {0, 0, 0}
ADIMASKSLIP.element_params 		= {"LMFD_ADI_PAGE"}--this may not be bneeded check when more pages done for backlight on page 7 SMS fc3 bs
ADIMASKSLIP.controllers			= {{"opacity_using_parameter",0}}--MENU PAGE = 1
ADIMASKSLIP.level 				= 11
ADIMASKSLIP.h_clip_relation     = h_clip_relations.COMPARE
vertices(ADIMASKSLIP,2.5)
Add(ADIMASKSLIP)
-------------------------------------------------------------------------------------------------------------------MASK WITH GLOW
ADIMASKSLIPGLOW                    = CreateElement "ceTexPoly"
ADIMASKSLIPGLOW.name    			= "BG"
ADIMASKSLIPGLOW.material			= ADI_SLIP_MASK_GLOW
ADIMASKSLIPGLOW.change_opacity 		= false
ADIMASKSLIPGLOW.collimated 			= false
ADIMASKSLIPGLOW.isvisible 			= true
ADIMASKSLIPGLOW.init_pos 			= {0, 0.12, 0} --L-R,U-D,F-B
ADIMASKSLIPGLOW.init_rot 			= {0, 0, 0}
ADIMASKSLIPGLOW.element_params 		= {"LMFD_ADI_PAGE","MFD_OPACITY",}--this may not be bneeded check when more pages done for backlight on page 7 SMS fc3 bs
ADIMASKSLIPGLOW.controllers			= {{"parameter_in_range",0,0.9,1.1},{"opacity_using_parameter",1}}--MENU PAGE = 1
ADIMASKSLIPGLOW.level 				= 11
ADIMASKSLIPGLOW.h_clip_relation     = h_clip_relations.COMPARE
vertices(ADIMASKSLIPGLOW,2.5)
Add(ADIMASKSLIPGLOW)
-----------------------------------
BOXES                    = CreateElement "ceTexPoly"
BOXES.name    			= "BG"
BOXES.material			= MFD_BOXES
BOXES.change_opacity 		= false
BOXES.collimated 			= false
BOXES.isvisible 			= true
BOXES.init_pos 			= {0, 0.12, 0} --L-R,U-D,F-B
BOXES.init_rot 			= {0, 0, 0}
BOXES.element_params 		= {"MFD_OPACITY","LMFD_ADI_PAGE"}--this may not be bneeded check when more pages done for backlight on page 7 SMS fc3 bs
BOXES.controllers			= {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1}}--MENU PAGE = 1
BOXES.level 				= 11
BOXES.h_clip_relation     = h_clip_relations.COMPARE
vertices(BOXES,2.5)
Add(BOXES)

RING                    = CreateElement "ceTexPoly"
RING.name    			= "BG"
RING.material			= MFD_RING
RING.change_opacity 		= false
RING.collimated 			= false
RING.isvisible 			= true
RING.init_pos 			= {0, 0.12, 0} --L-R,U-D,F-B
RING.init_rot 			= {0, 0, 0}
RING.element_params 		= {"MFD_OPACITY","LMFD_ADI_PAGE"}--this may not be bneeded check when more pages done for backlight on page 7 SMS fc3 bs
RING.controllers			= {{"opacity_using_parameter",0},{"parameter_in_range",1,0.9,1.1}}--MENU PAGE = 1
RING.level 				= 11
RING.h_clip_relation     = h_clip_relations.COMPARE
vertices(RING,2.5)
Add(RING)
-----------------------------------
--Indicated Airspeed
IAS						= CreateElement "ceStringPoly"
IAS.name				= "Indicated Airspeed"
IAS.material			= UFD_FONT
IAS.init_pos			= {-0.54, 0.65, 0} --L-R,U-D,F-B
IAS.alignment			= "RightCenter"
IAS.stringdefs			= {0.008, 0.008, 0, 0.0} --either 004 or 005
IAS.additive_alpha		= true
IAS.collimated			= false
IAS.isdraw				= true	
IAS.use_mipfilter		= true
IAS.h_clip_relation		= h_clip_relations.COMPARE
IAS.level				= 11
IAS.element_params		= {"MFD_OPACITY","IAS","LMFD_ADI_PAGE"}
IAS.formats				= {"%.0f"} --{"%.0f"}
IAS.controllers			= {{"opacity_using_parameter",0},{"text_using_parameter",1,0},{"parameter_in_range",2,0.9,1.1}}
vertices(IAS,2.5)
Add(IAS)
----------------------------------------------------------------------------------------------------------------------------------------------
BAROALT						= CreateElement "ceStringPoly"
BAROALT.name				= "Indicated Airspeed"
BAROALT.material			= UFD_FONT
BAROALT.init_pos			= {0.85, 0.65, 0} --L-R,U-D,F-B
BAROALT.alignment			= "RightCenter"
BAROALT.stringdefs			= {0.008, 0.008, 0, 0.0} --either 004 or 005
BAROALT.additive_alpha		= true
BAROALT.collimated			= false
BAROALT.isdraw				= true	
BAROALT.use_mipfilter		= true
BAROALT.h_clip_relation		= h_clip_relations.COMPARE
BAROALT.level				= 11
BAROALT.element_params		= {"MFD_OPACITY","BAROALT","LMFD_ADI_PAGE"}
BAROALT.formats				= {"%.0f"} --{"%.0f"}
BAROALT.controllers			= {{"opacity_using_parameter",0},{"text_using_parameter",1,0},{"parameter_in_range",2,0.9,1.1}}
vertices(BAROALT,2.5)
Add(BAROALT)
----------------------------------------------------------------------------------------------------------------------------------------------
FPM						= CreateElement "ceStringPoly"
FPM.name				= "Indicated Airspeed"
FPM.material			= UFD_FONT
FPM.init_pos			= {0.85, 0.75, 0} --L-R,U-D,F-B
FPM.alignment			= "RightCenter"
FPM.stringdefs			= {0.006, 0.006, 0, 0.0} --either 004 or 005
FPM.additive_alpha		= true
FPM.collimated			= false
FPM.isdraw				= true	
FPM.use_mipfilter		= true
FPM.h_clip_relation		= h_clip_relations.COMPARE
FPM.level				= 11
FPM.element_params		= {"MFD_OPACITY","vv","LMFD_ADI_PAGE"}
FPM.formats				= {"%.0f"} --{"%.0f"}
FPM.controllers			= {{"opacity_using_parameter",0},{"text_using_parameter",1,0},{"parameter_in_range",2,0.9,1.1}}
vertices(FPM,2.5)
Add(FPM) 
----------------------------------------------------------------------------------------------------------------------------------------------
NAV						= CreateElement "ceStringPoly"
NAV.name				= "heading numb"
NAV.material			= UFD_FONT
NAV.init_pos			= {0, 0.85, 0} --L-R,U-D,F-B
NAV.alignment			= "CenterCenter"
NAV.stringdefs			= {0.008, 0.008, 0, 0.0} --either 004 or 005
NAV.additive_alpha		= true
NAV.collimated			= false
NAV.isdraw				= true	
NAV.use_mipfilter		= true
NAV.h_clip_relation		= h_clip_relations.COMPARE
NAV.level				= 11
NAV.element_params		= {"MFD_OPACITY","NAV","LMFD_ADI_PAGE"}
NAV.formats				= {"%03.0f"} --{"%.0f"}
NAV.controllers			= {{"opacity_using_parameter",0},{"text_using_parameter",1,0},{"parameter_in_range",2,0.9,1.1}}
vertices(NAV,2.5)
Add(NAV)
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
MENU_CHK_TEXT.level 				= 11
MENU_CHK_TEXT.init_pos 			    = {-0.565, 0.92, 0}
MENU_CHK_TEXT.init_rot 			    = {0, 0, 0}
MENU_CHK_TEXT.element_params 	    = {"MFD_OPACITY","LMFD_ADI_PAGE"}
MENU_CHK_TEXT.controllers		    =   {
                                        {"opacity_using_parameter",0},
                                        {"parameter_in_range",1,0.9,1.1},--ENGINE PAGE = 0
						            }
Add(MENU_CHK_TEXT)
-----------------------------------
--MENU TEXT
HSI_TEXT 					    = CreateElement "ceStringPoly"
HSI_TEXT.name 				    = "menu"
HSI_TEXT.material 			    = UFD_FONT
HSI_TEXT.value 					= "HSI"
HSI_TEXT.stringdefs 		    = {0.0050, 0.0050, 0.0004, 0.001}
HSI_TEXT.alignment 				= "CenterCenter"
HSI_TEXT.formats 			    = {"%s"}
HSI_TEXT.h_clip_relation        = h_clip_relations.COMPARE
HSI_TEXT.level 					= 11
HSI_TEXT.init_pos 			    = {0.565, 0.92, 0}
HSI_TEXT.init_rot 			    = {0, 0, 0}
HSI_TEXT.element_params 	    = {"MFD_OPACITY","LMFD_ADI_PAGE"}
HSI_TEXT.controllers		    =   {
                                        {"opacity_using_parameter",0},
                                        {"parameter_in_range",1,0.9,1.1},--ENGINE PAGE = 0
						            }
Add(HSI_TEXT)
