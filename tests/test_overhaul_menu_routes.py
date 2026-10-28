"""Press/release routing stays with its owner across page and power changes."""
from cockpit_fixture import runtime

lua = runtime()
lua.execute(r'''
dofile(SCRIPT_ROOT..'Systems/EW_System.lua');post_initialize();local ec=SetCommand
dofile(SCRIPT_ROOT..'Systems/MFD_System.lua');post_initialize();local mc,mu=SetCommand,update
dofile(SCRIPT_ROOT..'Systems/PMFD_System.lua');post_initialize();local pc,pu=SetCommand,update
local function get(k)return get_param_handle(k):get()end
local function put(k,v)get_param_handle(k):set(v)end
local events={}
function dispatch_action(d,c,v)
 if d==devices.MFD_SYSTEM then mc(c,v);return end
 events[#events+1]={d,c,v}
 if d==devices.EW_SYSTEM then ec(c,v)end
end
local function tick()mu();pu()end
local bases={10060,10090,10110,10130};local names={'LMFD','RMFD','CMFD','PMFD'}
local function edge(panel,b,down)
 local device=panel==4 and devices.PMFD_SYSTEM or devices.MFD_SYSTEM
 local owner=panel==4 and pc or mc
 owner(bases[panel]+b,device+(down and .375 or .25))
end
local function key(panel,b)edge(panel,b,true);edge(panel,b,false);tick()end
put('MAIN_POWER',1);tick()
for panel,name in ipairs(names)do
 -- A selector press must not execute the newly entered page on release.
 key(panel,13);key(panel,6)
 assert(get('F22_'..name..'_FORMAT')==8,'ENG selection bounced on release')
 key(panel,13);assert(get('F22_'..name..'_FORMAT')==0)
 key(panel,12);assert(get('F22_'..name..'_FORMAT')==8,'RTN lost retained page')
 for _,transition in ipairs({'page','power'})do
  key(panel,13);key(panel,4);events={}
  local before=get('F22_CM_NORMAL_BANK')
  edge(panel,1,true);edge(panel,1,true)
  assert(get('F22_CM_NORMAL_BANK')==before%3+1,'repeat down bypassed owner latch')
  if transition=='page'then key(panel,13)else put('MAIN_POWER',0);tick()end
  edge(panel,1,false);edge(panel,1,false)
  local down,up=0,0
  for _,e in ipairs(events)do
   if e[1]==devices.EW_SYSTEM and e[2]==11105 then
    if e[3]==1 then down=down+1 elseif e[3]==0 then up=up+1 end
   end
  end
  assert(down==1 and up==1,'original owner release lost or duplicated')
  put('MAIN_POWER',1);tick()
  if get('F22_'..name..'_FORMAT')~=0 then key(panel,13)end
  key(panel,4);key(panel,1)
  assert(get('F22_CM_NORMAL_BANK')==(before%3+1)%3+1,'owner stayed latched after transition')
  key(panel,13);key(panel,6)
 end
end
''')
print('Four actual display routes: selector release, retained RTN, repeated down, page/power release and owner recovery PASS')
