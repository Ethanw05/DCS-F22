-- SPDX-License-Identifier: GPL-3.0-or-later
local root=assert(arg[1]);local Host=dofile(root.."/tests/lua/host.lua")
local h=Host.New(root);h:load("Cockpit/Scripts/Systems/ICP_System.lua");h.env.post_initialize();h.parameters.ICP_OPACITY=1
h:command(10043);h:command(3019);h:command(3021);h:command(3025);h:command(3026);h:step(.02)
assert(h.parameters.F22_NAV_COURSE==359,"transactional keypad course entry")
h:command(3025);h:command(3025);h:command(3025);h:command(3026);h:step(.02)
assert(h.parameters.F22_NAV_COURSE==359 and h.parameters.F22_ICP_ENTRY_HINT=="INVALID ENTRY","invalid does not overwrite")
h:command(3028);h:command(10046);h:step(.02);assert(h.parameters.ICP_HUD_MENU==1)
h:command(10046,0);h:step(.02);assert(h.parameters.ICP_HUD_MENU==1,"release does not toggle menu")
h:step(10);assert(h.parameters.ICP_HUD_MENU==0,"time-based menu timeout")
h.parameters.F22_HUD_CUSTOM=1;h.parameters.F22_HUD_MODE=105;h:command(3029)
assert(h.commands[#h.commands].command==10681,"wheel controls visible custom HUD")
h.parameters.ICP_OPACITY=0;h:command(10046);h:step(.02);assert(h.parameters.ICP_HUD_MENU==0)
print("PASS ICP keypad bounds/commit, menu timing, release handling and HUD wheel routing")
