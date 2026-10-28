"""Luacheck 1.2.0 in the same Lua 5.1 runtime as cockpit tests; legacy baseline."""
from collections import Counter
from pathlib import Path
import argparse
import subprocess
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
FILES = ["Systems/" + name + ".lua" for name in (
    "AESA_Control", "Radar_Track_Metadata", "Radar_Native", "Radar_Focus", "Radar_Resource", "Radar_Config",
    "Radar_Computer", "Radar_System", "Radar_Tactical", "Radar_Telemetry", "Radar_Launch_Zone", "AG_Radar_System", "AG_Radar_Modes")]
FILES.append("PMFD_CENTER/radar_format.lua")
HOST = ["LockOn_Options", "GetSelf", "get_base_data", "get_param_handle", "make_default_activity",
        "GetDevice", "get_model_time", "dispatch_action", "log", "devices", "Keys",
        "SetCommand", "post_initialize", "update", "need_to_be_closed"]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--luacheck-src", type=Path, default=ROOT / "build-radar/luacheck-1.2.0/src")
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
