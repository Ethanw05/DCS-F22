"""Native gun direction must use the optical axis, independent of decorative layout."""
from test_display_startup import runtime
lua=runtime()
lua.execute('''
dofile(SCRIPT_ROOT.."HUD/init.lua")
local forward=collimator_default_distance_factor[1]
local down=collimator_default_distance_factor[2]
dofile(SCRIPT_ROOT.."HUD/page.lua")
local gun
for _,e in ipairs(elements) do if e.name=="HUD_GUN_NATIVE" then gun=e end end
assert(gun,"active native pipper")
local unit=GetScale()
-- A zero body-elevation gun ray must intersect the aircraft forward axis.
-- At this optical plane: default Y + page Y (mrad) * native unit = 0.
assert(math.abs(down+gun.init_pos[2]*unit)<1e-9,
    "pipper inherits decorative offset instead of physical optical reference")
assert(math.abs(gun.init_pos[1]*unit+collimator_default_distance_factor[3])<1e-9)
local xgain,ygain
for _,c in ipairs(gun.controllers) do
 if c[1]=="move_left_right_using_parameter" then xgain=c[3] end
 if c[1]=="move_up_down_using_parameter" then ygain=c[3] end
end
assert(math.abs(xgain-forward)<1e-12 and math.abs(ygain-forward)<1e-12,
    "one radian must use the native focal distance")
-- Check a native trajectory direction projected onto the optical plane.
for _,el in ipairs({-.05,0,.05}) do
 local expected=forward*el
 local actual=down+gun.init_pos[2]*unit+el*ygain
 assert(math.abs(actual-expected)<1e-9)
end
-- IR direction and unlocked gun trajectories use that same optical zero.
for _,name in ipairs({'HUD_IR_NATIVE_3','HUD_GUN_FUNNEL'}) do
 local root
 for _,e in ipairs(elements)do if e.name==name then root=e end end
 assert(root and math.abs(down+root.init_pos[2]*unit)<1e-9,name..' optical zero')
end
local rail_count=0
for _,e in ipairs(elements)do
 if e.kind=='ceSimpleLineObject' and e.parent_element=='HUD_GUN_FUNNEL' then
  rail_count=rail_count+1
  assert(e.vertices and #e.vertices==2 and e.width>0)
  for _,c in ipairs(e.controllers)do
   if c[1]=='line_object_set_point_using_parameters' then
    assert(math.abs(c[5]-forward)<1e-12 and math.abs(c[6]-forward)<1e-12,'funnel radians/physical scale')
   end
  end
 end
end
assert(rail_count==12,'two connected six-segment rails')
''')
print("Gun optical alignment: physical zero, native angular scale and off-axis directions OK")
