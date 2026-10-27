"""Ground-radar audit regressions at command time and across scan geometry."""
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
fixture=ROOT/'tests/test_display_startup.py'
ns={'__file__':str(fixture)}
exec(compile(fixture.read_text().split('\nfor page in ',1)[0],str(fixture),'exec'),ns)
runtime=ns['runtime']

lua=runtime()
lua.execute(r'''
local now=10;function get_model_time()return now end
local function put(n,v)get_param_handle(n):set(v)end
local function val(n)return get_param_handle(n):get()end
function get_base_data()return {getSelfCoordinates=function()return 0,1000,0 end,
 getHeading=function()return 0 end,getPitch=function()return 0 end,getRoll=function()return 0 end}end
package.preload.terrain=function()return {GetHeight=function()return 50 end}end
native={set_power=function()end};function GetDevice()return native end
dofile(SCRIPT_ROOT..'Systems/Radar_System.lua');post_initialize()
put('MAIN_POWER',1);put('HUD_MODE',7);put('F22N_RADAR_MODE',1);
put('F22_AG_RADAR_NATIVE_READY',1);put('F22_AG_RETURN_TIME',now);put('F22_AG_RETURN_COUNT',1)
for k,v in pairs({N=18520,U=50,E=0,TIME=now,RCS=4})do put('F22G_1_'..k,v)end
put('F22_AG_VIDEO_SOURCE_PRESENT',1);put('F22_AG_VIDEO_READY',1);put('F22_AG_VIDEO_GEOMETRY_QUALIFIED',1)
update();SetCommand(10601,1);update();assert(val('F22_AG_RADAR_CANDIDATE')==1)
now=25;SetCommand(10606,1)
assert(val('F22_AG_DESIGNATION_SEQUENCE')==0,'stopped owner accepted a 15-second-old candidate')
assert(val('F22_AG_RADAR_CANDIDATE')==0,'stale availability remained offered after rejection')
-- Normal recovery must permit a deliberate designation of a fresh image.
put('F22_AG_RETURN_TIME',now);put('F22G_1_TIME',now);update();SetCommand(10606,1)
assert(val('F22_AG_DESIGNATION_SEQUENCE')==1 and val('F22_AG_DESIGNATION_VALID')==1)
local n,e=val('F22_AG_DESIGNATION_NORTH'),val('F22_AG_DESIGNATION_EAST')
-- Loss of the real image source must fail even while Lua keeps updating.
now=26;put('F22_AG_VIDEO_READY',0);update();SetCommand(10606,1)
assert(val('F22_AG_DESIGNATION_SEQUENCE')==1)
assert(val('F22_AG_DESIGNATION_NORTH')==n and val('F22_AG_DESIGNATION_EAST')==e,'rejection changed accepted coordinates')
-- Native unavailability between owner ticks is not a valid selection snapshot.
put('F22_AG_VIDEO_READY',1);put('F22_AG_RETURN_TIME',now);put('F22G_1_TIME',now);update()
put('F22_AG_RADAR_NATIVE_READY',0);SetCommand(10606,1)
assert(val('F22_AG_DESIGNATION_SEQUENCE')==1)
put('F22_AG_RADAR_NATIVE_READY',1);now=0;SetCommand(10606,1)
assert(val('F22_AG_DESIGNATION_SEQUENCE')==1,'future owner snapshot survived a clock rewind')
''')
print('Ground command path: stopped owner, stale transport, availability loss, recovery and immutable coordinates PASS')

