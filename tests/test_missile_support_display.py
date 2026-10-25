"""Actual HUD/radar warning gates, priority and persistence across weapon modes."""
from pathlib import Path
import contextlib,io,runpy
ROOT=Path(__file__).resolve().parents[1]
with contextlib.redirect_stdout(io.StringIO()):
 runtime=runpy.run_path(str(ROOT/'tests/test_display_startup.py'))['runtime']
def labels(page,params):
 lua=runtime();lua.execute("dofile(SCRIPT_ROOT.."+repr(page)+")")
 elements={str(e['name']):e for _,e in lua.globals().elements.items()}
 def visible(e,seen=None):
  seen=set() if seen is None else seen
  name=str(e['name']);assert name not in seen,'parent cycle';seen.add(name)
  parent=e['parent_element']
  if parent in elements and not visible(elements[parent],seen):return False
  keys=e['element_params'];controllers=e['controllers']
  if controllers:
   for _,c in controllers.items():
    if c[1] in ['parameter_in_range','opacity_using_parameter']:
     value=params.get(str(keys[int(c[2])+1]),0)
     if c[1]=='parameter_in_range' and not c[3]<value<c[4]:return False
     if c[1]=='opacity_using_parameter' and value<=0:return False
  return True
 return {str(e['value']) for e in elements.values() if e['value'] and visible(e)}
for page,prefix in [('HUD/page.lua','MSL SUP '),('PMFD_CENTER/radar_page.lua','SUPPORT ')]:
 for mode in [1,2,3,4,5,6,7]:
  p=dict(HUD_MODE=mode,HUD_POWER=1,MFD_OPACITY=1,PMFD_RDR_PAGE=1,F22_FC_MISSILES=1,
   F22_FC_SUPPORT_DEGRADED=1,F22_FC_SUPPORT_LOST=0)
  active=labels(page,p)
  assert prefix+'COAST' in active and prefix+'LOST' not in active,(page,mode,active)
  p['F22_FC_SUPPORT_LOST']=1;active=labels(page,p)
  assert prefix+'LOST' in active and prefix+'COAST' not in active,'lost must override coast'
  p['F22_FC_MISSILES']=0;active=labels(page,p)
  assert prefix+'LOST' not in active and prefix+'COAST' not in active,'ended missiles left warning'
  p['F22_FC_MISSILES']=1;p['HUD_POWER']=0;p['MFD_OPACITY']=0;active=labels(page,p)
  assert prefix+'LOST' not in active,'unpowered warning remained visible'
print('Actual HUD/radar support labels: NAV/IR/MRM/gun/AG persistence, loss priority, no missile and power gates PASS')
