-- Radian layout values shared by the producer and native HUD page.
-- Header placement calibrated against the actual F-22 cockpit render.
local angular_scale=.22
local optics=dofile(LockOn_Options.script_path..'HUD/optics.lua')
-- The fixed aircraft reference, FPM, NAV and sensor/weapon cues share one
-- physical forward-ray origin. Layout proportions must not create a second FRL.
return { angular_scale=angular_scale, boresight_y=optics.frl_elevation/angular_scale, heading_y_offset=-0.13,
    ladder_y_min=-0.25, ladder_y_max=0.11, font_scale=0.16,
    font_width_scale=0.6, heading_mrad_per_degree=3.3 }
