-- GPL-3.0-or-later. Own native LCD navigation format; original F-22 atlas.
return function(page_parameter)
dofile(LockOn_Options.script_path..'MFD_COMMON/definitions.lua')
dofile(LockOn_Options.script_path..'fonts.lua')
SetScale(FOV)
local physical=GetScale();local aspect=GetAspect and GetAspect() or 1
local scale=.95*math.min(1,aspect);local seq=0;local prefix='F22_NAV_'..page_parameter
local material={white=MakeMaterial(nil,{240,247,246,255}),blue=MakeMaterial(nil,{113,188,240,255}),green=MakeMaterial(nil,{0,255,0,255}),background=MakeMaterial(nil,{3,3,3,255})}
local fonts={white="F22_LCD_FONT_WHITE",blue="F22_LCD_FONT_BLUE",green="F22_LCD_FONT_GREEN",yellow="F22_LCD_FONT_YELLOW"}
local function add(e,name,parent)
    seq=seq+1;local full_name=prefix..'_'..(name or seq);e.name=full_name
    if parent then e.parent_element=parent end
    e.collimated=false;e.h_clip_relation=h_clip_relations.COMPARE;e.level=2
    e.additive_alpha=false;e.use_mipfilter=true;Add(e);return full_name
end
-- Same stencil level/aperture as the original shared MFD subsets.
for _,relation in ipairs({h_clip_relations.REWRITE_LEVEL,h_clip_relations.INCREASE_IF_LEVEL}) do
    local e=CreateElement('ceMeshPoly');e.name=prefix..'_MASK_'..relation
    e.vertices={{-1,-aspect},{1,-aspect},{1,aspect},{-1,aspect}};e.indices={0,1,2,2,3,0}
    e.material=material.background;e.primitivetype='triangles';e.h_clip_relation=relation;e.level=1;e.collimated=false;e.isvisible=false
    Add(e)
