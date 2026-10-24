-- SPDX-License-Identifier: GPL-3.0-or-later
local root=assert(arg[1]);local Host=dofile(root.."/tests/lua/host.lua")
local h=Host.New(root);h:load("Cockpit/Scripts/Systems/PMFD_System.lua");h.env.post_initialize()
h.parameters.MAIN_POWER=1;h.parameters.MFD_OPACITY=1;h.parameters.WoW=0
h:command(10141);h:command(86);h:step(.02);assert(h.parameters.RADAR_PWR==1,"native echo does not double-toggle")
h:command(86);h:step(.02);assert(h.parameters.RADAR_PWR==0,"native keyboard power reflected as command estimate")
h:command(10150,1);assert(h.commands[#h.commands].command==90,"antenna elevation, not TDC motion")
local count=#h.commands;h:step(.2);assert(#h.commands==count,"no per-frame selector command spam")
h:command(10150,0);assert(h.commands[#h.commands].command==235,"release stops antenna")
h:command(10149,1);h.parameters.MFD_OPACITY=0;h:step(.02);assert(h.commands[#h.commands].command==235,"power loss stops antenna")
for name,value in pairs(h.parameters) do if name:match("^PMFD_.+_PAGE$") then assert(value==0) end end
assert(h.parameters.WoW==0,"display does not own physics contact")
print("PASS PMFD native command synchronization, antenna release, exclusive power gating and WOW ownership")
