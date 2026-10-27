-- GPL-3.0-or-later. Same focused-format predicate used by SCS/TMS routing.
local Sensor = dofile(LockOn_Options.script_path .. "Systems/Sensor_Control.lua")
local M = {}
local formats, context = {}, {}
function M.allowed(get)
    local focus = get("F22_SOI")
    if get("F22_MFD_LAYOUT_READY") > 0.5 then
        formats[2], formats[3] = get("F22_PMFD_FORMAT"), get("F22_LMFD_FORMAT")
        formats[4], formats[5] = get("F22_RMFD_FORMAT"), get("F22_CMFD_FORMAT")
        context.common_formats = formats
        return Sensor.is_radar(context, focus)
    end
    -- Legacy startup has no selected SOI yet; preserve its old cursor contract.
    local page = get("F22_PMFD_PAGE")
    context.common_formats, context.primary_page = nil, page == 0 and 1 or page
    return focus == 0 or Sensor.is_radar(context, focus)
end
return M
