-- Experimental F-22-inspired HUD, user-selected C-130 heading variant.
-- Follows public USAF 2002 F-22 drawing for counters and pitch ladder.
dofile(LockOn_Options.common_script_path.."devices_defs.lua")
indicator_type = indicator_types.COMMON
purposes = {render_purpose.GENERAL, render_purpose.HUD_ONLY_VIEW}
init_pageID = 1
page_subsets = {
    [1] = LockOn_Options.script_path.."HUD/page.lua"
}
pages = { {1} }
