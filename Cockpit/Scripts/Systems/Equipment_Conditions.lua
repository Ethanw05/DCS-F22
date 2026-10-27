-- GPL-3.0-or-later. Fault causes from physical outputs, independent of display colors.
local Envelope = dofile(LockOn_Options.script_path .. 'Systems/Physical_Snapshot.lua')
local M = {}
local legacy_fields={ 'L_GEN_OUT', 'R_GEN_OUT', 'L_HYD_COLOR',
    'R_HYD_COLOR', 'L_OIL_COLOR', 'R_OIL_COLOR', 'CANOPY_LIGHT' }
function M.new(get, conditions)
    local frame = Envelope.new(get, {
        'EFM_FCS_INTEGRITY_VALID', 'EFM_FCS_DAMAGED', 'F22_ELECTRICAL_VALID',
        'L_GEN_POWER', 'R_GEN_POWER', 'EFM_HYD_LEFT_PSI', 'EFM_HYD_RIGHT_PSI',
        'EFM_ENGINE_VALID', 'EFM_ENGINE_LEFT_OIL_PSI', 'EFM_ENGINE_RIGHT_OIL_PSI',
        'F22_CANOPY_PROVIDER_VALID', 'F22_CANOPY_POSITION', 'F22_CANOPY_LOCKED',
    })
    local function condition(index, valid, active)
        conditions[index].valid, conditions[index].active = valid, active
    end
    local function low_pressure(index, value, limit, valid)
        condition(index, valid and Envelope.finite(value) and value >= 0 and value <= 10000,
            Envelope.finite(value) and value <= limit)
    end
    local function legacy()
        local valid = get('EFM_VEHICLE_VALID') == 1 and get('MAIN_POWER') == 1
        condition(1, get('MAIN_POWER') == 1 and get('EFM_FCS_INTEGRITY_VALID') == 1,
            get('EFM_FCS_DAMAGED') == 1)
        for index, key in ipairs(legacy_fields) do
            condition(index + 1, valid, get(key) > .5)
        end
    end
    local instance = {}
    function instance.update()
        frame:update()
        if not frame.owned then legacy(); return end
        local v, valid = frame.values, frame.valid
        condition(1, valid and v.EFM_FCS_INTEGRITY_VALID == 1 and Envelope.boolean(v.EFM_FCS_DAMAGED),
            v.EFM_FCS_DAMAGED == 1)
        local electrical = valid and v.F22_ELECTRICAL_VALID == 1
        condition(2, electrical and Envelope.boolean(v.L_GEN_POWER), v.L_GEN_POWER == 0)
        condition(3, electrical and Envelope.boolean(v.R_GEN_POWER), v.R_GEN_POWER == 0)
        -- Retain the existing mod's 1000 psi hydraulic / 100 psi oil alert thresholds.
        low_pressure(4, v.EFM_HYD_LEFT_PSI, 1000, valid)
        low_pressure(5, v.EFM_HYD_RIGHT_PSI, 1000, valid)
        low_pressure(6, v.EFM_ENGINE_LEFT_OIL_PSI, 100, valid and v.EFM_ENGINE_VALID == 1)
        low_pressure(7, v.EFM_ENGINE_RIGHT_OIL_PSI, 100, valid and v.EFM_ENGINE_VALID == 1)
        local canopy = valid and v.F22_CANOPY_PROVIDER_VALID == 1
            and Envelope.finite(v.F22_CANOPY_POSITION) and v.F22_CANOPY_POSITION >= 0
            and v.F22_CANOPY_POSITION <= 1 and Envelope.boolean(v.F22_CANOPY_LOCKED)
        condition(8, canopy, v.F22_CANOPY_LOCKED == 0 or v.F22_CANOPY_POSITION > .001)
    end
    return instance
end
return M
