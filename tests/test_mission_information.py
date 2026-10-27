"""Source ages, conflicts, awareness selection and explicit simulated responder."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
f=ROOT/'tests/test_display_startup.py';ns={'__file__':str(f)}
exec(compile(f.read_text().split('\nfor page in ',1)[0],str(f),'exec'),ns)
lua=ns['runtime']()
lua.execute(r'''
local function p(k,v)get_param_handle(k):set(v)end
local function g(k)return get_param_handle(k):get()end
local sensor={getSelfCoordinates=function()return 0,1000,0 end,
 getHeading=function()return 0 end,getPitch=function()return 0 end,getRoll=function()return 0 end}
local P=dofile(SCRIPT_ROOT..'Systems/Tactical_Picture.lua').new(g,p,sensor)
p('MAIN_POWER',1);p('F22_RADAR_RANGE_NM',40)
local function packet(sequence,now,known,observation)
 p('F22_DL_RX_SCHEMA',2);p('F22_DL_RX_EPOCH',1);p('F22_DL_RX_SEQUENCE',0)
 p('F22_DL_RX_TIME',now);p('F22_DL_RX_COUNT',1);p('F22_DL_RX_OWN',100)
 for field,value in pairs({SOURCE=200,REPORTER=300,LINK=2,TIME=known and observation or now,
  OBSERVATION_KNOWN=known and 1 or 0,OBSERVATION_TIME=known and observation or 0,
  RECEIVE_TIME=now,N=20000,U=1000,E=0,VN=100,VU=0,VE=0,AFFILIATION=0,FLIGHT=0,PPLI=0})do
  p('F22_DL_RX_01_'..field,value)
 end
 p('F22_DL_RX_SEQUENCE',sequence)
end
packet(1,10,false);P:update(10,{},true)
P:command(11140);P:update(11,{},true)
assert(g('F22_DONOR_SOURCE')==200 and g('F22_DONOR_OBSERVATION_KNOWN')==0)
assert(g('F22_DONOR_OBSERVATION_AGE')==999 and g('F22_DONOR_RECEIVE_AGE')==1)
local D=dofile(SCRIPT_ROOT..'Systems/Datalink_Tracks.lua')
local q=D.position(P.store.contacts[1].datalink,11)
assert(q.state==3 and q.coast and q.n==20000,'unknown sample epoch extrapolated as a fresh measurement')
P:command(11144);P:update(12,{},true)
assert(g('F22_DONOR_AWARENESS_ACCEPTED')==1 and g('F22_DONOR_WEAPON_AUTHORITY')==0)
P:command(11143);P:update(12,{},true)
assert(g('F22_DONOR_STATUS')==5 and g('F22_DONOR_HANDOFF_AVAILABLE')==0)
assert(g('F22_RADAR_WEAPON_TARGET_ID')==0 and g('F22_RADAR_STT_VALID')==0)
-- An older known sample newly received retains its original observation age.
packet(2,13,true,5);P:update(13,{},true)
assert(g('F22_DONOR_OBSERVATION_AGE')==8 and g('F22_DONOR_RECEIVE_AGE')==0)
-- Conflicting evidence is visible while friendly protection stays independent.
for field,value in pairs({VALID=1,SOURCE=200,AGE=0,AZ=0,EL=0,RANGE=20000,
 MEASURED_RANGE=20000,QUALITY=2,SELECTED=1,FRIENDLY=1,HOSTILE=0})do
 p('F22_RADAR_TACTICAL_01_'..field,value)
end
p('F22_RADAR_TACTICAL_SEQUENCE',1);p('F22_RADAR_TACTICAL_TIME',13)
P:update(13,{},true)
assert(g('F22_TACTICAL_01_IDENTITY_CONFLICT')==1 and g('F22_TACTICAL_01_FRIENDLY_PROTECTED')==1)
assert(P.store.contacts[1].identity_evidence.radar.kind==1)
assert(P.store.contacts[1].identity_evidence.datalink.kind==2)
assert(g('F22_TACTICAL_01_AFFILIATION')==1)
P:command(11142);P:update(14,{},true);assert(g('F22_DONOR_VALID')==0)
P:command(11140);P:update(14,{},true);assert(g('F22_DONOR_VALID')==1)
p('F22_DL_RX_EPOCH',2);p('F22_DL_RX_COUNT',0);p('F22_DL_RX_TIME',15);p('F22_DL_RX_SEQUENCE',3)
P:update(15,{},true);assert(g('F22_DONOR_VALID')==0 and g('F22_DONOR_AWARENESS_ACCEPTED')==0)
-- Ownship responder is independent from radar, contact interrogation and PPLI.
p('RADAR_PWR',0);p('F22_DATALINK_ENABLE',0);P:command(11130);P:update(16,{},true)
assert(g('F22_IFF_RESPONDER_READY')==1 and g('F22_IFF_RESPONDER_HOST_READY')==0)
P:command(11132);assert(g('F22_IFF_REPLY_SEQUENCE')==1)
p('MAIN_POWER',0);P:update(17,{},false);P:command(11132)
assert(g('F22_IFF_RESPONDER_READY')==0 and g('F22_IFF_REPLY_SEQUENCE')==1)
p('MAIN_POWER',1);P:update(18,{},true)
assert(g('F22_IFF_REPLY_SEQUENCE')==1,'restored supply replayed a prior interrogation')
local iff=dofile(SCRIPT_ROOT..'Systems/Radar_IFF.lua').new();iff:update(18,true)
assert(iff:reply(0,18,0,0)==-1,'no reply became hostile')
''')
print('Mission information: unknown/known sample epochs, donor SA isolation, conflict/protection, source evidence and responder recovery PASS')
