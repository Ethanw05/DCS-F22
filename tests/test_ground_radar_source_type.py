"""Native object acquisition and terrain fallback retain distinct authority."""
from pathlib import Path
import contextlib
import io
import runpy

ROOT = Path(__file__).resolve().parents[1]
with contextlib.redirect_stdout(io.StringIO()):
    runtime = runpy.run_path(str(ROOT / "tests/test_display_startup.py"))["runtime"]

for mode in (1, 2, 4):
    lua = runtime()
    lua.globals().MODE = mode
    lua.execute(r'''
local v={F22_AG_RADAR_NATIVE_READY=1,F22_AG_GMT_READY=1}
local function get(n)return v[n]or 0 end
local function put(n,x)v[n]=x end
package.preload.terrain=function()return {GetHeight=function()return 50 end}end
local s=dofile(SCRIPT_ROOT..'Systems/AG_Radar_System.lua').new(get,put,function()end)
s.model.mode=MODE
local pose={north=0,altitude=3000,east=0,heading=0,pitch=0,roll=0}
s:update(pose,10,.05,true,true)
s:command('acquire',1,true,10)
put('F22_AG_NATIVE_TRACK_REQUEST_SEQUENCE',get('F22_AG_TRACK_REQUEST_SEQUENCE'))
for k,x in pairs({VALID=1,ID=0,TYPE=3,N=18550,U=50,E=0,TIME=10,VN=0,VE=0})do
 put('F22_AG_NATIVE_TRACK_'..k,x)
end
s:update(pose,10.1,.05,true,true)
assert(get('F22_AG_TRACK_VALID')==1 and get('F22_AG_FIXED_TRACK')==1)
assert(get('F22_AG_TRACK_TYPE')==3 and get('F22_AG_MODE')==MODE,'terrain fallback promoted GMTT/SSTT')
put('F22_AG_NATIVE_TRACK_TYPE',0);s:update(pose,10.2,.05,true,true)
assert(get('F22_AG_TRACK_VALID')==0,'missing native type silently gained track authority')
''')
print("Ground track: MAP/GMT/SEA FTT fallback, source type publication and invalid result withdrawal PASS")
