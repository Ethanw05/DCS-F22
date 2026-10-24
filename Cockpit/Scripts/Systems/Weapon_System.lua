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

-- R09 32.3.5: stores management owns bay doors and armament. Host retains actual weapons.
local dev=GetSelf()
local Math=dofile(LockOn_Options.script_path.."Common/Math.lua")
local bus=dofile(LockOn_Options.script_path.."Common/Runtime.lua").New(get_base_data())
local Stores=dofile(LockOn_Options.script_path.."Common/Stores.lua")
local state=Stores.New()
local mode=105
local activeGun,activePickle=false,false
local ecm=false
make_default_activity(.02)
for _,c in ipairs({3001,3002,10006,10024,10007,10008,10021,10022,10026,136,101}) do dev:listen_command(c) end
for c=105,113 do dev:listen_command(c) end
local function flag(v) return v and 1 or 0 end
local function output(gun,pickle)
 if gun~=activeGun then dispatch_action(nil,gun and 84 or 85);activeGun=gun end
 if pickle~=activePickle then dispatch_action(nil,pickle and 350 or 351);activePickle=pickle end
end
function post_initialize()
 state=Stores.New();mode=105;ecm=false
 -- Clear host-held commands on initialization too.
 dispatch_action(nil,85);dispatch_action(nil,351);activeGun,activePickle=false,false
end
function SetCommand(c,v)
 if c==3001 or c==10007 then state.armed=v>.5
 elseif c==10008 and v>0 then state.armed=not state.armed
 elseif c==10006 then state.override=v>0
 elseif c==10024 and v>0 then state.override=not state.override
 elseif c==10021 then state.first=v>0
 elseif c==10022 then state.gun=v>0
 elseif c==10026 then state.pickle=v>0
 elseif c==3002 and v>0 then dispatch_action(nil,178) -- retained external-tank emergency jettison
 elseif c>=105 and c<=113 then
  if mode~=c then Stores.Cancel(state);output(false,false) end
  mode=c
 elseif c==101 then Stores.Cancel(state);output(false,false)
 elseif c==136 and v>0 then ecm=not ecm end
 if not state.armed then Stores.Cancel(state);output(false,false) end
 -- Release transitions are honored even after electrical failure.
 if c==10022 and v<=0 then output(false,activePickle) end
 if c==10026 and v<=0 then output(activeGun,false) end
end
function update()
 local power=bus.get("MAIN_POWER")>.5
 local wow=bus.wow()
 local hyd=Math.Clamp((math.max(bus.get("F22_HYD_LEFT_PSI"),bus.get("F22_HYD_RIGHT_PSI"))-500)/3500,0,1)
 if bus.get("F22_SYSTEMS_VALID")<.5 then hyd=power and 1 or 0 end
 if wow and bus.get("GROUND_POWER")>.5 then hyd=1 end -- assumed ground-service actuation
 local gun,pickle,permitted=Stores.Step(state,.02,{power=power,wow=wow,combat=mode~=105,
  bay=bus.get("BAY_STATION"),groundOverride=bus.get("GROUND_ORIDE")>.5,authority=power and hyd or 0})
 output(gun,pickle)
 for i,arg in ipairs({601,600,602,614}) do set_aircraft_draw_argument_value(arg,state.door[i]) end
 set_aircraft_draw_argument_value(615,state.phase)
 bus.set("BAY_L_ARG",state.door[1]);bus.set("BAY_C_ARG",state.door[2]);bus.set("BAY_R_ARG",state.door[3])
 bus.set("MASTER_ARM",flag(state.armed));bus.set("ARM_STATUS",wow and 2 or flag(permitted))
 bus.set("AIR_ORIDE",flag(state.override));bus.set("ORIDE_X",flag(not wow));bus.set("ORIDE_TEXT",flag(wow and bus.get("GROUND_ORIDE")>.5))
 bus.set("ECM_ARG",flag(ecm));bus.set("HUD_MODE",mode-104);bus.set("DOGFIGHT",flag(mode>=107 and mode<=110))
 bus.set("DETENT",state.gun and 1 or (state.first and .5 or 0));bus.set("PICKLE",flag(state.pickle))
 bus.set("F22_RELEASE_READY",flag(pickle));bus.set("F22_GUN_READY",flag(gun))
end
need_to_be_closed=false
