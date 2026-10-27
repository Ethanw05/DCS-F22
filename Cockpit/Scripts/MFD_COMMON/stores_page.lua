-- GPL-3.0-or-later. F-22 bay synoptic with contextual store employment controls.
-- Layout evidence and deliberate adaptations: docs/resources/research/OVERHAUL_UI_HANDOFF.md.
return function(page_parameter,prefix,ui_parameter)
ui_parameter=ui_parameter or'F22_SMS_UI_PAGE'
local D=dofile(LockOn_Options.script_path..'MFD_COMMON/lcd.lua')(page_parameter,prefix)
local caps=dofile(LockOn_Options.script_path..'Systems/Store_Capabilities.lua')
local function text(v,x,y,p,c,s,g)return D.text(v,x,y,p,c,s,g)end
local function choice(v,x,y,p,code,c,s,g)return text(v,x,y,nil,c,s,D.choice(p,code,g))end
local strike=D.choice('F22_SMS_AA_CONTEXT',0)
local aa=D.choice('F22_SMS_AA_CONTEXT',1)
local aa_home=D.choice(ui_parameter,0,aa)
local class_keys=D.group(ui_parameter,-.1,1.1,strike)
local nongun=D.group('HUD_AG_SUBMODE',1.1,3.1,strike)
local normal=D.group(ui_parameter,-.1,1.1,nongun)
local home=D.choice(ui_parameter,0,nongun)
local program=D.choice(ui_parameter,1,nongun)
local gun=D.choice('HUD_AG_SUBMODE',1,class_keys)
local doors=D.choice(ui_parameter,2)
local mode=D.choice(ui_parameter,4,strike)
local coordinates=D.choice(ui_parameter,3,nongun)

-- Original front-view bays, not the separate FCS planform.
D.texture('bay_frame.dds',0,-.03,1.9)
for _,bay in ipairs({'L','C','R'})do
 D.texture('bay_'..bay..'.dds',0,-.03,1.9,D.group('BAY_'..bay..'_ARG',-.1,.01))
 D.texture('bay_'..bay..'_open.dds',0,-.03,1.9,D.group('BAY_'..bay..'_ARG',.01,1.1))
end
text('STORES',0,.81,nil,'blue',.0048)
choice('A/G',.32,.81,'HUD_MODE',7,'green',.004)
choice('NAV',.32,.81,'HUD_MODE',1,'blue',.004)
text('A/A',.32,.81,nil,'green',.004,aa)
choice('WPN UNAVAIL',0,-.80,'F22_WEAPON_SUPPORTED',0,'yellow',.0030,aa)
choice('MASTER SAFE',0,.70,'ARM_STATUS',0,'blue',.0033)
choice('MASTER ARM',0,.70,'ARM_STATUS',1,'green',.0033)
choice('GROUND SAFE',0,.70,'ARM_STATUS',2,'yellow',.0033)
choice('SIM',.58,.70,'F22_SMS_SIM',1,'yellow',.0033)
text('RPM',0,.62,nil,'blue',.0031)
text('%.0f',-.46,.64,'RPM_L','green',.0048)
text('%.0f',.46,.64,'RPM_R','green',.0048)
for code,label in ipairs(caps.labels)do choice(label,0,.51,'F22_SMS_LABEL',code,'green',.0045,nongun)end
choice('NO A/G STORE',0,.51,'F22_SMS_LABEL',0,'blue',.004,nongun)
text('CANNON 20 MM',0,.51,nil,'green',.0045,D.choice('HUD_AG_SUBMODE',1,strike))
text('%s',0,.51,'F22_WEAPON_NAME','green',.0045,aa)
D.box(0,.51,.79,.09,'green')
-- Only the current delivery mode appears in the normal format.
for code,label in ipairs({'GUN','CCIP','AUTO'})do choice(label,0,.35,'HUD_AG_SUBMODE',code,'green',.0043,strike)end
text('LOAD %.0f',0,.35,'F22_WEAPON_COUNT','white',.0043,D.group('F22_WEAPON_KIND',-.1,4.9,aa))
local aa_gun=D.choice('F22_WEAPON_KIND',5,aa)
text('ROUNDS %.0f',0,.35,'F22_GUN_AMMO_COUNT','green',.0043,D.choice('F22_GUN_AMMO_VALID',1,aa_gun))
text('ROUNDS --',0,.35,nil,'blue',.0043,D.choice('F22_GUN_AMMO_VALID',0,aa_gun))
text('ROUNDS %.0f',0,-.43,'F22_GUN_AMMO_COUNT','green',.0035,D.choice('F22_GUN_AMMO_VALID',1,gun))
text('ROUNDS --',0,-.43,nil,'blue',.0035,D.choice('F22_GUN_AMMO_VALID',0,gun))

