"""Compile project-owned Lua with Lua 5.1; never execute aircraft/hook code."""
import subprocess
from pathlib import Path
import tempfile
import unittest
from host import Host, ROOT


class LuaSyntax(unittest.TestCase):
    def test_cli_compiles_without_executing_and_reports_each_failure(self):
        h = Host()
        with tempfile.TemporaryDirectory() as directory:
            good = Path(directory) / 'good.lua'
            bad = Path(directory) / 'bad.lua'
            good.write_text('unexpected_execution=1', encoding='utf-8')
            bad.write_text('local = invalid', encoding='utf-8')
            h.env.arg = h.lua.table_from([str(good)])
            h.execute((ROOT / 'tools/check_lua_syntax.lua').read_text())
            self.assertIsNone(h.env.unexpected_execution)
            h.env.arg = h.lua.table_from([str(good), str(bad)])
            with self.assertRaisesRegex(Exception, '1/2 Lua sources failed compilation'):
                h.execute((ROOT / 'tools/check_lua_syntax.lua').read_text())

    def test_cli_requires_a_bounded_explicit_file_list(self):
        h = Host()
        h.env.arg = h.lua.table_from([])
        with self.assertRaisesRegex(Exception, 'Supply 1..4096'):
            h.execute((ROOT / 'tools/check_lua_syntax.lua').read_text())

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
