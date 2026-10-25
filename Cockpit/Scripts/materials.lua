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
symbologyPaths = {LockOn_Options.script_path.."HUD"}
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
