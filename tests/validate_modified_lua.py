"""Check syntax of the modified Lua entrypoints with a pinned parser.

This catches malformed Lua before a user installs the experimental mod.
It does not validate DCS runtime functions, HUD connector names or VR optics.
"""
from pathlib import Path
from contextlib import redirect_stdout
from io import StringIO
from luaparser import ast

SCRIPTS = [
    Path("Cockpit/Scripts/materials.lua"),
    Path("Cockpit/Scripts/fonts.lua"),
    Path("Cockpit/Scripts/HUD/font.lua"),
    Path("Cockpit/Scripts/HUD/glass.lua"),
    Path("Cockpit/Scripts/HUD/layout.lua"),
    Path("Cockpit/Scripts/Systems/Engine_Data.lua"),
    Path("entry.lua"),
    Path("Cockpit/Scripts/devices.lua"),
    Path("Cockpit/Scripts/Systems/Electrical_System.lua"),
    Path("Cockpit/Scripts/Systems/HUD_Flight_Data.lua"),
    Path("Cockpit/Scripts/Systems/HUD_FlightMath.lua"),
    Path("Cockpit/Scripts/Systems/HUD_TargetMath.lua"),
    Path("Cockpit/Scripts/device_init.lua"),
    Path("Cockpit/Scripts/Systems/Avionics.lua"),
    Path("Cockpit/Scripts/Systems/Engine_System.lua"),
    Path("F-22A.lua"),
    Path("Weapons.lua"),
    Path("Weapons/GBU_32.lua"),
    Path("UnitPayloads/F-22A.lua"),
    Path("Cockpit/Scripts/Systems/MFD_System.lua"),
    Path("Cockpit/Scripts/HUD/init.lua"),
    Path("Cockpit/Scripts/HUD/page.lua"),
    Path("Cockpit/Scripts/HUD/tactical_page.lua"),
    Path("Cockpit/Scripts/HUD/gun_reticle.lua"),
    Path("Cockpit/Scripts/HUD/optics.lua"),
    Path("Cockpit/Scripts/HUD/style.lua"),
    Path("Cockpit/Scripts/HUD/gun_maneuver.lua"),
    Path("Cockpit/Scripts/HUD/gun_funnel.lua"),
    Path("Cockpit/Scripts/Systems/Gun_Funnel.lua"),
    Path("Cockpit/Scripts/Systems/Gun_Funnel_Presentation.lua"),
    Path("Cockpit/Scripts/Systems/IR_Seeker.lua"),
    Path("Cockpit/Scripts/Systems/Gun_Director.lua"),
    Path("Cockpit/Scripts/Systems/Gun_Motion.lua"),
    Path("Cockpit/Scripts/Systems/Gun_Frames.lua"),
    Path("Cockpit/Scripts/Systems/Weapon_System.lua"),
    Path("Cockpit/Scripts/Systems/IR_Audio.lua"),
    Path("Cockpit/Scripts/Systems/Navigation_System.lua"),
    Path("Cockpit/Scripts/Systems/Radar_Data_Bridge.lua"),
    Path("Cockpit/Scripts/Systems/AG_Ballistic_Computer.lua"),
    Path("Cockpit/Scripts/Systems/Ballistic_Point_Mass.lua"),
    Path("Cockpit/Scripts/Systems/AG_Release_Geometry.lua"),
    Path("Cockpit/Scripts/PMFD_CENTER/radar_page.lua"),
    Path("Cockpit/Scripts/Systems/NavGeometry.lua"),
    Path("Cockpit/Scripts/Systems/AG_Mark_System.lua"),
    Path("Cockpit/Scripts/Systems/ICP_System.lua"),
    Path("Cockpit/Scripts/clickabledata.lua"),
]

def main() -> None:
    extra=[Path('Cockpit/Scripts/Systems')/n for n in ('Flight_Guidance.lua','TACAN_Native.lua','ILS_Native.lua','Navigation_Power.lua')]
    extra+=[Path('Cockpit/Scripts/ICP/page_1.lua')]
    extra+=list(Path('Cockpit/Scripts/Systems').glob('Radar_*.lua'))
    extra += [Path('Cockpit/Scripts/Systems/Sensor_Control.lua'),Path('Cockpit/Scripts/MFD_COMMON/sensor_control.lua')]
    extra += [Path('Cockpit/Scripts') / name / 'sensor_control.lua' for name in ('MFD_LEFT','MFD_RIGHT','MFD_CENTER','PMFD_CENTER')]
    extra+=list(Path('Cockpit/Scripts/Systems').glob('AG_*.lua'))
    extra+=[Path('Cockpit/Scripts/PMFD_CENTER/ag_radar_format.lua')]
    extra+=[Path('Cockpit/Scripts/HUD/ag.lua'),Path('Weapons/AG_Training.lua')]
    extra += [Path('Cockpit/Scripts')/name for name in (
        'Systems/INS_Model.lua','Systems/Altitude_Settings.lua','Systems/Altitude_System.lua','Systems/ICP_Flight_Pages.lua',
        'Systems/Pilot_Warnings.lua','Systems/Pilot_Warning_System.lua','ICP/flight_pages.lua','HUD/pilot_warnings.lua','UFD_LEFT/base_page.lua','UFD_RIGHT/base_page.lua')]
    extra+=[Path('Cockpit/Scripts/Systems/EW_System.lua')]
    extra+=list(Path('Cockpit/Scripts/Systems').glob('RWR_*.lua'))
    extra+=list(Path('Cockpit/Scripts/Systems').glob('Tactical_*.lua'))
    extra+=list(Path('Cockpit/Scripts/Systems').glob('Terrain_*.lua'))
    extra+=list(Path('Cockpit/Scripts/Systems').glob('EW_*.lua'))
    extra+=[Path('Cockpit/Scripts/MFD_LEFT/attack_page.lua'),Path('Cockpit/Scripts/MFD_RIGHT/rwr_page.lua')]
    extra+=list(Path('Cockpit/Scripts/Systems').glob('MWS_*.lua'))
    extra+=list(Path('Cockpit/Scripts/Systems').glob('Nav_*.lua'))+[Path('Cockpit/Scripts/MFD_COMMON/nav_page.lua')]
    extra+=list(Path('Cockpit/Scripts/Systems').glob('Combat_*.lua'))+[Path('Cockpit/Scripts/Systems/Weapon_Native.lua'),Path('Cockpit/Scripts/Systems/Input_Value.lua'),Path('Cockpit/Scripts/Systems/PMFD_System.lua')]
    extra += [Path('Cockpit/Scripts/PMFD_CENTER/radar_format.lua'),
        Path('Cockpit/Scripts/PMFD_CENTER/tactical_overlay.lua'),
        Path('Input/F-22A/joystick/default.lua'),Path('Input/F-22A/keyboard/default.lua')]
    for filename in dict.fromkeys(SCRIPTS+extra):
        source = filename.read_text(encoding="utf-8-sig")
        # luaparser 3.3 emits its whole AST; retain only useful test output.
        with redirect_stdout(StringIO()):
            ast.parse(source)
        print(f"Parsed {filename}")

if __name__ == "__main__":
    main()
