-- SPDX-License-Identifier: GPL-3.0-or-later
local root=assert(arg[1]);local Host=dofile(root.."/tests/lua/host.lua")
local h=Host.New(root)
h.env.require=function(name) assert(name=="i_18n");return {translate=function(v) return v end} end
h.env.class_type={BTN=1,TUMB=2,LEV=3,MOVABLE_LEV=4}
h:load("Cockpit/Scripts/clickabledata.lua")
local count=0
for name,element in pairs(h.env.elements) do
 count=count+1;assert(type(element.device)=="number",name..": invalid device")
 for _,command in ipairs(element.action) do assert(type(command)=="number",name..": invalid command") end
end
assert(h.env.elements.FORMLIGHT_PNT.device==h.env.devices.ELECTRICAL_SYSTEM,"formation light routed to its state owner")
local gauge=Host.New(root);gauge.env.LoRegisterPanelControls=function() return {} end
gauge.env.CreateGauge=function() local v={};gauge.elements[#gauge.elements+1]=v;return v end
gauge:load("Cockpit/Scripts/mainpanel_init.lua")
assert(gauge.env.R_GEAR.parameter_name=="R_GEAR_LIGHT" and gauge.env.L_GEAR.parameter_name=="L_GEAR_LIGHT")
print("PASS "..count.." clickable controls, state-owner routing and independent gear-light wiring")
