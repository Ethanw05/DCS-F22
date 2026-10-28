-- GPL-3.0-or-later. Dedicated image source. No ordinary cockpit artwork.
dofile(LockOn_Options.common_script_path .. "devices_defs.lua")
indicator_type = indicator_types.COMMON
purposes = {render_purpose.GENERAL}
render_target = 8
-- MFD materials multiply video by this mask; use the core neutral white mask.
used_render_mask = "Bazar/TempTextures/white.png"
init_pageID = 1
page_subsets = {[1] = LockOn_Options.script_path .. "Systems/AG_Radar_Video/empty.lua"}
pages = {{1}}
get_param_handle("F22_AG_VIDEO_SOURCE_PRESENT"):set(1)

-- Geometry qualified 2026-10-26: camera cardinal/range regressions and native
-- texture-registration measurements in moving flight. Native ABI/ownership,
-- source readiness and fresh command-time snapshots remain separate gates.
get_param_handle("F22_AG_VIDEO_GEOMETRY_QUALIFIED"):set(1)
get_param_handle("F22_AG_VIDEO_TIMING_DIAGNOSTIC"):set(0)
-- GPU staging/readback stalls are for an explicitly requested qualification run.
get_param_handle("F22_AG_VIDEO_GPU_DIAGNOSTIC"):set(0)
for _,axis in ipairs({'FORWARD','RIGHT','UP'})do get_param_handle('F22_AG_VIDEO_PROBE_'..axis..'_M'):set(0)end
get_param_handle('F22_AG_VIDEO_PROBE_TEXTURE'):set(0)