-- Native stations: side 0/10, main 2/3/4/6/7/8, external 1/9, center 5.
local stations={{0,-.287,.035,-.48,.045},{10,.287,.035,.48,.045},
 {2,-.262,-.155,-.262,-.245},{3,-.166,-.155,-.166,-.245},{4,-.070,-.155,-.070,-.245},
 {6,.070,-.155,.070,-.245},{7,.166,-.155,.166,-.245},{8,.262,-.155,.262,-.245},
 {1,-.64,.10,-.64,-.01},{9,.64,.10,.64,-.01},{5,0,.07,0,.005}}
for _,station in ipairs(stations)do
 local index,x,y,lx,ly=unpack(station);local p=string.format('F22_SMS_STATION_%02d_',index)
 -- Alternate main-bay captions across two rows instead of compressing six
 -- weapon names into one line at cockpit-sized resolutions.
 if index==3 or index==6 or index==8 then ly=ly-.075 end
 local present=D.choice(p..'PRESENT',1)
 text('%.0f',x,y,p..'COUNT','white',.0030,present)
 for code,label in ipairs(caps.short_labels)do choice(label,lx,ly,p..'LABEL',code,'white',.0025,present)end
 local selected=D.choice(p..'SELECTED',1,D.group('HUD_AG_SUBMODE',1.1,3.1,present));D.box(x,y,.074,.071,'green',selected)
 D.box(x,y,.09,.09,'blue',D.choice(p..'ACTIVE',1,program))
 text('T',lx,ly-.05,nil,'blue',.0025,D.choice(ui_parameter,1,D.choice(p..'TARGET_VALID',1,present)))
end

-- Retained program readback stays visible while the UFC owns numeric entry.
text('PROG %.0f',0,-.43,'F22_SMS_PROFILE','green',.0035,normal)
local noentry=D.choice('F22_SMS_ENTRY_FIELD',0,normal)
text('STN %.0f',0,-.59,'F22_SMS_TARGET_STATION_DISPLAY','blue',.0032,D.choice(ui_parameter,1,noentry))
text('PP %.0f',.56,-.59,'F22_SMS_MISSION_SLOT','blue',.0028,D.choice(ui_parameter,1,noentry))
choice('NO TARGET',0,-.68,'F22_SMS_TARGET_VALID',0,'blue',.0032,D.choice(ui_parameter,1,noentry))
choice('LIVE DESIGNATION',0,-.68,'F22_SMS_TARGET_SOURCE',1,'blue',.0032,D.choice(ui_parameter,1,noentry))
choice('STORED COORDINATE',0,-.68,'F22_SMS_TARGET_SOURCE',2,'green',.0032,D.choice(ui_parameter,1,noentry))
text('LOCAL WORLD  NEU  METRES',0,-.43,nil,'blue',.0032,coordinates)
text('N %.0f M',0,-.51,'F22_SMS_TARGET_N','white',.0032,coordinates)
text('E %.0f M',0,-.59,'F22_SMS_TARGET_E','white',.0032,coordinates)
text('ELEV %.0f M',0,-.67,'F22_SMS_TARGET_U','white',.0032,coordinates)
choice('NO TARGET',0,-.76,'F22_SMS_TARGET_VALID',0,'yellow',.0030,coordinates)

-- Employment cues remain on Attack/HUD. Stores shows only actionable status.
for code,label in pairs({[1]='RELEASING',[3]='CHECK PROGRAM',[4]='MODE UNAVAILABLE',[6]='RELEASE PENDING',[7]='RELEASE UNCONFIRMED',[8]='WPN UNAVAIL',[9]='CHECK PROGRAM'})do
 choice(label,0,-.80,'F22_SMS_STATUS',code,(code==7 or code==8)and 'yellow' or 'green',.0030,noentry)
end

-- Alternatives appear only in the explicit MODE sublevel.
text('DELIVERY MODE',0,-.43,nil,'blue',.0038,mode)

text('BAY DOORS',0,-.43,nil,'blue',.0038,doors)
for i,bay in ipairs({'L','C','R'})do
 local x=(i-2)*.42;local param='BAY_'..bay..'_ARG'
 text(({L='LEFT',C='MAIN',R='RIGHT'})[bay],x,-.55,nil,'blue',.0032,doors)
 text('CLOSED',x,-.64,nil,'green',.0031,D.group(param,-.1,.01,doors))
 text('TRANSIT',x,-.64,nil,'yellow',.0031,D.group(param,.01,.99,doors))
 text('OPEN',x,-.64,nil,'green',.0031,D.group(param,.99,1.1,doors))
end
text('GROUND OVERRIDE OPEN',0,-.85,nil,'yellow',.0028,D.choice('GROUND_ORIDE',1,doors))


end