end
local root=CreateElement('ceSimple');root.element_params={'MFD_OPACITY',page_parameter}
root.controllers={{'opacity_using_parameter',0},{'parameter_in_range',1,.9,1.1}}
local main=add(root,'ROOT')
local function group(name,x,y,params,controllers,parent)
    local e=CreateElement('ceSimple');e.init_pos={x*scale,y*scale,0};e.element_params=params
    local converted={}
    for _,c in ipairs(controllers or {}) do
        local row={};for k,v in ipairs(c) do row[k]=v end
        if row[1]=='move_left_right_using_parameter' or row[1]=='move_up_down_using_parameter' then row[3]=row[3]*physical*scale end
        converted[#converted+1]=row
    end
    e.controllers=converted;return add(e,name,parent or main)
end
local function text(value,x,y,param,color,parent,size)
    local e=CreateElement('ceStringSLine');e.material=fonts[color or 'white'];e.init_pos={x*scale,y*scale,0}
    local h=(size or .0047)*scale;e.stringdefs={h, (h) * 0.60,h*.08,0};e.alignment='CenterCenter'
    if param then e.element_params={param};e.formats={value};e.controllers={{'text_using_parameter',0,0}} else e.value=value end
    return add(e,nil,parent or main)
end
local function line(x1,y1,x2,y2,color,parent)
    local e=CreateElement('ceSMultiLine');e.material=material[color or 'white'];e.vertices={{x1*scale,y1*scale},{x2*scale,y2*scale}};e.indices={0,1}
    e.thickness=1.6;e.fuzziness=.25;add(e,nil,parent or main)
end
local bg=CreateElement('ceMeshPoly');bg.material=material.background;bg.primitivetype='triangles'
bg.vertices={{-1,-aspect},{1,-aspect},{1,aspect},{-1,aspect}};bg.indices={0,1,2,2,3,0};add(bg,'BACKGROUND',main)
local page_key=page_parameter..'_DATA'
local format_root=main
main=group('STEERING',0,0,{page_key},{{'parameter_in_range',0,-.1,.1}},format_root)
text('RNG %.0f',-.58,.82,'F22_NAV_SCALE_NM','blue',nil,.0034)

text('NAV %s',0,.85,'F22_NAV_HEADING_TEXT','blue')
local map=group('MAP',0,.10,{},{});local compass=group('COMPASS',0,0,{'F22_NAV_COMPASS_ROT'},{{'rotate_using_parameter',0,1}},map)
for i=0,71 do
    local a=i*2*math.pi/72;local r=i%2==0 and .61 or .59
    line(.56*math.sin(a),.56*math.cos(a),r*math.sin(a),r*math.cos(a),'blue',compass)
end
for i=0,11 do
    local a=i*math.pi/6
    local labels={[0]='N',[3]='E',[6]='S',[9]='W'}
    -- Text moves with the compass but stays upright in the LCD plane.
    local place=group('CARDINAL_POS_'..i,.665*math.sin(a),.665*math.cos(a),{}, {},compass)
    local upright=group('CARDINAL_UP_'..i,0,0,{'F22_NAV_COMPASS_ROT'},{{'rotate_using_parameter',0,-1}},place)
    text(labels[i] or string.format('%02d',i*3),0,0,nil,'white',upright,.0040)
end
local valid=group('VALID',0,0,{'F22_NAV_DISPLAY_VALID'},{{'parameter_in_range',0,.9,1.1}})
local bearing=group('BEARING',0,0,{'F22_NAV_BRG_ROT'},{{'rotate_using_parameter',0,1}},map)
local bearing_valid=group('BEARING_VALID',0,0,{'F22_NAV_GUIDANCE_VALID'},{{'parameter_in_range',0,.9,1.1}},bearing)
line(0,.59,-.025,.55,'green',bearing_valid);line(0,.59,.025,.55,'green',bearing_valid)
line(-.025,.55,.025,.55,'green',bearing_valid)
-- The controller was verified in common CockpitBase: point index, X/Y
-- parameter indices, physical X/Y gains. It updates real line vertices.
for i=1,32 do
    local p=string.format('F22_NAV_LEG_%02d_',i)
    for active=0,1 do
        local e=CreateElement('ceSimpleLineObject');e.material=material[active==1 and 'green' or 'blue']
        e.vertices={{0,0},{.001,0}};e.primitivetype='lines'
        e.width=(active==1 and .0056 or .0040)*physical*scale
        e.element_params={p..'X1',p..'Y1',p..'X2',p..'Y2',p..'VALID',p..'ACTIVE'}
        e.controllers={{'line_object_set_point_using_parameters',0,0,1,physical*scale,physical*scale},
            {'line_object_set_point_using_parameters',1,2,3,physical*scale,physical*scale},
            {'parameter_in_range',4,.9,1.1},{'parameter_in_range',5,active-.1,active+.1}}
        add(e,'LEG_'..i..'_'..active,map)
    end
    p=string.format('F22_NAV_PT_%02d_',i)
    local pos=group('POINT_'..i,0,0,{p..'X',p..'Y',p..'VALID'},{{'move_left_right_using_parameter',0,1},{'move_up_down_using_parameter',1,1},{'parameter_in_range',2,.9,1.1}},map)
    for active=0,1 do
        local show=group('POINT_STATE_'..i..'_'..active,0,0,{p..'ACTIVE'},{{'parameter_in_range',0,active-.1,active+.1}},pos)
        local c=active==1 and 'green' or 'blue';local r=active==1 and .026 or .017
        line(0,r,r,0,c,show);line(r,0,0,-r,c,show);line(0,-r,-r,0,c,show);line(-r,0,0,r,c,show)
        text('%.0f',.04,-.04,p..'ID',c,show,.0038)
    end
end
line(0,.04,-.027,-.025,'white',map);line(-.027,-.025,0,-.01,'white',map)
line(0,-.01,.027,-.025,'white',map);line(.027,-.025,0,.04,'white',map)
local loc=group('ILS_LOCALIZER',0,0,{'HUD_ILS_LOC_VALID','HUD_ILS_LOC'},
 {{'parameter_in_range',0,.9,1.1},{'move_left_right_using_parameter',1,.20}},map)
line(0,-.20,0,.20,'green',loc)
local glide=group('ILS_GLIDESLOPE',0,0,{'HUD_ILS_GS_VALID','HUD_ILS_GS'},
 {{'parameter_in_range',0,.9,1.1},{'move_up_down_using_parameter',1,.20}},map)
line(-.20,0,.20,0,'green',glide)
local hdg=group('HDG_BUG' ,0,0,{'F22_NAV_HDG_BUG_ROT'},{{'rotate_using_parameter',0,1}},map)
line(-.025,.62,-.025,.66,'white',hdg);line(-.025,.66,.025,.66,'white',hdg);line(.025,.66,.025,.62,'white',hdg)
local cdi=group('CDI',0,0,{'F22_NAV_CDI_VALID','F22_NAV_COURSE_ROT'},
 {{'parameter_in_range',0,.9,1.1},{'rotate_using_parameter',1,1}},map)
line(0,.43,0,.22,'blue',cdi);line(0,-.22,0,-.43,'blue',cdi)
line(-.025,.39,0,.43,'blue',cdi);line(0,.43,.025,.39,'blue',cdi)
local deviation=group('CDI_DEVIATION',0,0,{'F22_NAV_CDI'},{{'move_left_right_using_parameter',0,.20}},cdi)
line(0,-.20,0,.20,'green',deviation)
for _,x in ipairs({-.20,-.10,.10,.20})do line(x,-.008,x,.008,'blue',cdi)end
text('%s',.65,.82,'F22_NAV_SOURCE_TEXT','green',nil,.0034)
text('%s',.65,.75,'F22_NAV_TO_FROM','blue',nil,.0032)
text('%s',.65,.68,'F22_NAV_CDI_SCALE_TEXT','blue',nil,.0034)
local unavailable=group('UNAVAILABLE',0,0,{'F22_NAV_DISPLAY_VALID'},{{'parameter_in_range',0,-.1,.1}})
text('%.22s',0,-.60,'F22_NAV_STATUS_TEXT','yellow',unavailable,.0036)
for _,state in ipairs({3,4,5,7})do
 local status=group('DESIGNATION_STATUS_'..state,0,0,{'F22_NAV_DESIGNATE_STATUS'},{{'parameter_in_range',0,state-.1,state+.1}})
 text('%.22s',0,-.60,'F22_NAV_DESIGNATE_STATUS_TEXT','yellow',status,.0036)
end
local fix=group('FIX_NAME',0,0,{'F22_NAV_DESIGNATE_STATUS'},{{'parameter_in_range',0,-.1,2.9}},valid)
text('%.22s',0,-.60,'F22_NAV_FIX_TEXT','white',fix,.0036)
text('%s',-.30,-.71,'F22_NAV_BRG_TEXT','white',valid,.0036)
text('%s',.30,-.71,'F22_NAV_DIST_TEXT','white',valid,.0036)
text('%s',-.30,-.82,'F22_NAV_ALT_TEXT','white',valid,.0034)
text('%s',.30,-.82,'F22_NAV_TTG_TEXT','white',valid,.0034)
main=format_root
for view=1,3 do
 local data=group('DATA_'..view,0,0,{page_key},{{'parameter_in_range',0,view-.1,view+.1}},format_root)
 text(({'WAYPOINT','TACAN','ILS'})[view],0,.72,nil,'blue',data,.0045)
 if view==1 then
  text('%s',0,.52,'F22_NAV_POINT_LABEL','green',data,.0050)
  text('LAT',-.49,.26,nil,'blue',data,.0038);text('%s',.14,.26,'F22_NAV_FIX_LAT_TEXT','white',data,.0045)
  text('LON',-.49,.10,nil,'blue',data,.0038);text('%s',.14,.10,'F22_NAV_FIX_LON_TEXT','white',data,.0045)
  text('ELEV',-.49,-.06,nil,'blue',data,.0038);text('%s',.14,-.06,'F22_NAV_FIX_ELEV_TEXT','white',data,.0043)
  text('%s',0,-.38,'F22_NAV_POINT_NAME_TEXT','blue',data,.0038)
  text('%s',-.30,-.55,'F22_NAV_COURSE_TEXT','blue',data,.0036)
  text('%s',.30,-.55,'F22_NAV_XTK_TEXT','blue',data,.0036)
 else
  text('%s',0,.43,view==2 and 'F22_TCN_TUNE_TEXT'or'F22_ILS_TUNE_TEXT','green',data,.005)
  text('%s',0,.16,'F22_NAV_CRS_TEXT','white',data,.0045)
  if view==2 then
   local brg=group('TCN_BRG',0,0,{'F22_NAV_TCN_BRG_AVAILABLE','F22_TCN_MODE'},{{'parameter_in_range',0,.9,1.1},{'parameter_in_range',1,.9,4.1}},data)
   local rng=group('TCN_RANGE',0,0,{'F22_NAV_TCN_RANGE_AVAILABLE','F22_TCN_MODE'},{{'parameter_in_range',0,.9,1.1},{'parameter_in_range',1,.9,4.1}},data)
   text('%s',-.25,-.10,'F22_NAV_TCN_BRG_TEXT','white',brg,.0040)
   text('%s',.25,-.10,'F22_NAV_TCN_DIST_TEXT','white',rng,.0040)
   local no_brg=group('TCN_BRG_INVALID',0,0,{'F22_NAV_TCN_BRG_AVAILABLE','F22_TCN_MODE'},{{'parameter_in_range',0,-.1,.1},{'parameter_in_range',1,.9,4.1}},data)
   local no_rng=group('TCN_RANGE_INVALID',0,0,{'F22_NAV_TCN_RANGE_AVAILABLE','F22_TCN_MODE'},{{'parameter_in_range',0,-.1,.1},{'parameter_in_range',1,.9,4.1}},data)
   text('BRG INVALID',-.25,-.10,nil,'yellow',no_brg,.0035)
   text('DME INVALID',.25,-.10,nil,'yellow',no_rng,.0035)
   local off=group('TCN_OFF',0,0,{'F22_TCN_MODE'},{{'parameter_in_range',0,-.1,.1}},data)
   text('BRG ---',-.25,-.10,nil,'blue',off,.0035)
   text('DME ---',.25,-.10,nil,'blue',off,.0035)
  else
   for _,part in ipairs({{'LOC','F22_ILS_LOC_VALID',-.18},{'GS','F22_ILS_GS_VALID',.18}})do
    local show=group('ILS_'..part[1],0,0,{part[2]},{{'parameter_in_range',0,.9,1.1}},data)
    text(part[1],part[3],-.10,nil,'green',show,.0043)
    local invalid=group('ILS_'..part[1]..'_INVALID',0,0,{part[2]},{{'parameter_in_range',0,-.1,.1}},data)
    text(part[1]..' INVALID',part[3],-.10,nil,'yellow',invalid,.0035)
   end
  end
 end
end
local mark_data=group('MARK_TIME_DATA',0,0,{page_key},{{'parameter_in_range',0,3.9,4.1}},format_root)
text('MARK / ARRIVAL',0,.72,nil,'blue',mark_data,.0045)
for index,key in ipairs({'MARK_TEXT','MARK_LAT_TEXT','MARK_LON_TEXT','MARK_ALT_TEXT',
 'CLOCK_TEXT','ARRIVAL_TEXT','TIMING_DEST_TEXT','TIMING_TEXT'})do
 text('%s',0,.51-(index-1)*.145,'F22_NAV_'..key,index<=4 and'white'or'green',mark_data,.0043)
end
text('UTC MANUAL REFERENCE',0,-.76,nil,'blue',mark_data,.0036)

end
