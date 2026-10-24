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

-- Original page geometry retained. Page state is exclusive and survives power interruption.
-- R09 describes integrated display roles, not the F-15 backend used by this mod.
local dev=GetSelf()
local Math=dofile(LockOn_Options.script_path.."Common/Math.lua")
local bus=dofile(LockOn_Options.script_path.."Common/Runtime.lua").New(get_base_data())
local selected={1,3,5}
local bay,groundOverride,option=2,0,0
local sideMode={0,0}
local names={"MENU","ENG","FCS","FUEL","ADI","BAY","CHECKLIST","SMS","HSI"}
local screens={"LMFD","RMFD","CMFD"}
local common={
 [0]={[3]=6,[6]=8,[8]=2,[10]=3,[13]=7,[16]=5,[18]=1,[20]=4},
 [1]={[1]=0,[2]=7,[3]=5,[4]=2,[5]=3},
 [2]={[1]=0,[2]=7,[4]=1,[5]=3},
 [3]={[1]=0,[2]=7,[3]=1,[4]=5,[5]=2},
 [4]={[1]=0,[5]=8},[5]={[1]=0,[2]=7,[3]=1,[4]=3,[5]=2},
 [6]={[1]=0,[2]=1,[3]=5,[4]=2,[5]=3},[7]={[1]=0,[13]=0},[8]={[1]=0,[5]=4}}
local center={
 [0]={[3]=6,[6]=8,[8]=2,[10]=3,[16]=5,[18]=1,[20]=4},
 [1]={[1]=0,[2]=5,[3]=2,[4]=3,[5]=4},[2]={[1]=0,[2]=5,[4]=1,[5]=3},
 [3]={[1]=0,[2]=1,[3]=5,[4]=2,[5]=8},[4]=common[4],
 [5]={[1]=0,[2]=1,[3]=2,[4]=3,[5]=8},[6]=common[6],[8]=common[8]}
make_default_activity(.02)
for c=3001,3060 do dev:listen_command(c) end
for _,range in ipairs({{10000,10005},{10061,10080},{10091,10130}}) do for c=range[1],range[2] do dev:listen_command(c) end end
function post_initialize()
 selected={1,3,5};bay,groundOverride,sideMode=2,0,{0,0}
 option=type(get_aircraft_property)=="function" and (get_aircraft_property("BAY_DOOR_OPTION") or 0) or 0
 option=(option==true or (type(option)=="number" and option>.5)) and 1 or 0
 if LockOn_Options.init_conditions.birth_place=="GROUND_COLD" and option==0 then groundOverride=1 end
 bus.set("BAY_OPTION",option)
end
local function selectSide(which)
 local station=which==1 and 1 or 3
 sideMode[which]=bay==station and sideMode[which]%3+1 or 1
 bay=station
 dispatch_action(nil,({110,108,107})[sideMode[which]])
 -- Selecting a bay must not blindly toggle radar emission.
end
function SetCommand(c,v)
 if v<=0 or bus.get("MAIN_POWER")<.5 then return end
 if c==10000 then selectSide(1) elseif c==10001 then selectSide(2)
 elseif c==10002 then bay=2;dispatch_action(nil,106)
 elseif c==10003 then bay=4;dispatch_action(nil,106)
 elseif c==10004 then bay=bay%4+1
 elseif c==10005 then selected={7,7,5} end
 local screen,key
 if c>=3001 and c<=3060 then screen=math.floor((c-3001)/20)+1;key=(c-3001)%20+1
 elseif c>=10061 and c<=10080 then screen,key=1,c-10060
 elseif c>=10091 and c<=10110 then screen,key=2,c-10090
 elseif c>=10111 and c<=10130 then screen,key=3,c-10110 end
 if not screen then return end
 local page=selected[screen]
 if page==5 then
  if key==17 and bus.wow() then groundOverride=1-groundOverride end
  if key==7 then bay=bay%4+1 elseif key==8 then bay=(bay+2)%4+1 end
 elseif page==8 then
  if key==15 then dispatch_action(nil,105) elseif key==19 then dispatch_action(nil,1315) elseif key==20 then dispatch_action(nil,102) end
 elseif page==7 and screen==2 and key==15 then dispatch_action(nil,286) end
 local mapping=(screen==3 and center or common)[page]
 if mapping and mapping[key]~=nil then selected[screen]=mapping[key] end
