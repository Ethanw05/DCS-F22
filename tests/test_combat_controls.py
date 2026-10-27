"""Exercise held HOTAS inputs and the actual gated weapon controller in Lua 5.1."""
from pathlib import Path
import runpy
ROOT=Path(__file__).resolve().parents[1]
runtime=runpy.run_path(str(ROOT/'tests/test_display_startup.py'))['runtime']
l=runtime()
l.execute('''
events={};local function emit(n,v) events[#events+1]={n,v} end
local s=dofile(SCRIPT_ROOT..'Systems/Combat_Logic.lua').new(emit)
local c={ground=false,locked=false,selected=false}
-- Repeated down events and release cannot undo a latched gun selection.
s:input('dogfight',1,c);assert(s.mode==5 and s.dogfight)
for i=1,20 do s:input('dogfight',1,c);s:update(.02,c) end
assert(s.mode==5 and s.dogfight)
s:input('dogfight',0,c);assert(s.mode==5)
s:input('tms_down',1,c);assert(events[#events][1]=='vertical')
s:input('tms_down',0,c);c.locked=true
s:input('tms_right',1,c);assert(events[#events][1]=='wide')
s:update(2,c);s:input('tms_right',0,c)
assert(events[#events][1]=='wide','ACM held right must select wide')
s:input('missile_step',1,c);s:input('missile_step',0,c)
assert(events[#events][1]=='undesignate')
-- Changing weapons is never a radar mode/lock command when already locked.
for _,n in ipairs({'srm','mrm','gun','weapon_select'}) do
 events={};s:input(n,1,c);s:input(n,0,c)
 for _,e in ipairs(events) do assert(e[1]~='rws' and e[1]~='boresight' and e[1]~='wide' and e[1]~='vertical') end
end
s:input('nav',1,c);s:input('nav',0,c);c.locked=false
events={};s:input('cage',1,c);s:input('cage',1,c);s:input('cage',0,c)
assert(#events==1 and events[1][1]=='nav_cage','NAV cage also commanded the seeker/repeated')
s:set_mode(3);events={};s:input('cage',1,c);s:input('cage',0,c)
assert(#events==1 and events[1][1]=='cage','weapon cage changed the NAV FPM')
s:set_mode(1)
for _,expected in ipairs({2,3,5,2}) do
 s:input('weapon_select',1,c);s:input('weapon_select',1,c)
 assert(s.mode==expected,'weapon cycle/repeated press failed')
 s:input('weapon_select',0,c);assert(s.mode==expected)
end
s:set_mode(2);events={}
s:input('tms_right',1,c);s:update(.6,c);assert(#events==0)
s:update(.5,c);assert(#events==1 and events[1][1]=='toggle')
s:input('tms_right',0,c);assert(#events==1,'hold also emitted short')
s:input('tms_right',1,c);s:update(.1,c);s:input('tms_right',0,c)
assert(events[#events][1]=='next_track')
s:input('trigger_second',1,c);s:input('trigger_second',0,c);s:input('trigger_second',0,c)
assert(events[#events][2]==0,'duplicate release must remain release')
''')
l=runtime()
l.execute('''
function get_aircraft_property(_) return 1 end
function get_aircraft_draw_argument_value(n) return draws[n] or 0 end
function set_aircraft_draw_argument_value(n,v) draws[n]=v end
native={get_station_info=function(self,i)
 return {count=i==0 and 2 or 0,CLSID='{6CEB49FC-DED8-4DED-B053-E1F033FF72D3}',weapon={level1=4,level2=4,level3=7,level4=22}} end,
 select_station=function(self,i) self.station=i end,
 get_chaff_count=function() return 120 end,get_flare_count=function() return 120 end,
 set_target_range=function(self,r) self.range=r end,set_target_span=function() end}
function GetDevice(i) assert(i==15);return native end
dofile(SCRIPT_ROOT..'Systems/Weapon_System.lua');post_initialize()
get_param_handle('MAIN_POWER'):set(1);get_param_handle('WoW'):set(0)
SetCommand(10800,5);update()
assert(actions[#actions-1][1]==283 and actions[#actions][1]==10850,'safe native arm and cockpit tick missing')
SetCommand(10008,1);SetCommand(10801,1);SetCommand(10802,1)
for i=1,20 do update() end
assert(get_param_handle('HUD_GUN_TRIGGER'):get()==1)
local fired=false;for _,a in ipairs(actions) do if a[1]==84 then fired=true end end;assert(fired,'native cannon did not receive fire')
SetCommand(10802,0);assert(actions[#actions][1]==85)
SetCommand(10802,0);update();assert(get_param_handle('HUD_GUN_TRIGGER'):get()==0)
SetCommand(10802,1);update();get_param_handle('WoW'):set(1);update()
assert(get_param_handle('HUD_GUN_TRIGGER'):get()==0,'ground did not stop fire')
get_param_handle('WoW'):set(0);update();assert(get_param_handle('HUD_GUN_TRIGGER'):get()==0)
SetCommand(Keys.PlaneModeVS,1);update();assert(get_param_handle('HUD_MODE'):get()==5,'legacy vertical changed gun weapon')
SetCommand(Keys.PlaneModeBore,1);update();assert(get_param_handle('HUD_MODE'):get()==5,'legacy bore changed gun weapon')
SetCommand(10800,3);update();assert(native.station==0)
SetCommand(Keys.PlaneModeBore,1);update();assert(get_param_handle('HUD_MODE'):get()==3,'legacy bore left the typed AIM-9 mode')
assert(get_param_handle('F22_IR_CAGED'):get()==1,'mode entry must cage seeker')
get_param_handle('F22_RADAR_STT_VALID'):set(1);update()
assert(get_param_handle('F22_IR_CAGED'):get()==1,'radar lock auto-uncaged seeker')
SetCommand(10805,1);update();assert(get_param_handle('F22_IR_CAGED'):get()==0)
get_param_handle('F22_RADAR_STT_VALID'):set(0);update()
assert(get_param_handle('F22_IR_CAGED'):get()==0,'radar loss recaged independent IR seeker')
SetCommand(10803,1)
for i=1,30 do update() end
assert(get_param_handle('BAY_L_ARG'):get()>=.98)
assert(get_param_handle('F22_IR_RELEASE_REQUEST'):get()==1)
assert(get_param_handle('F22_IR_STATION'):get()==0 and get_param_handle('F22_IR_TYPE4'):get()==22)
for _,a in ipairs(actions) do assert(a[1]~=350,'IR launch routed to empty generic seeker') end
SetCommand(10803,0);update();assert(get_param_handle('F22_IR_RELEASE_REQUEST'):get()==0)
get_param_handle('F22_IR_AVAILABLE'):set(1);get_param_handle('F22_IR_LOCK'):set(0);update()
assert(get_param_handle('HUD_IR_SEEKER_AVAILABLE'):get()==0,'unprojectable beam must not draw a circle')
get_param_handle('F22_IR_WORLD_VALID'):set(1);get_param_handle('F22_IR_WORLD_FWD_N'):set(1);update()
assert(get_param_handle('HUD_IR_SEEKER_AVAILABLE'):get()==1 and get_param_handle('HUD_IR_SEEKER_VALID'):get()==0)
get_param_handle('F22_IR_LOCK'):set(1);update();assert(get_param_handle('HUD_IR_SEEKER_VALID'):get()==1)
get_param_handle('F22_MWS_AUDIO_PRIORITY'):set(1);update()
assert(get_param_handle('HUD_IR_SEEKER_VALID'):get()==1 and get_param_handle('F22_IR_CAGED'):get()==0,'MWS priority changed seeker state')
native.get_station_info=function(self,i)return {count=i==0 and 1 or 0,CLSID='{AIM9X-BLKII}',weapon={level1=4,level2=4,level3=7,level4=10042}}end
for i=1,20 do update() end
assert(get_param_handle('F22_IR_AIM9X_PROFILE'):get()==1 and get_param_handle('F22_IR_TYPE4'):get()==10042)
SetCommand(10800,7);update();assert(get_param_handle('HUD_MODE'):get()==7,'private A/G mode was ignored')
assert(get_param_handle('F22_IR_RELEASE_REQUEST'):get()==0 and get_param_handle('HUD_GUN_TRIGGER'):get()==0)
''')
l=runtime()
l.execute("""
local decode=dofile(SCRIPT_ROOT..'Systems/Input_Value.lua')
assert(decode(16.375,16)==1 and decode(16.25,16)==0)
assert(decode(14.125,14)==-1 and decode(14.25,14)==0 and decode(14.375,14)==1)
assert(decode(0,16)==0 and decode(1,16)==1)
dofile(SCRIPT_ROOT..'Systems/Combat_System.lua');post_initialize()
get_param_handle('MAIN_POWER'):set(1)
SetCommand(10719,16.375);SetCommand(10719,16.25)
SetCommand(10719,16.375);SetCommand(10719,16.25)
-- Each physical click toggles once; releases must reach the latch.
local modes={};for _,a in ipairs(actions) do if a[1]==10800 then modes[#modes+1]=a[2] end end
assert(#modes==2 and modes[1]==5 and modes[2]==1)
SetCommand(10717,16.375);SetCommand(10717,16.25)
assert(actions[#actions][1]==10802 and actions[#actions][2]==0)
""")
print('Combat: contextual ACM, short/hold, mode restore, native arm, cannon/stop, WOW, station and bay-gated missile release OK')
