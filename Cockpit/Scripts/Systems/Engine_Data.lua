-- Engine RPM in percent, shared by electrical, indications and pressure proxies.
return function(base)
    local valid = get_param_handle("EFM_ENGINE_VALID")
    local left = get_param_handle("EFM_ENGINE_LEFT_RPM_PCT")
    local right = get_param_handle("EFM_ENGINE_RIGHT_RPM_PCT")
    local function rpm(handle, fallback)
        local value = valid:get() >= 0.5 and handle:get() or fallback()
        if type(value) ~= "number" or value ~= value or math.abs(value) == math.huge then return 0 end
        return math.max(0, value)
    end
    return setmetatable({
        getEngineLeftRPM = function() return rpm(left, base.getEngineLeftRPM) end,
        getEngineRightRPM = function() return rpm(right, base.getEngineRightRPM) end,
    }, {__index = function(_, key) return base[key] end})
end