lua=runtime()
lua.execute(r'''
local Model=dofile(SCRIPT_ROOT..'Systems/AG_Radar_Computer.lua')
local terrain={GetHeight=function()return 50 end}
local pose={north=0,altitude=1000,east=0,heading=0,pitch=0,roll=0}
local v={F22_AG_RADAR_NATIVE_READY=1,F22_AG_RETURN_TIME=10,F22_AG_RETURN_COUNT=2}
local function get(n)return v[n]or 0 end;local function put(n,x)v[n]=x end
package.preload.terrain=function()return terrain end
local s=dofile(SCRIPT_ROOT..'Systems/AG_Radar_System.lua').new(get,put,function()end)
s:command('rws',1,true,10)
for i,a in ipairs({0,math.rad(20)})do
 local p='F22G_'..i..'_'
 for k,x in pairs({N=18520*math.cos(a),U=50,E=18520*math.sin(a),TIME=10,RCS=4})do put(p..k,x)end
end
s:update(pose,10,.05,true,true)
s:command('designate',1,true) -- no independent clock exists in this fixture
assert(get('F22_AG_DESIGNATION_SEQUENCE')==0,'missing independent time renewed a snapshot')
for i=1,10 do s:command('cursor_right',1,true,10.05)end
assert(not s.model.candidate,'cursor edit retained its previous candidate')
s:command('designate',1,true,10.05)
assert(get('F22_AG_DESIGNATION_SEQUENCE')==1)
assert(math.abs(get('F22_AG_DESIGNATION_EAST')-18520*math.sin(math.rad(20)))<1e-6,'TDC selected the old cursor point')
-- Recenter also reselects correctly before a new sensor update.
-- A completed coordinate designation leaves MAP live; no FRZ toggle is needed.
s:command('recenter',1,true,10.06);s:command('designate',1,true,10.06)
assert(get('F22_AG_DESIGNATION_SEQUENCE')==2 and get('F22_AG_DESIGNATION_EAST')==0)
-- Geometry follows the drawn rectangular cursor footprint, at every range.
local checked=0
for _,nm in ipairs({5,10,20,40})do for _,heading in ipairs({0,90,180,359})do
 local m=Model.new();m.range_nm=nm;pose.heading=math.rad(heading)
 local cursor=m:point(pose,terrain)
 for _,factor in ipairs({.95,1,1.05})do
  local right=nm*1852*Model.cursor_half_width/1.65*factor
  local p={north=cursor.north-right*math.sin(pose.heading),east=cursor.east+right*math.cos(pose.heading),altitude=50,stamp=10,rcs=4}
  m:observe({p},pose,terrain,10)
  assert((m.candidate~=nil)==(factor<=1),'hit box and rendered cursor disagree')
  checked=checked+1
 end
end end
local m=Model.new();m.range_nm=40;pose.heading=0
m:observe({{north=37040,east=1840,altitude=50,stamp=10,rcs=4}},pose,terrain,10)
assert(not m.candidate,'40-NM cursor still snaps to the audited out-of-box return')
-- Stationary image memory remains usable while transport and the owner stay fresh.
m:observe({{north=37040,east=0,altitude=50,stamp=10,rcs=4}},pose,terrain,17.9)
assert(m.candidate);m:select(pose,terrain,18.01);assert(not m.candidate)
print('Cursor footprint cases: '..checked)
''')
print('Ground selection: digital move/recenter interleaving, visible footprint, image expiry and all map ranges PASS')

lua=runtime()
lua.execute(r'''
local Model=dofile(SCRIPT_ROOT..'Systems/AG_Radar_Computer.lua')
local checked=0
for _,width in ipairs({30,60,120})do for az=-180,180 do
 local m=Model.new();m.width=width
 local p=m:scan_plan(math.rad(az))
 assert(p.az-p.half_az>=-Model.scan_azimuth_limit-1e-9)
 assert(p.az+p.half_az<=Model.scan_azimuth_limit+1e-9)
 assert((math.abs(az)<=60)==p.cursor_covered,'coverage reports an unreachable body bearing')
 checked=checked+1
end end
package.preload.terrain=function()return {GetHeight=function()return 50 end}end
local v={F22_AG_RADAR_NATIVE_READY=1,F22_AG_RETURN_TIME=10}
local function get(n)return v[n]or 0 end;local function put(n,x)v[n]=x end
local s=dofile(SCRIPT_ROOT..'Systems/AG_Radar_System.lua').new(get,put,function()end)
s.model.cursor_fraction=.1;s.model.cursor_az=math.rad(55)
s:update({north=0,altitude=1000,east=0,heading=0,pitch=0,roll=0},10,.05,true,true)
local center=-get('F22N_SCAN_ZONE_ORIGIN_AZIMUTH');local half=get('F22N_SCAN_ZONE_VOLUME_AZIMUTH')/2
assert(math.abs(center)+half<=math.rad(60)+1e-9,'actual owner still requests a 115-degree edge')
assert(get('F22_AG_RADAR_SCAN_LIMITED')==1)
-- This is a chosen common-backend limit, not a recovered APG-77 parameter.
dofile(SCRIPT_ROOT..'Systems/Radar_Native.lua')
assert(math.abs(perfomance.tracking_azimuth[2]-Model.scan_azimuth_limit)<1e-9)
print('Bounded scan cases: '..checked)
''')
print('Ground scan: 1,083 width/bearing cases, coverage flags and native parameter publication PASS')

for scale in (.07,.1,.18):
    lua=runtime();lua.globals().native_scale=scale
    lua.execute("function GetScale()return native_scale end;dofile(SCRIPT_ROOT..'PMFD_CENTER/ag_radar_format.lua')('PMFD_RDR_PAGE','')")
    lua.execute(r'''
    local m=dofile(SCRIPT_ROOT..'Systems/AG_Radar_Computer.lua')
    local plot=dofile(SCRIPT_ROOT..'MFD_COMMON/display_layout.lua').for_display('PMFD',1,native_scale).ground_plot
    local found=0
    for _,e in ipairs(elements)do
     if e.parent_element=='F22_AG_RDR_CURSOR' and e.vertices then
      for _,p in ipairs(e.vertices)do
       assert(math.abs(math.abs(p[1])-plot.x_scale*m.cursor_half_width)<1e-12)
       assert(math.abs(math.abs(p[2])-plot.y_scale*m.cursor_half_height)<1e-12)
      end
      found=found+1
     end
    end
    assert(found==2,'cursor geometry missing from actual format')
    ''')
print('Actual display: cursor box and selection use one definition at three native scales PASS')
