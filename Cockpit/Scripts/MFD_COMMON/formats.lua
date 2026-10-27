-- GPL-3.0-or-later. Every main indicator loads these exact same formats.
return function(panel)
 local R=dofile(LockOn_Options.script_path..'Systems/Display_Routing.lua')
 local function load(file,...)return dofile(LockOn_Options.script_path..file)(...)end
 local prefix='F22_COMMON_'..panel..'_'
 local D=load('MFD_COMMON/lcd.lua',R.flag(panel,R.pages.menu),prefix..'MENU')
 D.text('FORMAT SELECT',0,.66,nil,'blue',.0048)
 load('MFD_COMMON/nav_page.lua',R.flag(panel,R.pages.nav))
 load('MFD_COMMON/stores_page.lua',R.flag(panel,R.pages.stores),prefix..'STORES','F22_SMS_UI_PAGE_'..panel)
 for _,item in ipairs({{'eng_page',R.pages.eng},{'fcs_page',R.pages.fcs},{'fuel_page',R.pages.fuel},
  {'adi_page',R.pages.adi},{'checklist_page',R.pages.checks}})do
  load('MFD_COMMON/'..item[1]..'.lua',R.flag(panel,item[2]))
 end
 load('PMFD_CENTER/radar_format.lua',R.flag(panel,R.pages.tsd),prefix..'AA_')
 load('PMFD_CENTER/ag_radar_format.lua',R.flag(panel,R.pages.tsd),prefix..'AG_')
 load('MFD_RIGHT/defensive_overview.lua',R.flag(panel,R.pages.def),prefix..'DEF_OV_')
 load('MFD_COMMON/bezel.lua',panel)
end
