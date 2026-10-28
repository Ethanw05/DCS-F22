return function(page_parameter,prefix,detail_parameter)
-- GPL-3.0-or-later. Museum-photo layout; measured/source-aware mod data.
local D=dofile(LockOn_Options.script_path..'MFD_COMMON/lcd.lua')(page_parameter,prefix)
local physical=GetScale()
D.materials.blue=MakeMaterial(nil,{12,46,185,255})
D.materials.cyan=MakeMaterial(nil,{0,255,255,255})
D.materials.red=MakeMaterial(nil,{255,78,78,255})
D.fonts.cyan="F22_LCD_FONT_TEAL"
local page_root=D.root
local view=detail_parameter or 'F22_DEF_DETAIL_RMFD'
local primary=D.choice(view,0,page_root)
local setup=D.choice(view,1,page_root)
D.root=primary
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
local ecm_api={group=function(_,params,controllers,parent)return group(params,controllers,parent)end,
 line=line,text=function(value,x,y,param,color,parent,size)return D.text(value,x,y,param,color,size,parent)end}
local coverage=dofile(LockOn_Options.script_path..'Systems/ECM_Coverage_Indicator.lua')
local contact_label=dofile(LockOn_Options.script_path..'Systems/Contact_Label_Indicator.lua')
dofile(LockOn_Options.script_path..'Systems/ECM_Indicator.lua')(
 ecm_api,.63,-.43,primary,prefix..'_OWN_ECM',.0032)
