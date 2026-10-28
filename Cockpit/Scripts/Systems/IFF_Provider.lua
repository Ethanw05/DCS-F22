-- GPL-3.0-or-later. Explicit current-host no-go, not an interrogation emulator.
-- Export names alone do not qualify an owned native instance, ABI or reply.
local M = {}

function M.new()
    local state = { snapshot = {} }

    function state:sample()
        local value = self.snapshot
        value.schema = 1
        value.provider_ready = true -- The unavailable decision is established.
        value.available = false
        value.status = 'HOST_UNQUALIFIED'
        value.identity = -1
        value.identity_known = false
        value.identity_time = nil
        value.received_time = nil
        value.clock_kind = 0 -- No qualified observation clock.
        value.source_epoch = 0 -- No active native reply producer.
        value.source_id = 0
        value.request_id = 0
        return value
    end

    function state:request()
        -- Every mode, power state and argument has the same no-go result.
        -- No dispatch, request queue or pending reply is created.
        self:sample()
        return false, 'HOST_UNQUALIFIED'
    end

    function state:reset()
        return self:sample()
    end

    state:reset()
    return state
end

return M
