-- SPDX-License-Identifier: GPL-3.0-or-later
local root=assert(arg[1]);local Host=dofile(root.."/tests/lua/host.lua")
local h=Host.New(root);h:load("Cockpit/Scripts/Systems/MFD_System.lua");h.env.post_initialize()
h.parameters.MAIN_POWER=1;h.parameters.MFD_OPACITY=1;h.parameters.F22_HYD_LEFT_PSI=2100
h.parameters.F22_HYD_RIGHT_PSI=700;h.parameters.F22_FUEL_VALID=1;h.parameters.F22_FUEL_FLOW_LEFT_KGS=1
h:step(.02);assert(h.parameters.LMFD_ENG_PAGE==1 and h.parameters.RMFD_FUEL_PAGE==1 and h.parameters.CMFD_BAY_PAGE==1)
h:command(10061,1);h:command(10061,0);h:step(.02);assert(h.parameters.LMFD_MENU_PAGE==1,"release must not select next page")
h:command(10068);h:step(.02);assert(h.parameters.LMFD_FCS_PAGE==1 and h.parameters.LMFD_MENU_PAGE==0)
h.parameters.MFD_OPACITY=0;h.parameters.MAIN_POWER=0;h:step(.02)
for name,value in pairs(h.parameters) do if name:match("^[LRC]MFD_.+_PAGE$") then assert(value==0,"no stale pages after power loss: "..name) end end
h.parameters.MFD_OPACITY=1;h.parameters.MAIN_POWER=1;h:step(.02);assert(h.parameters.LMFD_FCS_PAGE==1,"page restored")
assert(h.parameters.L_HYD_VALUE==2100 and h.parameters.R_HYD_VALUE==700 and h.parameters.R_HYD_COLOR==1,"display consumes physical pressure")
assert(math.abs(h.parameters.L_FF_VALUE-7936.6414392)<1e-5,"kg/s to lb/hour")
h:command(10000);h:step(.02);assert(#h.commands==1 and h.commands[1].command==110,"bay select must not toggle radar")
print("PASS MFD page exclusivity, press/release, power restore, pressure/fuel units and bay command")
