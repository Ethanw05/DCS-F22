"""A/A color resources must survive the linear native material contract.

The offline preview consumes sRGB while CockpitBase normalizes bytes directly.
Exercise actual registered resources and element bindings, not a mock palette.
"""
from pathlib import Path
from test_display_startup import runtime

root=Path(__file__).resolve().parents[1]
sim=runtime()
sim.execute("assert(loadfile(SCRIPT_ROOT..'materials.lua'))()")
sim.execute("dofile(SCRIPT_ROOT..'PMFD_CENTER/radar_format.lua')('PMFD_RDR_PAGE','CHECK_AA_')")
sim.execute(r'''
local palette=dofile(SCRIPT_ROOT..'MFD_COMMON/radar_palette.lua')
local function encode(v)
 v=v/255;return 255*(v<=.0031308 and 12.92*v or 1.055*v^(1/2.4)-.055)
end
for name,expected in pairs(palette.srgb)do
 local line=materials[palette.line(name)]
 local font=fonts[palette.font(name)]
 assert(line and font,'unregistered native A/A resource '..name)
 assert(font[1].class=='ceSLineFont'and font[1].symb_storage=='f22_lcd_font')
 for i=1,3 do
  assert(math.abs(encode(line[i])-expected[i])<1e-6,'incorrect native color space')
  assert(line[i]==font[3][i],'font and geometry palette mismatch')
 end
 assert(line[4]==255 and font[3][4]==255,'alpha was gamma decoded')
end
-- The original near-white blue must not reach the linear renderer unchanged.
local blue=materials[palette.line('blue')]
assert(blue[1]<45 and blue[2]>125 and blue[2]<132 and blue[3]>220)
local blue_lines,blue_text,lines=0,0,0
for _,e in ipairs(elements)do
 if e.kind=='ceSMultiLine'then
  lines=lines+1
  assert(e.material:find('F22_AA_LINE_',1,true)==1,'unregistered/legacy A/A line material')
  if e.material==palette.line('blue')then blue_lines=blue_lines+1 end
 elseif e.kind=='ceStringSLine'then
  assert(e.material:find('F22_AA_FONT_',1,true)==1,'legacy font palette in A/A format')
  if e.material==palette.font('blue')then blue_text=blue_text+1 end
 end
end
assert(blue_lines>200 and blue_text>20 and lines>blue_lines,'A/A range/compass/track colors not exercised')
''')
print('A/A palette: real native line/font resources, sRGB round trip, neutral background separation and all radar bindings PASS')