local function circle(x,y,r,color,parent,width)
 local vertices,indices={},{}
 for i=0,72 do
  local a=i*math.pi/36;vertices[#vertices+1]={(x+r*math.sin(a))*D.scale,(y+r*math.cos(a))*D.scale}
  if i<72 then indices[#indices+1]=i;indices[#indices+1]=i+1 end
 end
 local e=CreateElement('ceSMultiLine');e.material=D.materials[color or 'blue'];e.vertices=vertices;e.indices=indices
 e.thickness=width or .8;e.fuzziness=.2;D.add(e,parent or D.root)
end
local class_marker=dofile(LockOn_Options.script_path..'Systems/Defensive_Contact_Indicator.lua')
ecm_api.circle=circle
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
D.text('REL RF',-.48,.88,nil,'blue',.0028,D.choice('F22_RWR_FILTER',0,
 group({'F22_DEF_OV_PROXIMITY_COUNT'},{{'parameter_in_range',0,.5,16.5}},current)))
D.text('THRT',-.48,.88,nil,'white',.0028,D.choice('F22_RWR_FILTER',1,current))
D.text('PRI',.42,.88,nil,'white',.0034,D.choice('F22_DEF_OV_RANGE_VALID',0,current))
D.text('NO DATA',0,.84,nil,'yellow',.0034,D.choice('F22_DEF_OV_CURRENT',0))
D.text('RF OFF',0,.84,nil,'white',.0030,D.choice('F22_RWR_POWER',0,current))
D.text('MUTE',.65,.84,nil,'yellow',.0028,D.choice('F22_RWR_MUTE',1,current))

for i=1,16 do
 local p=string.format('F22_DEF_OV_%02d_',i)
 local at=group({p..'X',p..'Y',p..'VALID',p..'ALPHA'},{{'move_left_right_using_parameter',0,1},{'move_up_down_using_parameter',1,1},{'parameter_in_range',2,.9,1.1},{'opacity_using_parameter',3}},current,0,cy)
 local bearing=group({p..'ROT'},{{'rotate_using_parameter',0,1}},at)
 coverage(ecm_api,bearing,prefix..'_COVERAGE_'..i,1,{p..'RF_CURRENT'},{{'parameter_in_range',0,.9,1.1}})
 for _,aff in ipairs({{-1,'yellow'},{0,'red'},{1,'green'},{3,'cyan'}})do
  local label_color=D.choice(p..'ALERT',0,D.choice(p..'AFFILIATION',aff[1],at))
  contact_label(ecm_api,p,.075,.025,label_color,prefix..'_CONTACT_'..i..'_ID_'..aff[1],aff[2],.0030)
  class_marker(ecm_api,label_color,prefix..'_CLASS_'..i..'_'..aff[1],p..'KIND',aff[2])
 end
 local warning=D.choice(p..'ALERT',1,at)
 contact_label(ecm_api,p,.075,.025,warning,prefix..'_CONTACT_WARNING_'..i,'red',.0030)
 class_marker(ecm_api,warning,prefix..'_WARNING_CLASS_'..i,p..'KIND','red')
 -- A conditional passive location retains its estimate qualifier.
 D.text('E',-.045,.025,nil,'blue',.0026,D.choice(p..'GEO',1,at))
end

-- Compact expendable readbacks occupy the same lower-right region as the photo.
local counts=D.choice('F22_EW_BACKEND_READY',1)
D.text('CHAFF %.0f',.63,-.61,'F22_CHAFF_COUNT','white',.0032,counts)
D.text('FLARE %.0f',.63,-.69,'F22_FLARE_COUNT','white',.0032,counts)
D.text('CHAFF --',.63,-.61,nil,'white',.0032,D.choice('F22_EW_BACKEND_READY',0))
D.text('FLARE --',.63,-.69,nil,'white',.0032,D.choice('F22_EW_BACKEND_READY',0))
for mode,label in ipairs({'MAN','SEMI','AUTO'})do
 D.text(label..' P%.0f',-.56,-.64,'F22_CM_NORMAL_BANK','white',.0032,D.choice('F22_CM_MODE',mode))
end
local not_testing=D.choice('F22_CM_SELF_TEST',0)
local healthy=D.choice('F22_CM_FAILURE',0,not_testing)
local operating=D.choice('F22_CM_SYSTEM',2,healthy)
for state,label in pairs({[0]='CM OFF',[1]='CM STBY',[2]='CM ON'})do
 if state~=2 then D.text(label,-.56,-.72,nil,'yellow',.0030,D.choice('F22_CM_SYSTEM',state,healthy))end
end
D.text('CM TEST',-.56,-.72,nil,'yellow',.0030,D.choice('F22_CM_SELF_TEST',1))
D.text('CM FAIL',-.56,-.72,nil,'yellow',.0030,D.choice('F22_CM_FAILURE',1,not_testing))
D.text('CM LOW',.63,-.52,nil,'yellow',.0030,D.choice('F22_CM_LOW',1))
D.text('CONSENT?',-.56,-.72,nil,'yellow',.0030,D.choice('F22_CM_AWAITING_CONSENT',1,operating))
D.text('RUN P%.0f',-.56,-.72,'F22_CM_RUNNING_BANK','white',.0030,D.choice('F22_CM_EXECUTING',1,operating))
local waiting=D.choice('F22_CM_EXECUTING',0,D.choice('F22_CM_PROGRAM_RUNNING',1,operating))
D.text('REQUESTED',-.56,-.72,nil,'white',.0030,waiting)
-- Programming has one explicit entry/return; no draft or IFF table on DEF.
D.root=setup
D.text('DEF SETUP',0,.73,nil,'blue',.0048)
for _,item in ipairs({{'BANK %.0f',.48,'SELECTED'},{'CHAFF %.0f',.28,'CHAFF'},
 {'FLARE %.0f',.08,'FLARE'},{'INTERVAL %.2f S',-.12,'INTERVAL'},{'CYCLES %.0f',-.32,'CYCLES'}})do
 D.text(item[1],0,item[2],'F22_CM_PROGRAM_'..item[3],'white',.0043)
end
D.text('UNSAVED',0,-.47,nil,'yellow',.0034,D.choice('F22_CM_DRAFT_DIRTY',1))
D.text('SAVED',0,-.47,nil,'white',.0034,D.choice('F22_CM_DRAFT_DIRTY',0))
D.text('INVALID DRAFT',0,-.55,nil,'yellow',.0034,D.choice('F22_CM_DRAFT_ERROR',1))
D.text('EDIT PROGRAM / SAVE',0,-.68,nil,'blue',.0031)

end
