"""Actual EW owner status and coverage cue; synthetic host effect, no RF flight claim."""
from test_display_startup import runtime
lua=runtime()
lua.execute(r'''
local now,enabled=10,false
function get_model_time()return now end
local device={get_chaff_count=function()return 100 end,get_flare_count=function()return 100 end,
 drop_chaff=function()end,drop_flare=function()end,get_ECM_status=function()return enabled end,
 set_ECM_status=function(self,v)enabled=v end}
function GetDevice()return device end
local function p(k,v)get_param_handle(k):set(v)end
local function g(k)return get_param_handle(k):get()end
dofile(SCRIPT_ROOT..'Systems/EW_System.lua');post_initialize();p('MAIN_POWER',1);update()
assert(g('F22_ECM_DISPLAY_STATE')==0 and g('F22_ECM_TRANSMITTING_VALID')==0)
SetCommand(136,1);update()
assert(enabled and g('F22_ECM_DISPLAY_STATE')==2 and g('F22_ECM_TRANSMITTING')==0)
p('F22_AESA_SEQUENCE',2);p('F22_NATIVE_ECM_GENERATION',1)
p('F22_NATIVE_ECM_VALID',1);p('F22_NATIVE_ECM_ACTIVE',1);p('F22_NATIVE_ECM_TIME',now)
update();assert(g('F22_ECM_DISPLAY_STATE')==3 and g('F22_ECM_TRANSMITTING')==1)
-- Game activation/deactivation delay can differ from the switch acknowledgement.
SetCommand(136,1);update()
assert(not enabled and g('F22_ECM_DISPLAY_STATE')==3,'confirmed residual effect was hidden by OFF request')
p('F22_NATIVE_ECM_ACTIVE',0);update();assert(g('F22_ECM_DISPLAY_STATE')==0)
p('F22_NATIVE_ECM_ACTIVE',1);p('F22_AESA_SEQUENCE',3);update()
assert(g('F22_ECM_TRANSMITTING_VALID')==0 and g('F22_ECM_DISPLAY_STATE')==0)
p('F22_AESA_SEQUENCE',4);p('F22_NATIVE_ECM_GENERATION',0);update()
assert(g('F22_ECM_TRANSMITTING_VALID')==0)
p('F22_NATIVE_ECM_GENERATION',1);now=10.3;update()
assert(g('F22_ECM_TRANSMITTING_VALID')==0,'stale native activity retained JAM')
p('F22_NATIVE_ECM_TIME',11);update();assert(g('F22_ECM_TRANSMITTING_VALID')==0)
local status=dofile(SCRIPT_ROOT..'Systems/ECM_Status.lua')
assert(status.state(true,true,false,false,false,false)==status.requested)
assert(status.state(true,false,false,false,false,false)==status.unknown)
assert(status.state(true,true,true,true,true,true)==status.failed)
local reads=0
local function torn(k)if k=='F22_AESA_SEQUENCE'then reads=reads+1;return reads*2 end;return g(k)end
assert(not status.effect(torn,11),'torn publication accepted')
-- Capture the shared actual display contract and evaluate its inherited gates.
local groups,lines={},{}
local api={group=function(name,params,controllers,parent)groups[name]={params=params,controllers=controllers,parent=parent}end,
 line=function(x,y,u,v,color,parent)lines[#lines+1]={x,y,u,v,color,parent}end}
dofile(SCRIPT_ROOT..'Systems/ECM_Coverage_Indicator.lua')(api,'contact','arrow',1,
 {'AZ','COAST'},{{'rotate_using_parameter',0,1},{'parameter_in_range',1,-.1,.1}})
local function visible(values)
 local q=groups.arrow
 for _,c in ipairs(q.controllers)do
  if c[1]=='parameter_in_range'then local value=values[q.params[c[2]+1]]
   if value<c[3] or value>c[4]then return false end
  end
 end
 return true
end
local values={AZ=math.pi/2,COAST=0,F22_ECM_TRANSMITTING_VALID=1,F22_ECM_TRANSMITTING=1}
assert(visible(values) and #lines==3 and lines[1][5]=='green')
for _,key in ipairs({'F22_ECM_TRANSMITTING_VALID','F22_ECM_TRANSMITTING'})do
 values[key]=0;assert(not visible(values));values[key]=1
end
values.COAST=1;assert(not visible(values))
-- Arrow points outward toward the contact, not toward the center of the scope.
assert(lines[1][2]<lines[1][4] and lines[1][4]<0)
''')
print('ECM indication: actual EW owner, switch/effect divergence, stale/torn/unknown and outbound coverage gates PASS')
