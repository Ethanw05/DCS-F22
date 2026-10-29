-- Existing unanchored HUD indicator viewport, in cockpit metres.
-- Share this with designation placement so an edge cue cannot leave the viewport.
local optics = dofile(LockOn_Options.script_path..'HUD/optics.lua')
return {width = .14, height = .12, focal_length = optics.distance_factor[1]}
