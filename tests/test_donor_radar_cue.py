"""Actual donor selection -> coherent request -> owned radar search, never a target."""
from radar_test_runtime import owned_runtime

lua = owned_runtime()
lua.execute('''
local Picture=dofile(SCRIPT_ROOT..'Systems/Tactical_Picture.lua')
local sensors=get_base_data()
local picture=Picture.new(f.get,f.put,sensors)
local sequence=0
local function packet(known,source)
 sequence=sequence+1
 f.put('F22_DL_RX_SCHEMA',2);f.put('F22_DL_RX_EPOCH',1);f.put('F22_DL_RX_SEQUENCE',0)
 f.put('F22_DL_RX_TIME',f.now);f.put('F22_DL_RX_COUNT',1);f.put('F22_DL_RX_OWN',100)
 for key,value in pairs({SOURCE=source or 84,REPORTER=300,LINK=1,TIME=f.now,
  OBSERVATION_KNOWN=known and 1 or 0,OBSERVATION_TIME=f.now,RECEIVE_TIME=f.now,
  N=20000,U=8000,E=12000,VN=100,VU=0,VE=0,AFFILIATION=0,FLIGHT=0,PPLI=0})do
  f.put('F22_DL_RX_01_'..key,value)
 end
 f.put('F22_DL_RX_SEQUENCE',sequence)
 picture:update(f.now,{},true)
end
packet(false);picture:command(11140);picture:update(f.now,{},true)
assert(f.get('F22_DONOR_VALID')==1 and f.get('F22_DONOR_HANDOFF_AVAILABLE')==1)
picture:command(11143);picture:update(f.now,{},true);f.tick()
assert(f.get('F22_AESA_CONTROL_CUE_VALID')==1)
assert(f.get('F22_DONOR_CUE_OBSERVATION_KNOWN')==0 and f.get('F22_DONOR_CUE_OBS_TIME')==-100)
assert(f.get('F22_AESA_CONTROL_CUE_HALF_AZ')==math.rad(20),'held report gained false precision')
assert(f.get('F22_RADAR_TRACK_COUNT')==0,'held donor coordinates became a measured track')
local held_bearing=f.get('F22_AESA_CONTROL_CUE_AZ')
picture:update(f.now,{},true);f.tick()
assert(math.abs(f.get('F22_AESA_CONTROL_CUE_AZ')-held_bearing)<1e-9,'unknown epoch was extrapolated')
packet(true);assert(f.get('F22_DONOR_HANDOFF_AVAILABLE')==1)
picture:command(11143);picture:update(f.now,{},true);f.tick()
assert(f.get('F22_AESA_CONTROL_CUE_VALID')==1 and f.get('F22_RADAR_DONOR_STATUS')==1)
assert(f.get('F22_AESA_CONTROL_CUE_AZ')>.4 and f.get('F22_AESA_CONTROL_CUE_EL')>.1)
assert(f.get('F22_AESA_CONTROL_CUE_HALF_AZ')>=math.rad(4))
assert(f.get('F22_RADAR_TRACK_COUNT')==0 and f.get('F22_RADAR_STT_VALID')==0)
assert(f.get('F22_DONOR_WEAPON_AUTHORITY')==0 and f.get('F22_AESA_CONTROL_TARGET')==0)
local request=f.get('F22_AESA_CONTROL_CUE_REQUEST')
f.put('F22_AESA_CUE_REQUEST',request);f.put('F22_AESA_CUE_TIME',f.now);f.tick()
assert(f.get('F22_RADAR_DONOR_STATUS')==2,'completed RF search was not acknowledged')
-- Turning ownship reprojects the same reported world state, without copying it into a radar track.
f.pose.heading=.2;f.tick()
assert(f.get('F22_AESA_CONTROL_CUE_AZ')<.4 and f.get('F22_RADAR_TRACK_COUNT')==0)
-- Reject cancels the published request in the input call, before another owner update.
picture:command(11142);f.tick()
assert(f.get('F22_AESA_CONTROL_CUE_VALID')==0)
picture:update(f.now,{},true);picture:command(11140);picture:update(f.now,{},true)
picture:command(11143);picture:update(f.now,{},true);f.tick()
assert(f.get('F22_AESA_CONTROL_CUE_VALID')==1)
local start=f.now
while f.now-start<4.2 do picture:update(f.now,{},true);f.tick()end
assert(f.get('F22_AESA_CONTROL_CUE_VALID')==0,'retained donor awareness renewed pilot consent')
-- A current physical failure at input cannot be replayed when supply restores.
packet(true);f.put('EFM_PHYSICAL_VALID',0);picture:command(11143)
f.put('EFM_PHYSICAL_VALID',1);picture:update(f.now,{},true);f.tick()
assert(f.get('F22_AESA_CONTROL_CUE_VALID')==0)
picture:command(11143);picture:update(f.now,{},true);f.tick()
assert(f.get('F22_AESA_CONTROL_CUE_VALID')==1)
-- Native producer stops, then recovers: it must not retain an old cue command.
f.alive=false;f.tick();assert(f.get('F22_RADAR_DONOR_READY')==0)
f.alive=true;f.tick();assert(f.get('F22_AESA_CONTROL_CUE_VALID')==0,'receiver recovery replayed retired consent')
picture:update(f.now,{},true);picture:command(11143);picture:update(f.now,{},true);f.tick()
assert(f.get('F22_AESA_CONTROL_CUE_VALID')==1)
f.command(10600,1);f.command(10600,1);f.tick()
assert(f.get('F22_AESA_CONTROL_CUE_VALID')==0,'OFF/ON between updates replayed donor intent')
''')
print('Donor cue: current sample/power, explicit input, RF acknowledgement, expiry/withdrawal and no fabricated track PASS')


