-- GPL-3.0-or-later. Evidence flags and an explicitly simulated ownship responder.
-- No waveform, cryptography, host interrogation or PPLI transmission is implied.
local M = {}
function M.evidence(track, observation, sensor)
    if not observation.friendly and not observation.hostile then return end
    track.identity_evidence = track.identity_evidence or {}
    track.identity_evidence[sensor] = { friendly = observation.friendly,
        hostile = observation.hostile, time = observation.identity_time or observation.time,
        hostile_time = observation.hostile_time or observation.identity_time or observation.time,
        time_known = sensor=='datalink' and observation.observation_known==true
            or sensor=='radar' and observation.identity_known==true
            or sensor=='rf' and observation.identity_time~=nil,
        received = observation.received,
        kind = sensor == 'datalink' and 2 or 1 } -- 1 simulator-assisted, 2 donor.
    track.friendly_protected = track.friendly_protected or observation.friendly
    track.hostile_evidence = track.hostile_evidence or observation.hostile
    track.identity_conflict = track.friendly_protected and track.hostile_evidence or false
end
function M.responder(get, put)
    local supply = dofile(LockOn_Options.script_path..'Systems/EW_Power.lua').new(get)
    local state = { requested = false, emergency = false, sequence = 0, ready = false }
    function state:publish()
        put('F22_IFF_RESPONDER_SIMULATED', 1)
        put('F22_IFF_RESPONDER_HOST_READY', 0)
        put('F22_IFF_RESPONDER_REQUESTED', self.requested and 1 or 0)
        put('F22_IFF_RESPONDER_READY', self.ready and 1 or 0)
        put('F22_IFF_RESPONDER_SUPPLY_VALID', supply.valid and 1 or 0)
        put('F22_IFF_RESPONDER_PHYSICAL_OWNER', supply.snapshot.owned and 1 or 0)
        put('F22_IFF_RESPONDER_STATUS', not self.requested and 0 or not self.clock and 4
            or not supply.valid and 3 or not supply.electrical and 2 or 1)
        put('F22_IFF_RESPONDER_EMERGENCY', self.emergency and 1 or 0)
        put('F22_IFF_REPLY_SEQUENCE', self.sequence)
        put('F22_IFF_REPLY_TIME', self.reply_time or 0)
        put('F22_IFF_REPLY_RECENT',self.ready and self.reply_time
            and self.clock-self.reply_time>=0 and self.clock-self.reply_time<=1 and 1 or 0)
    end
    function state:update(now)
        local valid = type(now) == 'number' and now >= 0 and now < 1e9
        local generation = supply.snapshot.generation
        supply:update()
        local replaced = generation > 0 and generation ~= supply.snapshot.generation
        if self.clock and (not valid or now < self.clock) then
            self.reply_time, self.emergency = nil, false
        end
        if replaced then self.reply_time, self.emergency = nil, false end
        self.clock = valid and now or nil
        self.ready = valid and self.requested and supply.electrical
        if not self.ready then self.reply_time = nil end
        self:publish()
    end
    function state:command(command)
        local now = self.clock
        if type(get_model_time) == 'function' then
            local ok, value = pcall(get_model_time)
            now = ok and value or nil
        end
        -- Check this event's supply/epoch before a previous READY can reply.
        self:update(now)
        if command == 11130 then self.requested = not self.requested
        elseif command == 11131 then self.emergency = not self.emergency
        elseif command == 11132 and self.ready then
            self.sequence = self.sequence + 1
            self.reply_time = self.clock -- A new, neutral game interrogation event only.
        end
        self:update(now)
    end
    state:update(0)
    return state
end
return M
