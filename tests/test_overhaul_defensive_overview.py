"""Source-aware overview, native graph freshness and actual bezel contracts."""
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
fixture=ROOT/'tests/test_display_startup.py'
ns={'__file__':str(fixture)}
exec(compile(fixture.read_text().split('\nfor page in ',1)[0],str(fixture),'exec'),ns)
runtime=ns['runtime']
lua=runtime()
lua.execute(r'''
local Tracks=dofile(SCRIPT_ROOT..'Systems/Tactical_Tracks.lua')
local Overview=dofile(SCRIPT_ROOT..'Systems/Defensive_Overview.lua')
local Frames=dofile(SCRIPT_ROOT..'Systems/Gun_Frames.lua')
local pose={heading=0,pitch=0,roll=0}
local sensors={getHeading=function()return -pose.heading end,getPitch=function()return pose.pitch end,getRoll=function()return pose.roll end}
local h={F22_RADAR_RANGE_NM=40}
local function get(k)return h[k]or 0 end
local function put(k,v)h[k]=v end
local overview=Overview.new(get,put,sensors)
local function row(source)
 for i=1,16 do local p=string.format('F22_DEF_OV_%02d_',i);if get(p..'VALID')==1 and get(p..'SOURCE')==source then return p end end
end
local function count_matches()
 local n=0;for i=1,16 do n=n+get(string.format('F22_DEF_OV_%02d_VALID',i))end
 assert(n==get('F22_DEF_OV_COUNT'),'overview count includes a rejected/unplottable record')
end
local store=Tracks.new()
store:update(100,{
 radar={sequence=1,time=100,contacts={
  {source=20,age=0,az=0,el=0,range=20*1852,friendly=true},
  {source=30,age=0,az=.5,el=0,range=10*1852},
  {source=60,age=0,az=-.5,el=0,range=80*1852},
 }},
 rf={sequence=1,time=100,contacts={
  {source=10,age=0,az=.2,el=0,signal=2,range=12*1852},
  {source=20,age=10,az=0,el=0,signal=3},
  {source=40,age=0,az=-.2,el=0,signal=3},
 }},
 mws={sequence=1,time=100,contacts={
  {source=30,age=1,az=.5,el=0},
  {source=50,age=0,az=.8,el=0},
 }},
},true)
overview:update(100,store.contacts,true,false,40);count_matches()
local passive=assert(row(10));assert(get(passive..'RANGED')==0 and math.abs(math.sqrt(get(passive..'X')^2+get(passive..'Y')^2)-Overview.radius)<1e-9,string.format('passive range/radius invalid: ranged=%g radius=%g',get(passive..'RANGED'),math.sqrt(get(passive..'X')^2+get(passive..'Y')^2)))
local radar=assert(row(20));assert(get(radar..'RANGED')==1 and math.abs(get(radar..'Y')-Overview.radius*.5)<1e-9)
assert(get(radar..'AFFILIATION')==1 and get(radar..'ALERT')==0 and get(radar..'COAST')==1,'fresh radar renewed an expired RF launch warning')
local optical=assert(row(30));assert(get(optical..'OPTICAL')==1 and get(optical..'ALERT')==0 and get(optical..'COAST')==1,'fresh radar renewed an expired optical warning')
assert(get(assert(row(40))..'ALERT')==1 and get(assert(row(50))..'ALERT')==1)
assert(get('F22_DEF_OV_01_SOURCE')==40 and get('F22_DEF_OV_01_SELECTED')==1)
assert(get(assert(row(60))..'OFFSCALE')==1,'offscale radar range was not bounded to the outer ring')
h.F22_RADAR_RANGE_NM=0;overview:update(100,store.contacts,true,false,nil)
assert(get('F22_DEF_OV_RANGE_VALID')==0 and get(assert(row(20))..'RANGED')==0,'unknown scope scale still implied a measured plotted range')
h.F22_RADAR_RANGE_NM=40
overview:update(100,store.contacts,true,true,40);count_matches()
assert(row(10)and row(40)and row(50)and not row(20)and not row(30)and not row(60),'THRT filter renewed or invented warning evidence')
-- Fresh RF must not renew radar range beyond its own six-second validity.
local expired=Tracks.new();expired:update(100,{radar={sequence=1,time=100,contacts={{source=70,age=6.1,az=.1,el=0,range=10*1852}}},rf={sequence=1,time=100,contacts={{source=70,age=0,az=.1,el=0,signal=1}}}},true)
overview:update(100,expired.contacts,true,false,nil)
assert(get(assert(row(70))..'RANGED')==0)
-- Tilted ownship must retain a level heading-up display of the same world ray.
for _,p in ipairs({{0,0,0},{math.pi/2,.3,.7},{math.pi*1.5,-.2,-.8}})do
 pose.heading,pose.pitch,pose.roll=unpack(p)
 local body=Frames.body(Frames.from_pose(pose),{1,0,0})
 local t={source=80,age=0,az=math.atan2(body[3],body[1]),el=math.atan2(body[2],math.sqrt(body[1]^2+body[3]^2)),range=20*1852,affiliation=-1,observations={radar={time=100}}}
 overview:update(100,{t},true,false,nil);local q=assert(row(80))
 assert(math.abs(get(q..'X')+Overview.radius*.5*math.sin(pose.heading))<1e-9 and math.abs(get(q..'Y')-Overview.radius*.5*math.cos(pose.heading))<1e-9,'overview follows pitch/bank rather than stabilized horizontal direction')
end
pose.heading,pose.pitch,pose.roll=0,0,0
-- Affiliation is explicit producer data, never inferred from sensor type.
for _,aff in ipairs({-1,0,1})do
 overview:update(100,{{source=90,age=0,az=0,el=0,affiliation=aff,observations={rf={time=100,signal=1}}}},true,false,nil)
 assert(get(assert(row(90))..'AFFILIATION')==aff)
end
local many={};for i=1,20 do many[i]={source=i,age=0,az=i*.1,el=0,affiliation=-1,observations={rf={time=100,signal=1}}}end
overview:update(100,many,true,false,20);count_matches()
assert(get('F22_DEF_OV_COUNT')==16 and get('F22_DEF_OV_OVERFLOW')==4 and get('F22_DEF_OV_01_SOURCE')==20)
overview:update(100,many,false,false,nil);count_matches();assert(get('F22_DEF_OV_VALID')==0 and get('F22_DEF_OV_COUNT')==0)
pose.heading=0/0;overview:update(100,many,true,false,nil);count_matches();assert(get('F22_DEF_OV_VALID')==0)
pose.heading=0
-- At the vertical axis no horizontal bearing exists; do not count a blank slot.
overview:update(100,{{source=91,age=0,az=0,el=math.pi/2,affiliation=-1,observations={mws={time=100}}}},true,false,nil);count_matches()
''')
print('Defensive overview model: source-local warnings/range, stabilized geometry, explicit affiliation, priority/filter, limits and invalidation PASS')

