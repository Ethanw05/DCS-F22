-- GPL-3.0-or-later. Requested IFF policy and the reviewed unavailable provider.
-- A future achieved backend requires a new contract and consumer review.
local provider = dofile(LockOn_Options.script_path .. 'Systems/IFF_Provider.lua')
local M = { request_seconds = 8 }

local function finite(value)
    return type(value) == 'number' and value == value and math.abs(value) < 1e9
end

local function no_go(value)
    return type(value) == 'table' and value.schema == 1
        and value.provider_ready == true and value.available == false
        and value.status == 'HOST_UNQUALIFIED'
end

local function decision(state, ok, value)
    state.provider_ready = ok and no_go(value) or false
    state.available = false
    state.status = state.provider_ready and 'HOST_UNQUALIFIED' or 'PROVIDER_UNQUALIFIED'
    state.identity, state.identity_known = -1, false
end

function M.new()
    local state = {
        automatic = true, mode = 0, started = 0, until_time = 0,
        powered = false, clock = 0, az = 0, el = 0, auto_attempted = false,
        provider = provider.new(), request_intent = {},
    }

    function state:refresh()
        local ok, value = pcall(self.provider.sample, self.provider)
        decision(self, ok, value)
    end

    function state:attempt(kind, now, az, el)
        local request = self.request_intent
        request.kind, request.time, request.az, request.el = kind, now, az, el
        request.powered, request.automatic = self.powered, self.automatic
        local ok, accepted, status = pcall(self.provider.request, self.provider, request)
        self:refresh()
        if not ok or accepted ~= false or status ~= 'HOST_UNQUALIFIED' then
            decision(self, false, nil)
        end
        return false, self.status -- Rejection is never an achieved interrogation.
    end

    function state:reset(now)
        self.mode, self.started, self.until_time = 0, 0, 0
        self.clock = finite(now) and now >= 0 and now or 0
        self.powered, self.auto_attempted = false, false
        self.az, self.el = 0, 0
        local ok, value = pcall(self.provider.reset, self.provider)
        decision(self, ok, value)
    end

    function state:requested()
        return self.powered and (self.automatic or self.mode ~= 0)
    end

    function state.enabled()
        return false -- Schema 1 only establishes the unavailable decision.
    end

    function state:update(now, powered)
        if not finite(now) or now < 0 then
            self:reset(self.clock)
            return
        end
        if now < self.clock then self:reset(now) end
        self.clock, self.powered = now, powered == true
        if not self.powered or now > self.until_time then self.mode = 0 end
        self:refresh()
        if not self.powered or not self.automatic then
            self.auto_attempted = false
        elseif self.mode == 0 and not self.auto_attempted then
            self:attempt('auto', now, self.az, self.el)
            self.auto_attempted = true
        end
    end

    function state:toggle_auto()
        self.automatic = not self.automatic
        self.auto_attempted = false
    end

    function state:request(name, now, az, el)
        if name ~= 'interrogate' and name ~= 'interrogate_los' then return false end
        if not finite(now) or now < 0 or not finite(az) or not finite(el) then return false end
        self.mode = name == 'interrogate_los' and 2 or 1
        self.started, self.until_time, self.az, self.el = now, now + M.request_seconds, az, el
        return self:attempt(name, now, az, el)
    end

    function state:publish(put)
        put('F22_RADAR_IFF_AUTO', self.automatic and 1 or 0)
        put('F22_RADAR_IFF_REQUEST', self.mode)
        put('F22_RADAR_IFF_REMAINING', self.mode ~= 0 and math.max(0, self.until_time - self.clock) or 0)
        put('F22_RADAR_IFF_REQUESTED', self:requested() and 1 or 0)
        put('F22_RADAR_IFF_PROVIDER_READY', self.provider_ready and 1 or 0)
        put('F22_RADAR_IFF_UNAVAILABLE', 1)
        put('F22_RADAR_IFF_REASON', self.provider_ready and 1 or 2)
        put('F22N_IFF_INTERROGATOR_STATUS', 0)
        put('F22_RADAR_IFF_ON', 0)
    end

    state:reset(0)
    return state
end

return M
