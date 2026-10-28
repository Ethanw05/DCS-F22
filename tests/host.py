"""Explicit host inputs for new requirement cases; never imports legacy tests."""
from pathlib import Path
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]


class Host:
    def __init__(self):
        self.lua = LuaRuntime(unpack_returned_tuples=True)
        module = self.lua.execute((ROOT / 'tests/host.lua').read_text(encoding='utf-8'))
        self.state = module.new((ROOT / 'Cockpit/Scripts').as_posix() + '/')
        self.env = self.state.env

    def seed(self, values):
        """Only the case author supplies sample provenance, validity and clocks."""
        for name, value in values.items():
            self.state['values'][name] = value

    def sensor(self, name, result):
        if isinstance(result, tuple):
            self.state.sensors[name] = lambda: result
        else:
            self.state.sensors[name] = lambda: result

    def load(self, relative):
        return self.env.dofile(str(ROOT / 'Cockpit/Scripts' / relative))

    def execute(self, source):
        execute = self.lua.eval('function(env, text) local f=assert(loadstring(text)); setfenv(f,env); return f() end')
        return execute(self.env, source)

    def update(self):
        self.env.update()

    def get(self, name):
        return self.state['values'][name]