lua=runtime()
lua.execute(r'''
local now=100;function get_model_time()return now end
function get_aircraft_property()return 1 end
function get_aircraft_draw_argument_value(n)return draws[n]or 0 end
function set_aircraft_draw_argument_value(n,v)draws[n]=v end
for _,owner in ipairs({'RWR_System','EW_System','MFD_System'})do dofile(SCRIPT_ROOT..'Systems/'..owner..'.lua')end
local mfd_command,mfd_update=SetCommand,update
local declared={};for name in pairs(handles)do declared[name]=true end
local materials={};local material_number=0
function MakeMaterial(_,color)material_number=material_number+1;local name='overview-material-'..material_number;materials[name]=color;return name end
dofile(SCRIPT_ROOT..'MFD_RIGHT/rwr_page.lua')
local named={}
for _,e in ipairs(elements)do assert(not named[e.name],'duplicate Defensive native name');named[e.name]=e end
for _,e in ipairs(elements)do
 assert(not e.parent_element or named[e.parent_element],'unresolved Defensive native parent')
 if e.kind=='ceSMultiLine'then assert(e.material,'Defensive native line has no material')end
 for _,parameter in ipairs(e.element_params or {})do
  if parameter:find('F22_DEF_OV_',1,true)==1 then assert(declared[parameter],'overview parameter first declared after native binding: '..parameter)end
 end
end
local function put(k,v)get_param_handle(k):set(v)end
local function get(k)return get_param_handle(k):get()end
local function visible(e,seen)
 seen=seen or {};assert(not seen[e.name],'cyclic Defensive parent');seen[e.name]=true
 if e.parent_element and not visible(named[e.parent_element],seen)then return false end
 for _,c in ipairs(e.controllers or {})do
  local p=e.element_params and e.element_params[c[2]+1];local v=p and get(p)
  if c[1]=='parameter_in_range'and(v<c[3]or v>c[4])then return false end
  if c[1]=='opacity_using_parameter'and v<=0 then return false end
 end
 return true
end
local function text(label)
 for _,e in ipairs(elements)do if (e.value==label or e.formats and e.formats[1]==label)and visible(e)then return true end end
 return false
end
post_initialize();put('MAIN_POWER',1);put('MFD_OPACITY',1);put('F22_DEF_OV_VALID',1);put('F22_DEF_OV_TIME',100);put('F22_DEFENSIVE_DETAIL',0);mfd_update()
assert(get('F22_DEF_OV_CURRENT')==1 and visible(named.F22_COMPAT_DEF_OV__BACKGROUND))
assert(not text('DETAIL'),'retired hidden detail view returned')
-- Latest human mapping: positive friendly green, unknown yellow, explicit hostile red; cyan requires wing membership.
put('F22_DEF_OV_01_VALID',1);put('F22_DEF_OV_01_RANGED',1)
local function hue(c)
 if not c then return end
 if c[1]<80 and c[2]>150 and c[3]<100 then return 'green' end
 if c[1]<80 and c[2]>150 and c[3]>150 then return 'cyan' end
 if c[1]>150 and c[2]>150 and c[3]<100 then return 'yellow' end
 if c[1]>180 and c[2]<c[1]*.5 and c[3]<c[1]*.5 then return 'red' end
end
for _,case in ipairs({{1,'green'},{-1,'yellow'},{0,'red'}})do
 put('F22_DEF_OV_01_AFFILIATION',case[1]);local ink=0
 for _,e in ipairs(elements)do local c=materials[e.material]
  if e.kind=='ceSMultiLine'and hue(c)==case[2]and visible(e)then ink=ink+1 end
 end
 assert(ink>0,'explicit affiliation has no visible expected-color symbol')
end
put('F22_DEF_OV_01_AFFILIATION',-1);put('F22_DEF_OV_01_ALERT',1)
local red_alert=0;for _,e in ipairs(elements)do local c=materials[e.material];if e.kind=='ceSMultiLine'and hue(c)=='red'and visible(e)then red_alert=red_alert+1 end end
assert(red_alert>0,'fresh warning has no visible alert bracket')
now=100.251;mfd_update();assert(get('F22_DEF_OV_CURRENT')==0 and text('NO DATA'))
for _,e in ipairs(elements)do for _,p in ipairs(e.element_params or {})do if p=='F22_DEF_OV_01_VALID'then assert(not visible(e),'stalled overview retained its last threat glyph')end end end
now=99.9;mfd_update();assert(get('F22_DEF_OV_CURRENT')==0,'future overview timestamp was accepted')
now=100.1;put('MAIN_POWER',0);mfd_update();assert(get('F22_DEF_OV_CURRENT')==0)
put('MAIN_POWER',1);put('F22_DEF_OV_TIME',100.1);mfd_update();put('F22_DEFENSIVE_DETAIL',1)
assert(visible(named.F22_COMPAT_DEF_OV__BACKGROUND),'retired detail selector displaced unified overview')
put('F22_CM_DRAFT_DIRTY',1)
assert(not text('BANK %.0f')and not text('UNSAVED'),'programming leaked into normal DEF')
assert(not text('SIM ID STBY'),'ownship IFF state cluttered the defensive picture')
put('F22_DEF_DETAIL_RMFD',1)
assert(text('DEF SETUP')and text('BANK %.0f')and text('UNSAVED'))
for _,e in ipairs(elements)do for _,p in ipairs(e.element_params or {})do
 if p=='F22_DEF_OV_01_VALID'then assert(not visible(e),'setup retained the threat drawing underneath')end
end end
put('F22_DEF_DETAIL_RMFD',0)
assert(not text('DEF SETUP')and not text('UNSAVED'))
''')
print('Defensive native wrapper: construction bindings, exclusive formats, visible overview controls and independent MFD freshness PASS')

