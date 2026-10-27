"""Actual route transactions and ICP keypad; rejects malformed data without mutations."""
from test_display_startup import runtime
sim=runtime()
sim.execute("""
local E=dofile(SCRIPT_ROOT..'Systems/Nav_Entry.lua')
local e=E.new(2,41.5,42.5,10000,true)
e:choose(2);for c in ('4130123'):gmatch('.')do e:digit(tonumber(c))end
assert(e:accept() and math.abs(e.lat-(41+30.123/60))<1e-9)
e:hemisphere();assert(e.lat<0)
e:choose(3);e.buffer='04260123';assert(not e:accept(),'minutes 60 rejected')
e.buffer='18000001';assert(not e:accept(),'beyond date line rejected')
e.buffer='17959999';assert(e:accept())
local n=E.new(2,0,0,1000,false);assert(not n:ready(),'unknown coordinates must be entered explicitly')
local N=dofile(SCRIPT_ROOT..'Systems/Nav_Computer.lua')
local c=N.new({{x=0,y=0,alt=1000},{x=100,y=0,alt=1000}})
assert(c:edit(2,500,600,2000) and c.route[1].x==500)
assert(c:undo_edit() and c.route[1].x==100)
assert(c:edit(3,700,800,1000) and #c.route==2 and c.selected==2)
assert(c:undo_edit() and #c.route==1 and c.selected==1)
assert(not c:edit(200,0,0,1000) and #c.route==1,'reject sparse IDs')
assert(not c:edit(3,0/0,0,1000) and #c.route==1)
assert(not c:undo_edit())
assert(c:select_id(2) and not c:select_id(3))
""")
sim=runtime()
sim.execute(r'''
dofile(SCRIPT_ROOT..'Systems/ICP_System.lua');post_initialize()
local function p(k,v)get_param_handle(k):set(v)end
local function g(k)return get_param_handle(k):get()end
local function key(c)SetCommand(c,devices.ICP_SYSTEM+.375);SetCommand(c,devices.ICP_SYSTEM+.25)end
p('MAIN_POWER',1);p('HUD_WP_INDEX',2);p('F22_NAV_FIX_LAT',41.5);p('F22_NAV_FIX_LON',42.5)
p('F22_NAV_FIX_ALT_FT',10000);p('F22_NAV_FIX_GEO_VALID',1)
key(3004);key(3009)
for d in ('4130123'):gmatch('.')do key(d=='0'and 3027 or 3016+tonumber(d))end
assert(g('F22_UFC_SCRATCH')=='4130123_'and g('F22_NAV_EDIT_LAT')==0)
key(3012);assert(g('F22_UFC_ROW_5')=='HEMI S','explicit hemisphere modifier lost')
key(3009)
assert(g('F22_ENTRY_NAV_ACTIVE')==1 and g('F22_ENTRY_NAV_COMMAND')==10839)
assert(math.abs(g('F22_NAV_EDIT_LAT')+41.50205)<1e-8)
assert(g('F22_UFC_SELECTED')==2,'absent owner falsely acknowledged commit')
key(3003);assert(g('F22_UFC_PAGE')=='NAV'and g('F22_ENTRY_NAV_ACTIVE')==0)
''')
print('Coordinate validation, route commit/undo and UFC hemisphere/cancel transport PASS')
