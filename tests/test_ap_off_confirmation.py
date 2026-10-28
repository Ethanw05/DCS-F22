"""The real ICP transport may announce OFF only after native acknowledgement."""
from test_display_startup import runtime

sim = runtime()
sim.execute(r'''
local function p(k,v)get_param_handle(k):set(v)end
local function g(k)return get_param_handle(k):get()end
dofile(SCRIPT_ROOT..'Systems/ICP_System.lua');post_initialize()
p('MAIN_POWER',1);p('F22_AP_ACTIVE',1);p('F22_AP_ROLL_MODE',3);p('F22_AP_PITCH_MODE',2)
p('F22_AP_AT',1);p('F22_AP_OFF_SEQUENCE',7)
local function key(command)SetCommand(command,7.375);SetCommand(command,7.25)end
key(3015);key(3035)
assert(g('F22_UFC_SCRATCH')=='AP / AT OFF REQUESTED','button falsely announced native OFF')
p('F22_AP_OFF_SEQUENCE',8);update()
assert(g('F22_UFC_SCRATCH')=='AP / AT OFF REQUESTED','acknowledgement alone masked active NAV')
p('F22_AP_ACTIVE',0);p('F22_AP_AT',0);p('F22_AP_ROLL_MODE',0);p('F22_AP_PITCH_MODE',0)
p('F22_AP_OVERRIDE',0);p('F22_AP_NAV_OVERRIDE',0);update()
assert(g('F22_UFC_SCRATCH')=='AP / AT OFF')
key(3035);update()
assert(g('F22_UFC_SCRATCH')=='AP / AT OFF REQUESTED','prior native acknowledgement completed a new request')
for _=1,170 do update()end
assert(g('F22_UFC_SCRATCH')=='AP OFF NOT CONFIRMED','missing native response falsely succeeded')
key(3035);p('F22_AP_OFF_SEQUENCE',9);p('F22_AP_NAV_OVERRIDE',1);update()
assert(g('F22_UFC_SCRATCH')=='AP / AT OFF REQUESTED','remaining override latch was hidden')
p('F22_AP_NAV_OVERRIDE',0);update();assert(g('F22_UFC_SCRATCH')=='AP / AT OFF')
''')
print('Actual ICP: native OFF sequence, full state release, stale/missing acknowledgements and override gates PASS')

sim = runtime()
sim.execute(r'''
local values={MAIN_POWER=1,F22_AP_ACTIVE=1}
local sent={}
local function get(k)return values[k]or 0 end
local ui=dofile(SCRIPT_ROOT..'Systems/UFC_Controller.lua').new(get,function()end,
 function(_,command)sent[#sent+1]=command end)
ui:open('AP',true)
for _,state in ipairs({{1,2},{3,1}})do
 values.F22_AP_ROLL_MODE=state[1];values.F22_AP_PITCH_MODE=state[2]
 assert(ui:rows()[1].label==':ATTH','remaining attitude axis is hidden from its toggle button')
 ui:option(1);assert(sent[#sent]==10951,'partial attitude release did not use the common native mode')
end
''')
print('Partial roll/pitch attitude holds retain selected ATTH indication and a reachable release action PASS')
