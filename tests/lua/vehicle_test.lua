-- SPDX-License-Identifier: GPL-3.0-or-later
local root=assert(arg[1]);local Host=dofile(root.."/tests/lua/host.lua")
local h=Host.New(root);h:load("Cockpit/Scripts/Common/Vehicle.lua")
local Vehicle=h:load("Cockpit/Scripts/Common/Vehicle.lua")
local s=Vehicle.New(false)
Vehicle.Step(s,.02,{0,0},false);assert(not s.dc and not s.main)
s.battery=true;s.apuRequest=true
for _=1,500 do Vehicle.Step(s,.02,{0,0},false) end
assert(s.startAvailable and s.main and s.dc,"APU powers modeled main/essential supplies")
for _=1,2000 do Vehicle.Step(s,.02,{70,70},false) end
Vehicle.Step(s,.02,{0,70},false);assert(s.autoOff==0,"APU auto-stop requires uninterrupted conditions")
for _=1,2000 do Vehicle.Step(s,.02,{70,70},false,{hydraulic=true}) end
assert(s.hydraulic[1]<10 and s.hydraulic[2]<10,"symmetric hydraulic fault")
local a,b=Vehicle.New(true),Vehicle.New(true)
for _=1,1000 do Vehicle.Step(a,.01,{0,0},false) end
for _=1,100 do Vehicle.Step(b,.1,{0,0},false) end
assert(math.abs(a.hydraulic[1]-b.hydraulic[1])<1e-7,"time-based pressure decay")
h=Host.New(root);h.env.LockOn_Options.init_conditions.birth_place="GROUND_COLD"
h.sensor.getWOW_NoseLandingGear=1
h:load("Cockpit/Scripts/Systems/Engine_System.lua");h.env.post_initialize()
h:command(3001,1);h:command(3001,1);h:step(.04);assert(h.parameters.BATTERY_POWER==1,"idempotent battery switch")
h:command(10025,1);h:command(10025,0);h:step(10.1);assert(h.parameters.APU_READY==1,"APU key release does not reverse request")
h:command(10056,0);h:command(10057,1);h:step(.02)
assert(h.parameters.F22_BRAKE_LEFT==.5 and h.parameters.F22_BRAKE_RIGHT==1)
h:command(10659,1);h:command(10660,1);h:command(10661,1);h:step(.02)
assert(h.parameters.F22_BRAKE_LEFT==.5 and h.parameters.F22_BRAKE_RIGHT==1,"left release preserves right request")
print("PASS vehicle supplies, APU interruption, hydraulic faults, time consistency and engine/brake commands")
