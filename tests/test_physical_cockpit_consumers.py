"""Actual cockpit owners reject stale/mixed epochs and retain sensor/source distinctions."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
fixture = ROOT / 'tests/test_display_startup.py'
scope = {'__file__': str(fixture)}
exec(compile(fixture.read_text().split('\nfor page in ', 1)[0], str(fixture), 'exec'), scope)
lua = scope['runtime']()
lua.execute(r'''
local function get(key)return get_param_handle(key):get()end
local function put(key,value)get_param_handle(key):set(value)end
local startup_conditions={};for i=1,8 do startup_conditions[i]={}end
local startup_equipment=dofile(SCRIPT_ROOT..'Systems/Equipment_Conditions.lua').new(get,startup_conditions)
put('MAIN_POWER',1);put('EFM_VEHICLE_VALID',1);put('L_GEN_OUT',1);put('L_HYD_COLOR',1)
startup_equipment.update()
for i=1,8 do assert(not startup_conditions[i].valid,
 'loose display/power flags granted physical fault authority without the owner')end
local fields={EFM_POWER_OWNER=1,EFM_PHYSICAL_VALID=1,EFM_PHYSICAL_GENERATION=1,
 EFM_PHYSICAL_STAMP=10,EFM_PHYSICAL_CLOCK_KIND=1,F22_AP_CLOCK=10,EFM_HUD_VALID=1,
 EFM_HUD_VN=100,EFM_HUD_VE=0,EFM_HUD_VU=0,EFM_GROUND_VALID=1,EFM_WEIGHT_ON_WHEELS=0,
 EFM_AIRDATA_VALID=1,EFM_AIRDATA_STAMP=10,EFM_AIRDATA_CAS_MPS=150,EFM_AIRDATA_TAS_MPS=200,
 EFM_AIRDATA_HEALTH=0,EFM_HUD_TAS=100,EFM_HUD_SOUND=340.293988,EFM_HUD_PRESSURE=101325,
 EFM_GEAR_DOWN_LOCKED=0,EFM_GEAR_UP_LOCKED=0,EFM_GEAR_UNSAFE=1,
 F22_ALT_BARO_VALID=1,F22_ALT_BARO_FT=5000,EFM_VEHICLE_VALID=1,EFM_MASS_VALID=1,
 EFM_MASS_KG=20000,EFM_TRIM_VALID=1,EFM_TRIM_LEFT_DEG=2,EFM_TRIM_RIGHT_DEG=3,
 EFM_INTERNAL_FUEL_KG=1000,EFM_EXTERNAL_FUEL_KG=0,F22_ESSENTIAL_POWER=1,
 EFM_FCS_INTEGRITY_VALID=1,EFM_FCS_DAMAGED=0,F22_ELECTRICAL_VALID=1,L_GEN_POWER=1,
 R_GEN_POWER=1,EFM_HYD_LEFT_PSI=4000,EFM_HYD_RIGHT_PSI=500,EFM_ENGINE_VALID=1,
 EFM_ENGINE_LEFT_OIL_PSI=200,EFM_ENGINE_RIGHT_OIL_PSI=50,MAIN_POWER=1}
for k,v in pairs(fields)do put(k,v)end
function get_base_data()return{
 getPitch=function()return 0 end,getRoll=function()return 0 end,getHeading=function()return 0 end,
 getAngleOfSlide=function()return 0 end,getVerticalAcceleration=function()return 1 end,
 getAngleOfAttack=function()return math.rad(12)end,getVerticalVelocity=function()return 0 end,
 getWOW_NoseLandingGear=function()return 0 end}end
function get_aircraft_draw_argument_value()return 1 end
dofile(SCRIPT_ROOT..'Systems/HUD_Flight_Data.lua');post_initialize();update()
assert(math.abs(get('HUD_CAS')-150*1.943844492)<1e-6,'HUD bypassed measured CAS')
assert(get('HUD_EBRACKET_VALID')==0,'animation became a downlock')
put('EFM_GEAR_DOWN_LOCKED',1);put('EFM_GEAR_UNSAFE',0);update()
assert(get('HUD_EBRACKET_VALID')==1 and get('HUD_AOA_VALID')==1)
put('EFM_WEIGHT_ON_WHEELS',-1);update()
assert(get('HUD_EBRACKET_VALID')==0 and get('HUD_LANDING_CONFIG')==0,'invalid owned WOW became airborne')
put('EFM_WEIGHT_ON_WHEELS',0);update();assert(get('HUD_EBRACKET_VALID')==1)
put('EFM_AIRDATA_HEALTH',3);put('EFM_AIRDATA_CAS_MPS',160);update()
assert(math.abs(get('HUD_CAS')-160*1.943844492)<1e-6 and get('HUD_AIRDATA_DEGRADED')==1)
assert(get('HUD_AIRDATA_VALID')==1 and get('HUD_EBRACKET_VALID')==0)
put('EFM_AIRDATA_HEALTH',2);put('F22_AP_CLOCK',10.3);put('EFM_PHYSICAL_STAMP',10.3);update()
assert(get('HUD_AIRDATA_VALID')==0 and get('HUD_FPM_VALID')==1 and get('HUD_ALT_VALID')==1)
put('EFM_PHYSICAL_VALID',0);update()
assert(get('HUD_FPM_VALID')==0 and get('HUD_LANDING_CONFIG')==0 and get('HUD_ALT_VALID')==1)
put('EFM_POWER_OWNER',0);update();assert(get('HUD_AIRDATA_VALID')==0,'legacy truth revived')
put('EFM_POWER_OWNER',1);put('EFM_PHYSICAL_VALID',1);put('EFM_AIRDATA_STAMP',10.3)
put('EFM_AIRDATA_HEALTH',0);update();assert(get('HUD_AIRDATA_VALID')==1)
local refs=dofile(SCRIPT_ROOT..'Systems/Cockpit_References.lua').new(get,put)
refs.update();assert(get('F22_REFERENCE_MASS')=='WEIGHT 44092 LB')
put('EFM_GEAR_UP_LOCKED',1);refs.update();assert(get('F22_REFERENCE_GEAR')=='GEAR --')
put('EFM_GEAR_UP_LOCKED',0);put('EFM_GEAR_UNSAFE',-1)
refs.update();assert(get('F22_REFERENCE_GEAR')=='GEAR --')
put('EFM_GEAR_UNSAFE',1);refs.update();assert(get('F22_REFERENCE_GEAR')=='GEAR UNSAFE')
put('EFM_GEAR_UNSAFE',0)
put('EFM_PHYSICAL_STAMP',9);refs.update()
assert(get('F22_REFERENCE_MASS')=='WEIGHT --' and get('F22_REFERENCE_SUPPLY')=='SUPPLY --')
put('EFM_PHYSICAL_STAMP',10.3)
local conditions={};for i=1,8 do conditions[i]={}end
local equipment=dofile(SCRIPT_ROOT..'Systems/Equipment_Conditions.lua').new(get,conditions)
put('L_HYD_COLOR',1);put('R_HYD_COLOR',0);put('L_OIL_COLOR',1);put('CANOPY_LIGHT',1)
equipment.update()
assert(conditions[4].valid and not conditions[4].active and conditions[5].active)
assert(not conditions[6].active and conditions[7].active,'faults followed display colors')
assert(not conditions[8].valid,'unqualified canopy became healthy/faulted from animation')
put('EFM_HYD_LEFT_PSI',0/0);equipment.update();assert(not conditions[4].valid)
put('EFM_PHYSICAL_CLOCK_KIND',2);equipment.update()
for i=1,8 do assert(not conditions[i].valid,'wrong clock accepted')end
put('EFM_PHYSICAL_CLOCK_KIND',1)
local mixed=false
local envelope=dofile(SCRIPT_ROOT..'Systems/Physical_Snapshot.lua').new(function(k)
 local value=get(k)
 if mixed and k=='EFM_MASS_KG'then put('EFM_PHYSICAL_GENERATION',get('EFM_PHYSICAL_GENERATION')+1)end
 return value
end,{'EFM_MASS_KG'})
mixed=true;envelope:update();assert(not envelope.valid,'mixed generation accepted')
mixed=false;envelope:update();assert(envelope.valid)
''')
print('Cockpit physical consumers: coherent epochs, measured CAS/degraded health, gear proxies, independent barometry, fault causes and no legacy revival PASS')
