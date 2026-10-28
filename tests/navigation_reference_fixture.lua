-- Isolated NAV workflow fixture using the actual dual-reference producer.
-- Aligned airborne state and essential supply are explicit test assumptions.
return function()
    local function get(key) return get_param_handle(key):get() end
    local function put(key, value) get_param_handle(key):set(value) end
    local physical = dofile(SCRIPT_ROOT .. '../../tests/physical_frame_fixture.lua')({F22_ESSENTIAL_POWER=1})
    physical:publish(get('F22_AP_CLOCK'))
    local producer = dofile(SCRIPT_ROOT .. 'Systems/Gins_References.lua').new(get, put, get_base_data())
    producer:reset(true)
    local fixture = { producer=producer, physical=physical }
    function fixture:publish()
        physical:publish(get('F22_AP_CLOCK'))
        producer:update()
    end
    function fixture:wrap(callback)
        return function(...)
            self:publish()
            return callback(...)
        end
    end
    return fixture
end
