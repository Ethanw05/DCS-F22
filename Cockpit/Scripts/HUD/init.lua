-- SPDX-License-Identifier: GPL-3.0-or-later
-- Research: R03 Fig.3 counter-pointers; R12/R91 projection/validity; see docs/HUD.md.
dofile(LockOn_Options.common_script_path .. "devices_defs.lua")
indicator_type = indicator_types.COLLIMATOR
purposes = {render_purpose.GENERAL, render_purpose.HUD_ONLY_VIEW}
init_pageID = 1
page_subsets = {[1] = LockOn_Options.script_path .. "HUD/page.lua"}
pages = {{1}}
collimator_default_distance_factor = {1, 0, 0}
