"""Actual estimate and alignment owner under aiding loss, power interruption and reset."""
from test_display_startup import runtime
lua=runtime()
lua.execute("""
local I=dofile(SCRIPT_ROOT..'Systems/INS_Model.lua');local i=I.new()
local s={now=0,powered=true,enabled=true,aligned=true,aided=true,n=0,e=0,alt=1000,velocity_valid=true,vn=100,ve=0,vu=0}
i:update(s);assert(i.valid and i.error==15)
for t=1,20 do s.now=t;i:update(s);assert(i.n==0 and i.error==15,'steady GPS follows position even during active pause')end
s.now=0;i:update(s)
s.aided=false
for t=1,3600 do s.now=t;i:update(s)end
assert(math.abs(i.n-360000)<1e-8 and math.abs(i.error-1867)<1e-6 and math.abs(i.heading_error-3.1)<1e-6)
s.aided=true;s.now=3601;s.n=360500;i:update(s)
assert(math.abs(i.n-360150)<1e-6 and i.error==350,'normal prediction plus 50m/s correction')
s.aided=false;s.now=3602;s.velocity_valid=false;assert(not i:update(s)and not i.valid)
s.aided=true;s.now=3603;s.n=361000;i:update(s);assert(i.valid and i.n==361000)
s.aided=false;s.now=3602;assert(not i:update(s)and not i.valid,'clock rewind cannot integrate backwards')
s.aided=true;s.now=3604;i:update(s);assert(i.valid)
s.powered=false;s.now=3605;assert(not i:update(s)and not i.valid)
s.powered=true;s.aided=false;s.now=3606;assert(not i:update(s),'uncertain unpowered position requires aiding to recover')
s.aided=true;i:update(s);assert(i.valid)
s.aligned=false;s.now=3607;assert(not i:update(s)and not i.valid)
""")
lua=runtime()
lua.execute("""
local time=0;function get_model_time()return time end
local function p(n,v)get_param_handle(n):set(v)end
local function g(n)return get_param_handle(n):get()end
LockOn_Options.init_conditions.birth_place='AIR_HOT'
 p('MAIN_POWER',1);p('EFM_HUD_VALID',1);p('F22_AP_CLOCK',0)
local physical=dofile(SCRIPT_ROOT..'../../tests/physical_frame_fixture.lua')({F22_ESSENTIAL_POWER=1})
physical:publish(0)
dofile(SCRIPT_ROOT..'Systems/Flight_Guidance.lua');post_initialize()
local function tick(t)time=t;physical:publish(time);update()end
tick(0);assert(g('F22_INS_READY')==1)
p('MAIN_POWER',0);physical.values.F22_ESSENTIAL_POWER=0;tick(1);assert(g('F22_INS_READY')==0)
p('MAIN_POWER',1);physical.values.F22_ESSENTIAL_POWER=1;tick(3);assert(g('F22_INS_READY')==1,'short power interruption retains alignment')
p('MAIN_POWER',0);physical.values.F22_ESSENTIAL_POWER=0;tick(4);p('MAIN_POWER',1);physical.values.F22_ESSENTIAL_POWER=1;tick(10);assert(g('F22_INS_READY')==0)
for n=1,299 do tick(10+n*.1)end
assert(g('F22_INS_READY')==0,'core profile invented automatic airborne realignment')
SetCommand(10942,1);tick(time+.1)
assert(g('F22_GINS_COMMAND_RESULT')==2 and g('F22_INS_READY')==0,'airborne ground-alignment request accepted')
for n=1,400 do tick(time+.1)end;assert(g('F22_INS_READY')==0,'manual alignment requires ground stationary')
p('EFM_GROUND_VALID',1);p('EFM_WEIGHT_ON_WHEELS',1);p('HUD_GS_VALID',1);p('HUD_GS_MPS',0)
for n=1,4801 do tick(time+.1)end;assert(g('F22_INS_READY')==1,'normal estimated480s alignment failed')
SetCommand(10942,1);p('HUD_GS_MPS',5);p('EFM_HUD_VN',5)
for n=1,1900 do tick(time+.1)end;assert(g('F22_INS_READY')==0,'moving alignment never completes')
tick(0);assert(g('F22_INS_READY')==0,'rewind resets alignment')
""")
print('INS: bounded explicit uncertainty, coherent prediction/aiding correction, invalid sensor recovery, power/airborne/ground/motion/clock lifecycle PASS')
