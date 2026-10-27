-- GPL-3.0-or-later. Shared native LCD drawing primitives and bezel geometry.
return function(page_parameter,prefix,context_parameter,context_low,context_high)
 dofile(LockOn_Options.script_path..'MFD_COMMON/definitions.lua')
 dofile(LockOn_Options.script_path..'fonts.lua')
 SetScale(FOV)
 local aspect=GetAspect and GetAspect()or 1
 local scale=.95*math.min(1,aspect);local sequence=0
 local layout=dofile(LockOn_Options.script_path..'MFD_COMMON/display_layout.lua').for_display(page_parameter,aspect,GetScale())
 local colors={white={240,247,246,255},blue={113,188,240,255},green={0,255,0,255},
  yellow={255,220,40,255},red={255,35,20,255},cyan={0,255,255,255},magenta={235,80,211,255},background={3,3,3,255}}
 local material={};for k,v in pairs(colors)do material[k]=MakeMaterial(nil,v)end
 local fonts={white="F22_LCD_FONT_WHITE",blue="F22_LCD_FONT_BLUE",green="F22_LCD_FONT_GREEN",yellow="F22_LCD_FONT_YELLOW",
  red="F22_LCD_FONT_RED",cyan="F22_LCD_FONT_TEAL",magenta="F22_LCD_FONT_MAGENTA"}
 local D={scale=scale,colors=colors,materials=material,fonts=fonts}
 function D.add(e,parent,name)
  sequence=sequence+1;local identifier=prefix..'_'..(name or sequence);e.name=identifier;e.parent_element=parent
  e.h_clip_relation=h_clip_relations.COMPARE;e.level=2;e.collimated=false;e.additive_alpha=false;e.use_mipfilter=true
  Add(e);return identifier
 end
 for _,relation in ipairs({h_clip_relations.REWRITE_LEVEL,h_clip_relations.INCREASE_IF_LEVEL})do
  local e=CreateElement('ceMeshPoly');e.name=prefix..'_MASK_'..relation
  e.vertices={{-1,-aspect},{1,-aspect},{1,aspect},{-1,aspect}};e.indices={0,1,2,2,3,0};e.material=material.background
  e.primitivetype='triangles';e.h_clip_relation=relation;e.level=1;e.collimated=false;e.isvisible=false;Add(e)
 end
 local r=CreateElement('ceSimple');r.element_params={'MFD_OPACITY',page_parameter}
 local root_controllers={{'opacity_using_parameter',0},{'parameter_in_range',1,.9,1.1}}
 if context_parameter then
  r.element_params={'MFD_OPACITY',page_parameter,context_parameter}
  root_controllers[3]={'parameter_in_range',2,context_low,context_high}
 end
 r.controllers=root_controllers
 D.root=D.add(r,nil,'ROOT')
 local bg=CreateElement('ceMeshPoly');bg.material=material.background;bg.primitivetype='triangles'
 bg.vertices={{-1,-aspect},{1,-aspect},{1,aspect},{-1,aspect}};bg.indices={0,1,2,2,3,0};D.add(bg,D.root,'BACKGROUND')
 function D.group(parameter,low,high,parent)
  local e=CreateElement('ceSimple');e.element_params={parameter};e.controllers={{'parameter_in_range',0,low,high}}
  return D.add(e,parent or D.root)
 end
 function D.choice(parameter,code,parent)return D.group(parameter,code-.1,code+.1,parent)end
 function D.text(value,x,y,param,color,size,parent,alignment)
  local e=CreateElement('ceStringSLine');e.material=fonts[color or 'white'];e.init_pos={x*scale,y*scale,0};e.alignment=alignment or 'CenterCenter'
  local h=math.max(size or .0043,.0036)*scale;e.stringdefs={h, (h) * 0.60,h*.08,0}
  if param then e.element_params={param};e.formats={value};e.controllers={{'text_using_parameter',0,0}}else e.value=value end
  return D.add(e,parent or D.root)
 end
 function D.line(x1,y1,x2,y2,color,parent)
  local e=CreateElement('ceSMultiLine');e.material=material[color or 'green'];e.vertices={{x1*scale,y1*scale},{x2*scale,y2*scale}}
  e.indices={0,1};e.thickness=1.5;e.fuzziness=.25;return D.add(e,parent or D.root)
 end
 function D.box(x,y,w,h,color,parent)
  D.line(x-w/2,y-h/2,x+w/2,y-h/2,color,parent);D.line(x+w/2,y-h/2,x+w/2,y+h/2,color,parent)
  D.line(x+w/2,y+h/2,x-w/2,y+h/2,color,parent);D.line(x-w/2,y+h/2,x-w/2,y-h/2,color,parent)
 end
 D.bezel={}
 for i,key in ipairs(layout.keys)do D.bezel[i]={key.x/scale,key.y/scale}end
 function D.key(button,label,color,parent,size)
  local p=D.bezel[button];return D.text(label,p[1],p[2],nil,color,math.max(size or .0050,.0043),parent,layout.keys[button].alignment)
 end
 function D.texture(file,x,y,height,parent)
  local e=CreateElement('ceTexPoly');local h=height*scale/2
  e.material=MakeMaterial(LockOn_Options.script_path..'IndicationTextures/'..file,colors.green)
  e.vertices={{-h,h},{h,h},{h,-h},{-h,-h}};e.indices={0,1,2,2,3,0};e.tex_coords={{0,0},{1,0},{1,1},{0,1}}
  e.init_pos={x*scale,y*scale,0};return D.add(e,parent or D.root)
 end
 return D
end
