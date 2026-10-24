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


dofile(LockOn_Options.common_script_path.."elements_defs.lua")













MAXWAYPOINTS=60
MAXCONTACT=64

tex_scale = 0.004

SetScale(MILLYRADIANS)

DEFAULT_LEVEL = 8 --8
NOCLIP_LEVEL = DEFAULT_LEVEL - 1
CLIP_LEVEL = DEFAULT_LEVEL + 1

Centrex=-3
Centrey=-5

local Fond_MFD_sizeX = 125 -- demi largeur clipping
local Fond_MFD_sizeY = 115 -- demi hauteur

verts_MFD = 	{ {0,0},
				{-Fond_MFD_sizeX,Fond_MFD_sizeY-4},
				{-Fond_MFD_sizeX,-Fond_MFD_sizeY+4},
				{-Fond_MFD_sizeX+4,-Fond_MFD_sizeY},
				{ Fond_MFD_sizeX-4,-Fond_MFD_sizeY},
				{ Fond_MFD_sizeX,-Fond_MFD_sizeY+4},
				{ Fond_MFD_sizeX,Fond_MFD_sizeY-4},
				{ Fond_MFD_sizeX-4,Fond_MFD_sizeY},
				{-Fond_MFD_sizeX+4,Fond_MFD_sizeY}}

inds_MFD = 	{	0,1,2,
				0,2,3,
				0,3,4,
				0,4,5,
				0,5,6,
				0,6,7,
				0,7,8,
				0,8,1}
					
Base = CreateElement "ceMeshPoly"

scalex=1.11
scaley=1.035

local hTAC=0.0105
local lTAC=0.0120
local eTAC=0.0017
font_TAC={hTAC, lTAC, eTAC, 0.0}

posTop=102.0 -- 98.0
posTopdown=91.5 -- 87.5
posBottom=-111.0 -- -107.0
posBottomup=-101.0 -- -97.0
posLeft=-119.0 -- -115.0
posLeftin=-111.0 -- -107.0
posRight=113.5 -- 109.5
posRightin=105.5 -- 101.5

posBut1y=66.5
posmodey=48.5
posBut2y=30
posBut3y=-5
posBut4y=-41
posBut5y=-75.5
posBut6x=-79.0
posBut7x=-39
posBut8x=-2.0
posBut9x=36.0
posBut10x=75.5
posBut11y=-75.5
posBut12y=-41
posBut13y=-5
posBut14y=30
posBut15y=66.5
posBut16x=77.0
posBut17x=39.0
posBut18x=-1.0
posBut19x=-39.5
posBut20x=-77.0

posTACy=-92

local hMENU=0.006
local lMENU=0.007
local eMENU=0.0005
font_MENU={hMENU, lMENU, eMENU, 0.0}

local hMENUL=0.008
local lMENUL=0.007
local eMENUL=-0.0005
font_MENUL={hMENUL, lMENUL, eMENUL, 0.0}

local hMENUl=0.006
local lMENUl=0.007
local eMENUl=-0.0005
font_MENUl={hMENUl, lMENUl, eMENUl, 0.0}

local hCASL=0.012
local lCASL=0.010
local eCASL=-0.0005
font_CASL={hCASL, lCASL, eCASL, 0.0}

local hCASl=0.009
local lCASl=0.007
local eCASl=-0.0005
font_CASl={hCASl, lCASl, eCASl, 0.0}

local hCAlt=0.004
local lCAlt=0.004
local eCAlt=-0.0005
font_CAlt={hCAlt, lCAlt, eCAlt, 0.0}

local hCNum=0.004
local lCNum=0.004
local eCNum=-0.0005
font_CNum={hCNum, lCNum, eCNum, 0.0}

local hMENUHSI=0.0046
local lMENUHSI=0.0056
local eMENUVHSI=0.001
local eMENUHHSI=0.0002
font_MENUHSI={hMENUHSI, lMENUHSI, eMENUHHSI, eMENUVHSI}

local hWEAPS=0.005
local lWEAPS=0.008
local eWEAPSV=0.0
local eWEAPSH=-0.0006
font_WEAPS={hWEAPS, lWEAPS, eWEAPSH, eWEAPSV}

local hWEAPSEF=0.005
local lWEAPSEF=0.0075
local eWEAPSHEF=-0.002
font_WEAPSEF={hWEAPSEF, lWEAPSEF, eWEAPSHEF, eWEAPSV}

local hADV=0.0080
local lADV=0.010
local eADV=-0.0005
font_ADV={hADV, lADV, eADV, 0.0}

local hPROG=0.006
local lPROG=0.007
local ePROG=0.0000
font_PROG={hPROG, lPROG, ePROG, 0.0}

local hBTDN=0.005
local lBTDN=0.005
local eBTDN=0.0000
font_BTDN={hBTDN, lBTDN, eBTDN, 0.0}

-- Rectangles
local res=1024
-------------------
-- vertical
-------------------
-- set_verts_rect3letters_vert()
local l=31
local h=100
local x=58
local y=625
local lr=l/(res*tex_scale/scalex)
local hr=h/(res*tex_scale/scaley)
verts_rect3letters_vert={{-lr/2,hr/2}, {-lr/2, -hr/2},{lr/2, -hr/2}, {lr/2, hr/2}}
texparams_rect3letters_vert={(x+(l/2))/res, (y+(h/2))/res, tex_scale/scalex, tex_scale/scaley} -- pos x centre, pos y centre

-- set_verts_rect4letters_vert()
l=31
h=130
x=96
y=485
lr=l/(res*tex_scale/scalex)
hr=h/(res*tex_scale/scaley)
verts_rect4letters_vert={{-lr/2,hr/2}, {-lr/2, -hr/2},{lr/2, -hr/2}, {lr/2, hr/2}}
texparams_rect4letters_vert={(x+(l/2))/res, (y+(h/2))/res, tex_scale/scalex, tex_scale/scaley} -- pos x centre, pos y centre

-------------------
-- horizontal
-------------------
-- set_verts_rect3letters_hor()
l=75
h=41
x=336
y=841
lr=l/(res*tex_scale/scalex)
hr=h/(res*tex_scale/scaley)
verts_rect3letters_hor={{-lr/2,hr/2}, {-lr/2, -hr/2},{lr/2, -hr/2}, {lr/2, hr/2}}
texparams_rect3letters_hor={(x+(l/2))/res, (y+(h/2))/res, tex_scale/scalex, tex_scale/scaley} -- pos x centre, pos y centre

-- set_verts_rect4letters_hor()
l=95
h=41
x=161
y=796
lr=l/(res*tex_scale/scalex)
hr=h/(res*tex_scale/scaley)
verts_rect4letters_hor={{-lr/2,hr/2}, {-lr/2, -hr/2},{lr/2, -hr/2}, {lr/2, hr/2}}
texparams_rect4letters_hor={(x+(l/2))/res, (y+(h/2))/res, tex_scale/scalex, tex_scale/scaley} -- pos x centre, pos y centre

-- set_verts_rect6letters_hor()
l=145
h=41
x=416
y=841
lr=l/(res*tex_scale/scalex)
hr=h/(res*tex_scale/scaley)
verts_rect6letters_hor={{-lr/2,hr/2}, {-lr/2, -hr/2},{lr/2, -hr/2}, {lr/2, hr/2}}
texparams_rect6letters_hor={(x+(l/2))/res, (y+(h/2))/res, tex_scale/scalex, tex_scale/scaley} -- pos x centre, pos y centr

texparams_fcs={(x+(l/2))/res, (y+(h/2))/res, tex_scale/1.3, tex_scale/1.3}
