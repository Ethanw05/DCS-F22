"""Display true/magnetic selection preserves the accepted physical course."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
fixture = ROOT / 'tests/test_display_startup.py'
scope = {'__file__': str(fixture)}
exec(compile(fixture.read_text().split('\nfor page in ', 1)[0], str(fixture), 'exec'), scope)
lua = scope['runtime']()
lua.execute(r'''
local function get(k)return get_param_handle(k):get()end
local function put(k,v)get_param_handle(k):set(v)end
local guidance_physical=dofile(SCRIPT_ROOT..'../../tests/physical_frame_fixture.lua')({F22_ESSENTIAL_POWER=1})
guidance_physical:publish(get_param_handle('F22_AP_CLOCK'):get())
dofile(SCRIPT_ROOT..'Systems/Flight_Guidance.lua');post_initialize()
put('MAIN_POWER',1);put('F22_MAG_VALID',1);put('F22_MAG_DECL',math.rad(10))
SetCommand(10949,90);put('F22_NAV_OBS',1);update()
local guide=dofile(SCRIPT_ROOT..'Systems/Nav_Guidance.lua')
local own={x=0,y=0,alt=1000,heading=0,gs=200}
local point={bearing=0,distance=18520,waypoint={id=2}}
guide(get,put,own,point);local physical=get('F22_NAV_STEER_TRACK')
SetCommand(10939,1);update();guide(get,put,own,point)
assert(math.abs(get('F22_NAV_COURSE')-80)<1e-8 and get('F22_NAV_COURSE_TRUE')==90)
assert(math.abs(get('F22_NAV_STEER_TRACK')-physical)<1e-10,'display reference changed the physical course')
put('F22_MAG_VALID',0);update()
assert(get('F22_NAV_COURSE_REF_VALID')==0 and get('F22_NAV_COURSE_TRUE')==90)
local channel=dofile(SCRIPT_ROOT..'Systems/Entry_Transaction.lua').channel('GUIDANCE',get,put)
local request=channel:submit(function(_,c,v)SetCommand(c,v)end,'FLIGHT_GUIDANCE',10949,80,function()return true end)
assert(request.error()=='OWNER REJECTED' and get('F22_NAV_COURSE_TRUE')==90)
put('F22_MAG_VALID',1);put('F22_MAG_DECL',math.rad(20));update();guide(get,put,own,point)
assert(math.abs(get('F22_NAV_COURSE')-70)<1e-8 and get('F22_NAV_COURSE_TRUE')==90)
assert(math.abs(get('F22_NAV_STEER_TRACK')-physical)<1e-10)
''')
print('Canonical true course, magnetic display conversion, missing variation rejection and restoration invariance PASS')
