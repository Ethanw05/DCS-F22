-- SPDX-License-Identifier: GPL-3.0-or-later
local root=assert(arg[1]);local Host=dofile(root.."/tests/lua/host.lua")
local h=Host.New(root);h:load("Cockpit/Scripts/Systems/Avionics.lua");h.env.post_initialize()
h.parameters.F22_DC_AVAILABLE=1;h.parameters.MAIN_POWER=1
h.parameters.F22_FUEL_VALID=1;h.parameters.F22_FUEL_TOTAL_KG=3000;h.parameters.F22_FUEL_EXTERNAL_KG=400
h.parameters.F22_HYD_LEFT_PSI=4000;h.parameters.F22_HYD_RIGHT_PSI=4000
h:command(3008,1);h:command(3004,.1);h:step(.02)
assert(math.abs(h.parameters.UFD_OPACITY-.015)<1e-12,"night brightness remains positive")
assert(math.abs(h.parameters.FUELTANK-881.8490488)<1e-5,"external fuel measured, not total minus capacity")
h:command(3009,1);h:command(3009,0);h:step(.02);assert(h.parameters.R_WAR_OPACITY==1,"swap only on press")
h.draws[126]=1;h:step(.02);assert(h.parameters.L_FIRE_LIGHT==1 and h.parameters.CAUTION_LIGHT==1)
h:command(3004,0);h:step(.02);assert(h.parameters.L_FIRE_LIGHT==1 and h.parameters.UFD_OPACITY==0,"display off preserves failure")
h:command(379);h:step(.02);assert(h.parameters.CAUTION_LIGHT==0 and h.parameters.F22_WARNING_ACTIVE==1,"acknowledge does not repair")
h.draws[256]=1;h:step(.02);assert(h.parameters.CAUTION_LIGHT==1,"new fault re-annunciates while earlier fault persists")
h:command(10679);h:step(.02);assert(h.parameters.CAUTION_LIGHT==0,"dedicated acknowledge binding")
h.parameters.F22_DC_AVAILABLE=0;h:step(.02);assert(h.parameters.ICP_OPACITY==0)
print("PASS air-data/display power, bounded dimming, fuel quantity, swaps and warning persistence")
