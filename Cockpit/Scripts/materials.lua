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


dofile(LockOn_Options.script_path.."fonts.lua")
-- Native cockpit context loads SVG storage before constructing this font,
-- as in the AVQ-32 materials setup. Indicator init.lua does not register fonts.
symbologyPaths = {LockOn_Options.script_path.."HUD",LockOn_Options.script_path.."MFD_COMMON"}
local hud_style=dofile(LockOn_Options.script_path.."HUD/style.lua")
materials = {F22_HUD_GREEN = hud_style.color}
fonts = {F22_HUD_OWN_STROKE = {
    dofile(LockOn_Options.script_path.."HUD/font.lua"), 10, hud_style.color}}

-- Dedicated native stroke resources for the PMFD; original F-22 glyphs.
local radar_colors={WHITE={240,247,246,255},BLUE={113,188,240,255},
    GREEN={68,255,110,255},YELLOW={255,220,64,255},RED={255,78,78,255},MAGENTA={235,80,211,255}}
for name,color in pairs(radar_colors) do
    materials['F22_RDR_'..name]=color
    local descriptor=dofile(LockOn_Options.script_path..'HUD/font.lua')
    -- The smaller LCD needs a stronger stroke than the collimated HUD.
    descriptor.thickness=1.4;descriptor.fuzziness=.35
    fonts['F22_RDR_FONT_'..name]={descriptor,10,color}
end

-- Native LCD/UFC typography; independent of the HUD and original UFD bitmap font.
local lcd_colors={WHITE={240,247,246,255},BLUE={113,188,240,255},GREEN={0,255,0,255},
 YELLOW={255,220,40,255},RED={255,78,78,255},MAGENTA={235,80,211,255},TEAL={0,255,255,255},ORANGE={255,102,0,255}}
for name,color in pairs(lcd_colors)do
 fonts['F22_LCD_FONT_'..name]={dofile(LockOn_Options.script_path..'MFD_COMMON/font.lua'),10,color}
end

-- A/A geometry and labels share the same linear color resources. Other
-- indicators retain their existing palettes and the common neutral background.
local aa_palette=dofile(LockOn_Options.script_path..'MFD_COMMON/radar_palette.lua')
for name,color in pairs(aa_palette.linear)do
 materials[aa_palette.line(name)]=color
 fonts[aa_palette.font(name)]={dofile(LockOn_Options.script_path..'MFD_COMMON/font.lua'),10,color}
end
