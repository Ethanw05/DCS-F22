"""Pinned luacheck 1.2.0 through Lua 5.1; retain only identified legacy warnings.

Install lupa==2.6 and clone lunarmodules/luacheck at tag v1.2.0. Pass its
directory explicitly. No simulator process, global Lua installation, or lfs CLI
dependency is needed; this uses luacheck's documented check_strings library API.
"""
from pathlib import Path
import argparse
import json
import subprocess
from collections import Counter
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
FILES = ['Cockpit/Scripts/Systems/Engine_System.lua',
         'Cockpit/Scripts/Systems/Vehicle_Power_Adapter.lua',
         'Cockpit/Scripts/Systems/Engine_Status.lua']

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--luacheck', type=Path, required=True)
    parser.add_argument('--report', type=Path, required=True)
    args = parser.parse_args()
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.globals().LINT_PATH = (args.luacheck.resolve() / 'src').as_posix()
    lua.execute("package.path=LINT_PATH..'/?.lua;'..LINT_PATH..'/?/init.lua;'..package.path")
    lua.execute("dofile([=[" + (ROOT/'.luacheckrc').as_posix() + "]=])")
    check = lua.eval('''function(source)
        local lint=require('luacheck')
        assert(lint._VERSION=='1.2.0')
        return lint.check_strings({source}, {std=std, max_line_length=max_line_length,
            globals=globals, read_globals=read_globals})
    end''')
    report = {'tool': 'luacheck 1.2.0 / lupa 2.6 Lua 5.1', 'files': []}
    new_count = 0
    for name in FILES:
        current = (ROOT/name).read_text(encoding='utf-8-sig')
        prior = subprocess.run(['git', 'show', 'f22-overhaul-start-2026-10-27:' + name],
                               cwd=ROOT, capture_output=True)
        baseline = prior.stdout.decode('utf-8-sig') if prior.returncode == 0 else ''
        def warnings(source):
            lines = source.splitlines()
            checked = check(source)
            if checked[1]['fatal']:
                raise RuntimeError(checked[1]['msg'])
            return Counter((warning['code'], warning['name'] or '', lines[int(warning['line'])-1].strip())
                           for _, warning in checked[1].items() if hasattr(warning, 'items'))
        old = warnings(baseline)
        now = warnings(current)
        introduced = now - old
        new_count += sum(introduced.values())
        report['files'].append({'path': name, 'legacy_warnings': sum(old.values()),
            'current_warnings': sum(now.values()),
            'new_warnings': [{'code': key[0], 'name': key[1], 'source': key[2], 'count': count}
                             for key, count in introduced.items()]})
    args.report.write_text(json.dumps(report, indent=2), encoding='utf-8')
    print(json.dumps(report, indent=2))
    return 1 if new_count else 0

if __name__ == '__main__':
    raise SystemExit(main())
