-- GPL-3.0-or-later. Operational entry points; setup and diagnostics are secondary.
local D=dofile(LockOn_Options.script_path..'MFD_COMMON/lcd.lua')('PMFD_MENU_PAGE','F22_PMFD_MENU')
for button,label in ipairs({'TSD','NAV','STORES','SYSTEMS'})do D.key(button,label)end
D.key(13,'MENU')
