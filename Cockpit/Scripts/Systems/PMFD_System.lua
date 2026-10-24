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

-- Radar/RWR/ECM remain F-15 host avionics. R09/R34/R36 describe real systems;
-- they do not make host contacts APG-77/ALR-94 measurements.
local dev=GetSelf()
local Math=dofile(LockOn_Options.script_path.."Common/Math.lua")
local bus=dofile(LockOn_Options.script_path.."Common/Runtime.lua").New(get_base_data())
local page=0
local board={false,false}
local garfield,tint,flood,photo,visor=0,0,0,0,0
local scan,emitting,mode=0,false,0
local echoes={}
make_default_activity(.02)
for c=3001,3020 do dev:listen_command(c) end
for c=10131,10150 do dev:listen_command(c) end
for _,c in ipairs({86,285,10005,10054,10055}) do dev:listen_command(c) end
local function native(c) echoes[c]=(echoes[c] or 0)+1;dispatch_action(nil,c) end
local function stopScan()
 if scan~=0 then dispatch_action(nil,235);scan=0 end
end
function post_initialize()
 page=LockOn_Options.init_conditions.birth_place=="GROUND_COLD" and 0 or 1
 board={false,false};garfield,tint,flood,photo,visor=0,0,0,0,0
 scan,emitting,mode=0,false,0;echoes={}
end
function SetCommand(c,v)
 if c==86 or c==285 then
  if (echoes[c] or 0)>0 then echoes[c]=echoes[c]-1
  elseif v>0 then if c==86 then emitting=not emitting else mode=1-mode end end
  return
 end
 local key=c>=3001 and c<=3020 and c-3000 or (c>=10131 and c<=10150 and c-10130)
 if key and (key==19 or key==20) and v<=0 then stopScan();return end
 if v<=0 then return end
 if c==10054 then board[1]=not board[1];return elseif c==10055 then board[2]=not board[2];return end
 if bus.get("MAIN_POWER")<.5 then return end
 if c==10005 then page=1;return end
 if not key then return end
 local original=page
 if original==0 then page=({[13]=1,[14]=2,[12]=3,[16]=4,[11]=5})[key] or page
 elseif (original==1 and key==13) or (original~=1 and key==15) then page=0 end
 if page~=original then stopScan();return end
 if page==1 then
  if key==6 then dispatch_action(nil,104)
  elseif key==7 then dispatch_action(nil,103)
  elseif key==11 and not bus.wow() then emitting=not emitting;native(86)
  elseif key==14 and not bus.wow() then dispatch_action(nil,394)
  elseif key==15 and not bus.wow() then mode=1-mode;native(285)
  elseif (key==19 or key==20) and not bus.wow() then
   local target=key==20 and 1 or -1
   if scan~=target then stopScan();scan=target;dispatch_action(nil,scan>0 and 90 or 91) end
  end
 elseif page==4 and bus.wow() then
  if key==16 then garfield=1-garfield elseif key==17 then photo=1-photo
  elseif key==18 then flood=(flood+1)%4 elseif key==19 then visor=(visor+1)%5
  elseif key==20 then tint=(tint+1)%3 end
 end
end
local function flag(v) return v and 1 or 0 end
function update()
 local power=bus.get("MFD_OPACITY")>0
 if not power or bus.wow() then stopScan() end
 for i,name in ipairs({"MENU","RDR","MAP","SYS","CONFIG","SFM"}) do bus.set("PMFD_"..name.."_PAGE",flag(power and page==i-1)) end
 bus.set("PMFD_MASK",flag(power and page==1));bus.set("PMFD_BLANK_PAGE",0)
 bus.set("RADAR_MODE",mode);bus.set("RADAR_PWR",flag(emitting))
 bus.set("F22_RADAR_STATE_VALID",0) -- command estimate only; no verified host status API
 bus.set("GARFIELD",garfield);bus.set("TINT",tint*.5);bus.set("FLOOD_COLOR",flood*.2)
 bus.set("PHOTO",photo);bus.set("VISOR",visor*.1)
 bus.set("CLIPBOARD_L",flag(board[1]));bus.set("CLIPBOARD_R",flag(board[2]))
 -- Decorative flexible tail only. It does not move aerodynamic control surfaces.
 bus.set("GARFIELD_ROLL",Math.Clamp(bus.sample("getRateOfRoll")*.18,-1,1))
 bus.set("GARFIELD_PITCH",Math.Clamp(bus.sample("getRateOfPitch")*.18,-1,1))
 set_aircraft_draw_argument_value(620,garfield);set_aircraft_draw_argument_value(619,tint*.5);set_aircraft_draw_argument_value(621,visor*.1)
 -- EFM contact feedback owns WoW. A display must not overwrite it.
end
need_to_be_closed=false
