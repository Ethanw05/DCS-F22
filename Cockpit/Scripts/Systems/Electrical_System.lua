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

-- Switch requests have one owner; animation arguments are outputs, not switch storage.
-- No public F-22 wiring diagram is available: these are explicit simulator conventions.
dofile(LockOn_Options.script_path.."command_defs.lua")
local dev=GetSelf()
local Math=dofile(LockOn_Options.script_path.."Common/Math.lua")
local bus=dofile(LockOn_Options.script_path.."Common/Runtime.lua").New(get_base_data())
local aar,taxi,nav,formation,aarLight,master=0,0,0,.5,.5,true
local ownNativeRefuel=0
make_default_activity(.02)
for _,command in ipairs({155,175,328,3001,3002,3003,3004,3007,10015,10016,
    10151,10152,10153,10154,10505,10506,10507,10508,10509,10510,10511,10512}) do dev:listen_command(command) end
local function requestRefuel(value)
    if value==aar then return end
    aar=value
    -- The queued host command can also be observed by listen_command. Count our echoes.
    ownNativeRefuel=ownNativeRefuel+1
    dispatch_action(nil,155)
end
function post_initialize()
    aar,taxi,nav,formation,aarLight,master=0,0,0,.5,.5,true
    ownNativeRefuel=0
    bus.set("F22_ELECTRICAL_VALID",0)
end
function SetCommand(command,value)
    if command==155 then
        if ownNativeRefuel>0 then ownNativeRefuel=ownNativeRefuel-1 elseif value>0 then aar=1-aar end
    elseif command==3001 or command==10015 then requestRefuel(value>.5 and 1 or 0)
    elseif command==10016 and value>0 then requestRefuel(1-aar)
    elseif command==3002 then aarLight=Math.Clamp(value,0,1)
    elseif command==3003 then nav=math.floor(Math.Clamp(value,0,.4)*10+.5)/10
    elseif command==3004 then taxi=value<-.5 and -1 or (value>.5 and 1 or 0)
    elseif command==3007 then formation=Math.Clamp(value,0,1)
    elseif command==10151 then taxi=value>.5 and -1 or 0
    elseif command==10153 then taxi=value>.5 and 1 or 0
    elseif (command==10152 or command==10505) and value>0 then taxi=taxi==-1 and 0 or -1
    elseif (command==10154 or command==10506 or command==328) and value>0 then taxi=taxi==1 and 0 or 1
    elseif command==10507 and value>0 then formation=formation>0 and 0 or .5
    elseif command==10508 and value>0 then nav=nav==.4 and 0 or .4
    elseif command==10509 and value>0 then nav=nav==.3 and 0 or .3
    elseif command==10510 and value>0 then aarLight=aarLight>0 and 0 or .5
    elseif command==10511 and value>0 then nav=nav>.1 and 0 or .2
    elseif (command==10512 or command==175) and value>0 then master=not master end
end
function update()
    bus.set("AAR",aar)
    -- Host animates door 22. Read its achieved position before accepting tanker fuel.
    bus.set("AAR_READY",aar>.5 and get_aircraft_draw_argument_value(22)>.98 and 1 or 0)
    bus.set("TAXI_SWITCH",taxi);bus.set("NAV_LIGHT_SWITCH",nav)
    bus.set("FORM_KNOB",formation);bus.set("AAR_KNOB",aarLight)
    bus.set("F22_EXTERNAL_LIGHTS_MASTER",master and 1 or 0)
    bus.set("F22_ELECTRICAL_VALID",1)
end
need_to_be_closed=false
