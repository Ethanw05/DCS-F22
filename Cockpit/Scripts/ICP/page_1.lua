-- GPL-3.0-or-later. Five option apertures plus the real keypad scratchpad.
dofile(LockOn_Options.script_path..'ICP/definitions.lua')
dofile(LockOn_Options.script_path..'fonts.lua');SetScale(FOV)
local green=MakeMaterial(nil,{0,255,0,255})
for _,relation in ipairs({h_clip_relations.REWRITE_LEVEL,h_clip_relations.INCREASE_IF_LEVEL})do
 local e=CreateElement('ceMeshPoly');e.name='F22_UFC_MASK_'..relation
 e.vertices={{-3.8,-1.7},{1.6,-1.7},{1.6,1.7},{-3.8,1.7}};e.indices={0,1,2,2,3,0}
 e.material=green;e.h_clip_relation=relation;e.level=20;e.isvisible=false;Add(e)
end
local root='F22_UFC_ROOT'
local e=CreateElement('ceSimple');e.name=root;e.element_params={'ICP_OPACITY','F22_UFC_VISIBLE'}
e.controllers={{'opacity_using_parameter',0},{'parameter_in_range',1,.9,1.1}}
e.level=21;e.h_clip_relation=h_clip_relations.COMPARE;e.collimated=false;Add(e)
local function text(name,param,x,y,size)
 local t=CreateElement('ceStringSLine');t.name=name;t.parent_element=root;t.material='F22_LCD_FONT_GREEN'
 t.init_pos={x,y,0};t.alignment='LeftCenter';t.stringdefs={size,size*.6,.0003,.001}
 t.element_params={param};t.formats={'%s'};t.controllers={{'text_using_parameter',0,0}}
 t.level=21;t.h_clip_relation=h_clip_relations.COMPARE;t.collimated=false;Add(t)
end
-- The scratchpad occupies the separate aperture left of option row 1,
-- immediately above the number keys. Draft digits never replace option rows.
text('F22_UFC_SCRATCH','F22_UFC_SCRATCH',-3.48,1.2,.0052)
for i=1,5 do
 local y=1.8-i*.6
 text('F22_UFC_ROW_'..i,'F22_UFC_ROW_'..i,-.95,y,.0048)
 local mark=CreateElement('ceSMultiLine');mark.name='F22_UFC_SELECTION_'..i;mark.parent_element=root
 mark.vertices={{0,-.035},{-.04,0},{0,.035}};mark.indices={0,1,1,2};mark.init_pos={1.35,y,0}
 mark.material=green;mark.thickness=1.5;mark.fuzziness=.2;mark.level=21;mark.h_clip_relation=h_clip_relations.COMPARE
 mark.element_params={'F22_UFC_SELECTED'};mark.controllers={{'parameter_in_range',0,i-.1,i+.1}};Add(mark)
end
