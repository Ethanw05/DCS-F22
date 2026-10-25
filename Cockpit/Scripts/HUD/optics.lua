-- GPL-3.0-or-later: derivative within Grinnelli Designs F-22A project.
-- One optical reference for native trajectory directions and the collimator.
-- DCS AVQ32_init.lua defines optical depression as default Y / default X.
-- These are this mod's existing installation values, not F-22 specifications.
local distance = {0.55, -0.022, 0}
return {
    distance_factor = distance,
    -- Native mrad coordinates use the focal-plane slope convention.
    frl_elevation = -distance[2] / distance[1],
}
