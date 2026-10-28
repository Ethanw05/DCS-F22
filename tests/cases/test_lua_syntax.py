"""Compile project-owned Lua with Lua 5.1; never execute aircraft/hook code."""
import subprocess
import unittest
from host import Host, ROOT


class LuaSyntax(unittest.TestCase):
    def test_tracked_lua_and_replacement_fixtures_compile(self):
        h = Host()
        files = subprocess.check_output(['git', 'ls-files', '*.lua'], cwd=ROOT,
                                        text=True).splitlines()
        files += ['tests/host.lua']
        compile_file = h.lua.eval('function(p) local f,e=loadfile(p); return f~=nil,e end')
        for name in dict.fromkeys(files):
            path = ROOT / name
            if not path.exists():
                continue  # Explicitly deleted files may remain in the Git index.
            ok, reason = compile_file(str(path))
            self.assertTrue(ok, f'{name}: {reason}')


if __name__ == '__main__':
    unittest.main()
