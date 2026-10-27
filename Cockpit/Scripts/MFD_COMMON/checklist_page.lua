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

-- Mod workflow references; no authentic F-22 checklist or automatic completion claim.
return function(page_parameter)
 local panel=page_parameter:match('^(.-)_CHECKLIST_PAGE$') or 'PMFD'
 local view='F22_'..panel..'_VIEW'
 local D=dofile(LockOn_Options.script_path..'MFD_COMMON/lcd.lua')(page_parameter,'F22_REFERENCE_'..panel)
 local pages={
  {'START',{'BATTERY / SUPPLY - CHECK','APU / ENGINE START - AS REQUIRED',
   'FLIGHT INSTRUMENTS - CHECK','GINS ALIGNMENT - VERIFY','NAV / RADIOS - SET'}},
  {'TAXI',{'CANOPY / RESTRAINTS - CHECK','BRAKES / STEERING - CHECK',
   'FLIGHT CONTROLS - CHECK','FLIGHT INSTRUMENTS - CROSSCHECK','LIGHTS - AS REQUIRED'}},
  {'TAKEOFF',{'RUNWAY / DEPARTURE - CHECK','FUEL / CONFIGURATION - CHECK',
   'FLIGHT CONTROLS / TRIM - CHECK','WARNINGS - REVIEW','THRUST / INSTRUMENTS - CHECK'}},
  {'LANDING',{'APPROACH / MISSED APPROACH - REVIEW','NAV / RECEIVER FLAGS - CHECK',
   'GEAR DOWN - VERIFY','12 DEG AOA REFERENCE','BRAKES / STEERING - AS REQUIRED'}},
  {'SHUTDOWN',{'PARKING / GROUND STATE - CHECK','STORES / MASTER ARM - SAFE',
   'ENGINE SHUTDOWN - AS REQUIRED','ELECTRICAL SUPPLY - OFF','FAULT HISTORY - REVIEW'}},
 }
 for index,page in ipairs(pages)do
  local parent=D.choice(view,index-1)
  D.text(page[1]..' REFERENCE',0,.65,nil,'blue',.0048,parent)
  for line,text in ipairs(page[2])do D.text(text,0,.42-(line-1)*.14,nil,'green',.0043,parent)end
  D.text('%s',0,-.35,'F22_REFERENCE_MASS','white',.0043,parent)
  D.text('%s',0,-.49,index==4 and 'F22_REFERENCE_GEAR'or'F22_REFERENCE_TRIM','white',.0043,parent)
  D.text('%s',0,-.63,'F22_REFERENCE_FUEL','white',.0043,parent)
 end
 local faults=D.choice(view,5)
 D.text('FAULTS / RECALL',0,.65,nil,'blue',.0048,faults)
 for index=1,8 do D.text('%s',0,.46-(index-1)*.115,'F22_FAULT_LINE_'..index,'green',.0043,faults)end
 D.text('ACTIVE %.0f',-.3,-.55,'F22_FAULT_ACTIVE_COUNT','yellow',.0043,faults)
 D.text('UNKNOWN %.0f',.3,-.55,'F22_FAULT_UNKNOWN_COUNT','yellow',.0043,faults)
 local detail=D.choice(view,6)
 D.text('FAULT REFERENCE',0,.65,nil,'blue',.0048,detail)
 D.text('%s',0,.45,'F22_FAULT_SELECTED_TEXT','yellow',.0043,detail)
 for index=1,4 do D.text('%s',0,.22-(index-1)*.16,'F22_FAULT_REFERENCE_'..index,'green',.0043,detail)end
 D.text('SIM REFERENCE',0,-.78,nil,'blue',.0036)
end
