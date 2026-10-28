"""Achieved utility demand, empty tank identity, and lifecycle withdrawal."""
from cockpit_fixture import runtime

lua = runtime()
lua.execute(r'''
local Adapter=dofile(SCRIPT_ROOT..'Systems/Vehicle_Stores_Adapter.lua')
local positions={}
function get_aircraft_draw_argument_value(arg)return positions[arg] or 0 end
function set_aircraft_draw_argument_value(arg,value)positions[arg]=value end
local function put(name,value)get_param_handle(name):set(value)end
local function get(name)return get_param_handle(name):get()end
local physical={valid=true,generation=2,stamp=10}
local infos={[1]={CLSID='{LDTP_FUEL_Tank}',count=1},[9]={count=0}}
local adapter=Adapter.new()
for _,arg in ipairs({600,601,602,614})do set_aircraft_draw_argument_value(arg,0)end
put('F22_GUN_AMMO_VALID',1);put('F22_GUN_AMMO_COUNT',100)
adapter:update(physical,.02,infos,true,false,9.98)
assert(get('F22_HYD_DEMAND_VALID')==1 and get('F22_R_HYD_LOAD')==0)
assert(get('F22_FUEL_INVENTORY_VALID')==1 and get('F22_LEFT_TANK_INSTALLED')==1)
assert(get('F22_RIGHT_TANK_INSTALLED')==0 and get('F22_FUEL_INVENTORY_STAMP')==9.98)
set_aircraft_draw_argument_value(600,.05)
set_aircraft_draw_argument_value(601,.05)
set_aircraft_draw_argument_value(602,.05)
set_aircraft_draw_argument_value(614,.09)
put('F22_GUN_AMMO_COUNT',98)
adapter:update(physical,.02,infos,true,false,9.98)
assert(math.abs(get('F22_R_HYD_LOAD')-.95)<1e-9 and get('F22_L_HYD_LOAD')==0)
-- Holding an open bay or a gun command consumes no invented actuation flow.
adapter:update(physical,.02,infos,true,false,9.98)
assert(get('F22_R_HYD_LOAD')==0)
put('F22_GUN_AMMO_COUNT',200) -- rearm is not expended ammunition
adapter:update(physical,.02,infos,true,true,9.98)
assert(get('F22_R_HYD_LOAD')==0 and get('F22_FUEL_INVENTORY_VALID')==0)
infos[1]={CLSID='{LDTP_FUEL_Tank}',count=0}
adapter:update(physical,.02,infos,true,false,10)
assert(get('F22_LEFT_TANK_INSTALLED')==0)
infos[1]=nil
adapter:update(physical,.02,infos,true,false,10)
assert(get('F22_FUEL_INVENTORY_VALID')==0)
physical.valid=false
adapter:update(physical,.02,infos,true,false,10)
assert(get('F22_HYD_DEMAND_VALID')==0)
physical.valid=true;physical.generation=3;physical.stamp=0
put('F22_GUN_AMMO_COUNT',50)
set_aircraft_draw_argument_value(600,1)
adapter:update(physical,.02,infos,false,false,-1)
assert(get('F22_R_HYD_LOAD')==0 and get('F22_FUEL_INVENTORY_VALID')==0)
assert(get('F22_HYD_DEMAND_GENERATION')==3 and get('F22_HYD_DEMAND_STAMP')==0)
''')
print('vehicle stores: achieved travel, expended rounds, tank identity and lifecycle OK')
