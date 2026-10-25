-- GPL-3.0-or-later. Own native LCD navigation format; original F-22 atlas.
return function(page_parameter)
dofile(LockOn_Options.script_path..'MFD_COMMON/definitions.lua')
dofile(LockOn_Options.script_path..'fonts.lua')
SetScale(FOV)
local physical=GetScale();local aspect=GetAspect and GetAspect() or 1
local scale=.95*math.min(1,aspect);local seq=0;local prefix='F22_NAV_'..page_parameter
local material={white=MakeMaterial(nil,{240,247,246,255}),blue=MakeMaterial(nil,{113,188,240,255}),green=MakeMaterial(nil,{0,255,0,255}),background=MakeMaterial(nil,{3,3,12,255})}
local fonts={white=UFD_FONT,blue=UFD_RADAR_BLUE,green=UFD_GRN}
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
    local e=CreateElement('ceStringPoly');e.material=fonts[color or 'white'];e.init_pos={x*scale,y*scale,0}
    local h=(size or .0047)*scale;e.stringdefs={h,h,h*.08,0};e.alignment='CenterCenter'
    if param then e.element_params={param};e.formats={value};e.controllers={{'text_using_parameter',0,0}} else e.value=value end
    return add(e,nil,parent or main)
end
local function line(x1,y1,x2,y2,color,parent)
    local e=CreateElement('ceSMultiLine');e.material=material[color or 'white'];e.vertices={{x1*scale,y1*scale},{x2*scale,y2*scale}};e.indices={0,1}
    e.thickness=1.6;e.fuzziness=.25;add(e,nil,parent or main)
end
local bg=CreateElement('ceMeshPoly');bg.material=material.background;bg.primitivetype='triangles'
bg.vertices={{-1,-aspect},{1,-aspect},{1,aspect},{-1,aspect}};bg.indices={0,1,2,2,3,0};add(bg,'BACKGROUND',main)
text('MENU',-.565,.92);text('NAV',0,.92,nil,'blue');text('ADI',.565,.92)
text('NEXT',-.88,.42);text('PREV',-.88,.14)
text('RNG+',-.88,-.14);text('RNG-',-.88,-.42)
text('%s',-.88,-.70,'F22_NAV_AUTO_TEXT');text('NAV',-.565,-.92);text('D-TO',-.2825,-.92)
text('RNG %.0f',.61,-.92,'F22_NAV_SCALE_NM')
text('%s',0,.835,'F22_NAV_HEADING_TEXT')
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
local valid=group('VALID',0,0,{'F22_NAV_VALID'},{{'parameter_in_range',0,.9,1.1}})
local bearing=group('BEARING',0,0,{'F22_NAV_BRG_ROT'},{{'rotate_using_parameter',0,1}},map)
local bearing_valid=group('BEARING_VALID',0,0,{'HUD_WP_BRG_VALID'},{{'parameter_in_range',0,.9,1.1}},bearing)
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
text('%s',0,-.625,'F22_NAV_STATUS_TEXT','blue',nil,.0040)
text('%s',0,-.69,'F22_NAV_FIX_TEXT','white',valid,.0045)
text('%s',-.30,-.75,'F22_NAV_BRG_TEXT','white',valid,.0043)
text('%s',.30,-.75,'F22_NAV_DIST_TEXT','white',valid,.0043)
text('%s',-.30,-.81,'F22_NAV_ALT_TEXT','white',valid,.0038)
text('%s',.30,-.81,'F22_NAV_TTG_TEXT','white',valid,.0038)
text('%s',-.30,-.865,'F22_NAV_COURSE_TEXT','blue',valid,.0038)
text('%s',.30,-.865,'F22_NAV_XTK_TEXT','blue',valid,.0038)
end