end
local function flag(v) return v and 1 or 0 end
function update()
 local power=bus.get("MFD_OPACITY")>0
 for i,prefix in ipairs(screens) do
  local page=selected[i]
  bus.set(prefix.."_PAGE",page)
  for j,name in ipairs(names) do
   local actual=(i==2 and name=="SMS") and "RWR" or name
   bus.set(prefix.."_"..actual.."_PAGE",flag(power and page==j-1))
  end
  bus.set(prefix.."_MASK",flag(power and page==7 and i~=3))
 end
 bus.set("GROUND_ORIDE",groundOverride);bus.set("BAY_STATION",bay)
 bus.set("TANK_OPACITY",flag(bus.get("F22_FUEL_EXTERNAL_KG")>.1))
 bus.set("CABINPRESS",get_cockpit_draw_argument_value(114)) -- legacy host indication, not cabin simulation
 for _,side in ipairs({{"L","Left","LEFT",90},{"R","Right","RIGHT",89}}) do
  local rpm=bus.sample("getEngine"..side[2].."RPM")
  local temp=bus.sample("getEngine"..side[2].."TemperatureBeforeTurbine")
  local hyd=bus.get("F22_HYD_"..side[3].."_PSI")
  -- Oil pressure is an explicitly assumed RPM proxy, not measured F119 plumbing.
  bus.set("OIL_"..side[1],Math.Clamp(rpm*2.7,0,300))
  bus.set(side[1].."_HYD_VALUE",hyd);bus.set(side[1].."_HYD_COLOR",flag(hyd<1500))
  bus.set(side[1].."_OIL_COLOR",flag(rpm<66))
  bus.set(side[1].."_RPM_COLOR",rpm>100 and 1 or .5)
  bus.set(side[1].."_EGT_COLOR",temp>=850 and 1 or (temp>=730 and .5 or 0))
  local flow=bus.get("F22_FUEL_VALID")>.5 and bus.get("F22_FUEL_FLOW_"..side[3].."_KGS") or bus.sample("getEngine"..side[2].."FuelConsumption")
  bus.set(side[1].."_FF_VALUE",flow*2.204622622*3600)
  -- Engine page NZL remains exit-area animation percent, separate from TVC angle.
  bus.set(side[1].."_NOZZLE_POS",Math.Clamp(get_aircraft_draw_argument_value(side[4]),0,1)*100)
 end
 for name,index in pairs({FCS_RA=12,FCS_LA=11,FCS_RE=15,FCS_LE=16,FCS_RR=18,FCS_LR=17,FCS_RF=10,FCS_LF=9,FCS_SB=182,FCS_LEF=603}) do
  bus.set(name,get_aircraft_draw_argument_value(index))
 end
 for name,index in pairs({ILS_VERT=28,ILS_HORIZON=27,HSI_COMPASS=32,HSI_CRS_POINTER=35,HSI_DEVIATION=36,
  HSI_WP_POINTER=140,ILS_FLAG=141,ILS_NAV=501,MILE_1=270,MILE_2=269,MILE_3=268,MILE_4=267,
  COURSE_1=275,COURSE_2=276,COURSE_3=277,TO_FROM=278}) do bus.set(name,get_cockpit_draw_argument_value(index)) end
 bus.set("ILSN_VIS",flag(bus.get("ILS_NAV")>=.1));bus.set("NAV_VIS",flag(bus.get("ILS_NAV")<.1))
end
need_to_be_closed=false
