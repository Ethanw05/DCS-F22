-- GPL-3.0-or-later. AP and ALT use the same aligned ICP line-select geometry.
local function text(name,key,y,size)
 local e=CreateElement('ceStringSLine');e.name='F22_FLIGHT_'..name;e.material="F22_LCD_FONT_GREEN"
 e.stringdefs={size, (size) * 0.60,.0003,.001};e.alignment='LeftCenter';e.init_pos={-.95,y,0}
 e.h_clip_relation=h_clip_relations.COMPARE;e.level=21;e.collimated=false
 e.element_params={'ICP_OPACITY','ICP_FLIGHT_MENU',key};e.formats={'%s'}
 e.controllers={{'opacity_using_parameter',0},{'parameter_in_range',1,.9,5.1},{'text_using_parameter',2,0}}
 Add(e)
end
text('TITLE','ICP_FLIGHT_TITLE',1.31,.0026)
for i=1,5 do
 local y=i==1 and 1.15 or i==5 and -1.14 or 1.8-i*.6
 text('ROW_'..i,'ICP_FLIGHT_ROW_'..i,y,(i==1 or i==5)and .0043 or .0048)
 local e=CreateElement('ceSMultiLine');e.name='F22_FLIGHT_FIELD_'..i;e.material=MakeMaterial(nil,{0,255,0,255})
 e.vertices={{0,-.025},{-.035,0},{0,.025}};e.indices={0,1,1,2};e.thickness=1.6;e.fuzziness=.25;e.init_pos={1.35,y,0}
 e.h_clip_relation=h_clip_relations.COMPARE;e.level=21;e.collimated=false
 e.element_params={'ICP_OPACITY','ICP_FLIGHT_MENU','ICP_FLIGHT_FIELD'}
 e.controllers={{'opacity_using_parameter',0},{'parameter_in_range',1,.9,5.1},{'parameter_in_range',2,i-.1,i+.1}}
 Add(e)
end
-- Draft digits are shown in the selected full-size row, not in a footer.
-- The physical ICP has five separate apertures. Keep headings/help within rows 1/5.
