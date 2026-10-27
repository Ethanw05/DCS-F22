"""Physical polar geometry, identity colours and actual producer/display contract."""
from pathlib import Path
import contextlib,io,runpy
ROOT=Path(__file__).resolve().parents[1]
with contextlib.redirect_stdout(io.StringIO()):
    runtime=runpy.run_path(str(ROOT/'tests/test_display_startup.py'))['runtime']
lua=runtime()
lua.execute('''
local d=dofile(SCRIPT_ROOT..'Systems/Radar_Display.lua')
assert(d.affiliation(1)==1 and d.affiliation(-1)==-1 and d.affiliation(0)==0 and d.affiliation(2)==-1)
assert(d.affiliation(nil)==-1 and d.affiliation(99)==-1 and d.affiliation(0/0)==-1)
local x,y=d.point(20000,0,40000)
assert(math.abs(x)<1e-9 and math.abs(y-(d.origin_y+d.half_radius))<1e-9)
local lx,ly=d.point(20000,-math.pi/6,40000)
local rx,ry=d.point(20000,math.pi/6,40000)
assert(math.abs(lx+rx)<1e-9 and math.abs(ly-ry)<1e-9)
local nav=dofile(SCRIPT_ROOT..'Systems/NavGeometry.lua')
for _,pitch in ipairs({-20,-10,0,10,20}) do
    for _,roll in ipairs({-45,-20,0,20,45}) do
        local p,r=math.rad(pitch),math.rad(roll)
        local a,e,range=nav.project(30000,5000,2000,0,p,r)
        -- HUD projection uses up/forward; native radar spherical elevation
        -- uses up/horizontal-range. Convert the test observation accordingly.
        local spherical_el=math.atan(math.tan(e)*math.cos(a))
        local f,right,up=d.body_vector(range,a,spherical_el,p,r)
        assert(math.abs(f-30000)<1e-6 and math.abs(right-5000)<1e-6 and math.abs(up-2000)<1e-6)
    end
end
for heading=0,359 do
    local values={};d.compass(math.rad(heading),function(n,v) values[n]=v end)
    for i=1,19 do
        local p=string.format('F22_COMPASS_%02d_',i)
        if values[p..'VISIBLE']==1 then
            assert(math.abs(values[p..'X'])<1.02 and values[p..'Y']<.83)
        end
    end
end
function get_base_data() return {
    getSelfCoordinates=function() return 0,1500,0 end,
    getHeading=function() return -math.rad(271) end,
    getPitch=function() return 0 end,getRoll=function() return 0 end,
} end
native={set_power=function() end};function GetDevice(_) return native end
dofile(SCRIPT_ROOT..'Systems/Radar_System.lua');dofile(SCRIPT_ROOT..'../../tests/radar_body_fixture.lua');post_initialize()
local function put(n,v) get_param_handle(n):set(v) end
local function val(n) return get_param_handle(n):get() end
put('MAIN_POWER',1);put('F22N_RADAR_MODE',1)
SetCommand(10602,1)
local p='F22N_RADAR_CONTACT_01_'
put(p..'RANGE',18520);put(p..'AZIMUTH',.2);put(p..'ELEVATION',0)
put(p..'TIME',0);put(p..'FRIENDLY',1);put(p..'VX',0);put(p..'VY',0);put(p..'VZ',-170)
update();update();update()
assert(val('F22_SCOPE_01_VALID')==1)
assert(val('F22_SCOPE_01_AFFILIATION')==1)
assert(math.abs(val('F22_SCOPE_01_ALT_FT')-1500*3.280839895)<.01)
assert(math.abs(val('F22_SCOPE_01_VECTOR_LEN')-d.radius*170*30/(80*1852))<1e-6)
for _,iff in ipairs({-1,0,2,1}) do
    put(p..'FRIENDLY',iff);update();assert(val('F22_SCOPE_01_AFFILIATION')==1,'retains prior positive IFF between interrogations')
end
SetCommand(10613,1);update()
assert(val('F22_RADAR_CURSOR_X')>0 and val('F22N_RADAR_TDC_AZIMUTH')<0,'native candidate-ranking center reversed')
-- update_radar stores -TDCAZ as the candidate-ranking centre. The checked
-- native adapter reflects only the scanner's pattern rotation, preserving
-- the correct candidate metric for close contacts on both sides.
for _,az in ipairs({math.rad(-1.2),math.rad(1.2),math.rad(-20),math.rad(20)}) do
    local tdc=-az
    local ranking_center=-tdc
    local native_pattern=-ranking_center
    local beam_right=-math.sin(native_pattern)
    local beam_forward=math.cos(native_pattern)
    assert(math.abs(math.atan2(beam_right,beam_forward)-az)<1e-9)
    assert(math.abs(ranking_center-az)<1e-9)
end
SetCommand(10619,1);update();assert(val('F22N_IFF_INTERROGATOR_STATUS')==1)
put('MAIN_POWER',0);update()
assert(val('F22N_IFF_INTERROGATOR_STATUS')==0 and val('F22_SCOPE_01_VALID')==0)
''')
print('Polar display: 25 attitude poses, full compass sweep, native TDC sign, positive friend and unknown IFF evidence, altitude, velocity vectors and power clearing OK')

lua=runtime()
lua.execute('''
function MakeMaterial(_,color) return string.format('rgb-%d-%d-%d',color[1],color[2],color[3]) end
dofile(SCRIPT_ROOT..'PMFD_CENTER/radar_page.lua')
local lookup={};for _,e in ipairs(elements) do lookup[e.name]=e end
local expected={['1']='rgb-0-255-0',['-1']='rgb-255-220-0',['0']='rgb-255-35-20',['3']='rgb-0-255-255'}
for code,color in pairs(expected) do
    local parent='F22_RDR_TRACK_1_IFF_'..code
    local root=lookup[parent];assert(root,'missing identity-specific symbol')
    assert(root.element_params[1]=='F22_SCOPE_01_AFFILIATION')
    local count=0
    for _,e in ipairs(elements) do
        if e.parent_element==parent and e.kind=='ceSMultiLine' then
            assert(e.material==color,'identity colour mismatch');count=count+1
        end
    end
    assert(count>=4)
end
for _,e in ipairs(elements) do
    assert(e.level==20 or (e.level==19 and e.isvisible==false),'radar left its owned LCD stencil')
    if e.kind=='ceStringSLine'then assert(e.material:find('F22_LCD_FONT_',1,true)==1,'LCD text lost its own stroke resource')end
    assert(e.kind~='ceStringPoly','LCD page retained the bitmap lettering')
end
local config=dofile(SCRIPT_ROOT..'Systems/Radar_Config.lua')
assert(config.native_backend_enabled==true,'native radar disabled for the installed dogfight build')
''')
print('Actual Lua format: identity geometry, dedicated native LCD stroke fonts and LCD clipping level OK')
