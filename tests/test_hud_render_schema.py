"""Native HUD binding must succeed before any producer post-init or update."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
fixture=ROOT/'tests/test_display_startup.py';ns={'__file__':str(fixture)}
exec(compile(fixture.read_text().split('\nfor page in ',1)[0],str(fixture),'exec'),ns)
lua=ns['runtime']()
lua.execute(r'''
local original=get_param_handle
local retained={HUD_FPM_X_RAD=.11,HUD_FPM_Y_RAD=-.12,HUD_AG_TGT_AZ_RAD=.21,HUD_AG_TGT_EL_RAD=-.22,
 HUD_AG_CCIP_AZ_RAD=.31,HUD_AG_CCIP_EL_RAD=-.32,HUD_IR_SEEKER_AZ=.41,HUD_IR_SEEKER_EL=-.42,
 HUD_GUN_NATIVE_AZ=.51,HUD_GUN_NATIVE_EL=-.52,HUD_FUNNEL_01_L_X=.61,HUD_FUNNEL_01_L_Y=-.62,
 F22_GUN_MNV_LOW_AZ=.71,F22_GUN_MNV_LOW_EL=-.72,
 F22_AG_BOMB_IMPACT_N=12345,F22_GUN_AIM_N=.9,F22_FUNNEL_01_N=100,F22_IR_WORLD_FWD_N=.8}
for k,v in pairs(retained)do original(k):set(v)end
local written,wrapped={},{}
function get_param_handle(name)
 local h=original(name)
 if not wrapped[name]then
  wrapped[name]=true;local set=h.set
  function h:set(v)written[name]=true;return set(self,v)end
 end
 return h
end
function get_model_time()error('constructor unexpectedly advanced a producer')end
for _,owner in ipairs({'Weapon_System','Gun_System','HUD_Flight_Data','AG_Mark_System','AG_Ballistic_Computer'})do
 dofile(SCRIPT_ROOT..'Systems/'..owner..'.lua')
end
assert(#actions==0,'constructor dispatched a sensor/weapon/physics request')
for name,v in pairs(retained)do assert(handles[name]:get()==v,name..' angular/solver value overwritten by schema declaration')end
local declared={};for name in pairs(handles)do declared[name]=true end
dofile(SCRIPT_ROOT..'HUD/page.lua')
local used={}
for _,e in ipairs(elements)do for _,name in ipairs(e.element_params or {})do
 if name:find('_X_SLOPE',1,true)or name:find('_Y_SLOPE',1,true)or name:find('_PLANE_',1,true)then used[name]=true end
end end
local count=0
for name in pairs(used)do
 count=count+1
 assert(declared[name],name..' first created after native HUD binding')
 assert(written[name] and handles[name]:get()==0,name..' did not receive an explicit invalid render snapshot')
end
assert(count==47,'reviewed native render schema changed; audit all new bindings')
for _,name in ipairs({'HUD_FPM_VALID','HUD_AG_TARGET_VALID','HUD_AG_CUE_VALID','F22_AG_SOLUTION_VALID',
 'HUD_AG_CCIP_CUE_VALID','HUD_AG_CCIP_EST_VALID','HUD_AG_CCRP_EST_VALID','HUD_IR_SEEKER_AVAILABLE',
 'HUD_IR_SEEKER_VALID','HUD_GUN_NATIVE_VALID','F22_GUN_USING_DIRECTOR','HUD_GUN_FUNNEL_VALID',
 'F22_GUN_MNV_SHOW','F22_GUN_DIRECTOR_VALID'})do
 assert(written[name] and handles[name]:get()==0,name..' is not invalid before first update')
end
for i=1,7 do assert(handles[string.format('HUD_FUNNEL_%02d_VALID',i)]:get()==0)end
-- The complete owner schema also covers not-currently-drawn maneuver variants.
for _,point in ipairs({'LOW','HIGH','LEFT','RIGHT'})do for _,suffix in ipairs({'_X_SLOPE','_Y_SLOPE','_PLANE_LEN','_PLANE_ROT'})do
 local name='F22_GUN_MNV_'..point..suffix
 assert(declared[name] and written[name] and handles[name]:get()==0,name..' missing complete owner schema')
end end
''')
print('HUD schema startup: all47 actual bound plane channels and complete owner variants explicitly invalid before post-init/update; retained angular/native buffers unchanged PASS')
