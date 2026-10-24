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

-- R09 CNI/controls roles. Keypad reference entry is a mod feature, not a production ICP replica.
local dev=GetSelf()
local bus=dofile(LockOn_Options.script_path.."Common/Runtime.lua").New(get_base_data())
local menu,timer,buffer,error="",0,"",false
local course,altitude=0,10000
make_default_activity(.02)
for c=3001,3032 do dev:listen_command(c) end
for c=10041,10053 do dev:listen_command(c) end
local aliases={[10041]=1,[10042]=2,[10043]=3,[10044]=4,[10045]=5,[10046]=6,
 [10047]=15,[10048]=8,[10049]=9,[10050]=10,[10051]=11,[10052]=12,[10053]=7}
local function select(value) menu=value;timer=0;buffer="";error=false end
function post_initialize() menu,timer,buffer,error="",0,"",false;course,altitude=0,10000 end
function SetCommand(c,v)
 if v<=0 or bus.get("ICP_OPACITY")<=0 then return end
 local key=aliases[c] or (c>=3001 and c<=3032 and c-3000)
 if not key then return end
 timer=0
 if key==1 or key==2 then
  select("");dispatch_action(nil,179) -- host communications menu; no invented COM2 frequency interface
 elseif key==3 then select("COURSE");dispatch_action(nil,105)
 elseif key==4 then select("STPT")
 elseif key==5 then select("ALT")
 elseif key==6 then select(menu=="HUD" and "" or "HUD")
 elseif key==7 then dispatch_action(nil,156)
 elseif key==15 then select(menu=="AP" and "" or "AP")
 elseif key==13 then dispatch_action(nil,102)
 elseif key==14 then dispatch_action(nil,1315)
 elseif key==16 then dispatch_action(nil,1587) -- kneeboard reference, not a simulated INS markpoint
 elseif key==29 or key==30 then
  local custom=bus.get("F22_HUD_CUSTOM")>.5 and bus.get("F22_HUD_MODE")==105
  dispatch_action(nil,custom and (key==29 and 10681 or 10682) or (key==29 and 746 or 747))
 elseif key>=8 and key<=12 then
  if menu=="HUD" then dispatch_action(nil,({105,106,107,108,110})[key-7])
  elseif menu=="AP" then local action=({389,62,408})[key-7];if action then dispatch_action(nil,action) end end
 elseif (menu=="COURSE" or menu=="ALT") and ((key>=17 and key<=25) or key==27) then
  local digit=key==27 and 0 or key-16
  local maxDigits=menu=="COURSE" and 3 or 5
  if #buffer<maxDigits then buffer=buffer..digit;error=false else error=true end
 elseif key==26 and (menu=="COURSE" or menu=="ALT") then
  local value=tonumber(buffer)
  if value and value<=(menu=="COURSE" and 359 or 80000) then
   if menu=="COURSE" then course=value else altitude=value end
   buffer="";error=false
  else error=true end
 elseif key==28 then buffer="";error=false end
end
function update()
 timer=timer+.02
 if bus.get("ICP_OPACITY")<=0 then select("") end
 if timer>=10 and (menu=="HUD" or menu=="AP") then select("") end
 bus.set("ICP_HUD_MENU",menu=="HUD" and 1 or 0);bus.set("ICP_AP_MENU",menu=="AP" and 1 or 0)
 bus.set("F22_NAV_COURSE",course);bus.set("F22_SELECTED_ALT_FT",altitude)
 local title=menu=="COURSE" and "COURSE REFERENCE" or (menu=="ALT" and "ALT REF FT" or "HOST STEERPOINT")
 local value=buffer~="" and buffer or tostring(menu=="COURSE" and course or altitude)
 local description=menu=="STPT" and "UP / DN: NEXT / PREV" or "CKE: SET  UNDO: CLEAR"
 bus.set("F22_ICP_ENTRY_VISIBLE",(menu=="COURSE" or menu=="ALT" or menu=="STPT") and 1 or 0)
 bus.set("F22_ICP_ENTRY_TITLE",title);bus.set("F22_ICP_ENTRY_VALUE",menu=="STPT" and "" or value)
 bus.set("F22_ICP_ENTRY_HINT",error and "INVALID ENTRY" or description)
end
need_to_be_closed=false
