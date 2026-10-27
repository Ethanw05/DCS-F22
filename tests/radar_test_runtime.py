"""Actual Lua owners with an explicit synthetic owned-measurement producer."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
fixture=ROOT/'tests/test_display_startup.py'
ns={'__file__':str(fixture)}
exec(compile(fixture.read_text().split('\nfor page in ',1)[0],str(fixture),'exec'),ns)
def owned_runtime():
    lua=ns['runtime']()
    lua.execute("dofile(SCRIPT_ROOT..'../../tests/owned_radar_fixture.lua')")
    return lua
