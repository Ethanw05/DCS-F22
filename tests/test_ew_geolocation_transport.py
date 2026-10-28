"""Real receiver-to-display owners, without mission object positions or RF range."""
from pathlib import Path

root = Path(__file__).resolve().parents[1]
fixture = root / 'tests/test_display_startup.py'
ns = {'__file__': str(fixture)}
exec(compile(fixture.read_text().split('\nfor page in ', 1)[0], str(fixture), 'exec'), ns)
runtime = ns['runtime']
lua = runtime()
lua.execute(r'''
local now=0
local function position(t)return {n=250*t,u=3000,e=3*t*t}end
local function pose(t)return {heading=math.atan2(6*t,250),pitch=.08*math.sin(t/6),roll=.4*math.sin(t/9)}end
function get_model_time()return now end
function get_base_data()return {
 getSelfCoordinates=function()local p=position(now);return p.n,p.u,p.e end,
 getHeading=function()return -pose(now).heading end,
 getPitch=function()return pose(now).pitch end,getRoll=function()return pose(now).roll end}end
local native={set_power=function()end}
function GetDevice(id)if id==13 or id==17 then return native end end
local function put(k,v)get_param_handle(k):set(v)end
local function get(k)return get_param_handle(k):get()end
dofile(SCRIPT_ROOT..'Systems/RWR_System.lua');post_initialize();local rf_update=update
dofile(SCRIPT_ROOT..'Systems/Radar_System.lua');post_initialize();local radar_update=update
local Frames=dofile(SCRIPT_ROOT..'Systems/Gun_Frames.lua')
put('MAIN_POWER',1);put('F22_RADAR_RANGE_NM',40);put('HUD_MODE',2)
put('F22_RADAR_ACQ_COORDINATES_READY',1);put('F22_RADAR_OBSERVATIONS_READY',1);put('F22N_RADAR_MODE',1)
local prefix='RWR_CONTACT_01_'
for k,v in pairs({SOURCE=72,SIGNAL=1,GENERAL_TYPE=2,UNIT_TYPE='SA-11'})do put(prefix..k,v)end
local function tick(t,contradiction)
 now=t;local stamp=t-.2;local p=position(stamp)
 local n,u,e=20000-p.n,50-p.u,3000-p.e;local range=math.sqrt(n*n+u*u+e*e)
 local world=contradiction and {-1,0,0}or{n/range,u/range,e/range}
 local body=Frames.body(Frames.from_pose(pose(stamp)),world)
 put(prefix..'TIME',.2);put(prefix..'AZIMUTH',-math.atan2(body[3],body[1]))
 put(prefix..'ELEVATION',math.atan2(body[2],math.sqrt(body[1]^2+body[3]^2)))
 rf_update();radar_update()
end
for i=0,900 do tick(i*.05)end
assert(get('F22_TACTICAL_COUNT')==1 and get('F22_TACTICAL_01_GEO_VALID')==1)
assert(math.abs(get('F22_TACTICAL_01_GEO_N')-20000)<1 and math.abs(get('F22_TACTICAL_01_GEO_E')-3000)<1)
assert(get('F22_TACTICAL_01_GEO_RADIUS_M')>0 and get('F22_TACTICAL_01_GEO_AGE')<2)
assert(get('F22_TACTICAL_01_RANGE_VALID')==0 and get('F22_TACTICAL_01_MEASURED_RANGE_M')==0,'passive fit became radar range')
assert(get('F22_DEFENSIVE_GEO_VALID')==1 and get('F22_DEFENSIVE_RANGE_VALID')==0)
assert(get('F22_DEFENSIVE_GEO_RADIUS_NM')>0 and get('F22_DEFENSIVE_GEO_STATUS')==4)
assert(get('F22_DEF_OV_01_GEO')==1 and get('F22_DEF_OV_01_RANGED')==0,'overview lost estimated provenance')
assert(get('F22_TSD_GEO_COUNT')==1 and get('F22_TSD_GEO_01_SOURCE')==get('F22_TACTICAL_01_SOURCE'))
assert(get('F22_TSD_GEO_01_AFFILIATION')==-1,'ground taxonomy implied hostility')
assert(get('F22_TSD_BEARING_01_VALID')==0,'on-map estimate has duplicate bearing symbol')
assert(get('F22_TSD_GEO_01_H_VALID')==1 and get('F22_TSD_GEO_01_V_VALID')==1)
local own=position(now);local h=pose(now).heading;local factor=1.45/(get('F22_RADAR_RANGE_NM')*1852)
local x=(-(20000-own.n)*math.sin(h)+(3000-own.e)*math.cos(h))*factor
local y=-.66+((20000-own.n)*math.cos(h)+(3000-own.e)*math.sin(h))*factor
assert(math.abs(get('F22_TSD_GEO_01_X')-x)<.0001 and math.abs(get('F22_TSD_GEO_01_Y')-y)<.0001,'TSD failed heading-up reprojection')
assert(get('F22_RADAR_DRAWN_COUNT')==0 and get('F22_RADAR_STT_VALID')==0 and get('F22_RADAR_RF_CUE_ACTIVE')==0,'ground estimate became airborne discovery/lock')
-- Fresh contradicting evidence withdraws all four consumers in one owner tick.
tick(45.05,true)
assert(get('F22_TACTICAL_01_GEO_VALID')==0 and get('F22_DEFENSIVE_GEO_VALID')==0)
assert(get('F22_DEF_OV_01_GEO')==0 and get('F22_TSD_GEO_COUNT')==0)
assert(get('F22_TSD_BEARING_01_VALID')==1,'withdrawn fix did not fall back to a bearing')
put('MAIN_POWER',0);tick(45.1)
assert(get('F22_TACTICAL_COUNT')==0 and get('F22_DEFENSIVE_VALID')==0 and get('F22_DEF_OV_VALID')==0 and get('F22_TSD_GEO_COUNT')==0)
for _,a in ipairs(actions)do assert(a[1]~=84 and a[1]~=350 and a[1]~=509,'EW fit commanded firing/lock')end
-- Continued RF traffic cannot renew an expired location fit; a missing
-- qualified measured direction cannot introduce one through the store.
local store=dofile(SCRIPT_ROOT..'Systems/Tactical_Tracks.lua').new()
local fix={n=20000,u=50,e=3000,time=50,radius=1000,samples=10,span=15,residual=0}
local contact={source=8,age=0,az=0,el=0,signal=1,general=2,world={1,0,0},geolocation=fix}
store:update(50,{rf={sequence=1,time=50,contacts={contact}}},true)
assert(store.contacts[1].geolocation and not store.contacts[1].range)
for i=1,140 do
 local t=50+i*.05
 store:update(t,{rf={sequence=i+1,time=t,contacts={contact}}},true)
end
assert(#store.contacts==1 and not store.contacts[1].geolocation and not store.contacts[1].range)
fix.time=57;contact.world=nil
store:update(57.05,{rf={sequence=200,time=57.05,contacts={contact}}},true)
assert(not store.contacts[1].geolocation)
''')
print('Actual RWR -> tactical store -> defensive/detail/TSD: delayed turning flight, estimate provenance, reprojection, contradiction and power PASS')

