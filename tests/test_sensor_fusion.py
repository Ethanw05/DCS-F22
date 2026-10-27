"""Source identity, warning lifecycle, IFF evidence and two-target regressions."""
from pathlib import Path
import contextlib, io, runpy
ROOT=Path(__file__).resolve().parents[1]
with contextlib.redirect_stdout(io.StringIO()):
    runtime=runpy.run_path(str(ROOT/'tests/test_display_startup.py'))['runtime']
lua=runtime()
lua.execute('''
local module=dofile(SCRIPT_ROOT..'Systems/RWR_Computer.lua')
assert(module.label('MiG-29S',1)=='29' and module.label('FA-18C_hornet',1)=='18' and module.label('F-15C',1)=='15')
assert(module.label('UNRECOGNIZED',1)=='U' and module.label('AIM-120C',4)=='M')
local ew=module.new()
ew:update({{source=12,age=0,az=0,signal=1,priority=999,label='29'},
 {source=14,age=.1,az=1,signal=3,priority=10,label='M'},
 {source=13,age=0,az=-1,signal=2,priority=50,label='15'},
 {source=14,age=.3,az=1,signal=1},{source=99,age=13,az=0,signal=3},
 {source=0,age=0,az=0,signal=3}},true)
assert(#ew.contacts==3 and ew.contacts[1].source==14 and ew.alert==3)
assert(ew:associate(13).signal==2 and ew:associate(999)==nil)
for _,c in ipairs(ew.contacts) do assert(c.range==nil and c.north==nil,'RWR invented a position') end
ew:update({{source=14,age=4,az=1,signal=3}},true)
assert(#ew.contacts==1 and ew.alert==0,'remembered launch alarm latched')
ew:update({{source=14,age=0,az=1,signal=3}},false)
assert(#ew.contacts==0 and ew.alert==0)
local m=dofile(SCRIPT_ROOT..'Systems/Radar_Computer.lua')
local r=m.new();r:command('power');r:command('tws')
local function o(id,az,iff) return {native_id=id,age=0,range=5000,az=az,el=0,iff=iff} end
r:update(.05,{o(12,-.1,1),o(13,.1,0)},1)
assert(r.tracks[1].iff==1 and r.tracks[2].iff==0,'qualified simulator hostile classification was discarded')
r.cursor_range=5000;r.cursor_az=-.1;r:command('designate')
r.cursor_az=.1;r:command('secondary')
assert(r.selected==1 and r.secondary==2 and not r.acquire)
r:command('swap_targets');assert(r.selected==2 and r.secondary==1)
r:update(.1,{o(12,-.1,-1),o(13,.1,-1)},1)
assert(r.tracks[1].iff==1,'IFF off erased positive evidence')
r:update(.1,{o(13,.1,-1)},3)
r:command('swap_targets');assert(r.selected==2,'STT swap pretends a second guidance channel')
r:update(.1,{o(13,.1,-1)},1)
assert(not r.locked and r.selected==2 and r.secondary==1,'STT loss erased retained files')
for i=1,410 do r:update(.05,{o(13,.1,-1)},1) end
assert(r.secondary==nil and r.selected==2,'secondary did not expire independently')
for i=1,610 do r:update(.05,{o(13,.1,-1)},1) end
assert(r.tracks[2].iff==-1,'nonreply became hostile')
r:command('boresight');r:update(.1,{o(99,0,1)},1)
assert(not r.acquire,'ACM automatically acquired confirmed friendly')
''')
print('Fusion: exact source association; bearing-only RWR; priority/expiry; IFF friend evidence; primary/secondary coast and expiry OK')
lua=runtime()
lua.execute('''
native={set_power=function(self,v) self.power=v end};function GetDevice() return native end
local playing={};function create_sound_host() return {create_sound=function(self,name)
 return {is_playing=function() return playing[name] end,play_continue=function() playing[name]=true end,stop=function() playing[name]=false end,update=function() end,play_once=function() playing[name]=true end}
end} end
dofile(SCRIPT_ROOT..'Systems/RWR_System.lua');post_initialize()
local function put(n,v) get_param_handle(n):set(v) end
local function get(n) return get_param_handle(n):get() end
put('MAIN_POWER',1);put('RADAR_PWR',0)
local p='RWR_CONTACT_01_'
for k,v in pairs({SOURCE=42,TIME=0,AZIMUTH=-math.pi/2,SIGNAL=2,UNIT_TYPE='29',PRIORITY=300}) do put(p..k,v) end
update()
assert(get('HUD_EW_01_VALID')==1 and get('HUD_EW_01_LABEL')=='29')
assert(native.power and get('F22_RWR_COUNT')==1 and get('F22_RWR_ALERT')==2,'RWR depends on attack radar')
assert(get('F22_EW_01_X')>0 and math.abs(get('F22_EW_01_Y'))<1e-6,'native left-positive azimuth reversed')
assert(playing['Aircrafts/F-22A/RWR/lock'])
SetCommand(10901,1);update();assert(not playing['Aircrafts/F-22A/RWR/lock'] and get('F22_EW_01_VALID')==1)
put(p..'SIGNAL',3);SetCommand(10901,1);update();assert(playing['Aircrafts/F-22A/RWR/launch'])
put(p..'TIME',4);update();assert(not playing['Aircrafts/F-22A/RWR/launch'] and get('F22_EW_01_COAST')==1)
put(p..'TIME',13);update();assert(get('F22_EW_01_VALID')==0)
put('MAIN_POWER',0);update();assert(not native.power and get('F22_RWR_COUNT')==0)
''')
print('RWR owner: radar-off operation, bearing convention, separate mute/filter/power, lock/launch sounds, coast and expiry OK')
for page in ['MFD_RIGHT/rwr_page.lua','UFD_LEFT/base_page.lua','UFD_LEFT/ew_page.lua','PMFD_CENTER/radar_page.lua']:
    lua=runtime();lua.execute("dofile(SCRIPT_ROOT..'"+page+"')")
    print('DCS write-only indicator construction:',page,'OK')

