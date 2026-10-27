"""Real native-STT owner outputs override the retained BORE/VACQ/WIDE search cone."""
import contextlib,io,math
with contextlib.redirect_stdout(io.StringIO()):
 from test_display_startup import runtime
for command in [10605,10604,10622]:
 lua=runtime();lua.globals().PATTERN_COMMAND=command
 lua.execute('''
local now=1;function get_model_time()return now end
native={set_power=function()end};function GetDevice()return native end
local function p(k,v)get_param_handle(k):set(v)end
local function g(k)return get_param_handle(k):get()end
local pitch,roll=0,0
function get_base_data()return setmetatable({getSelfCoordinates=function()return 0,0,0 end,
 getPitch=function()return pitch end,getRoll=function()return roll end},
 {__index=function()return function()return 0 end end})end
dofile(SCRIPT_ROOT..'Systems/Radar_System.lua');post_initialize()
p('MAIN_POWER',1);p('HUD_MODE',3);p('EFM_HUD_VALID',1);p('F22N_RADAR_MODE',1)
SetCommand(10626,1);update();SetCommand(PATTERN_COMMAND,1);update()
for _,east in ipairs({2400,-3200,800})do
 pitch=.3;roll=1.1
 now=now+.05;p('F22N_RADAR_MODE',3);p('F22_STT_MOTION_VALID',1);p('F22_STT_TIME',now)
 p('F22_STT_ID',123);p('F22_STT_PN',6000);p('F22_STT_PE',east);p('F22_STT_PU',1000)
 update()
 assert(g('F22_RADAR_STT_VALID')==1 and g('F22_RADAR_COVERAGE_VALID')==1)
 assert(math.abs(g('F22_RADAR_COVERAGE_CENTER_ROT')+math.atan2(east,6000))<1e-8,'antenna cue stayed at bore instead of tracking measured target')
 assert(g('F22_RADAR_COVERAGE_ROT')==0 and g('F22_ACM_MODE')==0,'search cone/ACM reticle survived STT')
end
now=now+1;update()
assert(g('F22_RADAR_STT_VALID')==0 and g('F22_RADAR_COVERAGE_VALID')==0,'stale STT reverted to a misleading forward cone')
p('F22N_RADAR_MODE',1);now=now+.05;update()
assert(g('F22_RADAR_COVERAGE_VALID')==1 and g('F22_RADAR_COVERAGE_ROT')>0,'track loss failed to restore real search coverage')
''')
print('Radar tracking LOS: BORE/VACQ/WIDE acquisition -> moving native STT while pitched/banked -> stale withdrawal -> restored search PASS')
