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
assert(m.levels(true,10042,0,0,0,true).search==1)
assert(m.levels(true,10042,2,0,0,true).track==1)
assert(m.levels(true,10042,2,math.rad(28),0,true).verify==1)
assert(m.levels(true,10042,2,0,0,true,true).track==0)
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
audio:update(true,10042,2,0,0,true)
assert(sources.track.playing and not sources.high.playing)
audio:update(true,10042,2,0,0,true,true)
for _,s in pairs(sources) do assert(not s.playing) end
-- A continuing loop is owned by requested start/stop edges. A lagging native
-- playback-status result must not restart that same loop every cockpit tick.
local starts,stops=0,0
for _,s in pairs(sources)do
 function s:is_playing()return 0 end
 function s:play_continue()starts=starts+1;self.playing=true end
 function s:stop()if self.playing then stops=stops+1 end;self.playing=false end
end
for i=1,150 do audio:update(true,136,0,0,0)end
assert(starts==1 and sources.search.playing,'steady search loop repeatedly restarted')
audio:update(true,136,2,0,0)
for i=1,150 do audio:update(true,136,2,0,0)end
assert(starts==2 and stops==1 and sources.track.playing,'steady locked loop repeatedly restarted')
audio:update(true,136,2,0,0,false,true)
assert(stops==2 and not sources.track.playing,'warning preemption retained seeker audio')
audio:update(true,136,2,0,0)
assert(starts==3,'current lock tone failed to resume after warning')
audio:update(false,136,2,0,0)
assert(stops==3)
''')
print('IR audio: search/detect/FOV/track, HOBS verification, legacy strength mix, power-off silence OK')
