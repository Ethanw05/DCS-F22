"""Physical UFC descriptors must permit same-option commit and repeated digits."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
fixture=ROOT/'tests/test_display_startup.py';ns={'__file__':str(fixture)}
exec(compile(fixture.read_text().split('\nfor page in ',1)[0],str(fixture),'exec'),ns)
for guided in (False,True):
    lua=ns['runtime']();lua.globals().guided=guided
    lua.execute(r'''
    package.preload.i_18n=function()return {translate=function(s)return s end}end
    class_type={BTN=1,TUMB=2,LEV=3,SW=4}
    dofile(SCRIPT_ROOT..'clickabledata.lua');local points=elements
    local now=10;function get_model_time()return now end
    function get_aircraft_property()return 1 end
    local native={get_station_info=function(_,i)return {count=i==4 and 8 or 0,
      CLSID=guided and'{GBU_32_V_2B}'or'{F22-MK83-TRAINING}',
      weapon={level1=4,level2=5,level3=guided and 36 or 9,level4=guided and 85 or 32}}end,
      select_station=function()end,get_chaff_count=function()return 120 end,get_flare_count=function()return 80 end}
    function GetDevice()return native end
    local function put(k,v)get_param_handle(k):set(v)end
    local function get(k)return get_param_handle(k):get()end
    dofile(SCRIPT_ROOT..'Systems/Weapon_System.lua');post_initialize();local wc,wu=SetCommand,update
    dofile(SCRIPT_ROOT..'Systems/ICP_System.lua');post_initialize();local ic,iu=SetCommand,update
    dofile(SCRIPT_ROOT..'Systems/MFD_System.lua');post_initialize();local mc,mu=SetCommand,update
    dofile(SCRIPT_ROOT..'Systems/PMFD_System.lua');post_initialize();local pc,pu=SetCommand,update
    function dispatch_action(d,c,v)
     if d==devices.WEAPON_SYSTEM then wc(c,v)
     elseif d==devices.ICP_SYSTEM then ic(c,v)
     elseif d==devices.MFD_SYSTEM then mc(c,v)end
    end
    local function tick()now=now+.02;wu();mu();pu();iu()end
    local function click(point)
     local e=assert(points[point]);local owner=e.device==devices.ICP_SYSTEM and ic or e.device==devices.PMFD_SYSTEM and pc or mc
     owner(e.action[1],e.device+.375);tick()
     if e.use_release_message[1]then owner(e.stop_action[1],e.device+.25)end
     tick()
    end
    local function option(n)click('ICP_OP'..n..'_PNT')end
    local function digits(s)for i=1,#s do click('ICP_'..s:sub(i,i)..'_PNT')end end
    put('MAIN_POWER',1);wc(10800,7);for i=1,20 do tick()end
    for _,panel in ipairs({{'CMFD','B_MFD_'},{'LMFD','L_MFD_'},{'RMFD','R_MFD_'},{'PMFD','PMFD_'}})do
     local name,stem=panel[1],panel[2]
     click(stem..'13_PNT');click(stem..'3_PNT');click(stem..'8_PNT')
     assert(get('F22_UFC_PAGE')=='STORES','Stores UFC button did not open numeric programming')
     option(1);digits('2');option(1)
     assert(get('F22_SMS_QUANTITY')==2 and get('F22_UFC_SELECTED')==0,'physical same-option QTY commit failed on '..name)
     assert(get('F22_UFC_ROW_1')=='QTY 2','accepted quantity not displayed')
     assert(get('F22_MFD_'..name..'_KEY_8')=='UFC','Stores still labels its keypad control HUD')
     option(2);digits('2');option(2)
     assert(get('F22_SMS_PAIR')==2 and get('F22_UFC_SELECTED')==0,'physical MULT commit failed')
     option(3);digits('500');option(3)
     local field=guided and'F22_SMS_INTERVAL_MS'or'F22_SMS_SPACING_FT'
     assert(get(field)==500 and get('F22_UFC_SELECTED')==0,'interval/spacing or repeated zero entry failed')
     option(1);digits('9');option(1)
     assert(get('F22_SMS_QUANTITY')==2 and get('F22_UFC_SELECTED')==1,'invalid quantity was accepted or erased')
     click('ICP_CLR_PNT');digits('4');option(1)
     assert(get('F22_SMS_QUANTITY')==4 and get('F22_UFC_SELECTED')==0,'corrected quantity did not commit')
     click(stem..'8_PNT');assert(get('F22_UFC_PAGE')=='','same Stores UFC key could not close its page')
    end
    -- AP has two mouse actions; both must also release their transport latch.
    for _,e in pairs(points)do
     if e.device==devices.ICP_SYSTEM and e.class[1]==class_type.BTN then
      for button,kind in ipairs(e.class)do
       if kind==class_type.BTN then assert(e.use_release_message[button],'UFC pushbutton has no release')end
      end
     end
    end
    ''')
print('Physical Stores -> UFC -> Weapon path: QTY/MULT/interval same-option commit, repeated zeros, validation/correction and page reopening across 4 screens x guided/unguided stores PASS')
