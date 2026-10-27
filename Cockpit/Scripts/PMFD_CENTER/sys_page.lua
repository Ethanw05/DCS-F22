-- Local Systems selection. Each choice opens on this primary display.
local D=dofile(LockOn_Options.script_path..'MFD_COMMON/lcd.lua')('PMFD_SYS_PAGE','F22_PMFD_SYSTEMS')
for button,label in ipairs({'ENG','FCS','FUEL','ADI','CHECKS'})do D.key(button,label)end
D.key(13,'MENU')
