"""Identity evidence keeps its own epoch through the actual RF/donor owner."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
fixture = ROOT / 'tests/test_display_startup.py'
ns = {'__file__': str(fixture)}
exec(compile(fixture.read_text().split('\nfor page in ', 1)[0], str(fixture), 'exec'), ns)
lua = ns['runtime']()
lua.execute(r'''
local now=30;function get_model_time()return now end
local function p(n,v)get_param_handle(n):set(v)end
local function g(n)return get_param_handle(n):get()end
function GetDevice()return {set_power=function()end}end
p('MAIN_POWER',1);p('RADAR_PWR',0)
dofile(SCRIPT_ROOT..'Systems/RWR_System.lua');post_initialize()
local function packet(sequence,known,observation)
 p('F22_DL_RX_SCHEMA',2);p('F22_DL_RX_EPOCH',1);p('F22_DL_RX_SEQUENCE',0)
 p('F22_DL_RX_TIME',now);p('F22_DL_RX_COUNT',1);p('F22_DL_RX_OWN',100)
 for key,value in pairs({SOURCE=7,REPORTER=9,LINK=2,TIME=known and observation or now,
  OBSERVATION_KNOWN=known and 1 or 0,OBSERVATION_TIME=known and observation or 0,
  RECEIVE_TIME=now,N=20000,U=1000,E=0,VN=100,VU=0,VE=0,AFFILIATION=0,FLIGHT=0,PPLI=0})do
  p('F22_DL_RX_01_'..key,value)
 end
 p('F22_DL_RX_SEQUENCE',sequence)
end
for key,value in pairs({SOURCE=7,TIME=0,AZIMUTH=.2,ELEVATION=0,SIGNAL=3,
 PRIORITY=1,POWER=.25,GENERAL_TYPE=1,UNIT_TYPE='27'})do p('RWR_CONTACT_01_'..key,value)end
p('F22_RADAR_TACTICAL_SEQUENCE',1);p('F22_RADAR_TACTICAL_TIME',now)
for key,value in pairs({VALID=1,SOURCE=77,AGE=0,AZ=-.2,EL=0,RANGE=20000,QUALITY=2,
 FRIENDLY=1,IDENTITY_KNOWN=1,IDENTITY_TIME=10})do p('F22_RADAR_TACTICAL_01_'..key,value)end
packet(1,false);update()
assert(g('F22_DEFENSIVE_SOURCE')>0 and g('F22_DEFENSIVE_IDENTITY_CONFLICT')==1
 and g('F22_DEFENSIVE_FRIENDLY_PROTECTED')==1)
assert(g('F22_DEFENSIVE_AGE')==0 and g('F22_DEFENSIVE_ID_RADAR_FRIEND_AGE')==20
 and g('F22_DEFENSIVE_ID_RF_HOSTILE_AGE')==0,'fresh bearing renewed old friendly evidence')
assert(g('F22_DEFENSIVE_ID_RADAR_VALID')==1 and g('F22_DEFENSIVE_ID_RADAR_AGE_KNOWN')==1)
assert(g('F22_DEFENSIVE_ID_DONOR_VALID')==0,'unknown donor sample granted radar/RF correlation')
SetCommand(11140,1);update()
assert(g('F22_DONOR_OBSERVATION_AGE')==999 and g('F22_DONOR_RECEIVE_AGE')==0)
now=31;update()
assert(g('F22_DEFENSIVE_ID_RADAR_FRIEND_AGE')==21 and g('F22_DEFENSIVE_ID_RF_HOSTILE_AGE')==0)
assert(g('F22_DONOR_RECEIVE_AGE')==1)
packet(2,true,25);update()
assert(g('F22_DONOR_OBSERVATION_AGE')==6 and g('F22_DONOR_RECEIVE_AGE')==0)
now=41;update()
assert(g('F22_DEFENSIVE_ID_RF_FRIENDLY')==0 and g('F22_DEFENSIVE_FRIENDLY_PROTECTED')==0,
 'expired friendly identity was renewed by fresh RF observations')
p('MAIN_POWER',0);update()
assert(g('F22_DEFENSIVE_ID_RF_VALID')==0 and g('F22_DEFENSIVE_ID_DONOR_VALID')==0)
assert(g('F22_RADAR_WEAPON_TARGET_ID')==0,'identity evidence created weapon authority')

-- Invalid/future identity times remain unknown; a valid new position does not
-- repair the timestamp. The inspection helper retains fixed output names.
local output={};local I=dofile(SCRIPT_ROOT..'Systems/Identity_Inspection.lua')
local i=I.new(function(k,v)output[k]=v end,'TEST_')
local evidence={friendly=true,hostile=true,kind=1,time=100,hostile_time=40,time_known=true}
i:update({identity_evidence={rf=evidence}},41)
assert(output.TEST_RF_FRIEND_AGE_KNOWN==0 and output.TEST_RF_HOSTILE_AGE==1)
evidence.time=0/0;i:update({identity_evidence={rf=evidence}},41)
assert(output.TEST_RF_FRIEND_AGE_KNOWN==0 and output.TEST_RF_FRIEND_AGE==999)
i:update(nil,41);assert(output.TEST_RF_VALID==0 and output.TEST_RF_HOSTILE_AGE_KNOWN==0)
''')
print('Identity evidence: actual RF/donor ages, independent bearing/receipt epochs, '
      'conflict/protection, expiry, invalid timestamps and power reset PASS')
