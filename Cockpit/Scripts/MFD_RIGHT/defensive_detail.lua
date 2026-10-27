-- GPL-3.0-or-later. Compatibility entry for the retired DEF detail format.
-- Older subset registrations receive the same single defensive picture.
return function(page_parameter,prefix)
 return dofile(LockOn_Options.script_path..'MFD_RIGHT/defensive_overview.lua')(page_parameter,prefix)
end
