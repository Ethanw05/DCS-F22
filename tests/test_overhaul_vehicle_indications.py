"""Physical EFM supply/engine states must drive their displayed indications."""
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
fixture=ROOT/'tests/test_display_startup.py'
ns={'__file__':str(fixture)}
exec(compile(fixture.read_text().split('\nfor page in ',1)[0],str(fixture),'exec'),ns)
lua=ns['runtime']()
lua.execute(r'''
function get_aircraft_property()return 1 end
local original=get_base_data
function get_base_data()
 local base=original()
 base.getEngineLeftRPM=function()return .67 end
 base.getEngineRightRPM=function()return .73 end
 base.getEngineLeftTemperatureBeforeTurbine=function()return 101 end
 base.getEngineRightTemperatureBeforeTurbine=function()return 102 end
 return base
end
local function put(k,v)get_param_handle(k):set(v)end
local function value(k)return get_param_handle(k):get()end
local sample=dofile(SCRIPT_ROOT..'Systems/Engine_Data.lua')(get_base_data())
put('EFM_ENGINE_VALID',1);put('EFM_ENGINE_LEFT_RPM_PCT',78);put('EFM_ENGINE_RIGHT_RPM_PCT',82)
put('EFM_VEHICLE_VALID',1);put('EFM_ENGINE_LEFT_TEMP_C',650);put('EFM_ENGINE_RIGHT_TEMP_C',855)
assert(sample.getEngineLeftRPM()==78 and sample.getEngineRightRPM()==82)
assert(sample.getEngineLeftTemperatureBeforeTurbine()==650 and sample.getEngineRightTemperatureBeforeTurbine()==855)
put('EFM_ENGINE_LEFT_TEMP_C',0/0);assert(sample.getEngineLeftTemperatureBeforeTurbine()==0,'invalid physical temperature fell back to a healthy host reading')
put('EFM_VEHICLE_VALID',0);assert(sample.getEngineLeftTemperatureBeforeTurbine()==101)
put('EFM_VEHICLE_VALID',1);put('EFM_ENGINE_LEFT_TEMP_C',650)
put('EFM_HYD_LEFT_PSI',39);put('EFM_HYD_RIGHT_PSI',3950)
put('EFM_ENGINE_LEFT_OIL_PSI',0);put('EFM_ENGINE_RIGHT_OIL_PSI',210)
put('EFM_ENGINE_LEFT_NOZZLE_PCT',12);put('EFM_ENGINE_RIGHT_NOZZLE_PCT',87)
dofile(SCRIPT_ROOT..'Systems/MFD_System.lua');post_initialize();put('MAIN_POWER',1)
for i=1,100 do update()end
assert(value('L_HYD_VALUE')==39 and value('R_HYD_VALUE')==3950,'display proxy overrode physical circuit pressure')
assert(value('L_HYD_COLOR')==1 and value('R_HYD_COLOR')==0)
assert(value('OIL_L')==0 and value('OIL_R')==210)
assert(value('L_OIL_COLOR')==1 and value('R_OIL_COLOR')==0,'running engine hid actual low oil pressure')
assert(value('L_NOZZLE_POS')==12 and value('R_NOZZLE_POS')==87,'nozzle display used RPM in place of achieved state')
assert(value('L_EGT_COLOR')==0 and value('R_EGT_COLOR')==1,'EGT color used host temperature instead of shared physical state')
-- Physical pressure/failure changes are visible immediately, independently.
put('EFM_HYD_LEFT_PSI',2200);put('EFM_HYD_RIGHT_PSI',0)
put('EFM_ENGINE_LEFT_RPM_PCT',0);put('EFM_ENGINE_LEFT_OIL_PSI',220);put('EFM_ENGINE_RIGHT_OIL_PSI',0)
update()
assert(value('L_HYD_VALUE')==2200 and value('R_HYD_VALUE')==0 and value('L_HYD_COLOR')==0 and value('R_HYD_COLOR')==1)
assert(value('OIL_L')==220 and value('OIL_R')==0 and value('L_OIL_COLOR')==0 and value('R_OIL_COLOR')==1,'oil caution followed RPM instead of retained physical pressure')
-- Invalid/out-of-range achieved data cannot leak into a cockpit gauge.
put('EFM_HYD_LEFT_PSI',0/0);put('EFM_HYD_RIGHT_PSI',5000)
put('EFM_ENGINE_LEFT_NOZZLE_PCT',-20);put('EFM_ENGINE_RIGHT_NOZZLE_PCT',120)
update()
assert(value('L_HYD_VALUE')==0 and value('R_HYD_VALUE')==3950)
assert(value('L_NOZZLE_POS')==0 and value('R_NOZZLE_POS')==100)
''')
print('Overhaul vehicle indications: physical pressure/oil/nozzle/temperature ownership, independent failure readback and guarded fallback PASS')

for panel in ('LEFT','RIGHT','CENTER'):
    lua=ns['runtime']()
    lua.execute(f"dofile(SCRIPT_ROOT..'MFD_{panel}/eng_page.lua')")
    lua.execute(r'''
    for _,gauge in ipairs({{'R_NEEDLE_OIL_R','OIL_R'},{'R_NEEDLE_OIL_G','OIL_R'},{'L_NEEDLE_OIL_L','OIL_L'},{'L_NEEDLE_OIL_G','OIL_L'}})do
     local element=element_data[_G[gauge[1]]];assert(element,'missing engine oil gauge')
     local rotation
     for _,controller in ipairs(element.controllers or {})do
      if controller[1]=='rotate_using_parameter'then
       assert(element.element_params[controller[2]+1]==gauge[2],'oil needle followed an unrelated engine channel')
       rotation=controller[3]*270
      end
     end
     assert(rotation and math.abs(rotation)>math.pi/2 and math.abs(rotation)<2*math.pi,'oil needle no longer has a useful PSI sweep')
    end
    ''')
print('Overhaul engine formats: all 12 oil needles use their corresponding physical PSI channel PASS')
