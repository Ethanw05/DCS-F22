"""World lead/cue damping: noise, coupling, normalization and bounded storage."""
from pathlib import Path
from lupa.lua51 import LuaRuntime
ROOT=Path(__file__).resolve().parents[1]
lua=LuaRuntime()
lua.globals().PATH=(ROOT/'Cockpit/Scripts/Systems/Gun_Cue_Stabilizer.lua').as_posix()
lua.execute("""
local module=dofile(PATH)
local sight=module.new()
local los={1,0,0}
local aim={1,0,0}
local cues={base={1,0,0},LOW={1,0,0},HIGH={1,0,0},LEFT={1,0,0},RIGHT={1,0,0}}
local previous_raw,previous,raw_step,filtered_step=0,0,0,0
for sample=1,1200 do
 local now=sample/120
 local angle=.02+(math.floor(now/.025)%2==0 and .002 or -.002)
 aim[1],aim[3]=math.cos(angle),math.sin(angle)
 local filtered=sight:primary(now,aim,los)
 local actual=math.atan2(filtered[3],filtered[1])
 assert(math.abs(filtered[1]^2+filtered[2]^2+filtered[3]^2-1)<1e-12,'aim must remain a unit ray')
 if sample>120 then raw_step=math.max(raw_step,math.abs(angle-previous_raw));filtered_step=math.max(filtered_step,math.abs(actual-previous))end
 previous_raw,previous=angle,actual
 -- Reference vectors sharing a plane and proportional angular offsets must
 -- retain those relationships through every group update.
 local turn=(math.floor(now/.1)%2==0 and .04 or -.04)
 cues.HIGH[1],cues.HIGH[2]=math.cos(turn),math.sin(turn)
 cues.LEFT[1],cues.LEFT[2]=math.cos(2*turn),math.sin(2*turn)
 cues.RIGHT[1],cues.RIGHT[2]=math.cos(-2*turn),math.sin(-2*turn)
 local out=sight:maneuver(now,cues)
 local high=math.atan2(out.HIGH[2],out.HIGH[1])
 assert(math.abs(math.atan2(out.LEFT[2],out.LEFT[1])-2*high)<1e-10)
 assert(math.abs(math.atan2(out.RIGHT[2],out.RIGHT[1])+2*high)<1e-10)
end
assert(filtered_step<raw_step*.25,'frame-to-frame lead discontinuity was not substantially reduced')
-- Constant direction is reproduced exactly after a reset; no old-target cue.
sight:reset();aim[1],aim[3]=math.cos(.02),math.sin(.02)
local out=sight:primary(20,aim,los)
assert(math.abs(math.atan2(out[3],out[1])-.02)<1e-12)
for i=1,1000 do sight:primary(20+i/120,aim,los);sight:maneuver(20+i/120,cues)end
collectgarbage('collect');collectgarbage('stop')
local before=collectgarbage('count')
for i=1001,11000 do sight:primary(20+i/120,aim,los);sight:maneuver(20+i/120,cues)end
local growth=collectgarbage('count')-before;collectgarbage('restart')
assert(growth<1,'cue damping allocated recurring tables')
print(string.format('120Hz cue control: peak frame step %.3f to %.3fmrad; coupled references; %.3fKiB/10000 callbacks',raw_step*1000,filtered_step*1000,growth))
""")
