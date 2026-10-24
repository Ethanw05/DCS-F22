--[[
    Grinnelli Designs F-22A Raptor
    Copyright (C) 2024, Joseph Grinnelli
    
    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.
    
    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.
    
    You should have received a copy of the GNU General Public License
    along with this program.  If not, see https://www.gnu.org/licenses.
--]]


-- Power/APU/engine-command owner. Research and assumptions: docs/OVERNIGHT_OVERHAUL.md.
local dev, sensor = GetSelf(), get_base_data()
dofile(LockOn_Options.script_path.."command_defs.lua")
local Math = dofile(LockOn_Options.script_path.."Common/Math.lua")
local Runtime = dofile(LockOn_Options.script_path.."Common/Runtime.lua")
local Vehicle = dofile(LockOn_Options.script_path.."Common/Vehicle.lua")
local bus=Runtime.New(sensor)
local dt=.02
make_default_activity(dt)
local state=Vehicle.New(false)
local cutoff={false,false}
local throttle={1,1}
local pedal={-1,-1}
local brakeKeys={false,false}
local parking=false
local nativePower=false
local clam={1,1}
local cart=-1
local sounds={}
local soundPhase="off"
local function flag(v) return v and 1 or 0 end
local function clicked(value) return value>.5 end
local commands={3001,3002,3003,3004,3009,3010,3011,3012,309,310,311,312,313,314,
    2004,2005,2006,74,75,10009,10010,10011,10012,10013,10014,10019,10020,
    10023,10025,10028,10029,10038,10039,10056,10057,10058,10659,10660,10661,10662}
for _,command in ipairs(commands) do dev:listen_command(command) end
dev:listen_event("GroundPowerOn");dev:listen_event("GroundPowerOff")
local function requestStart(index,forward)
    if bus.wow() and not state.startAvailable then
        cutoff[index]=false
        dispatch_action(nil,index==1 and 313 or 314)
        print_message_to_user("Engine start requires APU READY or ground start supply")
        return
    end
    cutoff[index]=true
    if forward then dispatch_action(nil,index==1 and 311 or 312) end
end
local function stopEngine(index,forward)
    cutoff[index]=false
    if forward then dispatch_action(nil,index==1 and 313 or 314) end
end
function post_initialize()
    local hot=LockOn_Options.init_conditions.birth_place~="GROUND_COLD"
    state=Vehicle.New(hot);cutoff={hot,hot};nativePower=hot
    throttle={1,1};pedal={-1,-1};brakeKeys={false,false};parking=false
    clam={hot and 0 or 1,hot and 0 or 1};cart=-1;soundPhase="off"
    bus.set("GROUND_POWER",0)
    bus.set("F22_SYSTEMS_VALID",0)
    if type(create_sound_host)=="function" then
        local host=create_sound_host("EXTERNAL_AIRCRAFT","3D",0,0,0)
        for _,phase in ipairs({"start","run","stop"}) do sounds[phase]=host:create_sound("Aircrafts/F-22A/External/apu_"..phase) end
    end
end
function CockpitEvent(event)
    if event=="GroundPowerOn" then bus.set("GROUND_POWER",1) end
    if event=="GroundPowerOff" then bus.set("GROUND_POWER",0) end
end
function SetCommand(command,value)
    if command==3001 then state.battery=clicked(value)
    elseif command==10009 then state.battery=clicked(value)
    elseif command==10010 and value>0 then state.battery=not state.battery
    elseif command==3003 or command==10011 then state.generator[1]=clicked(value)
    elseif command==3004 or command==10013 then state.generator[2]=clicked(value)
    elseif command==10012 and value>0 then state.generator[1]=not state.generator[1]
    elseif command==10014 and value>0 then state.generator[2]=not state.generator[2]
    elseif command==3002 then
        if value>0 then state.apuRequest=state.dc elseif value<0 then state.apuRequest=false end
    elseif command==10025 and value>0 then state.apuRequest=not state.apuRequest and state.dc
    elseif command==3009 and value>0 then requestStart(1,true)
    elseif command==3010 and value>0 then requestStart(2,true)
    elseif command==311 then requestStart(1,false)
    elseif command==312 then requestStart(2,false)
    elseif command==309 then requestStart(1,false);requestStart(2,false)
    elseif command==313 then stopEngine(1,false)
    elseif command==314 then stopEngine(2,false)
    elseif command==310 then stopEngine(1,false);stopEngine(2,false)
    elseif (command==10028 or command==10029) and value>0 then
        local i=command==10028 and 1 or 2
        if cutoff[i] then stopEngine(i,true) else requestStart(i,true) end
    elseif command==2004 then throttle={Math.Clamp(value,-1,1),Math.Clamp(value,-1,1)}
    elseif command==2005 then throttle[1]=Math.Clamp(value,-1,1)
    elseif command==2006 then throttle[2]=Math.Clamp(value,-1,1)
    elseif command==3011 and value>0 then dispatch_action(nil,Keys.PlaneGear)
    elseif command==3012 or command==10019 then parking=clicked(value)
    elseif command==10020 and value>0 then parking=not parking
    elseif command==10056 then pedal[1]=Math.Clamp(value,-1,1)
    elseif command==10057 then pedal[2]=Math.Clamp(value,-1,1)
    elseif command==10058 or command==10023 then pedal={Math.Clamp(value,-1,1),Math.Clamp(value,-1,1)}
    elseif command==10659 then brakeKeys[1]=value>0
    elseif command==10660 then brakeKeys[2]=value>0
    elseif command==10661 then brakeKeys[1]=false
    elseif command==10662 then brakeKeys[2]=false
    elseif command==10038 or command==74 then brakeKeys={true,true}
    elseif command==10039 or command==75 then brakeKeys={false,false} end
