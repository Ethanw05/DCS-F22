"""Reproduce the crash's numeric70/%s pair using DCS-like parameter coercion."""
from pathlib import Path
import argparse
import ctypes as C
import re
import subprocess
from cockpit_fixture import runtime, engine_frame

ROOT=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser()
parser.add_argument('--baseline')
args=parser.parse_args()
sim=runtime()
if args.baseline:
    names=['Systems/Engine_Indications.lua','UFD_LEFT/base_page.lua','UFD_RIGHT/base_page.lua',
           'MFD_COMMON/eng_page.lua','MFD_COMMON/fuel_page.lua','MFD_COMMON/stores_page.lua']
    snapshots={}
    for name in names:
        snapshots[(ROOT/'Cockpit/Scripts'/name).as_posix()]=subprocess.check_output(
            ['git','show',args.baseline+':Cockpit/Scripts/'+name],cwd=ROOT,text=True)
    sim.globals().snapshots=sim.table_from(snapshots)
    sim.execute("""
    local original=dofile
    function dofile(path)
      if snapshots[path]then return assert(loadstring(snapshots[path]))()end
      return original(path)
    end
    """)
sim.execute("""
local original=get_param_handle;local wrapped={}
function get_param_handle(name)
 local h=original(name)
 if not wrapped[h]then
  wrapped[h]=true;local set=h.set
  function h:set(value)
   -- DCS treats numeric-looking strings as numeric parameter values.
   if type(value)=='string'and tonumber(value)~=nil then value=tonumber(value)end
   return set(self,value)
  end
 end
 return h
end
dofile(SCRIPT_ROOT..'Systems/Avionics.lua');post_initialize();avionics_update=update
""")
sample=dict(rpm=70,temperature=70,oil=180.9,nozzle=70,flow=.126,hydraulic=3950)
engine_frame(sim,left=sample,right=sample)
sim.globals().avionics_update()
for page,call in [('UFD_LEFT/base_page.lua',''),('UFD_RIGHT/base_page.lua',''),
                  ('MFD_COMMON/eng_page.lua',"('RMFD_ENG_PAGE')"),
                  ('MFD_COMMON/fuel_page.lua',"('LMFD_FUEL_PAGE')"),
                  ('MFD_COMMON/stores_page.lua',"('CMFD_BAY_PAGE','CRASH_STORES','F22_SMS_UI_PAGE_CMFD')")]:
    sim.execute("dofile(SCRIPT_ROOT..'"+page+"')"+call)

numeric={'RPM_L','RPM_R','EGT_L','EGT_R','OIL_L','OIL_R',
         'L_NOZZLE_POS','R_NOZZLE_POS','L_FF_VALUE','R_FF_VALUE','L_HYD_VALUE','R_HYD_VALUE'}
crt=C.CDLL('ucrtbase')
format_native=crt.__stdio_common_vsprintf
format_native.argtypes=[C.c_ulonglong,C.c_void_p,C.c_size_t,C.c_char_p,C.c_void_p,C.c_void_p]
format_native.restype=C.c_int
checked=0
for _,element in sim.globals().elements.items():
    for _,controller in (element['controllers'].items() if element['controllers']else[]):
        if controller[1]!='text_using_parameter':
            continue
        name=element['element_params'][int(controller[2])+1]
        if name not in numeric and not re.fullmatch(r'F22_ENGINE_[LR]_[A-Z]+_TEXT',name):
            continue
        h=sim.globals().get_param_handle(name)
        value=h.get(h)
        fmt=element['formats'][int(controller[3])+1]
        assert '%s'not in fmt or isinstance(value,str),(
            'native crash: numeric argument supplied to string format',name,value,fmt,element['name'])
        assert name in numeric and isinstance(value,(int,float))and fmt.endswith('f'),(name,value,fmt)
        buffer=C.create_string_buffer(128)
        argument=C.c_double(value)
        assert format_native(1,buffer,len(buffer),fmt.encode(),None,C.byref(argument))>=0
        assert buffer.value and b'---'not in buffer.value
        checked+=1
assert checked==36,('engine readout coverage changed',checked)

# All qualified legacy numeric readouts have an identically styled static
# unavailable element; static text has no parameter formatter to mis-type.
sim.execute("""
local pairs_checked=0
for index,e in ipairs(elements)do
 local params=e.element_params
 local valid=params and params[#params]
 if type(valid)=='string'and valid:match('^F22_ENGINE_[LR]_[A-Z]+_VALID$')then
  local is_numeric=false
  for _,c in ipairs(e.controllers or{})do if c[1]=='text_using_parameter'then is_numeric=true end end
  if is_numeric then
   local missing=assert(elements[index+1])
   assert(missing.value=='---'and not missing.formats)
   assert(missing.material==e.material and missing.alignment==e.alignment)
   for i=1,3 do assert(missing.init_pos[i]==e.init_pos[i])end
   for i=1,4 do assert(missing.stringdefs[i]==e.stringdefs[i])end
   local yes=e.controllers[#e.controllers];local no=missing.controllers[#missing.controllers]
   assert(yes[3]==.9 and no[4]==.1 and yes[2]==no[2])
   pairs_checked=pairs_checked+1
  end
 end
end
assert(pairs_checked==34)
get_param_handle('EFM_ENGINE_LEFT_TEMP_C'):set(0/0);avionics_update()
assert(get_param_handle('F22_ENGINE_L_EGT_VALID'):get()==0)
assert(get_param_handle('F22_ENGINE_R_EGT_VALID'):get()==1)
get_param_handle('EFM_POWER_OWNER'):set(0);avionics_update()
for _,side in ipairs({'L','R'})do for _,field in ipairs({'RPM','EGT','OIL','NOZZLE','FLOW','HYD'})do
 assert(get_param_handle('F22_ENGINE_'..side..'_'..field..'_VALID'):get()==0)
end end
""")
print('Native-format regression: 36 real engine/UFD/fuel/stores readouts, DCS coercion, actual CRT formatting, identical-style static unavailability and metric/supply failure PASS')
