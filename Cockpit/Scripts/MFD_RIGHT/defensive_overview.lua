return function(page_parameter,prefix,detail_parameter)
-- GPL-3.0-or-later. Museum-photo layout; measured/source-aware mod data.
local D=dofile(LockOn_Options.script_path..'MFD_COMMON/lcd.lua')(page_parameter,prefix)
local physical=GetScale()
D.materials.blue=MakeMaterial(nil,{12,46,185,255})
D.materials.cyan=MakeMaterial(nil,{0,255,255,255})
D.materials.red=MakeMaterial(nil,{255,78,78,255})
D.fonts.cyan="F22_LCD_FONT_TEAL"
local seq=0
local function group(params,controllers,parent,x,y)
 local e=CreateElement('ceSimple');local converted={}
 for _,row in ipairs(controllers)do
  local c={};for i,v in ipairs(row)do c[i]=v end
  if c[1]=='move_left_right_using_parameter'or c[1]=='move_up_down_using_parameter'then c[3]=c[3]*physical*D.scale end
  converted[#converted+1]=c
 end
 e.element_params=params;e.controllers=converted;e.init_pos={(x or 0)*D.scale,(y or 0)*D.scale,0}
 return D.add(e,parent or D.root)
end
local function line(x,y,u,v,color,parent,width)
 local e=CreateElement('ceSMultiLine');e.material=D.materials[color or 'blue']
 e.vertices={{x*D.scale,y*D.scale},{u*D.scale,v*D.scale}};e.indices={0,1};e.thickness=width or .8;e.fuzziness=.2
 return D.add(e,parent or D.root)
end
local function circle(x,y,r,color,parent,width)
 local vertices,indices={},{}
 for i=0,72 do
  local a=i*math.pi/36;vertices[#vertices+1]={(x+r*math.sin(a))*D.scale,(y+r*math.cos(a))*D.scale}
  if i<72 then indices[#indices+1]=i;indices[#indices+1]=i+1 end
 end
 local e=CreateElement('ceSMultiLine');e.material=D.materials[color or 'blue'];e.vertices=vertices;e.indices=indices
 e.thickness=width or .8;e.fuzziness=.2;D.add(e,parent or D.root)
end
local cy=.045
-- Two fine blue rings and the compact central aircraft follow the public photo.
circle(0,cy,.84,'blue');circle(0,cy,.40,'blue')
for deg=0,330,30 do
 local a=math.rad(deg);line(.84*math.sin(a),cy+.84*math.cos(a),.87*math.sin(a),cy+.87*math.cos(a),'blue')
end
line(0,cy+.84,0,cy+.89,'white')
-- Reuse the FCS aircraft's actual contour, without its control labels. Batched
-- vector paths keep the small F-22 silhouette crisp on the native LCD.
local ownship=CreateElement('ceSMultiLine');local vertices,indices={},{}
for _,path in ipairs(dofile(LockOn_Options.script_path..'MFD_COMMON/f22_outline.lua'))do
 local first=#vertices
 for i,p in ipairs(path)do
  vertices[#vertices+1]={p[1]*.16*D.scale,(cy+p[2]*.16)*D.scale}
  if i>1 then indices[#indices+1]=first+i-2;indices[#indices+1]=first+i-1 end
 end
end
ownship.vertices=vertices;ownship.indices=indices;ownship.material=D.materials.white
ownship.thickness=1.15;ownship.fuzziness=.2;D.add(ownship,D.root,'OWNSHIP_F22')
local current=D.choice('F22_DEF_OV_CURRENT',1)
local ranged=D.choice('F22_DEF_OV_RANGE_VALID',1,current)
D.text('%.0f NM',.42,.88,'F22_DEF_OV_RANGE_NM','white',.0034,ranged)
D.text('REL RF',-.48,.88,nil,'blue',.0028,group({'F22_DEF_OV_PROXIMITY_COUNT'},{{'parameter_in_range',0,.5,16.5}},current))
D.text('PRI',.42,.88,nil,'white',.0034,D.choice('F22_DEF_OV_RANGE_VALID',0,current))
D.text('NO DATA',0,.84,nil,'yellow',.0034,D.choice('F22_DEF_OV_CURRENT',0))
D.text('RF OFF',0,.84,nil,'white',.0030,D.choice('F22_RWR_POWER',0,current))
D.text('MUTE',.65,.84,nil,'yellow',.0028,D.choice('F22_RWR_MUTE',1,current))

for i=1,16 do
 local p=string.format('F22_DEF_OV_%02d_',i)
 local at=group({p..'X',p..'Y',p..'VALID'},{{'move_left_right_using_parameter',0,1},{'move_up_down_using_parameter',1,1},{'parameter_in_range',2,.9,1.1}},current,0,cy)
 local bearing=group({p..'ROT'},{{'rotate_using_parameter',0,1}},at)
 for _,aff in ipairs({{-1,'yellow'},{0,'red'},{1,'green'},{3,'cyan'}})do
  local colored=D.choice(p..'AFFILIATION',aff[1],bearing)
  -- A bearing stem does not assert target heading. Open outer-ring ticks have
  -- no measured range; measured contacts use the common track's radar range.
  local measured=D.choice(p..'RANGED',1,colored)
  circle(0,0,.018,aff[2],measured,1.2)
  line(0,.018,0,.095,aff[2],measured,1.2)
  line(-.020,.064,0,.037,aff[2],measured,1.2);line(.020,.064,0,.037,aff[2],measured,1.2)
  local prox=D.choice(p..'PROXIMITY',1,colored)
  circle(0,0,.018,aff[2],prox,1.2)
  line(0,.018,0,.065,aff[2],prox,1.2)
  local passive=D.choice(p..'PROXIMITY',0,D.choice(p..'GEO',0,D.choice(p..'RANGED',0,colored)))
  line(-.030,0,.030,0,aff[2],passive,1.2)
  line(0,0,0,-.085,aff[2],passive,1.2)
  line(-.020,-.052,0,-.080,aff[2],passive,1.2);line(.020,-.052,0,-.080,aff[2],passive,1.2)
  -- An open diamond with E is a conditional RF location, never radar range.
  local estimate=D.choice(p..'GEO',1,colored)
  line(0,.03,.03,0,aff[2],estimate,1.2);line(.03,0,0,-.03,aff[2],estimate,1.2)
  line(0,-.03,-.03,0,aff[2],estimate,1.2);line(-.03,0,0,.03,aff[2],estimate,1.2)
  D.text('E',.05,0,nil,aff[2],.0026,estimate)
 end
 local alert=D.choice(p..'ALERT',1,at)
 line(-.046,-.035,-.046,.035,'red',alert,1.2);line(.046,-.035,.046,.035,'red',alert,1.2)
 local selected=D.choice(p..'SELECTED',1,at)
 for _,side in ipairs({-1,1})do
  line(side*.06,-.05,side*.06,.05,'white',selected,1)
  line(side*.06,.05,side*.04,.05,'white',selected,1)
  line(side*.06,-.05,side*.04,-.05,'white',selected,1)
 end
 D.text('M',.06,-.05,nil,'white',.0026,D.choice(p..'OPTICAL',1,at))
 D.text('C',-.06,-.05,nil,'white',.0026,D.choice(p..'COAST',1,at))
 for link,label in ipairs({'IFDL','L16'})do D.text(label,.08,.025,nil,'white',.0025,D.choice(p..'DATALINK',link,at))end
end

-- Compact expendable readbacks occupy the same lower-right region as the photo.
local counts=D.choice('F22_EW_BACKEND_READY',1)
D.text('CHAFF %.0f',.63,-.61,'F22_CHAFF_COUNT','white',.0032,counts)
D.text('FLARE %.0f',.63,-.69,'F22_FLARE_COUNT','white',.0032,counts)
D.text('CHAFF --',.63,-.61,nil,'white',.0032,D.choice('F22_EW_BACKEND_READY',0))
D.text('FLARE --',.63,-.69,nil,'white',.0032,D.choice('F22_EW_BACKEND_READY',0))
-- Draft values follow the five edit keys. Execution uses only saved banks.
for _,item in ipairs({{'EDIT %.0f',-.66,'SELECTED'},{'C %.0f',-.33,'CHAFF'},
 {'F %.0f',0,'FLARE'},{'%.2fS',.33,'INTERVAL'},{'CYC %.0f',.66,'CYCLES'}})do
 D.text(item[1],item[2],-.84,'F22_CM_PROGRAM_'..item[3],'white',.0032)
end
D.text('UNSAVED',-.48,-.75,nil,'yellow',.0028,D.choice('F22_CM_DRAFT_DIRTY',1))
D.text('INVALID DRAFT',-.48,-.68,nil,'yellow',.0028,D.choice('F22_CM_DRAFT_ERROR',1))
D.text('NORMAL %.0f',-.45,-.60,'F22_CM_NORMAL_BANK','white',.0028)
D.text('DIRECT %.0f',-.12,-.60,'F22_CM_DIRECT_BANK','white',.0028)
D.text('RUN %.0f',.18,-.60,'F22_CM_RUNNING_BANK','white',.0028)
for mode,label in ipairs({'MAN','SEMI','AUTO'})do
 D.text(label,.63,-.38,nil,'white',.0028,D.choice('F22_CM_MODE',mode))
end
for state,label in pairs({[0]='CM OFF',[1]='CM STBY',[2]='CM ON'})do
 D.text(label,.63,-.45,nil,'white',.0028,D.choice('F22_CM_SYSTEM',state))
end
D.text('CM TEST',.63,-.52,nil,'yellow',.0028,D.choice('F22_CM_SELF_TEST',1))
D.text('CM FAIL',.63,-.52,nil,'yellow',.0028,D.choice('F22_CM_FAILURE',1))
D.text('CM LOW',.63,-.31,nil,'yellow',.0028,D.choice('F22_CM_LOW',1))
D.text('CONSENT?',-.48,-.52,nil,'yellow',.0028,D.choice('F22_CM_AWAITING_CONSENT',1))
D.text('AUTO AUTH',-.12,-.52,nil,'yellow',.0028,D.choice('F22_CM_AUTHORIZED',1))
local cm=dofile(LockOn_Options.script_path..'Systems/EW_Dispenser.lua')
for status,label in pairs(cm.labels)do
 D.text(label,.18,-.68,nil,'white',.0028,D.choice('F22_CM_STATUS',status))
end

end
