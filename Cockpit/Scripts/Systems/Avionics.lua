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

-- Display/air-data/annunciation owner. Physical power/APU state belongs to Engine_System.
-- Architecture: R09 sections 32.3.7 and 32.4. This is not the production ICAW logic.
local dev=GetSelf()
local Math=dofile(LockOn_Options.script_path.."Common/Math.lua")
local bus=dofile(LockOn_Options.script_path.."Common/Runtime.lua").New(get_base_data())
local knobs={1,1,1,1,.25,.3}
local night,swapped=false,false
local caution,previousFault,ack=false,{},false
make_default_activity(.02)
for _,c in ipairs({3001,3002,3003,3004,3005,3006,3008,3009,3010,3011,144,379,10017,10018,10027,10679}) do dev:listen_command(c) end
local function flag(v) return v and 1 or 0 end
function post_initialize()
    knobs={1,1,1,1,.25,.3};night,swapped=false,false
    caution,previousFault,ack=false,{},false
end
function SetCommand(c,v)
    if c>=3001 and c<=3006 then knobs[c-3000]=Math.Clamp(v,0,1)
    elseif c==3008 or c==10017 then night=v>.5
    elseif c==10018 and v>0 then night=not night
    elseif (c==3009 or c==3010 or c==10027) and v>0 then swapped=not swapped
    elseif c==3011 and v>0 then dispatch_action(nil,83)
    elseif (c==144 or c==379 or c==10679) and v>0 then ack=true end
end
local function draw(i) return Math.Clamp(get_cockpit_draw_argument_value(i),0,1) end
function update()
    local dc=bus.get("F22_DC_AVAILABLE")>.5
    local main=bus.get("MAIN_POWER")>.5
    local dim=night and .15 or 1 -- assumed display curve; avoids negative opacity.
    local ufd=dc and knobs[4]*dim or 0
    local mfd=main and knobs[3]*dim or 0
    for i,name in ipairs({"F22_MAP_LEFT_KNOB","F22_MAP_RIGHT_KNOB","F22_MFD_KNOB","F22_UFD_KNOB","F22_CONSOLE_KNOB","F22_FLOOD_KNOB"}) do bus.set(name,knobs[i]) end
    bus.set("DAY_NIGHT",flag(night));bus.set("UFD_OPACITY",ufd);bus.set("MFD_OPACITY",mfd)
    bus.set("ICP_OPACITY",ufd)
    bus.set("L_WAR_OPACITY",flag(not swapped and ufd>0));bus.set("R_WAR_OPACITY",flag(swapped and ufd>0))
    bus.set("R_ADI_OPACITY",flag(not swapped and ufd>0));bus.set("L_ADI_OPACITY",flag(swapped and ufd>0))
    bus.set("PANEL_LIGHT",dc and knobs[5] or 0);bus.set("FLOOD_LIGHT",dc and knobs[6] or 0)
    bus.set("F22_MAP_LEFT_LIGHT",dc and knobs[1] or 0);bus.set("F22_MAP_RIGHT_LIGHT",dc and knobs[2] or 0)
    for _,row in ipairs({{"TAS","getTrueAirSpeed",1.943844492},{"IAS","getIndicatedAirSpeed",1.943844492},
        {"GFORCE","getVerticalAcceleration",1},{"ADIPITCH","getPitch",1},{"ADIROLL","getRoll",1},
        {"SLIP","getAngleOfSlide",1},{"YAW","getRateOfYaw",1},{"ROLLRATE","getRateOfRoll",180/math.pi},
        {"PITCHRATE","getRateOfPitch",180/math.pi},{"YAWRATE","getRateOfYaw",180/math.pi},
        {"AOA","getAngleOfAttack",180/math.pi},{"VV","getVerticalVelocity",196.850394},
        {"MACH","getMachNumber",1},{"RADALT","getRadarAltitude",1},{"BAROALT","getBarometricAltitude",3.280839895},
        {"RPM_L","getEngineLeftRPM",1},{"RPM_R","getEngineRightRPM",1},
        {"EGT_L","getEngineLeftTemperatureBeforeTurbine",1},{"EGT_R","getEngineRightTemperatureBeforeTurbine",1}}) do
        bus.set(row[1],bus.sample(row[2])*row[3])
    end
    bus.set("NAV",Math.Wrap360(-bus.sample("getHeading")*180/math.pi))
    local fuel=math.max(0,bus.sample("getTotalFuelWeight"))
    local external=0
    if bus.get("F22_FUEL_VALID")>.5 then fuel=bus.get("F22_FUEL_TOTAL_KG");external=bus.get("F22_FUEL_EXTERNAL_KG") end
    bus.set("FUEL",fuel*2.204622622);bus.set("FUELL",fuel*2.204622622/100)
    bus.set("FUELT",external*2.204622622);bus.set("FUELTANK",external*2.204622622)
    for name,arg in pairs({CANOPY_LIGHT=251,CHAFF_LIGHT=254,FLARE_LIGHT=255,L_FIRE_LIGHT=126,R_FIRE_LIGHT=256}) do bus.set(name,draw(arg)) end
    bus.set("SPD_BRK_LIGHT",flag(get_aircraft_draw_argument_value(21)>.01))
    bus.set("BINGO_LIGHT",math.max(draw(225),flag(fuel<1500))) -- assumed low-fuel threshold, shared with EFM
    bus.set("FLAPS_MOVE",draw(42));bus.set("FLAPS_DOWN",flag(get_aircraft_draw_argument_value(9)>.95 and get_aircraft_draw_argument_value(10)>.95))
    bus.set("AAR_LIGHT",bus.get("AAR_READY"))
    local faults={}
    for _,side in ipairs({{"L","LEFT"},{"R","RIGHT"}}) do
        local failed=bus.get("RPM_"..side[1])>40 and bus.get("F22_GEN_"..side[2].."_AVAILABLE")<.5
        bus.set(side[1].."_GEN_OUT",flag(failed));faults[#faults+1]=failed
    end
    local hydLeft=bus.get("F22_HYD_LEFT_PSI")<1500
    local hydRight=bus.get("F22_HYD_RIGHT_PSI")<1500
    local hyd=hydLeft or hydRight
    local oilLeft,oilRight,oilHost=bus.get("L_OIL_COLOR")>.5,bus.get("R_OIL_COLOR")>.5,draw(220)>.5
    local oil=oilLeft or oilRight or oilHost
    bus.set("HYD_LIGHT",flag(hyd));bus.set("OIL_LIGHT",flag(oil))
    -- Keep independent failure edges: acknowledging the left supply must not
    -- silence a later right-supply failure just because the aggregate stayed on.
    for _,active in ipairs({hydLeft,hydRight,oilLeft,oilRight,oilHost,draw(251)>.5,draw(126)>.5,draw(256)>.5}) do faults[#faults+1]=active end
    local fault=false
    for i,active in ipairs(faults) do
        if active and not previousFault[i] then caution=true end
        fault=fault or active
    end
    if ack then caution=false;ack=false end
    previousFault=faults
    bus.set("CAUTION_LIGHT",flag(caution));bus.set("F22_WARNING_ACTIVE",flag(fault))
    -- Brightness never clears a failure or physical source parameter.
end
need_to_be_closed=false
