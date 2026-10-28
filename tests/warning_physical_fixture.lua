-- Test-only healthy airframe publisher for warning/audio owner workflows.
-- Callers mutate declared physical payloads directly; airborne predictor tests
-- supply their measured-CAS callback. Audio-only cases declare a 200m/s sample.
return function(measured_cas)
    local function put(key, value) get_param_handle(key):set(value) end
    for key, value in pairs({F22_ESSENTIAL_POWER=1,EFM_GROUND_VALID=1,
        EFM_WEIGHT_ON_WHEELS=0,EFM_GEAR_DOWN_LOCKED=0,EFM_GEAR_UP_LOCKED=1,EFM_GEAR_UNSAFE=0,
        EFM_AIRDATA_VALID=1,EFM_AIRDATA_HEALTH=0,EFM_FCS_INTEGRITY_VALID=1,EFM_FCS_DAMAGED=0,
        F22_ELECTRICAL_VALID=1,L_GEN_POWER=1,R_GEN_POWER=1,EFM_HYD_LEFT_PSI=4000,EFM_HYD_RIGHT_PSI=4000,
        EFM_ENGINE_VALID=1,EFM_ENGINE_LEFT_OIL_PSI=200,EFM_ENGINE_RIGHT_OIL_PSI=200,
        F22_CANOPY_PROVIDER_VALID=1,F22_CANOPY_POSITION=0,F22_CANOPY_LOCKED=1})do put(key,value)end
    local physical=dofile(SCRIPT_ROOT..'../../tests/physical_frame_fixture.lua')({})
    local fixture={}
    function fixture:publish()
        local now=get_model_time()
        put('EFM_AIRDATA_STAMP',now)
        put('EFM_AIRDATA_CAS_MPS',measured_cas and measured_cas()or 200)
        physical:publish(now)
    end
    function fixture:wrap(callback)
        return function(...)
            self:publish()
            return callback(...)
        end
    end
    fixture:publish()
    return fixture
end