end
local function soundUpdate()
    local phase=state.apuRequest and (state.apu>=.95 and "run" or "start") or "off"
    if phase~=soundPhase then
        for _,sound in pairs(sounds) do if sound.stop then sound:stop() end end
        if phase=="run" and sounds.run then sounds.run:play_continue()
        elseif phase=="start" and sounds.start then sounds.start:play_once()
        elseif phase=="off" and sounds.stop and soundPhase~="off" then sounds.stop:play_once() end
        soundPhase=phase
    end
end
function update()
    local rpm={bus.sample("getEngineLeftRPM"),bus.sample("getEngineRightRPM")}
    local commonFault=get_cockpit_draw_argument_value(208)>.5
    Vehicle.Step(state,dt,rpm,bus.get("GROUND_POWER")>.5,{
        hydraulic=commonFault,
        hydraulic1=bus.get("F22_FAIL_HYD_LEFT")>.5,hydraulic2=bus.get("F22_FAIL_HYD_RIGHT")>.5,
        generator1=bus.get("F22_FAIL_GEN_LEFT")>.5,generator2=bus.get("F22_FAIL_GEN_RIGHT")>.5})
    if state.dc~=nativePower then dispatch_action(nil,Keys.PowerOnOff);nativePower=state.dc end
    bus.set("BATTERY_POWER",flag(state.battery));bus.set("MAIN_POWER",flag(state.main))
    bus.set("F22_DC_AVAILABLE",flag(state.dc));bus.set("F22_BATTERY_SOC",state.batteryAh/25)
    bus.set("APU_RPM_STATE",state.apu*4);bus.set("APU_POWER",flag(state.apuRequest and state.apu>=.95))
    bus.set("APU_READY",flag(state.startAvailable));bus.set("APU_SPOOL",flag(state.apuRequest and state.apu<.95))
    bus.set("F22_START_AVAILABLE",flag(state.startAvailable))
    for i,side in ipairs({"L","R"}) do
        if bus.get("F22_FUEL_VALID")>.5 then
            throttle[i]=bus.get("F22_THROTTLE_"..(i==1 and "LEFT" or "RIGHT").."_RAW")
            cutoff[i]=bus.get("F22_ENGINE_"..(i==1 and "LEFT" or "RIGHT").."_RUN")>.5
        end
        bus.set(side.."_GEN_POWER",flag(state.generator[i]));bus.set("F22_GEN_"..(i==1 and "LEFT" or "RIGHT").."_AVAILABLE",flag(state.genAvailable[i]))
        bus.set("F22_HYD_"..(i==1 and "LEFT" or "RIGHT").."_PSI",state.hydraulic[i])
        bus.set(side.."_THROTTLE_CUT",flag(cutoff[i]));bus.set(side.."_THROTTLE_POS",cutoff[i] and throttle[i] or 1)
        local request=math.max((pedal[i]+1)*.5,flag(brakeKeys[i]),flag(parking))
        bus.set("F22_BRAKE_"..(i==1 and "LEFT" or "RIGHT"),request)
        bus.set(side.."_TOE",request*2-1)
        clam[i]=Math.Approach(clam[i],rpm[i]<35 and 1 or 0,.21,dt)
        set_aircraft_draw_argument_value(i==1 and 611 or 610,clam[i])
        local name=i==1 and "LTHROT_PNT" or "RTHRT_PNT"
        if type(get_clickable_element_reference)=="function" then local ref=get_clickable_element_reference(name);if ref and ref.update then ref:update() end end
    end
    bus.set("PARK",flag(parking));bus.set("B_TOE",math.max(bus.get("L_TOE"),bus.get("R_TOE")))
    bus.set("F22_SYSTEMS_VALID",1)
    cart=Math.Approach(cart,bus.get("GROUND_POWER")>.5 and 1 or -1,.5,dt)
    set_aircraft_draw_argument_value(616,cart>-.99 and 1 or 0);set_aircraft_draw_argument_value(617,cart)
    set_aircraft_draw_argument_value(618,(get_absolute_model_time()*2)%1)
    soundUpdate()
end
need_to_be_closed=false
