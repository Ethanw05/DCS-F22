-- GPL-3.0-or-later. One bezel geometry and one label per physical key.
local function track_pair(panel,layout,prefix,root,native_scale,green,h)
 -- One TRACK caption spans the two top-right keys. Vector arrowheads keep
 -- the direction readable without depending on optional font glyphs.
 local pair=prefix..'TRACK_PAIR'
 local group=CreateElement('ceSimple');group.name=pair;group.parent_element=root
 group.element_params={'F22_MFD_'..panel..'_TRACK_PAIR'}
 group.controllers={{'parameter_in_range',0,.9,1.1}}
 group.level=28;group.h_clip_relation=h_clip_relations.COMPARE;group.collimated=false;Add(group)
 local left,right=layout.keys[4],layout.keys[5]
 local caption=CreateElement('ceStringSLine');caption.name=prefix..'TRACK_CAPTION';caption.parent_element=pair
 caption.material='F22_LCD_FONT_WHITE';caption.value='TRACK';caption.alignment='CenterCenter'
 caption.init_pos={(left.x+right.x)/2,(left.y+right.y)/2,0};caption.stringdefs={h,h*.6,h*.06,0}
 caption.level=28;caption.h_clip_relation=h_clip_relations.COMPARE;caption.collimated=false;Add(caption)
 local y=math.min(left.y,right.y)-1.15*h/native_scale
 local head=.12*(right.x-left.x)
 local arrow=CreateElement('ceSMultiLine');arrow.name=prefix..'TRACK_ARROW';arrow.parent_element=pair
 arrow.vertices={{left.x,y},{right.x,y},{left.x+head,y+head*.6},{left.x+head,y-head*.6},
  {right.x-head,y+head*.6},{right.x-head,y-head*.6}}
 arrow.indices={0,1,0,2,0,3,1,4,1,5};arrow.material=green;arrow.thickness=1.4;arrow.fuzziness=.2
 arrow.level=28;arrow.h_clip_relation=h_clip_relations.COMPARE;arrow.collimated=false;Add(arrow)
end
return function(panel)
 dofile(LockOn_Options.script_path..'MFD_COMMON/definitions.lua')
 dofile(LockOn_Options.script_path..'fonts.lua');SetScale(FOV)
 local aspect=GetAspect and GetAspect()or 1
 local native_scale=GetScale()
 local layout=dofile(LockOn_Options.script_path..'MFD_COMMON/display_layout.lua').for_display(panel,aspect,native_scale)
 local h=layout.font_height
 local prefix='F22_BEZEL_'..panel..'_'
 local green=MakeMaterial(nil,{0,255,0,255})
 for _,relation in ipairs({h_clip_relations.REWRITE_LEVEL,h_clip_relations.INCREASE_IF_LEVEL})do
  local e=CreateElement('ceMeshPoly');e.name=prefix..'MASK_'..relation
  e.vertices={{-1,-aspect},{1,-aspect},{1,aspect},{-1,aspect}};e.indices={0,1,2,2,3,0}
  e.material=green;e.h_clip_relation=relation;e.level=27;e.isvisible=false;Add(e)
 end
 local root=prefix..'ROOT'
 local e=CreateElement('ceSimple');e.name=root;e.element_params={'MFD_OPACITY'}
 e.controllers={{'opacity_using_parameter',0}};e.level=28;e.h_clip_relation=h_clip_relations.COMPARE;e.collimated=false;Add(e)
 for button=1,20 do
  local key=layout.keys[button]
  local t=CreateElement('ceStringSLine');t.name=prefix..button;t.parent_element=root
  t.material='F22_LCD_FONT_WHITE';t.init_pos={key.x,key.y,0};t.alignment=key.alignment
  t.stringdefs={h,h*.6,h*.06,0}
  t.element_params={'F22_MFD_'..panel..'_KEY_'..button};t.formats={'%s'}
  t.controllers={{'text_using_parameter',0,0}};t.level=28;t.h_clip_relation=h_clip_relations.COMPARE;t.collimated=false;Add(t)
  -- Anchor the outside of side labels to the glass, then grow inward by the
  -- current label's glyph count. The selection outline uses the same anchor.
  local anchor_name=prefix..'SEL_'..button
  local anchor=CreateElement('ceSimple');anchor.name=anchor_name;anchor.parent_element=root
  local pad=key.side and (key.right and .2 or -.2)*h/native_scale or 0
  anchor.init_pos={key.x+pad,key.y,0};anchor.level=28;anchor.h_clip_relation=h_clip_relations.COMPARE
  anchor.collimated=false
  anchor.element_params={'F22_MFD_'..panel..'_SEL_'..button}
  anchor.controllers={{'parameter_in_range',0,.9,1.1}};Add(anchor)
  local left=key.side and (key.right and -1 or 0)or -.5
  local right=key.side and (key.right and 0 or 1)or .5
  local corners={{left,-.7},{right,-.7},{right,.7},{left,.7}}
  for edge=1,4 do
   local a,b=corners[edge],corners[edge%4+1]
   local box=CreateElement('ceSimpleLineObject');box.name=prefix..'SEL_'..button..'_'..edge;box.parent_element=anchor_name
   box.vertices={{0,0},{.001,0}};box.primitivetype='lines';box.width=.00014
   box.material=green;box.thickness=1.4;box.fuzziness=.2;box.level=28;box.h_clip_relation=h_clip_relations.COMPARE
   box.collimated=false;box.additive_alpha=false
   box.element_params={'F22_MFD_'..panel..'_SPAN_'..button,'F22_MFD_LABEL_ONE'}
   box.controllers={{'line_object_set_point_using_parameters',0,0,1,a[1]*h,a[2]*h},
    {'line_object_set_point_using_parameters',1,0,1,b[1]*h,b[2]*h}}
   Add(box)
  end
 end
 track_pair(panel,layout,prefix,root,native_scale,green,h)
end
