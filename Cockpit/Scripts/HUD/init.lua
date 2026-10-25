-- Experimental F-22-inspired HUD, user-selected C-130 heading variant.
-- Follows public USAF 2002 F-22 drawing for counters and pitch ladder.
dofile(LockOn_Options.common_script_path.."devices_defs.lua")
indicator_type = indicator_types.COLLIMATOR
purposes = {render_purpose.GENERAL, render_purpose.HUD_ONLY_VIEW}
-- Same native stroke-renderer setup used by the installed AVQ-32 HUD.
shaderLineParamsUpdatable = true
shaderLineDefaultThickness = 0.8
shaderLineDefaultFuzziness = 0.5
shaderLineDrawAsWire = false
shaderLineUseSpecularPass = false
-- Collimated elements use this origin independently of the common indicator
-- plane geometry. Lowering device_init's sy alone does not move this HUD.
local optics = dofile(LockOn_Options.script_path.."HUD/optics.lua")
collimator_default_distance_factor = optics.distance_factor
init_pageID = 1
page_subsets = {
    [1] = LockOn_Options.script_path.."HUD/page.lua"
}
pages = { {1} }
