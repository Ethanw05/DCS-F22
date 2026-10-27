"""Actual NAV/MFD/ICP owners: DATA inspection, explicit UFC commits and isolation."""
from pathlib import Path

root=Path(__file__).resolve().parents[1]
fixture=root/'tests/test_display_startup.py'
ns={'__file__':str(fixture)}
exec(compile(fixture.read_text().split('\nfor page in ',1)[0],str(fixture),'exec'),ns)
lua=ns['runtime']()
lua.execute(r'''
local now=10
function get_model_time()return now end
function get_aircraft_property()return 1 end
function get_aircraft_draw_argument_value(n)return draws[n]or 0 end
function set_aircraft_draw_argument_value(n,v)draws[n]=v end
function get_mission_route()return {{x=0,y=0,alt=3000},{x=18520,y=3704,alt=3000,name='INGRESS'},{x=37040,y=18520,alt=3000,name='TARGET'}}end
package.preload.terrain=function()return {
 GetHeight=function()return 0 end,
 convertMetersToLatLon=function(n,e)return 41+n/100000,42+e/100000 end,
 convertLatLonToMeters=function(lat,lon)return(lat-41)*100000,(lon-42)*100000 end}end
local function p(k,v)get_param_handle(k):set(v)end
local function g(k)return get_param_handle(k):get()end
p('MAIN_POWER',1);p('F22_AP_CLOCK',now)
dofile(SCRIPT_ROOT..'Systems/Navigation_System.lua');post_initialize();local nav_command,nav_update=SetCommand,update
dofile(SCRIPT_ROOT..'Systems/Flight_Guidance.lua');post_initialize();local guidance_command,guidance_update=SetCommand,update
dofile(SCRIPT_ROOT..'Systems/MFD_System.lua');post_initialize();local mfd_command,mfd_update=SetCommand,update
dofile(SCRIPT_ROOT..'Systems/ICP_System.lua');post_initialize();local icp_command,icp_update=SetCommand,update
local sent={}
function dispatch_action(device,command,value)
 sent[#sent+1]={device,command,value}
 if device==devices.NAV_SYSTEM then nav_command(command,value)
 elseif device==devices.FLIGHT_GUIDANCE then guidance_command(command,value)
 elseif device==devices.ICP_SYSTEM then icp_command(command,value)end
end
local function tick()
 now=now+.05;p('F22_AP_CLOCK',now);guidance_update()
 -- Declared receiver observations for this DATA/entry fixture.
 p('F22_TCN_MODE',2);p('F22_TCN_BRG_VALID',1);p('F22_TCN_BRG_MAG',.5)
 p('F22_TCN_RANGE_VALID',1);p('F22_TCN_RANGE_M',12345)
 nav_update();mfd_update();icp_update()
end
local function bezel(n)mfd_command(10110+n,devices.MFD_SYSTEM+.375);mfd_command(10110+n,devices.MFD_SYSTEM+.25)end
local function key(n)icp_command(n,devices.ICP_SYSTEM+.375);icp_command(n,devices.ICP_SYSTEM+.25)end
local function digits(s)for d in s:gmatch('.')do d=tonumber(d);key(d==0 and 3027 or 3016+d)end end
p('MAIN_POWER',1);p('MFD_OPACITY',1);p('HUD_MODE',7);p('HUD_GS_VALID',1);p('HUD_GS_MPS',200)
p('F22_MAG_VALID',1);p('F22_MAG_DECL',.1);p('F22_TCN_BRG_VALID',1);p('F22_TCN_BRG_MAG',.5)
p('F22_TCN_RANGE_VALID',1);p('F22_TCN_RANGE_M',12345)
p('EFM_HUD_VALID',1);p('EFM_HUD_VN',200)
mfd_command(10823,1);tick()
assert(g('CMFD_HSI_PAGE')==1 and g('CMFD_HSI_PAGE_DATA')==0 and g('HUD_WP_INDEX')==2)
bezel(11);tick();assert(g('CMFD_HSI_PAGE_DATA')==1 and g('F22_NAV_SOURCE')==0)
bezel(6);tick();assert(g('ICP_NAV_MENU')==1 and g('HUD_MODE')==7,'DATA UFC changed the master mode')
local old_lat,old_lon=g('F22_NAV_FIX_LAT'),g('F22_NAV_FIX_LON')
key(3009);digits('4160000');key(3009);tick()
assert(g('F22_NAV_FIX_LAT')==old_lat and g('F22_UFC_ROW_2'):find('MIN 00-59.999',1,true),'invalid minutes changed the point or lost their corrective cue')
-- Choosing a different field abandons the draft; no implicit save.
key(3010);digits('04230123');key(3010);tick()
assert(g('ICP_NAV_MENU')==1 and g('F22_NAV_FIX_LAT')==old_lat)
assert(math.abs(g('F22_NAV_FIX_LON')-(42+30.123/60))<1e-8)
key(3009);digits('4130123');tick();assert(g('F22_NAV_FIX_LAT')==old_lat,'typing committed without ENTER')
key(3009);tick()
assert(math.abs(g('F22_NAV_FIX_LAT')-(41+30.123/60))<1e-8 and g('ICP_NAV_MENU')==1)
assert(g('F22_NAV_FIX_LAT_TEXT'):find('30.123',1,true))
digits('4159999');bezel(20);tick()
assert(g('HUD_WP_INDEX')==3 and g('ICP_NAV_MENU')==1 and g('F22_UFC_SELECTED')==0,'point change retained an old edit context')
-- Radio DATA is independent of active waypoint steering and uses radio data.
bezel(3);bezel(6);tick()
assert(g('CMFD_HSI_PAGE_DATA')==2 and g('F22_UFC_PAGE')=='NAV' and g('F22_NAV_SOURCE')==0)
key(3008);digits('16');key(3008);tick()
assert(g('F22_TCN_CHANNEL')==16 and g('HUD_MODE')==7)
assert(g('F22_NAV_TCN_DIST_TEXT')=='DME 6.7NM' and g('F22_NAV_TCN_BRG_TEXT')=='BRG 034T','TCN DATA borrowed waypoint bearing/range')
bezel(4);bezel(6);tick();assert(g('CMFD_HSI_PAGE_DATA')==3 and g('F22_UFC_PAGE')=='NAV')
key(3009);digits('11030');key(3009);tick()
assert(g('F22_ILS_FREQ_KHZ')==110300)
bezel(12);tick();assert(g('CMFD_HSI_PAGE_DATA')==0)
p('MAIN_POWER',0);tick();assert(g('ICP_CNI_MENU')==0 and g('CMFD_HSI_PAGE_DATA')==0)
for _,e in ipairs(sent)do assert(e[2]~=Keys.PlaneModeNAV and e[2]~=84 and e[2]~=350,'data inspection/editing issued a master-mode/fire command')end
''')
print('Actual NAV DATA -> WYPT/TCN/ILS -> UFC: explicit commits, invalid drafts, point changes, independent radio data and power PASS')
