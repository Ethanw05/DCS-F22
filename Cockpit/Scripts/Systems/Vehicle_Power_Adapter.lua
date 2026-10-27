-- Requests only after the EFM claims ownership. Once latched, a missing/stale
-- EFM publication cannot start a competing Lua battery/APU integrator.
local M = {}
local function finite(value)
    return type(value) == "number" and value == value and math.abs(value) < math.huge
end
local function normalized(value)
    return finite(value) and math.max(0, math.min(1, value)) or 0
end
function M.new()
    local names = {
        "EFM_POWER_OWNER", "F22_POWER_REQUEST_VALID", "F22_BATTERY_REQUEST",
        "F22_L_GEN_REQUEST", "F22_R_GEN_REQUEST", "F22_APU_REQUEST",
        "APU_RPM_STATE", "APU_POWER", "L_GEN_POWER", "R_GEN_POWER", "MAIN_POWER",
        "F22_L_BLEED_REQUEST", "F22_R_BLEED_REQUEST", "F22_ECS_REQUEST",
        "EFM_APU_AUTO_SHUTDOWN",
        "F22_POWER_REQUEST_SEQUENCE",
    }
    local handles = {}
    for index = 1, #names do handles[index] = get_param_handle(names[index]) end
    local adapter = {latched = false, sequence = 0, apu_rpm = 0, apu_power = 0,
        left_generator = 0, right_generator = 0, main = 0, auto_shutdown = false}
    function adapter:update(battery, left_generator, right_generator, apu)
        if not self.latched and normalized(handles[1]:get()) > 0.5 then
            self.latched = true
            handles[12]:set(1)
            handles[13]:set(1)
            handles[14]:set(1)
        end
        if not self.latched then return false end
        handles[2]:set(0)
        handles[3]:set(battery == 1 and 1 or 0)
        handles[4]:set(left_generator == 1 and 1 or 0)
        handles[5]:set(right_generator == 1 and 1 or 0)
        handles[6]:set(apu == 1 and 1 or 0)
        self.sequence = self.sequence % 16777215 + 1
        handles[16]:set(self.sequence)
        handles[2]:set(1)
        local raw_spool = handles[7]:get()
        self.apu_rpm = normalized(finite(raw_spool) and raw_spool / 4 or 0) * 4
        self.apu_power = normalized(handles[8]:get())
        self.left_generator = normalized(handles[9]:get())
        self.right_generator = normalized(handles[10]:get())
        self.main = normalized(handles[11]:get())
        self.auto_shutdown = normalized(handles[15]:get()) > 0.5
        return true
    end
    return adapter
end
return M