# RWR observations associate with a ranged radar file only by exact source ID.
lua=runtime()
lua.execute("""
native={set_power=function() end};function GetDevice() return native end
get_param_handle('MAIN_POWER'):set(1)
for k,v in pairs({SOURCE=55,TIME=0,AZIMUTH=0,SIGNAL=2,UNIT_TYPE='FA-18C_hornet'}) do get_param_handle('RWR_CONTACT_01_'..k):set(v) end
dofile(SCRIPT_ROOT..'Systems/RWR_System.lua');post_initialize();update()
dofile(SCRIPT_ROOT..'Systems/Radar_System.lua');post_initialize();SetCommand(10602,1)
get_param_handle('F22N_RADAR_MODE'):set(1)
get_param_handle('F22_RADAR_OBSERVATIONS_READY'):set(1)
get_param_handle('F22_RADAR_OBSERVATION_COUNT'):set(2)
for i,id in ipairs({55,56}) do
 local p=string.format('F22O_%02d_',i)
 for k,v in pairs({ID=id,AGE=0,NORTH=5000+i*1000,EAST=0,ALTITUDE=0,IFF=i==1 and 1 or 0}) do get_param_handle(p..k):set(v) end
end
update();update()
assert(get_param_handle('F22_SCOPE_01_AFFILIATION'):get()==1)
assert(get_param_handle('F22_SCOPE_01_EW_SIGNAL'):get()==2)
assert(get_param_handle('F22_SCOPE_02_EW_SIGNAL'):get()==0,'same-bearing target incorrectly fused')
assert(get_param_handle('F22_SCOPE_02_AFFILIATION'):get()==0)
""")
print('Radar/EW producer integration: exact-source match; same bearing different ID stays separate; no false hostile IFF OK')
lua=runtime()
lua.execute("""
dofile(SCRIPT_ROOT..'Systems/Avionics.lua');post_initialize()
get_param_handle('BATTERY_POWER'):set(1);get_param_handle('MAIN_POWER'):set(1)
update();assert(get_param_handle('F22_UFD_EW_PAGE'):get()==0 and get_param_handle('F22_UFD_STATUS_PAGE'):get()==1)
local old=get_param_handle('L_ADI_OPACITY'):get()
SetCommand(device_commands.Button_10,1);update()
assert(get_param_handle('L_ADI_OPACITY'):get()~=old)
SetCommand(device_commands.Button_10,1);update()
assert(get_param_handle('L_ADI_OPACITY'):get()~=old,'held swap toggled twice')
SetCommand(device_commands.Button_10,0);SetCommand(device_commands.Button_10,1);update()
assert(get_param_handle('L_ADI_OPACITY'):get()==old)
assert(get_param_handle('F22_UFD_EW_PAGE'):get()==0 and get_param_handle('F22_UFD_STATUS_PAGE'):get()==1)
SetCommand(device_commands.Button_8,1);update()
assert(get_param_handle('UFD_OPACITY'):get()>0 and get_param_handle('UFD_OPACITY'):get()<1)
assert(get_param_handle('L_WAR_OPACITY'):get()==1,'night dimming hid the original caution page')
""")
print('Original upper-left status/ADI layout: exclusive original swap, press/release latch and no EW scope PASS')