lua=runtime()
lua.execute(r'''
local now=100;function get_model_time()return now end
dofile(SCRIPT_ROOT..'Systems/RWR_System.lua');post_initialize();local rc,ru=SetCommand,update
dofile(SCRIPT_ROOT..'Systems/EW_System.lua');post_initialize();local ec=SetCommand
dofile(SCRIPT_ROOT..'Systems/MFD_System.lua');post_initialize();local mc,mu=SetCommand,update
local function get(k)return get_param_handle(k):get()end
local function put(k,v)get_param_handle(k):set(v)end
local events={}
function dispatch_action(d,c,v)
 events[#events+1]={d,c,v}
 if d==devices.RWR_SYSTEM then rc(c,v)elseif d==devices.EW_SYSTEM then ec(c,v)end
end
local function tick()ru();mu()end
local function edge(b,down)mc(10090+b,devices.MFD_SYSTEM+(down and .375 or .25))end
local function key(b)edge(b,true);edge(b,false);tick()end
put('MAIN_POWER',1);tick();assert(get('F22_DEFENSIVE_DETAIL')==0)
local active=0
for b=1,20 do if get('F22_MFD_RMFD_KEY_'..b)~=''then active=active+1 end end
assert(active==5,'normal DEF needs exactly five routine controls')
events={};key(20)
assert(#events==0 and get('F22_RWR_FILTER')==0,'blank DEF key changed focus or receiver state')
local edit_before=get('F22_CM_PROGRAM_SELECTED')
local normal_before=get('F22_CM_NORMAL_BANK')
key(1)
assert(get('F22_CM_NORMAL_BANK')==normal_before%3+1 and get('F22_CM_PROGRAM_SELECTED')==edit_before,
 'normal program selection required/mutated programming')
key(10);assert(get('F22_DEF_DETAIL_RMFD')==1 and get('F22_MFD_RMFD_KEY_12')=='RTN')
key(20);assert(get('F22_RWR_FILTER')==1,'setup filter missed receiver')
local before=get('F22_CM_PROGRAM_SELECTED');events={}
edge(1,true);edge(1,true);assert(get('F22_CM_PROGRAM_SELECTED')==before%3+1)
key(13);edge(1,false);edge(1,false)
local downs,ups=0,0
for _,e in ipairs(events)do if e[1]==devices.EW_SYSTEM and e[2]==10910 then
 if e[3]==1 then downs=downs+1 elseif e[3]==0 then ups=ups+1 end
end end
assert(downs==1 and ups==1,'page change lost/duplicated original CM release')
key(4);assert(get('F22_DEF_DETAIL_RMFD')==0)
key(10);key(1);assert(get('F22_CM_PROGRAM_SELECTED')==(before%3+1)%3+1)
key(12);assert(get('F22_DEF_DETAIL_RMFD')==0 and get('F22_MFD_RMFD_KEY_10')=='SETUP')
local controls=dofile(SCRIPT_ROOT..'Systems/Defensive_Controls.lua')
put('F22_CM_READY',1);put('F22_CM_MODE',3);put('F22_CM_AUTHORIZED',0)
assert(controls.for_page(0,get)[3].command==11111,'AUTO has no actionable consent control')
put('F22_CM_AUTHORIZED',1)
assert(controls.for_page(0,get)[3].command==11112)
put('F22_CM_PROGRAM_RUNNING',1)
assert(controls.for_page(0,get)[4].command==11113)
put('F22_CM_READY',0);assert(controls.for_page(0,get)[3]==nil)
-- An inactive key's physical down latch cannot become a new action when a
-- conditional STOP label appears underneath the still-held button.
put('F22_CM_MODE',1);put('F22_CM_PROGRAM_RUNNING',0);put('F22_CM_AWAITING_CONSENT',0);mu()
events={};edge(4,true);assert(#events==0)
put('F22_CM_PROGRAM_RUNNING',1);mu();edge(4,true)
assert(#events==0,'new STOP action inherited an earlier blank-key press')
edge(4,false);key(4)
local stop_down,stop_up=0,0
for _,e in ipairs(events)do if e[1]==devices.EW_SYSTEM and e[2]==11113 then
 if e[3]==1 then stop_down=stop_down+1 elseif e[3]==0 then stop_up=stop_up+1 end
end end
assert(stop_down==1 and stop_up==1)
''')
print('Actual DEF owners: five routine keys, inert blanks, direct normal selection, explicit setup, '
      'actionable consent/stop, repeated-down and captured release recovery PASS')
