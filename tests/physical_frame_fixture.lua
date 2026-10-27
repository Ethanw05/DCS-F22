-- Exogenous physical publication for owner/consumer tests, not a physics model.
-- Callers declare payload fields and advance the frame explicitly. No loose
-- flags are promoted automatically into physical availability.
return function(values)
    local f = { values = values or {}, generation = 0, enabled = true }
    local function put(name, value) get_param_handle(name):set(value) end
    function f:publish(clock)
        if not self.enabled then return end
        assert(type(clock) == 'number' and clock == clock and clock >= 0 and clock < 1e9)
        self.generation = self.generation + 1
        assert(self.generation <= 4294967295)
        put('EFM_PHYSICAL_VALID', 0)
        put('EFM_POWER_OWNER', 1)
        for name, value in pairs(self.values) do put(name, value) end
        put('EFM_PHYSICAL_GENERATION', self.generation)
        put('EFM_PHYSICAL_CLOCK_KIND', 1)
        put('EFM_PHYSICAL_STAMP', clock)
        put('F22_AP_CLOCK', clock)
        put('EFM_PHYSICAL_VALID', 1)
    end
    return f
end
