"""Coherent owned IR samples and actual HUD/audio consumers reject stale feedback."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
fixture = ROOT / 'tests/test_display_startup.py'
ns = {'__file__': str(fixture)}
exec(compile(fixture.read_text().split('\nfor page in ', 1)[0], str(fixture), 'exec'), ns)
lua = ns['runtime']()
lua.execute(r'''
local Feedback=dofile(SCRIPT_ROOT..'Systems/IR_Feedback.lua')
local values={};local change
local function get(n)
 local value=values[n]
 if n=='F22_IR_LOCK' and change then values[change[1]]=change[2]end
 return value
end
local function frame()
 values={F22_IR_SAMPLE_OWNER=1,F22_IR_SAMPLE_SCHEMA=1,F22_IR_SAMPLE_VALID=1,
  F22_IR_SAMPLE_SEQUENCE=2,F22_IR_SAMPLE_TIME=100,F22_IR_SAMPLE_STATION=0,
  F22_IR_SAMPLE_GENERATION=42,F22_IR_STATION=0,F22_IR_STORE_GENERATION=42,
  F22_IR_AVAILABLE=1,F22_IR_LOCK=1,F22_IR_STRENGTH=2,F22_IR_WORLD_VALID=1,
  F22_IR_WORLD_FWD_N=1,F22_IR_WORLD_FWD_U=0,F22_IR_WORLD_FWD_E=0,F22_AP_CLOCK=5}
end
frame();values.F22_IR_SAMPLE_OWNER=0
local sample=Feedback.new(get);sample:update(true,100)
assert(sample.valid and sample.locked and not sample.owned,'older DLL compatibility changed')
frame();sample:update(true,100);assert(sample.valid and sample.owned and sample.locked)
for _,case in ipairs({
 {'F22_IR_SAMPLE_OWNER',0},{'F22_IR_SAMPLE_SCHEMA',0},{'F22_IR_SAMPLE_SCHEMA',2},
 {'F22_IR_SAMPLE_VALID',0},{'F22_IR_SAMPLE_SEQUENCE',0},{'F22_IR_SAMPLE_SEQUENCE',3},
 {'F22_IR_SAMPLE_SEQUENCE',2.5},{'F22_IR_SAMPLE_SEQUENCE',math.huge},
 {'F22_IR_SAMPLE_TIME',99.89},{'F22_IR_SAMPLE_TIME',100.06},{'F22_IR_SAMPLE_TIME',0/0},
 {'F22_IR_SAMPLE_STATION',11},{'F22_IR_SAMPLE_STATION',1.5},{'F22_IR_STATION',10},
 {'F22_IR_SAMPLE_GENERATION',-1},{'F22_IR_SAMPLE_GENERATION',16777216},
 {'F22_IR_STORE_GENERATION',43},{'F22_IR_AVAILABLE',0},{'F22_IR_LOCK',2},
 {'F22_IR_STRENGTH',0/0},{'F22_IR_STRENGTH',-1},{'F22_IR_STRENGTH',2.01},
})do
 frame();values[case[1]]=case[2];sample:update(true,100)
 assert(sample.owned and not sample.valid and not sample.available and not sample.locked,
  'bad owned feedback accepted or revived legacy fallback: '..case[1])
end
for _,case in ipairs({{'F22_IR_SAMPLE_OWNER',0},{'F22_IR_SAMPLE_SCHEMA',2},
 {'F22_IR_SAMPLE_VALID',0},{'F22_IR_SAMPLE_SEQUENCE',4},{'F22_IR_SAMPLE_TIME',100.01},
 {'F22_IR_SAMPLE_STATION',1},{'F22_IR_SAMPLE_GENERATION',43}})do
 frame();change=case;sample:update(true,100)
 assert(not sample.valid,'torn feedback accepted: '..case[1]);change=nil
end
frame();sample:update(true,0);assert(not sample.valid,'World epoch rollback accepted future native sample')
frame();sample:update(false,100);assert(not sample.valid and sample.owned)
sample:update(true,100);assert(sample.valid and sample.locked)

local Seeker=dofile(SCRIPT_ROOT..'Systems/IR_Seeker.lua')
local heading=0
local seeker=Seeker.new({getHeading=function()return heading end,getPitch=function()return 0 end,
 getRoll=function()return 0 end},get)
local az,el=seeker:update(true,.02,100);assert(az==0 and el==0)
values.F22_IR_SAMPLE_SEQUENCE=4;values.F22_IR_SAMPLE_TIME=100.02
values.F22_IR_WORLD_FWD_N=math.cos(.1);values.F22_IR_WORLD_FWD_E=math.sin(.1)
az=seeker:update(true,.02,100.02);assert(math.abs(az-.04)<1e-10)
values.F22_IR_SAMPLE_GENERATION=43;values.F22_IR_STORE_GENERATION=43
values.F22_IR_WORLD_FWD_N=math.cos(.2);values.F22_IR_WORLD_FWD_E=math.sin(.2)
az=seeker:update(true,.02,100.02);assert(math.abs(az-.2)<1e-10,'replacement inherited old head interpolation')
az,el=seeker:update(true,.02,100.13)
assert(az==nil and el==nil and not seeker.locked,'frozen native sample left a current beam/lock')
values.F22_IR_SAMPLE_SEQUENCE=6;values.F22_IR_SAMPLE_TIME=100.13
values.F22_IR_WORLD_FWD_U=nil;az,el=seeker:update(true,.02,100.13)
assert(az==nil and el==nil,'incomplete direction was projected')
values.F22_IR_WORLD_FWD_U=0;heading=0/0;az,el=seeker:update(true,.02,100.13)
assert(az==nil and el==nil,'invalid own attitude retained a previous cue')
seeker:reset();assert(seeker.feedback.owned and not seeker.locked and seeker.az==nil)
''')
print('IR feedback: ownership, World time, torn/stale samples, station/generation identity, '
      'finite signal/beam checks and interpolation reset PASS')

lua = ns['runtime']()
lua.execute(r'''
local now=100;function get_model_time()return now end
function get_aircraft_property()return 1 end
function get_aircraft_draw_argument_value(n)return draws[n]or 0 end
function set_aircraft_draw_argument_value(n,v)draws[n]=v end
local function p(n,v)get_param_handle(n):set(v)end
local function g(n)return get_param_handle(n):get()end
local native={get_station_info=function(_,station)
 return {count=station==0 and 1 or 0,CLSID='{5CE2FF2A-645A-4197-B48D-8720AC69394F}',
 weapon={level1=4,level2=4,level3=7,level4=136}}
 end,select_station=function()end}
function GetDevice()return native end
local sounds={}
function create_sound_host()return {create_sound=function(_,path)
 local s={playing=false};sounds[path]=s
 function s:update()end;function s:is_playing()return self.playing end
 function s:play_continue()self.playing=true end;function s:stop()self.playing=false end
 return s
end}end
p('MAIN_POWER',1);p('WoW',0);p('RADAR_PWR',0)
dofile(SCRIPT_ROOT..'Systems/Weapon_System.lua');post_initialize();SetCommand(10800,3);update()
local function frame(sequence)
 for name,value in pairs({OWNER=1,SCHEMA=1,VALID=1,SEQUENCE=sequence,TIME=now,
  STATION=g('F22_IR_STATION'),GENERATION=g('F22_IR_STORE_GENERATION')})do p('F22_IR_SAMPLE_'..name,value)end
 for name,value in pairs({AVAILABLE=1,LOCK=1,STRENGTH=2,WORLD_VALID=1,WORLD_FWD_N=1,
  WORLD_FWD_U=0,WORLD_FWD_E=0})do p('F22_IR_'..name,value)end
end
frame(2);update()
assert(g('HUD_IR_SEEKER_AVAILABLE')==1 and g('HUD_IR_SEEKER_VALID')==1
 and g('F22_IR_FEEDBACK_LOCK')==1 and g('F22_RADAR_STT_VALID')==0,
 'radar-independent native lock did not reach the existing HUD')
assert(sounds['Aircrafts/F-22A/IR/track'].playing)
now=100.11;update()
assert(g('F22_IR_LOCK')==1 and g('HUD_IR_SEEKER_AVAILABLE')==0 and g('HUD_IR_SEEKER_VALID')==0
 and g('F22_IR_FEEDBACK_VALID')==0,'frozen raw provider bits remained current HUD feedback')
for _,sound in pairs(sounds)do assert(not sound.playing,'stale seeker feedback kept a tone playing')end
frame(4);update();assert(g('HUD_IR_SEEKER_VALID')==1 and sounds['Aircrafts/F-22A/IR/track'].playing)
p('F22_IR_SAMPLE_GENERATION',g('F22_IR_STORE_GENERATION')+1);update()
assert(g('HUD_IR_SEEKER_VALID')==0 and g('F22_IR_FEEDBACK_LOCK')==0,'wrong weapon instance supplied current lock')
frame(6);p('F22_IR_WORLD_VALID',0);update()
assert(g('HUD_IR_SEEKER_AVAILABLE')==0 and g('HUD_IR_SEEKER_VALID')==0
 and g('F22_IR_FEEDBACK_LOCK')==1,'missing cue geometry invented a centered reticle or erased native lock')
frame(8);update();assert(g('HUD_IR_SEEKER_VALID')==1)
post_initialize()
assert(g('HUD_IR_SEEKER_VALID')==0 and g('F22_IR_FEEDBACK_VALID')==0
 and g('F22_IR_SAMPLE_VALID')==1,'consumer reset retained a cue or rewrote native ownership')
for _,sound in pairs(sounds)do assert(not sound.playing,'consumer reset retained a seeker tone')end
p('MAIN_POWER',0);update();assert(g('HUD_IR_SEEKER_VALID')==0)
''')
print('Actual weapon owner: radar-independent HUD lock/audio, stale/incomplete feedback withdrawal, '
      'fresh recovery, instance mismatch and independent geometry validity PASS')
