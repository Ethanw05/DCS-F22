-- GPL-3.0-or-later. Read-only reference values; no checklist item repairs hardware.
local M = {}
local function finite(value)
    return type(value) == 'number' and value == value and math.abs(value) < 1e9
end
function M.new(get, put)
    local envelope = dofile(LockOn_Options.script_path .. 'Systems/Physical_Snapshot.lua')
    local snapshot = envelope.new(get, {
        'EFM_VEHICLE_VALID', 'EFM_MASS_VALID', 'EFM_MASS_KG', 'EFM_TRIM_VALID',
        'EFM_TRIM_LEFT_DEG', 'EFM_TRIM_RIGHT_DEG', 'EFM_INTERNAL_FUEL_KG', 'EFM_EXTERNAL_FUEL_KG',
        'F22_ESSENTIAL_POWER', 'EFM_GEAR_DOWN_LOCKED', 'EFM_GEAR_UP_LOCKED', 'EFM_GEAR_UNSAFE',
    })
    local function sample(key)
        if not snapshot.owned then return get(key) end
        return snapshot.valid and snapshot.values[key] or nil
    end
    local previous = {}
    local function publish(key, value)
        if previous[key] ~= value then previous[key] = value; put(key, value) end
    end
    for _, key in ipairs({'MASS','TRIM','FUEL','SUPPLY','GEAR'}) do
        publish('F22_REFERENCE_' .. key, key .. ' --')
    end
    local references = {}
    function references.update()
        snapshot:update()
        local physical = sample('EFM_VEHICLE_VALID') == 1
        local mass = sample('EFM_MASS_KG')
        publish('F22_REFERENCE_MASS', sample('EFM_MASS_VALID') == 1 and finite(mass) and mass > 0
            and string.format('WEIGHT %.0f LB', mass * 2.204622622) or 'WEIGHT --')
        local left, right = sample('EFM_TRIM_LEFT_DEG'), sample('EFM_TRIM_RIGHT_DEG')
        publish('F22_REFERENCE_TRIM', sample('EFM_TRIM_VALID') == 1 and finite(left) and finite(right)
            and string.format('TAIL L %.1f R %.1f DEG', left, right) or 'TAIL --')
        local internal, external = sample('EFM_INTERNAL_FUEL_KG'), sample('EFM_EXTERNAL_FUEL_KG')
        publish('F22_REFERENCE_FUEL', physical and finite(internal) and finite(external)
            and internal >= 0 and external >= 0 and string.format('FUEL %.0f LB', (internal + external) * 2.204622622)
            or 'FUEL --')
        local supply
        if snapshot.owned then supply = sample('F22_ESSENTIAL_POWER') else supply = get('MAIN_POWER') end
        publish('F22_REFERENCE_SUPPLY',
            physical and finite(supply) and (supply > .5 and 'SUPPLY AVAILABLE' or 'SUPPLY LOST') or 'SUPPLY --')
        local down, up, unsafe = sample('EFM_GEAR_DOWN_LOCKED'), sample('EFM_GEAR_UP_LOCKED'), sample('EFM_GEAR_UNSAFE')
        local gear = unsafe == 1 and 'GEAR UNSAFE' or down == 1 and 'GEAR DOWN'
            or up == 1 and 'GEAR UP' or 'GEAR TRANSIT'
        local gear_valid = snapshot.valid and envelope.boolean(down) and envelope.boolean(up)
            and envelope.boolean(unsafe) and down + up <= 1
        publish('F22_REFERENCE_GEAR', gear_valid and gear or 'GEAR --')
    end
    return references
end
return M
