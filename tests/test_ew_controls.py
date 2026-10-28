"""Actual EW device: physical edges, native counts/status, power and rearm."""
from pathlib import Path
from test_display_startup import runtime

ROOT=Path(__file__).resolve().parents[1]
lua=runtime()
lua.execute('''
chaff=120;flare=120;ecm=false;available=true;calls=0
local native={
 drop_chaff=function(self,n)assert(n==1);chaff=math.max(0,chaff-n)end,
 drop_flare=function(self,n)assert(n==1);flare=math.max(0,flare-n)end,
 get_chaff_count=function()return chaff end,get_flare_count=function()return flare end,
 get_ECM_status=function()return ecm end,
 set_ECM_status=function(self,on)assert(type(on)=='boolean');ecm=on;calls=calls+1 end}
function GetDevice(id)assert(id==15);if available then return native end end
dofile(SCRIPT_ROOT..'Systems/EW_System.lua');post_initialize()
get_param_handle('MAIN_POWER'):set(1);get_param_handle('MASTER_ARM'):set(0);update()
assert(get_param_handle('F22_EW_BACKEND_READY'):get()==1)
SetCommand(11114,20.375);SetCommand(11114,20.375);SetCommand(11114,20.25)
assert(flare==119,'held private binding must dispense once')
SetCommand(11114,1);SetCommand(11114,0);assert(flare==118)
SetCommand(357,1);SetCommand(357,0);assert(flare==117)
SetCommand(358,1);SetCommand(358,0);assert(chaff==119)
SetCommand(11115,1);SetCommand(11115,1);SetCommand(11115,0);assert(chaff==118)
update();assert(get_param_handle('F22_CHAFF_COUNT'):get()==118)
SetCommand(11116,1);SetCommand(11116,1);SetCommand(11116,0);update()
assert(ecm and get_param_handle('ECM_ARG'):get()==1)
assert(get_param_handle('F22_ECM_REQUESTED'):get()==1)
ecm=false;update();assert(get_param_handle('F22_ECM_ACTIVE'):get()==0,
 'indication must report the actual native flag, not merely the switch request')
SetCommand(136,1);SetCommand(136,0);update();assert(not ecm)
SetCommand(136,1);update();assert(ecm)
get_param_handle('MAIN_POWER'):set(0);update();assert(not ecm)
SetCommand(357,1);SetCommand(358,1);SetCommand(136,1);update()
assert(flare==117 and chaff==118 and not ecm)
get_param_handle('MAIN_POWER'):set(1);chaff=0;flare=0;update()
assert(get_param_handle('CHAFF_LIGHT'):get()==1 and get_param_handle('FLARE_LIGHT'):get()==1)
chaff=120;flare=120;update()
assert(get_param_handle('F22_CHAFF_COUNT'):get()==120 and get_param_handle('CHAFF_LIGHT'):get()==0)
available=false;update();assert(get_param_handle('F22_EW_BACKEND_READY'):get()==0)
available=true;update();assert(get_param_handle('F22_EW_BACKEND_READY'):get()==1)
post_initialize();update();assert(not ecm and get_param_handle('F22_ECM_REQUESTED'):get()==0)
''')

for kind in ('keyboard','joystick'):
    lua.globals().folder=(ROOT/f'Input/F-22A/{kind}').as_posix()+'/'
    source=(ROOT/f'Input/F-22A/{kind}/default.lua').read_text()
    binding_code=source.split('-- Preserve the base command names/default key combinations, but own routing.',1)[1].rsplit('return res',1)[0]
    lua.execute('''
    function _(text)return text end
    function join(target,extra)for _,binding in ipairs(extra)do target[#target+1]=binding end end
    iCommandPlaneDropFlareOnce=357;iCommandPlaneDropChaffOnce=358;iCommandActiveJamming=136
    original_combo={key='Insert'}
    res={keyCommands={{down=357},{down=358,combos={original_combo}},{down=136},{down=999}}}
    ''')
    lua.execute(binding_code)
    lua.execute('''
    for i=1,3 do local b=res.keyCommands[i]
     assert(b.down==11113+i and b.up==b.down and b.value_down==1 and b.value_up==0)
     assert(b.cockpit_device_id==20)
    end
    assert(res.keyCommands[2].combos[1]==original_combo and res.keyCommands[4].down==999)
    for i=5,6 do local b=res.keyCommands[i]
     assert(b.cockpit_device_id==22 and b.down==10915+i and b.up==b.down)
     assert(b.value_down==1 and b.value_up==0)
    end
    ''')
print('EW: own physical/global controls, actual CM/ECM state, arm independence, power, rearm and reset PASS')
