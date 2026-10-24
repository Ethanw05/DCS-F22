-- SPDX-License-Identifier: GPL-3.0-or-later
-- Shared parameter/command bus across all active devices; does not emulate native avionics/EFM.
local root=assert(arg[1]);local Host=dofile(root.."/tests/lua/host.lua")
local params,draws,sensor,queue={},{},{},{}
local devices={}
for _,name in ipairs({"Engine_System","Electrical_System","Avionics","MFD_System","Weapon_System","ICP_System","PMFD_System","HUD_System"}) do
 local h=Host.New(root);h.parameters=params;h.draws=draws;h.sensor=sensor
 h.env.LockOn_Options.init_conditions.birth_place="GROUND_COLD"
 h.env.dispatch_action=function(_,command,value) queue[#queue+1]={command,value or 1} end
 h:load("Cockpit/Scripts/Systems/"..name..".lua");devices[name]=h;h.env.post_initialize()
end
local function run(seconds)
 for _=1,math.floor(seconds/.02+.5) do
  for _,h in pairs(devices) do h.time=h.time+.02;h.env.update() end
  local limit=0
  while #queue>0 do
   limit=limit+1;assert(limit<1000,"recursive command feedback")
   local event=table.remove(queue,1)
   for _,h in pairs(devices) do if h.listeners[event[1]] then h:command(event[1],event[2]) end end
  end
 end
end
run(.1);assert(params.MAIN_POWER==0 and params.F22_HUD_VISIBLE==0)
devices.Engine_System:command(3001,1);devices.Engine_System:command(3003,1);devices.Engine_System:command(3004,1);run(.1)
devices.Engine_System:command(3002,1);devices.Engine_System:command(3002,0);run(10.5)
assert(params.APU_READY==1 and params.MAIN_POWER==1 and params.F22_HUD_VISIBLE>0,"coherent cold battery/APU/display startup")
devices.Engine_System:command(3009,1);devices.Engine_System:command(3010,1)
sensor.getEngineLeftRPM=67;sensor.getEngineRightRPM=67;run(2)
assert(params.F22_GEN_LEFT_AVAILABLE==1 and params.F22_HYD_LEFT_PSI>1500,"generator switches and running engines supply hydraulics/power")
draws[126]=1;run(.1);devices.Avionics:command(3004,0);run(.1)
assert(params.L_FIRE_LIGHT==1 and params.UFD_OPACITY==0,"other devices must not erase warnings")
devices.Electrical_System:command(3001,1);run(.1);assert(params.AAR==1,"echo synchronized once")
run(62);assert(params.APU_POWER==0 and params.MAIN_POWER==1,"APU stops only after continuous generator availability")
print("PASS shared-bus cold start, APU/generator handoff, warnings and native command feedback")
