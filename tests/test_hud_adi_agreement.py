"""Healthy independent HUD/primary/SFG references retain the same attitude convention."""
from pathlib import Path
import math,runpy
root=Path(__file__).resolve().parents[1]
runtime=runpy.run_path(str(root/'tests/test_display_startup.py'))['runtime']
lua=runtime()
lua.execute('''
    pose_pitch=0; pose_roll=0
    function get_base_data()
        return setmetatable({getPitch=function() return pose_pitch end,
            getRoll=function() return pose_roll end},
            {__index=function() return function() return 0 end end})
    end
    dofile(SCRIPT_ROOT..'Systems/Avionics.lua'); post_initialize()
    local reference=dofile(SCRIPT_ROOT..'../../tests/reference_frame_fixture.lua')()
    adi_update=reference:wrap(update)
    dofile(SCRIPT_ROOT..'Systems/HUD_Flight_Data.lua'); post_initialize()
    hud_update=reference:wrap(update)
    dofile(SCRIPT_ROOT..'HUD/page.lua')
''')
elements={e['name']:e for _,e in lua.globals().elements.items()}
hud_rotation=elements['HUD_ATTITUDE_ROLL']['controllers'][1][3]
hud_pitch_gain=elements['HUD_ATTITUDE']['controllers'][1][3]
scale=lua.globals().GetScale()
for file in ('UFD_RIGHT/base_page.lua','MFD_RIGHT/adi_page.lua'):
    adi=runtime()
    adi.execute('dofile(SCRIPT_ROOT..'+repr(file)+')')
    found=0
    roll_parameter='F22_SFG_ROLL' if file.startswith('UFD_RIGHT') else 'ADIROLL'
    pitch_parameter='F22_SFG_PITCH' if file.startswith('UFD_RIGHT') else 'ADIPITCH'
    for _,element in adi.globals().elements.items():
        if element['name']!='up':continue
        params=element['element_params']
        if not params or roll_parameter not in params.values() or pitch_parameter not in params.values():continue
        controllers={c[1]:c for _,c in element['controllers'].items()}
        r=controllers['rotate_using_parameter'];p=controllers['move_up_down_using_parameter']
        assert params[r[2]+1]==roll_parameter and params[p[2]+1]==pitch_parameter
        assert r[3]==hud_rotation and p[3]<0 and hud_pitch_gain<0
        found+=1
    assert found==1,file
for pitch in (-20,-5,0,8,20):
    for roll in (-60,-25,0,25,60):
        lua.globals().pose_pitch=math.radians(pitch)
        lua.globals().pose_roll=math.radians(roll)
        lua.execute('adi_update();hud_update()')
        h=lua.globals().handles
        adi_roll=h['ADIROLL']['value']; hud_roll=h['HUD_ROLL']['value']
        adi_pitch=h['ADIPITCH']['value']; hud_pitch=h['HUD_PITCH']['value']
        assert abs(adi_roll-hud_roll)<1e-12
        assert abs(adi_pitch-hud_pitch)<1e-12
        assert abs(h['F22_SFG_ROLL']['value']-hud_roll)<1e-12
        assert abs(h['F22_SFG_PITCH']['value']-hud_pitch)<1e-12
        # Compare orientation and pitch displacement in each display's units.
        assert abs(math.sin(adi_roll)-math.sin(hud_roll*hud_rotation))<1e-12
        assert abs(hud_pitch_gain*hud_pitch/(1000*scale)+adi_pitch)<1e-9
        # A level-world velocity ray must fall along the HUD horizon in bank.
        m=lua.execute('return dofile(SCRIPT_ROOT.."Systems/HUD_FlightMath.lua")')
        az,el=m.project(100,0,0,0,adi_pitch,adi_roll)
        assert abs(math.tan(el)*math.cos(adi_roll)-math.tan(az)*math.sin(adi_roll)+math.tan(adi_pitch))<1e-10
print('HUD agrees with UFD and MFD ADI attitude across 25 pitch/bank poses: OK')
