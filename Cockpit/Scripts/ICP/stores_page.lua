-- GPL-3.0-or-later. Numeric delivery programming lives at the front keypad.
local function line(name,key,y,size)
 local e=CreateElement('ceStringSLine');e.name='F22_STORES_ICP_'..name;e.material="F22_LCD_FONT_GREEN"
 e.stringdefs={size, (size) * 0.60,.0003,.001};e.alignment='LeftCenter';e.init_pos={-.95,y,0}
 e.h_clip_relation=h_clip_relations.COMPARE;e.level=21;e.collimated=false
 e.element_params={'ICP_OPACITY','ICP_STORES_MENU',key};e.formats={'%s'}
 e.controllers={{'opacity_using_parameter',0},{'parameter_in_range',1,.9,1.1},{'text_using_parameter',2,0}}
 Add(e)
end
line('TITLE','ICP_STORES_TITLE',1.31,.0026)
for i=1,5 do line('ROW_'..i,'ICP_STORES_ROW_'..i,i==1 and 1.15 or i==5 and -1.14 or 1.8-i*.6,.0044)end
-- Draft digits are rendered at full size in the selected option row.
