"""Check syntax of the modified Lua entrypoints with a pinned parser.

This catches malformed Lua before a user installs the experimental mod.
It does not validate DCS runtime functions, HUD connector names or VR optics.
"""
from pathlib import Path
from luaparser import ast

SCRIPTS = [
    Path("Cockpit/Scripts/device_init.lua"),
    Path("Cockpit/Scripts/Systems/Avionics.lua"),
    Path("Cockpit/Scripts/Systems/Engine_System.lua"),
    Path("Cockpit/Scripts/Systems/MFD_System.lua"),
    Path("Cockpit/Scripts/HUD/init.lua"),
    Path("Cockpit/Scripts/HUD/page.lua"),
    Path("Cockpit/Scripts/HUD/tactical_page.lua"),
    Path("Cockpit/Scripts/Systems/Weapon_System.lua"),
    Path("Cockpit/Scripts/Systems/Navigation_System.lua"),
    Path("Cockpit/Scripts/PMFD_CENTER/radar_page.lua"),
    Path("Cockpit/Scripts/Systems/NavGeometry.lua"),
    Path("Cockpit/Scripts/Systems/AG_Mark_System.lua"),
    Path("Cockpit/Scripts/Systems/ICP_System.lua"),
    Path("Cockpit/Scripts/clickabledata.lua"),
]

def main() -> None:
    for filename in SCRIPTS:
        source = filename.read_text(encoding="utf-8-sig")
        ast.parse(source)
        print(f"Parsed {filename}")

if __name__ == "__main__":
    main()
