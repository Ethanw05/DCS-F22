-- GPL-3.0-or-later. Game consent/dispense transactions, never threat recipes.
local M = {}
M.status = { idle = 0, requested = 1, running = 2, complete = 3, partial = 4,
    empty = 5, stopped = 6, power = 7, fault = 8, busy = 9, invalid = 10, revoked = 11 }
M.labels = { [0] = 'IDLE', 'REQUESTED', 'RUNNING', 'COMPLETE', 'PARTIAL',
    'EMPTY', 'STOPPED', 'NO POWER', 'CM FAULT', 'BUSY', 'INVALID', 'REVOKED' }
local function quantity(value)
    return type(value) == 'number' and value >= 0 and value < 1e6 and value % 1 == 0
end
function M.new(programs)
    return setmetatable({ programs = programs, mode = 1, consent = false, status = 0,
        sequence = 0, started = 0, completed = 0, bank = 0, remaining = 0,
        observed_chaff = 0, observed_flare = 0, rejection = 0 }, { __index = M })
end
function M:stop(reason)
    if self.pending then self.barrier = self.pending end
    self.active, self.pending, self.awaiting = nil, nil, nil
    self.remaining = 0
    self.executing = false
    self.status = reason or M.status.stopped
end
function M:revoke(reason)
    self.consent = false
    self:stop(reason or M.status.revoked)
end
function M:set_mode(mode)
    if mode ~= 1 and mode ~= 2 and mode ~= 3 then return false end
    self:revoke()
    self.mode = mode
    return true
end
function M:authorize(ready)
    if not ready then return false end
    self.consent = true
    if self.awaiting and self.mode == 2 then
        local event = self.awaiting
        self.awaiting = nil
        self:begin(event.bank, event.program, ready)
        self.consent = false -- SEMI consent applies to this event only.
    end
    return true
end
function M:begin(bank, program, ready)
    self.sequence = self.sequence + 1
    if self.active or self.barrier then self.rejection = M.status.busy; return false end
    self.bank, self.rejection = bank, 0
    if not ready then self.status = M.status.fault; return false end
    if not program then self.status = M.status.invalid; return false end
    self.active, self.pending, self.awaiting = program, nil, nil
    self.remaining, self.next_time = program.repetitions, nil
    self.observed_chaff, self.observed_flare = 0, 0
    self.executing = false
    self.status = M.status.requested
    return true
end
function M:request(bank, ready)
    return self:begin(bank, self.programs:capture(bank), ready)
end
function M:event(ready)
    if self.mode == 1 or not ready or self.active or self.awaiting then return false end
    local bank = self.programs.normal
    local program = self.programs:capture(bank)
    if not program then self.status = M.status.invalid; return false end
    if self.mode == 2 then
        self.awaiting = { bank = bank, program = program }
        self.consent = false
        return true
    end
    if self.consent then return self:begin(bank, program, ready) end
    return false
end
local function invoke(device, method, count)
    if count == 0 then return true end
    local ok, result = pcall(device[method], device, count)
    return ok and result ~= false
end
function M:dispatch(device, chaff, flare, now)
    local program = self.active
    local nc, nf = math.min(chaff, program.chaff), math.min(flare, program.flare)
    if nc + nf == 0 then self:stop(M.status.empty); return end
    self.pending = { chaff = chaff, flare = flare, nc = nc, nf = nf, time = now,
        partial = nc < program.chaff or nf < program.flare }
    self.status = self.executing and M.status.running or M.status.requested
    local chaff_ok = invoke(device, 'drop_chaff', nc)
    local flare_ok = invoke(device, 'drop_flare', nf)
    if not chaff_ok or not flare_ok then self:stop(M.status.fault) end
end
function M:confirm(chaff, flare, now)
    local pending = self.pending
    if chaff > pending.chaff or flare > pending.flare then
        self:stop(M.status.stopped) -- Refill is not completion of a pending request.
        return
    end
    local dc, df = pending.chaff - chaff, pending.flare - flare
    if dc == pending.nc and df == pending.nf then
        if not self.executing then self.started=self.started+1 end
        self.executing = true
        self.status = M.status.running
        self.observed_chaff = self.observed_chaff + dc
        self.observed_flare = self.observed_flare + df
        self.pending = nil
        self.remaining = self.remaining - 1
        if pending.partial then self:stop(M.status.partial)
        elseif self.remaining == 0 then
            self.completed = self.completed + 1
            self:stop(M.status.complete)
        else self.next_time = now + self.active.interval end
    elseif dc > pending.nc or df > pending.nf or now - pending.time > 0.8 then
        self:stop(M.status.fault) -- Unknown native effect must never report COMPLETE.
    end
end
function M:update(device, chaff, flare, now, ready, powered)
    if not powered then self:revoke(M.status.power); return end
    if not ready or not quantity(chaff) or not quantity(flare) then
        if self.active or self.awaiting or self.consent then self:revoke(M.status.fault) end
        return
    end
    if self.last_time and now < self.last_time then self:revoke(M.status.stopped) end
    self.last_time = now
    local barrier = self.barrier
    if barrier then
        local reconciled = chaff <= barrier.chaff - barrier.nc and flare <= barrier.flare - barrier.nf
        local refill = chaff > barrier.chaff or flare > barrier.flare
        if reconciled or refill then self.barrier = nil else return end
    end
    if not self.active then return end
    if self.pending then self:confirm(chaff, flare, now); return end
    if not self.next_time or now + 1e-9 >= self.next_time then
        self:dispatch(device, chaff, flare, now) -- At most one cycle per callback.
    end
end
function M:publish(put)
    put('F22_CM_MODE', self.mode)
    put('F22_CM_CONSENT', self.consent and 1 or 0)
    put('F22_CM_AWAITING_CONSENT', self.awaiting and 1 or 0)
    put('F22_CM_AUTHORIZED', self.mode == 3 and self.consent and 1 or 0)
    put('F22_CM_PROGRAM_RUNNING', self.active and 1 or 0)
    put('F22_CM_EXECUTING',self.active and self.executing and 1 or 0)
    put('F22_CM_RUNNING_BANK', self.active and self.bank or 0)
    put('F22_CM_LAST_BANK', self.bank)
    put('F22_CM_BURSTS_REMAINING', self.remaining)
    put('F22_CM_STATUS', self.status)
    put('F22_CM_REJECTION', self.rejection)
    put('F22_CM_UNCONFIRMED', self.barrier and 1 or 0)
    put('F22_CM_REQUEST_SEQUENCE', self.sequence)
    put('F22_CM_STARTED_SEQUENCE', self.started)
    put('F22_CM_COMPLETED_SEQUENCE', self.completed)
    put('F22_CM_OBSERVED_CHAFF', self.observed_chaff)
    put('F22_CM_OBSERVED_FLARE', self.observed_flare)
end
return M
