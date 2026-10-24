-- SPDX-License-Identifier: GPL-3.0-or-later
local root=assert(arg[1]);local Host=dofile(root.."/tests/lua/host.lua")
local mathlib=dofile(root.."/Cockpit/Scripts/Common/Math.lua")
assert(math.abs(mathlib.CounterAngle(50,100)+math.pi)<1e-10)
assert(mathlib.CounterAngle(100,100)==0)
local x,y,valid,caged=mathlib.FlightPath(100,-10,5,85,115)
assert(x==50 and y==-100 and valid and not caged)
x,y,valid,caged=mathlib.FlightPath(10,-10,10,85,115)
assert(x==85 and y==-115 and valid and caged)
assert(select(3,mathlib.FlightPath(0,0,0,85,115))==false)
assert(select(3,mathlib.FlightPath(100,0/0,0,85,115))==false)
assert(select(3,mathlib.FlightPath(math.huge,0,0,85,115))==false)
local h=Host.New(root);h:load("Cockpit/Scripts/Systems/HUD_System.lua");h.env.post_initialize()
h.parameters.MAIN_POWER=1;h.parameters.F22_EFM_VALID=1;h.parameters.F22_VEL_BODY_X=100
h.sensor.getIndicatedAirSpeed=100;h.sensor.getHeading=-math.pi/2
h:step(.1);assert(h.parameters.F22_HUD_VISIBLE==.8);assert(h.parameters.F22_HUD_HEADING==90)
assert(#h.commands==32,"one native dim transition")
h:step(.1);assert(#h.commands==32,"no per-frame native brightness spam")
h:command(106);h:step(.02);assert(h.parameters.F22_HUD_VISIBLE==0 and #h.commands==64,"native tactical fallback")
h:command(105);h:step(.02);assert(h.parameters.F22_HUD_VISIBLE==.8)
h:command(113);h:step(.02);assert(h.parameters.F22_HUD_VISIBLE==0 and h.parameters.F22_HUD_MODE==113)
h:command(113,0);h:step(.02);assert(h.parameters.F22_HUD_MODE==113,"release does not toggle cannon")
h:command(113);h:step(.02);assert(h.parameters.F22_HUD_VISIBLE==.8,"cannon off restores previous NAV mode")
h:command(106);h:command(113);h:command(113);h:step(.02)
assert(h.parameters.F22_HUD_MODE==106,"cannon off restores previous combat mode")
h:command(105);h:command(10682,0);h:step(.02)
assert(h.parameters.F22_HUD_VISIBLE==.8,"brightness release does not step")
for _=1,100 do h:command(10682) end
h:step(.02);assert(h.parameters.F22_HUD_VISIBLE>=.05,"bounded brightness")
h.parameters.MAIN_POWER=0;h:step(.02);assert(h.parameters.F22_HUD_VISIBLE==0)
h.sensor.getHeading=math.huge;h.sensor.getPitch=0/0;h.sensor.getIndicatedAirSpeed=-math.huge
h:step(.02)
assert(h.parameters.F22_HUD_HEADING==0 and h.parameters.F22_HUD_IAS==0,"invalid air data uses finite fallback")
local page=Host.New(root);page:load("Cockpit/Scripts/HUD/page.lua")
local names={}
for _,e in ipairs(page.elements) do
 assert(not names[e.name],"unique HUD element");names[e.name]=true
 for _,c in ipairs(e.controllers or {}) do
  for i=2,2 do if type(c[i])=="number" then assert(e.element_params and c[i]<#e.element_params,"controller index") end end
 end
end
assert(#page.elements>200,"complete HUD constructed")
print("PASS HUD math, mode/power lifecycle and "..#page.elements.." element contracts; rendering not emulated")
