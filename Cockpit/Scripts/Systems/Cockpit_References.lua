-- GPL-3.0-or-later. Read-only reference values; no checklist item repairs hardware.
local M = {}
local function finite(value)
    return type(value) == 'number' and value == value and math.abs(value) < 1e9
end
function M.new(get, put)
    local previous = {}
    local function publish(key, value)
        if previous[key] ~= value then previous[key] = value; put(key, value) end
    end
    for _, key in ipairs({'MASS','TRIM','FUEL','SUPPLY','GEAR'}) do
        publish('F22_REFERENCE_' .. key, key .. ' --')
    end
    local references = {}
    function references.update()
        local physical = get('EFM_VEHICLE_VALID') > .5
        local mass = get('EFM_MASS_KG')
        publish('F22_REFERENCE_MASS', get('EFM_MASS_VALID') > .5 and finite(mass) and mass > 0
            and string.format('WEIGHT %.0f LB', mass * 2.204622622) or 'WEIGHT --')
        local left, right = get('EFM_TRIM_LEFT_DEG'), get('EFM_TRIM_RIGHT_DEG')
        publish('F22_REFERENCE_TRIM', get('EFM_TRIM_VALID') > .5 and finite(left) and finite(right)
            and string.format('TAIL L %.1f R %.1f DEG', left, right) or 'TAIL --')
        local internal, external = get('EFM_INTERNAL_FUEL_KG'), get('EFM_EXTERNAL_FUEL_KG')
        publish('F22_REFERENCE_FUEL', physical and finite(internal) and finite(external)
            and internal >= 0 and external >= 0 and string.format('FUEL %.0f LB', (internal + external) * 2.204622622)
            or 'FUEL --')
        local supply = get('EFM_POWER_OWNER') > .5 and get('F22_ESSENTIAL_POWER') or get('MAIN_POWER')
        publish('F22_REFERENCE_SUPPLY',
            physical and (supply > .5 and 'SUPPLY AVAILABLE' or 'SUPPLY LOST') or 'SUPPLY --')
        local gear = get('EFM_GEAR_DOWN_LOCKED') > .5 and 'GEAR DOWN'
            or get('EFM_GEAR_UP_LOCKED') > .5 and 'GEAR UP' or 'GEAR TRANSIT'
        publish('F22_REFERENCE_GEAR', get('EFM_PHYSICAL_VALID') > .5 and gear or 'GEAR --')
    end
    return references
end
return M