lua = owned_runtime()
lua.execute(r''' 
local Cue=dofile(SCRIPT_ROOT..'Systems/Radar_Donor_Cue.lua')
local keys={'VALID','TIME','REQUEST','START','SOURCE','EPOCH','OBS_TIME','RECEIVE_TIME',
 'OBSERVATION_KNOWN','N','U','E','VN','VU','VE'}
local good={VALID=1,TIME=10,REQUEST=1,START=9.9,SOURCE=84,EPOCH=2,OBS_TIME=9.8,RECEIVE_TIME=9.9,
 OBSERVATION_KNOWN=1,N=20000,U=3000,E=0,VN=100,VU=0,VE=0}
local function restore()
 f.put('F22_DONOR_CUE_SCHEMA',1);f.put('F22_DONOR_CUE_SEQUENCE',4);f.put('F22_DL_RX_EPOCH',2)
 for _,key in ipairs(keys)do f.put('F22_DONOR_CUE_'..key,good[key])end
end
local receiver=Cue.new(f.get,f.put)
restore();assert(receiver:read(10,f.pose))
for key,bad in pairs({VALID=0,TIME=9,REQUEST=0,START=4,SOURCE=0,EPOCH=1,OBS_TIME=10.1,
 RECEIVE_TIME=10.2,OBSERVATION_KNOWN=0,N=0/0,VN=1501})do
 restore();f.put('F22_DONOR_CUE_'..key,bad)
 assert(not receiver:read(10,f.pose),key..' malformed donor packet steered RF search')
end
restore();f.put('F22_DONOR_CUE_SCHEMA',2);assert(not receiver:read(10,f.pose))
restore();f.put('F22_DONOR_CUE_SEQUENCE',5);assert(not receiver:read(10,f.pose))
restore();assert(not receiver:read(10.3,f.pose),'stopped producer renewed request authority')
local reads=0
local function torn(name)
 if name=='F22_DONOR_CUE_SEQUENCE'then reads=reads+1;return reads==1 and 4 or 6 end
 return f.get(name)
end
local torn_receiver=Cue.new(torn,f.put)
restore();assert(not torn_receiver:read(10,f.pose),'torn packet accepted')
restore();receiver:retire(10);assert(not receiver:read(10,f.pose),'retired intent replayed')
f.put('F22_DONOR_CUE_REQUEST',2);assert(receiver:read(10,f.pose))
local Controls=dofile(SCRIPT_ROOT..'Systems/MFD_Controls.lua')
local Routing=dofile(SCRIPT_ROOT..'Systems/Display_Routing.lua')
f.put('HUD_MODE',2);f.put('F22_DONOR_HANDOFF_AVAILABLE',0)
assert(not Controls.for_page(Routing.pages.tsd,6,f.get)[10])
f.put('F22_DONOR_HANDOFF_AVAILABLE',1)
local action=Controls.for_page(Routing.pages.tsd,6,f.get)[10]
assert(action.label=='CUE' and action.command==11143 and action.device=='RWR_SYSTEM')
''')
print('Donor packet: malformed/torn/stale/retired data, fresh command recovery and shared bezel contract PASS')
