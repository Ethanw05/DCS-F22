-- SPDX-License-Identifier: GPL-3.0-or-later
local root=assert(arg[1]);local Host=dofile(root.."/tests/lua/host.lua")
local h=Host.New(root);h:load("Cockpit/Scripts/Systems/Weapon_System.lua");h.env.post_initialize()
h.parameters.MAIN_POWER=1;h.parameters.BAY_STATION=2;h:command(3001,1);h:command(106);h:command(10026,1)
h:step(.2);assert(h.parameters.F22_RELEASE_READY==0,"release waits for bay clearance")
h:step(.22);assert(h.parameters.F22_RELEASE_READY==1,"release after achieved clearance")
for _,arg in ipairs({600,601,602}) do assert(h.draws[arg]>=.98,"unknown host station: all bays clear") end
local count=#h.commands;h:step(.1);assert(#h.commands==count,"no per-frame fire command spam")
h.parameters.MAIN_POWER=0;h:step(.02);assert(h.commands[#h.commands].command==351,"power loss stops native release")
h:command(10026,0);h.parameters.MAIN_POWER=1;h:step(.5);assert(h.parameters.F22_RELEASE_READY==0,"no automatic resumption")
h:command(10022,1);h:step(.24);assert(h.parameters.F22_GUN_READY==1)
h:command(10022,0);assert(h.commands[#h.commands].command==85,"release always stops gun")
h.parameters.WoW=1;h:command(10026,1);h:step(.6);assert(h.parameters.F22_RELEASE_READY==0,"real WOW inhibits weapons")
h:command(3001,0);h:command(3001,0);h:step(.02);assert(h.parameters.MASTER_ARM==0,"master arm idempotent")
for _,arg in ipairs({600,601,602,614,615}) do assert(h.draws[arg]>=0 and h.draws[arg]<=1,"animation bounded") end
print("PASS stores clearance, power/arm/WOW inhibits, command cancellation and bounded animation")