def graph(page):
    lua = runtime()
    lua.globals().PAGE = page
    lua.execute(r'''
    for _,name in ipairs({'RWR_System','Radar_System','MFD_System'})do dofile(SCRIPT_ROOT..'Systems/'..name..'.lua')end
    local declared={};for k in pairs(handles)do declared[k]=true end
    dofile(SCRIPT_ROOT..PAGE)
    named={}
    for _,e in ipairs(elements)do assert(not named[e.name],'duplicate element name: '..e.name);named[e.name]=e end
    for _,e in ipairs(elements)do
     assert(not e.parent_element or named[e.parent_element],'unresolved native parent')
     for _,p in ipairs(e.element_params or {})do
      if p:find('GEO',1,true)or p=='F22_RADAR_SENSOR_TASK'then assert(declared[p],'uninitialized native parameter '..p)end
     end
    end
    function put(k,v)get_param_handle(k):set(v)end
    function get(k)return get_param_handle(k):get()end
    function visible(e)
     if e.parent_element and not visible(named[e.parent_element])then return false end
     for _,c in ipairs(e.controllers or {})do
      local p=e.element_params and e.element_params[c[2]+1];local v=p and get(p)
      if c[1]=='parameter_in_range'and(v<c[3]or v>c[4])then return false end
      if c[1]=='opacity_using_parameter'and v<=0 then return false end
     end
     return true
    end
    function text(label)
     for _,e in ipairs(elements)do if(e.value==label or e.formats and e.formats[1]==label)and visible(e)then return true end end
     return false
    end
    put('MFD_OPACITY',1)
    ''')
    return lua

lua = graph('PMFD_CENTER/radar_page.lua')
lua.execute(r'''
put('PMFD_RDR_PAGE',1);put('HUD_MODE',2);put('F22_RADAR_MODE_CODE',2);put('F22_RADAR_SCAN_AUTO',1)
put('F22_TSD_VALID',1);put('F22_DEF_OV_CURRENT',1);put('F22_TSD_GEO_01_VALID',1);put('F22_TSD_GEO_01_H_VALID',1)
assert(text('RF EST')and visible(named.F22_COMPAT_AA_F22_TSD_GEO_1_ERROR_H))
put('F22_DEF_OV_CURRENT',0)
assert(not text('RF EST')and not visible(named.F22_COMPAT_AA_F22_TSD_GEO_1_ERROR_H),'stalled RWR owner retained an estimated mark')
''')
lua = graph('MFD_RIGHT/rwr_page.lua')
lua.execute(r'''
put('RMFD_RWR_PAGE',1);put('F22_DEF_OV_CURRENT',1);put('F22_DEF_OV_01_VALID',1)
put('F22_DEF_OV_01_AFFILIATION',-1);put('F22_DEF_OV_01_GEO',1);put('F22_DEF_OV_01_RANGED',0)
assert(text('E'),'conditional RF location lost its estimate marker')
put('F22_DEF_OV_01_GEO',0);put('F22_DEF_OV_01_RANGED',1)
assert(not text('E'),'radar range retained the conditional estimate marker')
put('F22_DEF_OV_01_RANGED',0)
assert(not text('E'),'bearing-only contact claimed an estimated position')
put('F22_DEF_OV_01_GEO',1);put('F22_DEF_OV_CURRENT',0)
assert(not text('E')and text('NO DATA'),'stale defensive owner retained its estimated position')
''')
print('Actual native graphs: early bindings, estimated/error/age display and independent stale-owner withdrawal PASS')
