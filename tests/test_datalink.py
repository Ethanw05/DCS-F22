"""Offboard provenance, expiration, reprojection and fire-control separation."""
from pathlib import Path
repo=Path(__file__).resolve().parents[1]
fixture=repo/'tests/test_display_startup.py'
namespace={'__file__':str(fixture)}
exec(compile(fixture.read_text().split('\nfor page in ',1)[0],str(fixture),'exec'),namespace)
lua=namespace['runtime']()
lua.execute('''
local D=dofile(SCRIPT_ROOT..'Systems/Datalink_Tracks.lua')
local P=dofile(SCRIPT_ROOT..'Systems/Tactical_Picture.lua')
local heading,north=0,0
local sensors={getSelfCoordinates=function()return north,3000,0 end,
 getHeading=function()return -heading end,getPitch=function()return 0 end,getRoll=function()return 0 end}
local function get(k)return get_param_handle(k):get()end
local function put(k,v)get_param_handle(k):set(v)end
local p=P.new(get,put,sensors)
put('F22_RADAR_RANGE_NM',40)
local function packet(seq,stamp,rows)
 put('F22_DL_RX_SEQUENCE',0)
 put('F22_DL_RX_OWN',100);put('F22_DL_RX_EPOCH',1)
 put('F22_DL_RX_TIME',stamp);put('F22_DL_RX_COUNT',#rows)
 for i,row in ipairs(rows)do
  local defaults={SOURCE=200,REPORTER=300,LINK=2,TIME=stamp,N=18520,U=3000,E=0,VN=100,VU=0,VE=0,AFFILIATION=-1,FLIGHT=0,PPLI=0}
  for k,v in pairs(row)do defaults[k]=v end
  for k,v in pairs(defaults)do put(string.format('F22_DL_RX_%02d_',i)..k,v)end
 end
 put('F22_DL_RX_SEQUENCE',seq)
end
packet(1,10,{{}});p:update(10,{},true)
assert(#p.store.contacts==1)
local t=p.store.contacts[1]
assert(t.source==200 and t.mask==8 and not t.range and not t.selected)
assert(get('F22_TACTICAL_01_DATALINK')==2 and get('F22_TACTICAL_01_RANGE_VALID')==0)
assert(get('F22_TSD_DL_COUNT')==1 and get('F22_TSD_DL_01_LINK')==2)
-- Changing display range rescales/edges symbols without deleting a report.
for _,range in ipairs({160,80,40,20,10,5,1,40})do
 put('F22_RADAR_RANGE_NM',range);p:update(10,{},true)
 assert(#p.store.contacts==1 and get('F22_TSD_DL_COUNT')==1)
 assert(math.abs(get('F22_TSD_DL_01_X'))<=.85 and get('F22_TSD_DL_01_Y')<=.88)
 if range<=5 then assert(get('F22_TSD_DL_01_OFFSCALE')==1)
 elseif range>=20 then assert(get('F22_TSD_DL_01_OFFSCALE')==0)end
end
-- Cached messages are reprojected against current ownship, without renewing age.
heading=math.rad(90);north=1000;p:update(11,{},true)
t=p.store.contacts[1];assert(math.abs(t.az+math.pi/2)<1e-8 and t.datalink_age==1)
p:update(23.5,{},true);assert(get('F22_TSD_DL_01_COAST')==1)
p:update(60,{},true);assert(#p.store.contacts==1 and get('F22_TSD_DL_01_COAST')==1,'native AI surveillance interval erased SA memory')
p:update(86,{},true);assert(#p.store.contacts==0 and get('F22_TSD_DL_COUNT')==0)
p:reset()
-- Reject a malformed complete packet and keep the previous observation's clock.
heading=0;north=0;packet(2,30.1,{{}});p:update(30.1,{},true)
packet(3,30.2,{{VN=0/0}});p:update(30.2,{},true)
assert(p.store.contacts[1].datalink.time==30.1)
packet(4,31,{{TIME=32}});p:update(31,{},true)
assert(p.store.contacts[1].datalink.time==30.1,'future packet renewed report')
-- Complete empty packet withdraws; a frozen ingress cannot reanimate it.
packet(5,32,{});p:update(32,{},true);assert(#p.store.contacts==0)
p:update(33,{},true);assert(#p.store.contacts==0)
-- Join native IDs; fresh onboard range remains exclusively radar-derived.
packet(6,40,{{LINK=1,REPORTER=200,SOURCE=200,PPLI=1,FLIGHT=1,AFFILIATION=1}})
for k,v in pairs({VALID=1,SOURCE=200,AGE=0,AZ=0,EL=0,RANGE=20000,MEASURED_RANGE=19900,QUALITY=2,SELECTED=1,FRIENDLY=1})do put('F22_RADAR_TACTICAL_01_'..k,v)end
put('F22_RADAR_TACTICAL_SEQUENCE',1);put('F22_RADAR_TACTICAL_TIME',40)
put('F22_SCOPE_01_VALID',1);put('F22_SCOPE_01_SOURCE',200)
p:update(40,{},true);t=p.store.contacts[1]
assert(#p.store.contacts==1 and t.mask==9 and t.affiliation==3 and t.range==20000 and t.measured_range==19900)
assert(get('F22_TSD_DL_COUNT')==0,'duplicate symbol for a fresh radar contact')
put('F22_SCOPE_01_VALID',0);p:update(40.1,{},true)
assert(get('F22_TSD_DL_01_AFFILIATION')==3 and get('F22_TSD_DL_01_LINK')==1)
-- Power loss and mission rewind remove the offboard picture.
p:update(40.2,{},false);assert(#p.store.contacts==0 and get('F22_TSD_DL_COUNT')==0)
p:update(40.3,{},true);assert(not p.store.contacts[1] or not p.store.contacts[1].datalink)
packet(7,50,{{}});p:update(50,{},true);p:update(1,{},true)
assert(#p.store.contacts==0)
-- Only direct same-flight IFDL PPLI can establish flight membership.
packet(8,2,{{LINK=2,PPLI=1,REPORTER=200,FLIGHT=1,AFFILIATION=1}});p:update(2,{},true)
assert(#p.store.contacts==0)
packet(9,2.1,{{SOURCE=100}});p:update(2.1,{},true);assert(#p.store.contacts==0)
-- The actual radar/weapon owners see no detection or lock from link-only data.
dofile(SCRIPT_ROOT..'Systems/Radar_System.lua');post_initialize()
packet(10,3,{{}});p:update(3,{},true)
assert(get('F22_RADAR_DRAWN_COUNT')==0 and get('F22_RADAR_STT_VALID')==0)
for _,action in ipairs(actions)do assert(action[1]~=509 and action[1]~=84 and action[1]~=350)end
-- Twelve-second native reports do not blink out before a jittered update.
local report={time=0,n=100,u=3000,e=0,vn=100,vu=0,ve=0,ppli=true}
assert(D.position(report,12.4)and not D.position(report,12.4).coast)
assert(D.position(report,25.9).coast and not D.position(report,26.1))
assert(D.position(report,14).n==1400,'prediction stopped before the next native report')
report.ppli=false;assert(D.position(report,60).coast and not D.position(report,75.1))
print('Datalink: coherent ingress, aging, world reprojection, provenance, duplicate suppression, flight PPLI and fire-control isolation PASS')
''')
