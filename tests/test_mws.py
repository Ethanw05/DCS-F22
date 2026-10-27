"""Native-observation warning policy and actual Lua/indicator owner contracts."""
from pathlib import Path
import math,wave
from lupa.lua51 import LuaRuntime
from test_display_startup import runtime
ROOT=Path(__file__).resolve().parents[1]
l=LuaRuntime();l.globals().SCRIPT=(ROOT/'Cockpit/Scripts').as_posix()+'/'
l.execute('''
local M=dofile(SCRIPT..'Systems/MWS_Computer.lua');local r=M.new()
local o={source=123,time=10,az=math.pi,el=.2}
r:update(10,{o},true);assert(#r.contacts==1 and not r.contacts[1].coast and M.sector(o.az)==6)
r:update(10.4,{o},true);assert(r.contacts[1].age>.39,'cached observation was refreshed')
r:update(11,{o},true);assert(r.contacts[1].coast,'old source must be memory')
r:update(13.1,{o},true);assert(#r.contacts==0,'memory expired incorrectly')
r:update(10,{o},true);assert(#r.contacts==1)
r:update(9,{o},true);assert(#r.contacts==0,'rewind carried a future threat')
r:update(10,{o},false);assert(#r.contacts==0)
for _,bad in ipairs({0,-1,1.5,4294967296,0/0})do
 r:update(10,{{source=bad,time=10,az=0,el=0}},true);assert(#r.contacts==0)
end
for _,v in ipairs({{0,12},{math.pi/2,3},{math.pi,6},{-math.pi/2,9}})do assert(M.sector(v[1])==v[2])end
''')
l=runtime()
l.execute('''
now=10;function get_model_time()return now end
playing=false
local sound={update=function()end,is_playing=function()return playing end,
 play_continue=function()playing=true end,stop=function()playing=false end}
function create_sound_host(...)return{create_sound=function()return sound end}end
dofile(SCRIPT_ROOT..'Systems/MWS_System.lua');post_initialize()
local function put(n,v)get_param_handle(n):set(v)end
local function get(n)return get_param_handle(n):get()end
put('MAIN_POWER',1);put('F22_MWS_NATIVE_READY',1);put('F22_MWS_NATIVE_TIME',10)
local p='F22_MWS_NATIVE_01_'
put(p..'VALID',1);put(p..'THREAT',1);put(p..'SOURCE',123);put(p..'TIME',10);put(p..'AZ',math.pi);put(p..'EL',.2)
update();assert(get('F22_MWS_ALERT')==1 and get('F22_MWS_CLOCK')==6 and get('F22_MWS_ELEVATION')==1)
assert(playing and get('F22_MWS_AUDIO_PRIORITY')==1)
SetCommand(10921,22.375);SetCommand(10921,22.375);SetCommand(10921,22.25);update()
assert(get('F22_MWS_ALERT')==1 and not playing and get('F22_MWS_AUDIO_PRIORITY')==0)
SetCommand(10921,1);SetCommand(10921,0);update();assert(playing)
now=10.4;update();assert(get('F22_MWS_READY')==0 and get('F22_MWS_ALERT')==0,'frozen native publication stayed ready')
put('F22_MWS_NATIVE_TIME',now);put(p..'TIME',now);update();assert(get('F22_MWS_ALERT')==1)
put(p..'THREAT',0);update();assert(get('F22_MWS_ALERT')==0,'known outgoing missile remained in warning memory')
put(p..'THREAT',1);put(p..'TIME',now+.01);update();assert(get('F22_MWS_ALERT')==1)
put('MAIN_POWER',0);update();assert(get('F22_MWS_ALERT')==0 and not playing)
put('MAIN_POWER',1);put(p..'VALID',0);update();assert(get('F22_MWS_ALERT')==0)
''')
ui=runtime();ui.execute('dofile(SCRIPT_ROOT.."HUD/page.lua")')
elements={e['name']:e for _,e in ui.globals().elements.items()}
assert elements['HUD_MWS_WARNING']['element_params'][2]=='F22_MWS_BLINK'
assert 'HUD_MWS_WARNING'in elements and 'HUD_MWS_MEMORY'in elements
ui.execute('dofile(SCRIPT_ROOT.."UFD_LEFT/ew_page.lua")')
with wave.open(str(ROOT/'Sounds/Effects/Aircrafts/F-22A/MWS/approach.wav'),'rb')as wav:
    assert wav.getnchannels()==1 and wav.getsampwidth()==2 and wav.getframerate()==44100
print('MWS: native freshness, memory/rewind, clock sectors, actual owner/audio/power/mute and HUD/EW construction PASS')
