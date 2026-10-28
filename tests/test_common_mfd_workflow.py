"""Run the real shared routers, indicators and format-aware sensor input."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
fixture=ROOT/'tests/test_display_startup.py';ns={'__file__':str(fixture)}
exec(compile(fixture.read_text().split('\nfor page in ',1)[0],str(fixture),'exec'),ns)
lua=ns['runtime']()
lua.execute(r'''
function get_aircraft_property()return 1 end
local function put(k,v)get_param_handle(k):set(v)end
local function get(k)return get_param_handle(k):get()end
dofile(SCRIPT_ROOT..'Systems/MFD_System.lua');post_initialize();local mc,mu=SetCommand,update
dofile(SCRIPT_ROOT..'Systems/PMFD_System.lua');post_initialize();local pc,pu=SetCommand,update
local events={}
function dispatch_action(d,c,v)
 events[#events+1]={d=d,c=c,v=v}
 if d==devices.MFD_SYSTEM then mc(c,v)end
end
local function tick()mu();pu()end
local function edge(panel,b,down)
 if panel==4 then pc(10130+b,devices.PMFD_SYSTEM+(down and .375 or .25))
 else mc(({10060,10090,10110})[panel]+b,devices.MFD_SYSTEM+(down and .375 or .25))end
end
local function key(panel,b)edge(panel,b,true);edge(panel,b,false);tick()end
local panels={'LMFD','RMFD','CMFD','PMFD'}
put('MAIN_POWER',1);put('HUD_MODE',7);put('HUD_AG_SUBMODE',3)
put('F22_SMS_LABEL',2);put('F22_SMS_MODE_AVAILABLE_3',1);tick()
local routing=dofile(SCRIPT_ROOT..'Systems/Display_Routing.lua')
for panel,name in ipairs(panels)do
 for b,page in ipairs(routing.order)do
  key(panel,13);assert(get('F22_'..name..'_FORMAT')==0)
  assert(get('F22_MFD_'..name..'_KEY_'..b)==routing.names[page])
  key(panel,b);assert(get('F22_'..name..'_FORMAT')==page,'format unavailable on '..name)
  for other,other_name in ipairs(panels)do
   local count=0;for p in pairs(routing.suffix)do count=count+get(routing.flag(other_name,p))end
   assert(count==1,'overlapping or blank formats on '..other_name)
  end
  assert(get('F22_MFD_'..name..'_KEY_13')=='MENU')
 end
end
-- Legacy input profiles emit only a down impulse. These must not latch.
for panel=1,4 do
 local owner=panel==4 and pc or mc;local base=({10060,10090,10110,10130})[panel]
 owner(base+13,1);tick();owner(base+2,1);tick()
 assert(get('F22_'..panels[panel]..'_FORMAT')==7)
 owner(base+13,1);tick();owner(base+3,1);tick()
 assert(get('F22_'..panels[panel]..'_FORMAT')==6,'down-only alias latched on '..panels[panel])
end
-- Mirrored Stores uses independent local data subpages.
for panel=1,4 do key(panel,13);key(panel,3)end
key(1,11);assert(get('F22_LMFD_VIEW')==1 and get('F22_CMFD_VIEW')==0)
assert(get('F22_MFD_LMFD_KEY_12')=='RTN'and get('F22_MFD_CMFD_KEY_12')=='')
key(1,13);assert(get('F22_SMS_PROGRAM_PAGE')==1,'another visible Stores lost keypad ownership')
key(1,12);assert(get('F22_LMFD_FORMAT')==6)
-- A blank old system shortcut cannot operate another page.
key(2,13);key(2,6);events={};key(2,2)
assert(get('F22_RMFD_FORMAT')==8,'obsolete ENG shortcut is active')
-- DEF press release is delivered to its original owner after a page/power change.
key(3,13);key(3,4);events={}
edge(3,1,true);key(3,13);put('MAIN_POWER',0);tick();edge(3,1,false)
local downs,ups=0,0
for _,e in ipairs(events)do if e.d==devices.EW_SYSTEM and e.c==11105 then if e.v==1 then downs=downs+1 else ups=ups+1 end end end
assert(downs==1 and ups==1,'EW release lost or duplicated after page/power transition')
-- AA radar has exactly one pair of range buttons; moved radar is fully routed.
put('MAIN_POWER',1);put('HUD_MODE',2);tick()
for panel,name in ipairs(panels)do
 key(panel,13);key(panel,1);events={};key(panel,15);key(panel,14)
 assert(get('F22_MFD_'..name..'_KEY_15')=='RNG-'and get('F22_MFD_'..name..'_KEY_14')=='RNG+')
 local in_count,out_count=0,0
 for _,e in ipairs(events)do if e.v==1 and e.c==10608 then in_count=in_count+1 elseif e.v==1 and e.c==10607 then out_count=out_count+1 end end
 assert(in_count==1 and out_count==1,'range action duplicated')
 key(panel,8);key(panel,1);assert(get('F22_'..name..'_VIEW')==0,'ACM selection did not return')
end
local sensor=dofile(SCRIPT_ROOT..'Systems/Sensor_Control.lua')
local sent={};local logic=dofile(SCRIPT_ROOT..'Systems/Combat_Logic.lua').new(function(n,v)sent[#sent+1]={n,v}end)
local context={locked=false,selected=true,common_formats={[2]=1,[3]=1,[4]=1,[5]=1}}
logic.mode=2
for focus=2,5 do
 logic:focus(focus);sent={};logic:input('tdc',1,context);logic:input('tdc',0,context)
 assert(sent[#sent][1]=='designate','radar rejects focus '..focus)
 assert(sensor.action(focus,1,2,context)=='stt')
end
context.common_formats[3]=7;logic:focus(3);sent={};logic:input('tdc',1,context);logic:input('tdc',0,context)
assert(#sent==0,'NAV fell through into an unseen radar')
sent={};logic:set_mode(3);for _,e in ipairs(sent)do assert(e[1]~='radar_page','master mode stole display arrangement')end
''')
print('Common MFD routing: 4 x 9 formats, local views, release ownership, range placement and sensor focus PASS')

counts=[]
for panel,folder in [('LMFD','MFD_LEFT'),('RMFD','MFD_RIGHT'),('CMFD','MFD_CENTER'),('PMFD','PMFD_CENTER')]:
    lua=ns['runtime']()
    lua.execute("resources={};local n=0;function MakeMaterial(file,c)n=n+1;local k='m'..n;resources[k]={file=file,color=c};return k end")
    lua.execute("dofile(SCRIPT_ROOT..'"+folder+"/page.lua')")
    lua.globals().PANEL=panel
    lua.execute(r'''
local lookup={};for _,e in ipairs(elements)do lookup[e.name]=true end
for _,e in ipairs(elements)do
 if e.parent_element then assert(lookup[e.parent_element],'unresolved native parent '..e.parent_element)end
end
local keys={}
for _,e in ipairs(elements)do
 if e.name:find('F22_BEZEL_'..PANEL..'_',1,true)==1 and e.kind=='ceStringSLine'then
  local key=tonumber(e.name:match('_(%d+)$'));keys[key]=e
 end
end
assert(keys[13].init_pos[1]==0 and keys[13].init_pos[2]<-.8)
for b=1,20 do assert(keys[b],'missing common bezel label')end
local found=false
for _,m in pairs(resources)do
 if m.color and m.color[1]==3 and m.color[2]==3 and m.color[3]==12 then error('navy background remains')end
 if m.color and m.color[1]==3 and m.color[2]==3 and m.color[3]==3 then found=true end
end
assert(found,'upper-UFD neutral gray background missing')
''')
    counts.append(len(lua.globals().elements))
assert len(set(counts))==1,counts
print('Common native element graphs: identical libraries, valid parents, physical bezels and neutral gray PASS')
