"""Luacheck 1.2.0 in the same Lua 5.1 runtime as cockpit tests; legacy baseline."""
from collections import Counter
from pathlib import Path
import argparse
import subprocess
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
FILES = ["Systems/" + name + ".lua" for name in (
    "Gins_Alignment", "Gins_References", "Attitude_References", "Physical_Snapshot", "Equipment_Conditions", "Combat_Logic", "Combat_System", "Entry_Transaction", "External_Light_Control", "Cockpit_References", "Equipment_Profile", "UFC_Controller",
    "Flight_Guidance", "Altitude_System", "Altitude_Settings", "Altitude_Alerts", "Recovery_Context", "Navigation_System", "MFD_Controller",
    "Fault_Registry", "Pilot_Warnings", "Pilot_Warning_System", "Warning_Audio_Gate",
    "IR_Audio", "Avionics", "Mission_Data", "Nav_Entry", "INS_Model", "Nav_Marks_Time", "Nav_Publication", "Nav_Computer", "Nav_Guidance", "Radio_Navigation", "Nav_Display_Controls", "ICP_System", "HUD_Flight_Data", "Weapon_System")]
FILES.extend(["MFD_COMMON/checklist_page.lua", "MFD_COMMON/nav_page.lua"])
HOST = ["LockOn_Options", "GetSelf", "get_base_data", "get_param_handle", "make_default_activity",
        "GetDevice", "get_model_time", "dispatch_action", "log", "devices", "Keys", "device_commands",
        "SetCommand", "CockpitEvent", "post_initialize", "update", "need_to_be_closed", "get_mission_route",
        "get_cockpit_draw_argument_value", "get_aircraft_draw_argument_value",
        "set_cockpit_draw_argument_value", "set_aircraft_draw_argument_value",
        "create_sound_host", "get_aircraft_property", "print_message_to_user",
        "SetScale", "FOV", "GetAspect", "GetScale", "MakeMaterial", "MakeFont", "CreateElement", "Add",
        "h_clip_relations"]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--luacheck-src", type=Path, default=ROOT.parent / "DCS-F22-radar/build-radar/luacheck-1.2.0/src")
    args = parser.parse_args()
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.globals().lint_path = args.luacheck_src.resolve().as_posix()
    lua.globals().lint_globals = lua.table_from(HOST)
    lua.execute('''
package.path=lint_path.."/?.lua;"..lint_path.."/?/init.lua;"..package.path
local checker=require("luacheck")
assert(checker._VERSION=="1.2.0","Use pinned Luacheck 1.2.0")
function lint(source)
 return checker.check_strings({source},{std="lua51",globals=lint_globals,max_line_length=120})[1]
end
''')
    errors, legacy = 0, 0
    for item in FILES:
        relative = "Cockpit/Scripts/" + item
        path = ROOT / relative
        old = subprocess.run(["git", "show", "f22-overhaul-start-2026-10-27:" + relative],
                             cwd=ROOT, capture_output=True)
        baseline = Counter()
        if old.returncode == 0:
            report = lua.globals().lint(old.stdout.decode("utf-8-sig"))
            baseline.update((w["code"], w["name"]) for w in report.values())
        report = lua.globals().lint(path.read_text(encoding="utf-8-sig"))
        for warning in report.values():
            key = warning["code"], warning["name"]
            if baseline[key]:
                baseline[key] -= 1
                legacy += 1
            else:
                print(f'{relative}:{warning["line"]}:{warning["column"]}: W{warning["code"]} {warning["name"] or ""}')
                errors += 1
    print(f"Lua 5.1 / Luacheck 1.2.0: {errors} new findings; {legacy} retained baseline findings")
    raise SystemExit(bool(errors))


if __name__ == "__main__":
    main()
