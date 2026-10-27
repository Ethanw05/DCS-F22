"""Native POWER must survive the real receiver/picture/display path."""
from pathlib import Path
repo=Path(__file__).resolve().parents[1]
fixture=repo/'tests/test_display_startup.py';namespace={'__file__':str(fixture)}
exec(compile(fixture.read_text().split('\nfor page in ',1)[0],str(fixture),'exec'),namespace)
lua=namespace['runtime']()
lua.execute('''
local Prox=dofile(SCRIPT_ROOT..'Systems/RWR_Proximity.lua')
assert(Prox.radius(.1)>.7 and Prox.radius(.8)<.2)
assert(Prox.radius(0)==.84 and Prox.radius(1)>.1)
for _,x in ipairs({-1,1.01,math.huge,0/0,'0.5'})do assert(not Prox.radius(x))end
local now=0
function get_model_time()return now end
function GetDevice(id)if id==17 then return {set_power=function()end}end end
local function put(k,v)get_param_handle(k):set(v)end
local function get(k)return get_param_handle(k):get()end
dofile(SCRIPT_ROOT..'Systems/RWR_System.lua');post_initialize()
put('MAIN_POWER',1);put('F22_RADAR_RANGE_NM',40)
local q='RWR_CONTACT_01_'
for k,v in pairs({SOURCE=55,TIME=0,AZIMUTH=-.4,ELEVATION=0,SIGNAL=1,PRIORITY=100,POWER=.15,GENERAL_TYPE=1,UNIT_TYPE='F-15C'})do put(q..k,v)end
now=.05;update()
assert(get('F22_TACTICAL_01_RF_POWER_VALID')==1 and get('F22_TACTICAL_01_RF_POWER')==.15)
assert(get('F22_TACTICAL_01_RANGE_VALID')==0,'relative proximity invented NM')
assert(get('F22_DEF_OV_01_RANGED')==0 and get('F22_DEF_OV_01_PROXIMITY')==1)
local far=math.sqrt(get('F22_DEF_OV_01_X')^2+get('F22_DEF_OV_01_Y')^2)
put(q..'POWER',.8);now=.1;update()
local near=math.sqrt(get('F22_DEF_OV_01_X')^2+get('F22_DEF_OV_01_Y')^2)
assert(near<far and math.abs(near-.84*.2)<1e-9,'native proximity stayed on outer ring')
assert(math.abs(get('F22_EW_01_X')-math.sin(.4)*near)<1e-9)
-- Threat severity retains separate warning markings and does not replace POWER.
put(q..'SIGNAL',3);now=.15;update()
assert(get('F22_DEF_OV_01_ALERT')==1 and math.abs(get('F22_EW_01_X')-math.sin(.4)*near)<1e-9)
-- A new radar or datalink report cannot rejuvenate a stale RF POWER sample.
put(q..'TIME',7);now=7.2;update();assert(get('F22_EW_01_COAST')==1)
-- Offboard PPLI uses its reported world position and exposes its link source.
local Overview=dofile(SCRIPT_ROOT..'Systems/Defensive_Overview.lua')
local values={F22_RADAR_RANGE_NM=40}
local function read(k)return values[k]or 0 end
local o=Overview.new(read,function(k,v)values[k]=v end,get_base_data())
o:update(10,{{source=77,az=0,el=0,age=0,affiliation=3,signal=0,observations={},
 datalink={time=10,n=37040,u=0,e=0,vn=0,vu=0,ve=0,link=1}}},true,false,nil)
assert(values.F22_DEF_OV_01_RANGED==1 and values.F22_DEF_OV_01_DATALINK==1)
assert(math.abs(values.F22_DEF_OV_01_Y-.84*.5)<1e-9 and values.F22_DEF_OV_01_AFFILIATION==3)
''')
print('Native RWR proximity: real POWER transport, far/near movement, independent severity/age and datalink position PASS')
