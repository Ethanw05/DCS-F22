-- Exogenous current physical/array publications for cockpit workflow tests.
-- This fixture does not model electrical/thermal physics. Disable it explicitly
-- when exercising absent, malformed or stopped physical-owner behavior.
return function()
    local f={enabled=true,clock=0,generation=1,temperature=60,mission=1,array=1}
    local function put(name,value)get_param_handle(name):set(value)end
    local clock_function
    if type(get_model_time)~="function" then
        clock_function=function()return f.world or 0 end
        get_model_time=clock_function
        f.clock_function=clock_function
    end
    function f:publish()
        for name,value in pairs({EFM_POWER_OWNER=1,EFM_PHYSICAL_VALID=1,
            EFM_PHYSICAL_GENERATION=self.generation,EFM_PHYSICAL_CLOCK_KIND=1,
            EFM_PHYSICAL_STAMP=self.clock,F22_AP_CLOCK=self.clock,
            EFM_MISSION_POWER_AVAILABLE=self.mission,F22_ELECTRICAL_VALID=1,
            EFM_ENVIRONMENT_VALID=1,EFM_EQUIPMENT_TEMP_C=self.temperature,EFM_THERMAL_FAULT=0,
            EFM_UTILITY_AVAILABLE=1,EFM_VEHICLE_VALID=1,EFM_ACTUATOR_AVAILABLE=1,
            F22_AESA_ARRAY_KNOWN=1,F22_AESA_ARRAY_HEALTH=self.array})do put(name,value)end
    end
    function f:advance()
        if not self.enabled then return end
        local now
        if get_model_time==clock_function then now=(self.world or 0)+.05
        else
            local ok,value=pcall(get_model_time)
            if not ok or type(value)~="number" or value~=value or math.abs(value)==math.huge then return end
            now=value
        end
        if self.world and now<self.world then self.generation=self.generation+1;self.clock=0
        elseif self.world then self.clock=self.clock+now-self.world end
        self.world=now
        self:publish()
    end
    f:publish()
    return f
end
