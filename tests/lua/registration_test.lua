-- SPDX-License-Identifier: GPL-3.0-or-later
-- Checks declared tables and launcher identities; does not emulate weapon guidance.
local root=assert(arg[1]);local Host=dofile(root.."/tests/lua/host.lua")
local h=Host.New(root);local e=h.env
e.current_mod_path=root;e._=function(v) return v end
e.CAT_AIR_TO_AIR=1;e.WSTYPE_PLACEHOLDER=0;e.wsType_Weapon=4;e.wsType_Missile=4;e.wsType_AA_Missile=7
local weapons,loadouts={},{}
e.declare_weapon=function(v) weapons[#weapons+1]=v end
e.declare_loadout=function(v) assert(not loadouts[v.CLSID],"duplicate CLSID");loadouts[v.CLSID]=v end
e.predefined_warhead=function() return {} end;e.enhanced_a2a_warhead=function() return {} end
e.pylon=function(number,kind,x,y,z,args,launchers) return {Number=number,Launchers=launchers} end
e.gun_mount=function() return {} end;e.aircraft_task=function() return {} end;e.add_aircraft=function()end
e.dofile(root.."/Weapons.lua");e.dofile(root.."/F-22A.lua")
assert(#weapons==6,"only six approximate AAM definitions registered")
assert(not loadouts["{GBU32_JDAM}"] and not loadouts["{MAKO_A2G_C}"],"invalid stores quarantined")
for _,station in ipairs(e.F_22A.Pylons) do for _,v in ipairs(station.Launchers) do
 assert(v.CLSID~="{GBU32_JDAM}" and v.CLSID~="{MAKO_A2G_C}","quarantined store still offered")
end end
local cm=e.F_22A.passivCounterm
assert(cm.chaff.default*cm.chaff.chargeSz+cm.flare.default*cm.flare.chargeSz<=cm.SingleChargeTotal,"countermeasures exceed charge budget")
assert(not e.F_22A.Sensors.IRST and not e.F_22A.Sensors.OPTIC,"no unverified baseline OLS/TADS")
for _,v in pairs(loadouts) do assert(v.displayName:find("[APPROX]",1,true),"custom loadout must identify approximation") end
local payloads=e.dofile(root.."/UnitPayloads/F-22A.lua")
for _,payload in ipairs(payloads.payloads) do for _,station in pairs(payload.pylons) do
 assert(station.CLSID~="{GBU32_JDAM}" and station.CLSID~="{MAKO_A2G_C}")
end end
print("PASS weapon registration, quarantined launchers/presets, charge budget and baseline sensors")
