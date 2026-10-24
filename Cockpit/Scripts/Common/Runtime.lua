-- SPDX-License-Identifier: GPL-3.0-or-later
local Runtime = {}
function Runtime.New(sensor)
    local handles = {}
    local function handle(name)
        if not handles[name] then handles[name] = get_param_handle(name) end
        return handles[name]
    end
    return {
        get=function(name) return handle(name):get() end,
        set=function(name,value) handle(name):set(value) end,
        sample=function(name,fallback)
            if not sensor or type(sensor[name])~="function" then return fallback or 0 end
            local ok,value=pcall(sensor[name])
            if ok and type(value)=="number" and value==value then return value end
            return fallback or 0
        end,
        wow=function()
            for _,name in ipairs({"getWOW_NoseLandingGear","getWOW_LeftMainLandingGear","getWOW_RightMainLandingGear"}) do
                if sensor and sensor[name] then local ok,v=pcall(sensor[name]);if ok and type(v)=="number" and v>.5 then return true end end
            end
            return handle("WoW"):get()>.5
        end,
    }
end
return Runtime
