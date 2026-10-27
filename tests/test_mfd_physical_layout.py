"""Actual shared formats inherit measured bezel anchors and one ground-plot transform."""
from pathlib import Path
import math
ROOT=Path(__file__).resolve().parents[1]
f=ROOT/'tests/test_display_startup.py';ns={'__file__':str(f)}
exec(compile(f.read_text().split('\nfor page in ',1)[0],str(f),'exec'),ns)
# Independent cockpit-connector measurements. The PMFD side row/column pitch
# differs substantially from the smaller three MFDs.
expected={
 'LMFD':(0.9916455596168496,-0.5657890742332662,0.4351524540448926,0.0774774849415284),
 'RMFD':(0.9916452111913295,-0.5604387680447226,0.43515268771656346,0.07747749984268959),
 'CMFD':(0.991645790169953,-0.565724619967519,0.43289027297928756,0.07747749984266665),
 'PMFD':(0.974297133750073,-0.6155210351433766,0.5531223403809389,0.0932006910443306),
}
for panel,(aspect,top_x,side_y,model_scale)in expected.items():
 for native in [.07,.1,.18,model_scale]:
  l=ns['runtime']();l.globals().panel=panel;l.globals().aspect=aspect;l.globals().native_scale=native
  l.execute('''
  function GetScale()return native_scale end;function GetAspect()return aspect end
  local Layout=dofile(SCRIPT_ROOT..'MFD_COMMON/display_layout.lua')
  spec=Layout.for_display(panel..'_RDR_PAGE',aspect,native_scale)
  dofile(SCRIPT_ROOT..'PMFD_CENTER/ag_radar_format.lua')(panel..'_RDR_PAGE','AG_')
  dofile(SCRIPT_ROOT..'MFD_COMMON/bezel.lua')(panel)
  local lookup={};for _,e in ipairs(elements)do lookup[e.name]=e end
  local video=lookup.AG_F22_AG_RADAR_VIDEO
  assert(math.abs(video.vertices[1][1]+spec.ground_plot.half_width)<1e-12)
  assert(math.abs(video.vertices[1][2]+spec.ground_plot.half_height)<1e-12)
  local sx,sy=spec.ground_plot.x_scale,spec.ground_plot.y_scale
  local cursor=lookup.AG_F22_AG_RDR_CURSOR
  assert(cursor.controllers[1][3]==native_scale*sx and cursor.controllers[2][3]==native_scale*sy)
  for _,e in ipairs(elements)do
   if e.parent_element=='AG_F22_AG_RDR_CURSOR'and e.vertices then
    assert(math.abs(math.abs(e.vertices[1][1])-.025*sx)<1e-12)
    assert(math.abs(math.abs(e.vertices[1][2])-.025*sy)<1e-12)
   end
   for _,c in ipairs(e.controllers or{})do
    if c[1]=='line_object_set_point_using_parameters'then
     assert(e.kind=='ceSimpleLineObject','dynamic line controller on unsupported native element')
     if e.name:find('AG_',1,true)==1 then
      assert(c[5]==native_scale*sx and c[6]==native_scale*sy,'cursor/corral detached from image')
     end
    end
   end
  end
  for b=1,20 do
   local key=spec['keys'][b];local text=lookup['F22_BEZEL_'..panel..'_'..b]
   assert(text.init_pos[1]==key.x and text.init_pos[2]==key.y and text.alignment==key.alignment)
   assert(math.abs(key.x)<1 and math.abs(key.y)<aspect)
   assert(text.stringdefs[1]==spec.font_height,'bezel label size varies by format')
   for edge=1,4 do
    local box=lookup['F22_BEZEL_'..panel..'_SEL_'..b..'_'..edge]
    for _,c in ipairs(box.controllers)do
     -- Longest current ground-radar side label, with its actual outline.
     local x=key.x+(key.side and(key.right and .2 or-.2)*spec.font_height/native_scale or 0)
         +Layout.label_span('ACTIVE')*c[5]/native_scale
     local y=key.y+c[6]/native_scale
     assert(math.abs(x)<.999 and math.abs(y)<aspect,'selection outline extends off glass')
    end
   end
  end
  assert(spec['keys'][13].x==0 and spec['keys'][13].y<-.9*aspect)
  ''')
  spec=l.globals().spec
  assert abs(spec['keys'][1].x-top_x)<2e-5,(panel,'top column')
  assert abs(spec['keys'][6].y-side_y*aspect)<2e-5,(panel,'side row')
  if native==.1:
   plot=spec.ground_plot
   old=.82*min(1,aspect)
   assert plot.half_width*plot.half_height/(.825*.76*old**2)>1.45
print('4 measured display profiles x 4 native scales: 80 physical anchors, outward text, dynamic outlines, bottom MENU, enlarged image/cursor/corral registration PASS')

l=ns['runtime']()
l.execute('''
local function p(k,v)get_param_handle(k):set(v)end
local function g(k)return get_param_handle(k):get()end
local R=dofile(SCRIPT_ROOT..'Systems/Display_Routing.lua')
local L=dofile(SCRIPT_ROOT..'MFD_COMMON/display_layout.lua')
local m=dofile(SCRIPT_ROOT..'Systems/MFD_Controller.lua').new(get_param_handle,function()end,function()end)
p('HUD_MODE',7);p('F22_AG_GAIN_INDEX',5);p('F22_AG_RANGE_AVAILABLE',1);p('F22_AG_ACTIVE_AVAILABLE',1)
p('F22_AG_OPTIONS_AVAILABLE',1);p('F22_AG_EXP1_AVAILABLE',1);p('F22_AG_BEAM_AVAILABLE',1)
m:update(true)
for panel,name in ipairs(R.panels)do
 for _,page in ipairs(R.order)do
  m:select(panel,page)
  for b=1,20 do
   local text=g('F22_MFD_'..name..'_KEY_'..b)
   assert(g('F22_MFD_'..name..'_SPAN_'..b)==L.label_span(text),'stale label outline')
  end
 end
end
assert(g('F22_MFD_LABEL_ONE')==1)
''')
print('Actual shared controller: live text and selection widths stay synchronized across all 4 x 9 common formats PASS')

