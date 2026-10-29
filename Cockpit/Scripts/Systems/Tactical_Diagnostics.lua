-- GPL-3.0-or-later. Bounded flight evidence for association and actual link cadence.
-- Two-second snapshots; no disk ownership and no simulator control.
local M = {}
local order = {'radar','rf','mws','datalink','irst'}
local function emit(text)
    log.write('F22_FUSION', log.INFO, text)
end
local function observation(sensor, o, now)
    emit(string.format('t=%.3f sensor=%s id=%.0f epoch=%.0f fused=%.0f age=%.3f az=%.5f el=%.5f'
        ..' reporter=%.0f link=%.0f ppli=%d known=%d received=%.3f n=%.1f u=%.1f e=%.1f',
        now, sensor, o.source, o.epoch or 0, o.picture_source or 0, now-o.time, o.az, o.el,
        o.reporter or 0, o.link or 0, o.ppli and 1 or 0, o.observation_known and 1 or 0,
        o.received or -1, o.n or 0, o.u or 0, o.e or 0))
end
function M.new(get)
    local s = {last=-100}
    function s:update(now, store)
        if not log or not log.write or now>=self.last and now-self.last<2 then return end
        self.last = now
        emit(string.format('t=%.3f epoch=%.0f tracks=%d rx=%.0f raw=%.0f rejected=%.0f'
            ..' tx=%.0f newest_receive_age=%.3f oldest_receive_age=%.3f tx_age=%.3f',
            now, store.epoch, #store.contacts, get('F22_DATALINK_RX_MESSAGES'),
            get('F22_DATALINK_RAW_MESSAGES'), get('F22_DATALINK_REJECTED'),
            get('F22_IFDL_TX_MESSAGES'), get('F22_DATALINK_NEWEST_RECEIVE_AGE'),
            get('F22_DATALINK_OLDEST_RECEIVE_AGE'), get('F22_IFDL_LAST_TRANSMIT_AGE')))
        local count = 0
        for _, sensor in ipairs(order) do
            local batch = store.batches[sensor]
            for _, o in pairs(batch and batch.contacts or {}) do
                if count<176 then observation(sensor, o, now); count=count+1 end
            end
        end
        for i=1,math.min(64,#store.contacts) do
            local t = store.contacts[i]
            emit(string.format('t=%.3f track=%.0f mask=%.0f affiliation=%d conflict=%d direction=%s',
                now, t.source, t.mask, t.affiliation, t.identity_conflict and 1 or 0,
                t.direction_sensor or 'none'))
        end
    end
    return s
end
return M
