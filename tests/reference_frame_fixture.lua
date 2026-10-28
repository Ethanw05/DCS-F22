-- Test-only exogenous, healthy selected-pose publication for isolated displays.
-- This does not implement alignment, physical supply or position readiness.
return function()
    local fixture = { sequence = 0 }
    local roles = { NAV = 1, HUD = 1, SFG = 2 }
    local function put(key, value) get_param_handle(key):set(value) end
    function fixture:publish()
        local base = get_base_data()
        local pitch, roll = base.getPitch(), base.getRoll()
        local heading = (-base.getHeading()) % (2 * math.pi)
        put('F22_GINS_VALID', 0)
        for role, source in pairs(roles) do
            local prefix = 'F22_GINS_' .. role .. '_'
            put(prefix .. 'SOURCE', source); put(prefix .. 'POWER', 1)
            put(prefix .. 'ATTITUDE_VALID', 1); put(prefix .. 'HEADING_VALID', 1)
            put(prefix .. 'POSITION_READY', 0)
            put(prefix .. 'PITCH', pitch); put(prefix .. 'ROLL', roll); put(prefix .. 'HEADING', heading)
        end
        self.sequence = self.sequence + 1
        put('F22_GINS_SCHEMA', 1); put('F22_GINS_SEQUENCE', self.sequence)
        put('F22_GINS_STAMP', get_param_handle('F22_AP_CLOCK'):get())
        put('F22_GINS_VALID', 1)
    end
    function fixture:wrap(callback)
        return function(...)
            self:publish()
            return callback(...)
        end
    end
    return fixture
end
