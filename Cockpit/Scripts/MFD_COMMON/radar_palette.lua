-- GPL-3.0-or-later. A/A symbology is authored in display sRGB.
-- CockpitBase MakeMaterial and the native font registry normalize RGB by 255
-- without decoding sRGB. Decode here before the linear cockpit render pass;
-- otherwise the light-blue rings and compass approach white after tone mapping.
local M={srgb={
 blue={113,188,240,255},cyan={0,255,255,255},white={240,247,246,255},
 green={0,255,0,255},yellow={255,220,0,255},red={255,35,20,255},
 magenta={235,80,211,255},
},linear={}}
function M.decode_byte(value)
 local v=value/255
 return 255*(v<=.04045 and v/12.92 or ((v+.055)/1.055)^2.4)
end
for name,color in pairs(M.srgb)do
 local native={};for i=1,3 do native[i]=M.decode_byte(color[i])end
 native[4]=color[4] -- alpha is coverage, not a color channel
 M.linear[name]=native
end
function M.line(name)return 'F22_AA_LINE_'..string.upper(name)end
function M.font(name)return 'F22_AA_FONT_'..string.upper(name)end
return M
