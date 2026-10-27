"""User palette, evidence boundaries and actual atlas/font construction."""
from test_display_startup import runtime
lua=runtime()
lua.execute('''
local I=dofile(SCRIPT_ROOT..'Systems/Tactical_Identity.lua')
assert(I.color(0)=='red'and I.color(1)=='green'and I.color(-1)=='yellow')
assert(I.color(3)=='cyan'and I.color(99)=='yellow'and I.color(nil)=='yellow')
local Display=dofile(SCRIPT_ROOT..'Systems/Radar_Display.lua')
for _,native in ipairs({2,3,-1,99})do
 assert(Display.affiliation(native)==-1,'native nonreply/coalition became hostile or wingman')
end
assert(Display.affiliation(1)==1 and Display.affiliation(0)==0,'qualified combat ID lost its palette')
local IFF=dofile(SCRIPT_ROOT..'Systems/Radar_IFF.lua').new();IFF:update(10,true)
assert(IFF:reply(0,10,0,0)==-1,'missing raw friendly reply became hostile')
-- Load the real fonts, rather than letting the native-property fixture hide
-- a local-atlas scope error behind a permissive MakeFont mock.
local original=dofile
function dofile(path)
 if path==SCRIPT_ROOT..'fonts.lua'then return assert(loadfile(path))()end
 return original(path)
end
function MakeFont(atlas,rgba,name)
 assert(type(atlas)=='table','font constructor received missing/local atlas')
 assert(type(rgba)=='table'and #rgba==4,'font color is not an RGBA tuple')
 return name or 'font'
end
dofile(SCRIPT_ROOT..'PMFD_CENTER/radar_page.lua')
assert(UFD_TEAL=='UFD_FONT_TEAL','reserved cyan did not reuse original native atlas font')
''')
print('Tactical identity: red hostile, green friend, yellow unknown, reserved cyan flight; real font atlas construction and IFF boundary PASS')
