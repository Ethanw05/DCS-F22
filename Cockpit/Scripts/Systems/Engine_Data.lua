-- Shared achieved engine state; legacy host readings only when the EFM contract is absent.
return function(base)
    local valid = get_param_handle("EFM_ENGINE_VALID")
    local left = get_param_handle("EFM_ENGINE_LEFT_RPM_PCT")
    local right = get_param_handle("EFM_ENGINE_RIGHT_RPM_PCT")
    local vehicle = get_param_handle('EFM_VEHICLE_VALID')
    local left_temp = get_param_handle('EFM_ENGINE_LEFT_TEMP_C')
    local right_temp = get_param_handle('EFM_ENGINE_RIGHT_TEMP_C')
    local function rpm(handle, fallback)
        local value = valid:get() >= 0.5 and handle:get() or fallback()
        if type(value) ~= "number" or value ~= value or math.abs(value) == math.huge then return 0 end
        return math.max(0, value)
    end
    local function temperature(handle,fallback)
        local value=vehicle:get()>.5 and handle:get()or fallback()
        return type(value)=='number' and value==value and math.abs(value)<math.huge and value or 0
    end
    return setmetatable({
        getEngineLeftRPM = function() return rpm(left, base.getEngineLeftRPM) end,
        getEngineRightRPM = function() return rpm(right, base.getEngineRightRPM) end,
        getEngineLeftTemperatureBeforeTurbine = function()return temperature(left_temp,base.getEngineLeftTemperatureBeforeTurbine)end,
        getEngineRightTemperatureBeforeTurbine = function()return temperature(right_temp,base.getEngineRightTemperatureBeforeTurbine)end,
    }, {__index = function(_, key) return base[key] end})
end
