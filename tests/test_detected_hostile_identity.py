"""Detected simulator classification survives radar -> RWR -> fused display transport."""
import contextlib,io
with contextlib.redirect_stdout(io.StringIO()):
 from test_display_startup import runtime
lua=runtime()
lua.execute('''
local now=1;function get_model_time()return now end
native={set_power=function()end};function GetDevice()return native end
local function p(k,v)get_param_handle(k):set(v)end
local function g(k)return get_param_handle(k):get()end
dofile(SCRIPT_ROOT..'Systems/Radar_System.lua');post_initialize();local radar=update;local command=SetCommand
dofile(SCRIPT_ROOT..'Systems/RWR_System.lua');post_initialize();local rwr=update
p('MAIN_POWER',1);p('F22N_RADAR_MODE',1);p('F22_RADAR_OBSERVATIONS_READY',1);p('F22_RADAR_OBSERVATION_COUNT',1)
for k,v in pairs({ID=123,AGE=0,NORTH=5000,ALTITUDE=0,EAST=200,VN=0,VU=0,VE=0,IFF=0})do p('F22O_01_'..k,v)end
for k,v in pairs({SOURCE=123,TIME=0,AZIMUTH=-.04,ELEVATION=.1,SIGNAL=1,PRIORITY=1,GENERAL_TYPE=1,UNIT_TYPE='27'})do p('RWR_CONTACT_01_'..k,v)end
command(10626,1);radar();rwr()
assert(g('F22_SCOPE_01_AFFILIATION')==0,'detected known hostile remained yellow on radar')
assert(g('F22_IDENT_01_CLASS')==0 and g('F22_RADAR_TACTICAL_01_HOSTILE')==1)
assert(g('F22_TACTICAL_01_AFFILIATION')==0,'known hostile was lost between radar, RWR and tactical picture')
-- Hard lock stops the search-class feed. The same freshly measured source must
-- retain its confirmed ID throughout a dogfight longer than the 30-second cache.
p('F22N_RADAR_MODE',3);p('F22_RADAR_OBSERVATION_COUNT',0);p('F22_STT_MOTION_VALID',1)
p('F22_STT_ID',123);p('F22_STT_PN',5000);p('F22_STT_PE',200);p('F22_STT_PU',0)
for i=1,650 do now=now+.05;p('F22_STT_TIME',now);radar();rwr()end
assert(g('F22_RADAR_STT_IFF')==0 and g('F22_SCOPE_01_AFFILIATION')==0
 and g('F22_TACTICAL_01_AFFILIATION')==0,'long hard lock reverted confirmed hostile to unknown')
p('F22N_RADAR_MODE',1);p('F22_STT_MOTION_VALID',0);p('F22_RADAR_OBSERVATION_COUNT',1)
-- Positive friend remains distinct; missing classification is not auto-hostile.
now=now+.1;p('F22O_01_IFF',1);radar();rwr()
assert(g('F22_SCOPE_01_AFFILIATION')==1 and g('F22_TACTICAL_01_AFFILIATION')==1)
p('F22O_01_ID',456);p('F22O_01_EAST',-1000);p('F22O_01_IFF',-1);now=now+.1;radar()
local unknown=false
for i=1,64 do local q=string.format('F22_SCOPE_%02d_',i)
 if g(q..'VALID')==1 and g(q..'AFFILIATION')==-1 then unknown=true end
end
assert(unknown,'unclassified detection became hostile')
local iff=dofile(SCRIPT_ROOT..'Systems/Radar_IFF.lua').new();iff:update(10,true)
assert(iff:reply(0,10,0,0)==-1,'missing STT friendly response became hostile')
assert(iff:reply(0,10,0,0,true)==0,'explicit simulator identification was rejected')
iff:toggle_auto();assert(iff:reply(0,10,0,0,true)==-1,'disabled identification accepted new class')
''')
print('Combat ID: detected confirmed foe red across radar/RWR/tactical, friend green, unclassified/no-reply unknown and identification gating PASS')
