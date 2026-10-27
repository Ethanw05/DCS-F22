"""Real weapon/radio/altimeter owners behind the shared UFC transaction."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
fixture=ROOT/'tests/test_display_startup.py';ns={'__file__':str(fixture)}
exec(compile(fixture.read_text().split('\nfor page in ',1)[0],str(fixture),'exec'),ns)
lua=ns['runtime']()
lua.execute(r'''
local original_param=get_param_handle
function get_param_handle(k)
 local h=original_param(k)
 if not h.native_number then h.native_number=true;local old=h.set;h.set=function(self,v)old(self,type(v)=='string'and tonumber(v)or v)end end
 return h
end
local now=10
function get_model_time()return now end
function get_aircraft_property()return 1 end
function get_base_data()return setmetatable({getSelfCoordinates=function()return 0,3000,0 end,getRadarAltitude=function()return 1200 end},
 {__index=function()return function()return 0 end end})end
local native={get_station_info=function(_,i)return {count=i==4 and 8 or 0,CLSID='{F22-MK83-TRAINING}',weapon={level1=4,level2=5,level3=9,level4=32}}end,
 select_station=function()end,get_chaff_count=function()return 120 end,get_flare_count=function()return 120 end}
function GetDevice()return native end
local function put(k,v)get_param_handle(k):set(v)end
local function get(k)return get_param_handle(k):get()end
dofile(SCRIPT_ROOT..'Systems/Weapon_System.lua');post_initialize();local wc,wu=SetCommand,update
dofile(SCRIPT_ROOT..'Systems/Flight_Guidance.lua');post_initialize();local fc,fu=SetCommand,update
dofile(SCRIPT_ROOT..'Systems/Altitude_System.lua');post_initialize();local ac,au=SetCommand,update
dofile(SCRIPT_ROOT..'Systems/ICP_System.lua');post_initialize();local ic,iu=SetCommand,update
local events={}
function dispatch_action(d,c,v)
 events[#events+1]={d=d,c=c,v=v}
 if d==devices.WEAPON_SYSTEM then wc(c,v)elseif d==devices.FLIGHT_GUIDANCE then fc(c,v)elseif d==devices.ALTITUDE_SYSTEM then ac(c,v)end
end
local function tick()now=now+.02;wu();fu();au();iu()end
local function key(c)ic(c,devices.ICP_SYSTEM+.375);ic(c,devices.ICP_SYSTEM+.25);tick()end
local function digits(s)for i=1,#s do local n=tonumber(s:sub(i,i));key(n==0 and 3027 or 3016+n)end end
put('MAIN_POWER',1);put('F22_SMS_PROGRAM_PAGE',1);put('HUD_MODE',1)
wc(10800,1);for i=1,20 do tick()end
-- Quantity is entered above keys and never commits on the first option press.
key(10989);key(3008);digits('02')
assert(get('F22_UFC_SCRATCH')=='02_'and get('F22_SMS_QUANTITY')==1)
assert(get('F22_UFC_ROW_1')=='QTY 1','draft replaced accepted option readback')
key(3028);assert(get('F22_UFC_SCRATCH')=='0_','UNDO is not a one-character backspace')
key(3026);assert(get('F22_UFC_SCRATCH')=='_'and get('F22_UFC_SELECTED')==1,'CLR exited or failed to clear')
digits('2');key(3008);tick();assert(get('F22_SMS_QUANTITY')==2 and get('F22_UFC_SELECTED')==0)
-- Option 5 is not a generic Enter key. Same-option commit works for interval.
key(3010);digits('500');key(3012);assert(get('F22_SMS_SPACING_FT')~=500)
key(3010);tick();assert(get('F22_SMS_SPACING_FT')==500)
-- Invalid quantity leaves the accepted program and draft intact for correction.
key(3008);digits('9');key(3008);tick()
assert(get('F22_SMS_QUANTITY')==2 and get('F22_UFC_SCRATCH')=='9_')
assert(get('F22_UFC_ROW_1'):find('!',1,true),'backend rejection is invisible')
key(3026);digits('4');key(3008);tick();assert(get('F22_SMS_QUANTITY')==4)
-- NAV tuning is independent from aircraft master mode and uses own option.
wc(10800,7);tick();key(3003);key(3008);digits('016');events={};key(3008)
assert(get('F22_TCN_CHANNEL')==16 and get('HUD_MODE')==7)
for _,e in ipairs(events)do assert(e.c~=Keys.PlaneModeNAV,'tuning changed master mode')end
key(3009);digits('11030');key(3009);assert(get('F22_ILS_FREQ_KHZ')==110300)
key(3010);digits('126');key(3010);assert(get('F22_NAV_COURSE')==126 and get('F22_NAV_OBS')==0,'course entry silently enabled OBS')
-- ALT affects altimetry only. CLR and UNDO have the same meanings here.
key(3005);key(3008);digits('2992');key(3028);assert(get('F22_UFC_SCRATCH')=='299_')
key(3026);digits('3000');events={};key(3008);tick()
assert(math.abs(get('F22_ALT_PRESSURE_MMHG')-762)<.01)
for _,e in ipairs(events)do assert(e.d~=devices.FLIGHT_GUIDANCE,'ALT entry commanded AP')end
-- Page changes discard unsubmitted input. Empty UNDO cannot close a page.
key(3008);digits('299');key(3026);key(3028);assert(get('F22_UFC_PAGE')=='ALT')
key(3003);assert(get('F22_UFC_SELECTED')==0 and get('F22_UFC_PAGE')=='NAV')
-- Down-only legacy aliases can be pressed repeatedly; brake IDs cannot open pages.
ic(10043,1);ic(10043,1);assert(get('F22_UFC_PAGE')=='NAV')
key(10056);key(10057);assert(get('F22_UFC_PAGE')=='NAV','brake commands changed UFC page')
key(11401);assert(get('F22_UFC_PAGE')=='IFF')
-- Opening AP does nothing to flight controls; its modes are explicit actions.
events={};key(3015)
for _,e in ipairs(events)do assert(e.d~=devices.FLIGHT_GUIDANCE,'opening AP engaged automation')end
assert(get('F22_UFC_ROW_1')=='ATTH'and get('F22_UFC_ROW_5')=='NAV CPL')
events={};key(3010)
local guidance={};for _,e in ipairs(events)do if e.d==devices.FLIGHT_GUIDANCE then guidance[#guidance+1]=e end end
assert(guidance[1].c==11011 and math.abs(guidance[1].v-9842.519685)<.01 and guidance[2].c==10950,'BALT did not capture current height before engaging')
events={};key(3035);assert(events[1].c==10953,'explicit AP/AT disconnect missing')
-- STPT uses the same transaction and retains leading zeros in the scratchpad.
put('HUD_WP_INDEX',2);put('F22_NAV_FIX_LAT',41.5);put('F22_NAV_FIX_LON',42.5);put('F22_NAV_FIX_ALT_FT',10000);put('F22_NAV_FIX_GEO_VALID',1)
key(3004);key(3009);digits('4130000');assert(get('F22_UFC_SCRATCH')=='4130000_')
assert(get('F22_UFC_ROW_2'):find('41',1,true));key(3009);assert(get('F22_UFC_SELECTED')==0)
-- Actual indicator binds typed digits to the left scratchpad aperture only.
dofile(SCRIPT_ROOT..'ICP/page_1.lua')
local scratch,rows=0,0
for _,e in ipairs(elements)do
 if e.name=='F22_UFC_SCRATCH'then scratch=scratch+1;assert(e.init_pos[1]<-1.6 and math.abs(e.init_pos[2]-1.2)<.01)end
 if e.name:match('^F22_UFC_ROW_%d$')then rows=rows+1;assert(e.init_pos[1]>-1.6)end
end
assert(scratch==1 and rows==5,'duplicated/missing UFC entry displays')
put('MAIN_POWER',0);iu();assert(get('F22_UFC_VISIBLE')==0 and get('F22_UFC_SELECTED')==0)
''')
print('Universal UFC: real Stores, same-option commit, CLR/UNDO, NAV/ILS, ALT isolation, AP capture and scratchpad binding PASS')
