"""Retired summaries cannot return through startup, DMS, combat or menu routes."""
from pathlib import Path
from test_display_startup import runtime
ROOT=Path(__file__).resolve().parents[1]
lua=runtime()
lua.execute("""
function get_aircraft_property()return 1 end
function get_aircraft_draw_argument_value(n)return draws[n]or 0 end
function set_aircraft_draw_argument_value(n,v)draws[n]=v end
dofile(SCRIPT_ROOT..'Systems/MFD_System.lua');post_initialize()
local function g(k)return get_param_handle(k):get()end
local function key(c)SetCommand(c,devices.MFD_SYSTEM+.375);SetCommand(c,devices.MFD_SYSTEM+.25);update()end
get_param_handle('MAIN_POWER'):set(1);update()
assert(g('LMFD_PAGE')==5 and g('LMFD_BAY_PAGE')==1 and g('LMFD_SMS_PAGE')==0)
local events={};function dispatch_action(d,c,v)events[#events+1]={d,c,v}end
key(10073);assert(g('LMFD_PAGE')==0)
key(10061);assert(g('LMFD_PAGE')==0)
local n=0;for _,e in ipairs(events)do if e[1]==devices.PMFD_SYSTEM and e[2]==10825 and e[3]==1 then n=n+1 end end
assert(n==0,'blank former Attack key opened another display')
key(10063);assert(g('LMFD_PAGE')==5 and g('LMFD_BAY_PAGE')==1)
for i=1,24 do key(10820);assert(g('LMFD_PAGE')~=7 and g('LMFD_SMS_PAGE')==0)end
key(10005);assert(g('LMFD_PAGE')==5 and g('RMFD_PAGE')==7)
""")
for page in ['attack_page.lua','ground_attack.lua','sms_page.lua']:
 lua=runtime();lua.execute(f"dofile(SCRIPT_ROOT..'MFD_LEFT/{page}')")
 assert len(lua.globals().elements)==0,page
lua=runtime();lua.execute("dofile(SCRIPT_ROOT..'UFD_LEFT/init.lua')")
assert len(lua.globals().page_subsets)==1
assert 'ew_page.lua' not in (ROOT/'Cockpit/Scripts/UFD_LEFT/init.lua').read_text()
print('Actual MFD owner: Stores default, TSD, DMS/combat shortcuts and no retired Attack/EW subsets PASS')
