"""Reference signal-state boundaries, including no radar input to tone policy."""
from pathlib import Path
from lupa.lua51 import LuaRuntime
r=Path(__file__).resolve().parents[1]
l=LuaRuntime()
l.globals().MODULE=str(r/'Cockpit/Scripts/Systems/IR_Audio.lua')
l.execute('''
local m=dofile(MODULE)
assert(m.levels(false,136,2,0,0).track==0)
assert(m.levels(true,136,0,0,0).search==1)
assert(m.levels(true,136,.7,0,0).detect==1)
assert(m.levels(true,136,.71,0,0).fov==1)
assert(m.levels(true,136,1,0,0).track==0)
assert(m.levels(true,136,2,0,0).track==1)
assert(m.levels(true,136,2,math.rad(28),0).verify==1)
assert(m.levels(true,22,0,0,0).quiet==1)
assert(m.levels(true,22,2,0,0).high==1.5)
local v=m.levels(true,22,.5,0,0)
assert(v.low==.125 and v.high==.3*.5^5 and v.pitch==.5^4)
-- Verify actual source routing and numeric Lua audio update arguments.
local sources={}
function create_sound_host(name,kind)
 assert(name=='COCKPIT_ARMS' and kind=='HEADPHONES')
 return {create_sound=function(self,path)
  local s={playing=false}
  function s:update(pitch,gain) assert(type(pitch)=='number' and type(gain)=='number');self.gain=gain end
  function s:play_continue() self.playing=true end
  function s:is_playing() return self.playing end
  function s:stop() self.playing=false end
  sources[path:match('[^/]+$')]=s;return s
 end}
end
local audio=m.new();audio:update(true,136,0,0,0)
assert(sources.search.playing and not sources.track.playing)
audio:update(true,136,2,0,0)
assert(not sources.search.playing and sources.track.playing)
audio:update(false,136,2,0,0)
for _,s in pairs(sources) do assert(not s.playing) end
''')
print('IR audio: search/detect/FOV/track, HOBS verification, legacy strength mix, power-off silence OK')