# Native text formatter contract: new emitter labels must use numeric handles
# and static glyphs, including empty slots before the device's first update.
for page in ['UFD_LEFT/ew_page.lua','MFD_RIGHT/rwr_page.lua','PMFD_CENTER/radar_page.lua','HUD/page.lua']:
    lua=runtime();lua.execute("dofile(SCRIPT_ROOT..'"+page+"')")
    for _,e in lua.globals().elements.items():
        if e['formats']:
            for _,fmt in e['formats'].items():
                if '%s' in fmt:
                    assert not str(e['name']).startswith('HUD_EW_'),(page,e['name'])
                    assert page=='HUD/page.lua',(page,e['name'],'unsafe native printf string format')
print('Native emitter text ABI: empty slots never pass a numeric handle to printf %s OK')

lua=runtime()
lua.execute("""
native={set_power=function() end};function GetDevice() return native end
local function put(n,v) get_param_handle(n):set(v) end
local function get(n) return get_param_handle(n):get() end
put('MAIN_POWER',1)
for i,code in ipairs({1,0}) do
 local p=string.format('F22_IDENT_%02d_',i)
 for k,v in pairs({VALID=1,SOURCE=100+i,CLASS=code,AGE=0}) do put(p..k,v) end
 local q=string.format('RWR_CONTACT_%02d_',i)
 for k,v in pairs({SOURCE=100+i,TIME=0,AZIMUTH=i*.1,SIGNAL=1,UNIT_TYPE=i==1 and 'FA-18C_hornet' or 'MiG-29S'}) do put(q..k,v) end
end
dofile(SCRIPT_ROOT..'Systems/RWR_System.lua');post_initialize();update()
assert(get('F22_EW_01_AFFILIATION')==1 and get('F22_EW_02_AFFILIATION')==0,'EW discarded qualified simulator hostile ID')
put('F22_IDENT_01_VALID',0);put('F22_IDENT_02_VALID',0);update()
assert(get('F22_EW_01_AFFILIATION')==1,'turning radar off erased recent friendly identity')
dofile(SCRIPT_ROOT..'Systems/Radar_Data_Bridge.lua');post_initialize()
for k,v in pairs({MAIN_POWER=1,RADAR_PWR=1,F22_RADAR_BACKEND_READY=1,HUD_MODE=2,F22N_RADAR_MODE=3,
F22N_RADAR_STT_RANGE=5000,F22N_RADAR_STT_AZIMUTH=0,F22N_RADAR_STT_ELEVATION=0,F22N_RADAR_STT_FRIENDLY=1}) do put(k,v) end
dofile(SCRIPT_ROOT..'../../tests/stt_snapshot_fixture.lua');publish_test_stt(5000,0,0,1)
update();assert(get('HUD_TD_FRIENDLY')==1 and get('HUD_TD_BOX_VALID')==1)
put('MAIN_POWER',0);update();assert(get('HUD_TD_FRIENDLY')==0)
""")
print('Correlated friendly/unknown EW colors, identity memory and timestamped friendly HUD track gate OK')
