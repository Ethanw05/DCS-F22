-- SPDX-License-Identifier: GPL-3.0-or-later
-- Simplified IVSC-style supply model: R22 architecture, not production plumbing.
local Math = dofile(LockOn_Options.script_path.."Common/Math.lua")
local Vehicle = {}
function Vehicle.New(hot)
    return {battery=hot, batteryAh=25, generator={hot,hot}, apuRequest=false,
        apu=0, autoOff=0, hydraulic={hot and 4000 or 0, hot and 4000 or 0},
        dc=hot, main=hot, genAvailable={hot,hot}, apuReady=false,startAvailable=false}
end
function Vehicle.Step(s, dt, rpm, groundPower, fault)
    fault=fault or {}
    if fault.apu then s.apuRequest=false end
    local batteryAvailable=s.battery and s.batteryAh>.05
    if s.apuRequest and (batteryAvailable or groundPower or s.main) and not fault.apu then
        s.apu=Math.Approach(s.apu,1,1/10,dt)
    else
        s.apu=Math.Approach(s.apu,0,1/6,dt)
        if not batteryAvailable and not groundPower and not s.main then s.apuRequest=false end
    end
    local ready=s.apu>=.95 and s.apuRequest and not fault.apu
    s.apuReady=ready
    for i=1,2 do
        local previous=s.genAvailable[i]
        s.genAvailable[i]=s.generator[i] and not fault["generator"..i] and rpm[i]>=(previous and 58 or 63)
        local pump=Math.Clamp((rpm[i]-20)/45,0,1)
        local target=(fault.hydraulic or fault["hydraulic"..i]) and 0 or 4000*pump
        s.hydraulic[i]=Math.Lag(s.hydraulic[i],target,target>s.hydraulic[i] and 2 or 6,dt)
        s.hydraulic[i]=Math.Clamp(s.hydraulic[i],0,4000)
    end
    local supply=groundPower or ready or s.genAvailable[1] or s.genAvailable[2]
    s.main=supply
    s.dc=supply or batteryAvailable
    s.startAvailable=ready or groundPower
    local current=s.battery and (supply and -5 or (10+(s.apuRequest and 70 or 0))) or 0
    s.batteryAh=Math.Clamp(s.batteryAh-current*dt/3600,0,25)
    if ready and s.genAvailable[1] and s.genAvailable[2] then s.autoOff=s.autoOff+dt else s.autoOff=0 end
    if s.autoOff>=60 then s.apuRequest=false;s.autoOff=0 end
end
return Vehicle
