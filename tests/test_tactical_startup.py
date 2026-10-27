"""Actual formats bind only initialized new tactical/defensive/CM handles."""
from test_display_startup import runtime
lua=runtime()
lua.execute('''
local scripts={'RWR_System.lua','EW_System.lua','Radar_System.lua'}
for _,name in ipairs(scripts)do dofile(SCRIPT_ROOT..'Systems/'..name)end
-- No post_initialize/update callbacks before native indicators bind.
local initialized={}
for k in pairs(handles)do initialized[k]=true end
dofile(SCRIPT_ROOT..'PMFD_CENTER/radar_page.lua')
dofile(SCRIPT_ROOT..'MFD_RIGHT/rwr_page.lua')
dofile(SCRIPT_ROOT..'MFD_LEFT/attack_page.lua')
local checked=0
for _,e in ipairs(elements)do
 for _,param in ipairs(e.element_params or {})do
  if param:match('^F22_TSD_')or param:match('^F22_DEFENSIVE_')or param:match('^F22_CM_PROGRAM_')then
   assert(initialized[param],'new format parameter missing before native bind: '..param)
   checked=checked+1
  end
 end
end
assert(checked>100)
assert(handles.F22_TSD_VALID.value==0 and handles.F22_DEFENSIVE_VALID.value==0)
assert(handles.F22_TACTICAL_01_VALID.value==0 and handles.F22_TACTICAL_01_RANGE_VALID.value==0)
assert(handles.F22_RADAR_TACTICAL_01_VALID.value==0)
''')
print('Tactical startup: actual format-to-producer bindings initialized before post_initialize/update PASS')
