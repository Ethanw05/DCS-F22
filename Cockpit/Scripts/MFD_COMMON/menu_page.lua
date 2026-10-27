-- GPL-3.0-or-later. Direct page selection at physical bezels; no landing prose.
return function(panel)
 local D=dofile(LockOn_Options.script_path..'MFD_COMMON/lcd.lua')(panel..'_MENU_PAGE','F22_MENU_'..panel)
 local choices={[2]='NAV',[3]='STORES',[4]='ENG',[5]='FCS',[6]='FUEL',[7]='ADI',[8]='CHECKS'}
 if panel=='RMFD'then choices[1]='DEF'elseif panel=='CMFD'then choices[1]='TSD'end
 for button,label in pairs(choices)do
  D.key(button,label,'white',nil,.0050)
 end
 D.key(13,'MENU')
end
