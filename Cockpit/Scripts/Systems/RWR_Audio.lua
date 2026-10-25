-- GPL-3.0-or-later. Original warning policy; not claimed ALR-94 recordings.
-- Contact identity, native observation time and severity drive audio events.
local M={names={'ping','new_contact','contact_lost','lock','launch'}}
function M.new()
    local a={clock=0,known={},last_ping=-100,event_until=0}
    function a:update(dt,contacts,powered,muted,alert)
        self.clock=self.clock+dt
        if not powered then
            self.known={};self.event_until=0;self.last_ping=self.clock
            return {loop=nil,event=nil}
        end
        local present={};local added,lost,return_seen=false,false,false
        for _,c in ipairs(contacts) do
            present[c.source]=true
            local stamp=self.clock-c.age
            local old=self.known[c.source]
            if not old then added=true;old={stamp=stamp};self.known[c.source]=old
            elseif stamp>old.stamp+.1 then
                if c.signal==1 then return_seen=true end
                old.stamp=stamp
            end
            old.seen=self.clock
        end
        for source,old in pairs(self.known) do
            if not present[source] and self.clock-old.seen>=.5 then
                self.known[source]=nil;lost=true
            end
        end
        local loop=alert==3 and 'launch' or alert==2 and 'lock' or nil
        local event=nil
        if not loop then
            if added and self.clock>=self.event_until then event='new_contact'
            elseif lost and self.clock>=self.event_until then event='contact_lost'
            elseif return_seen and self.clock-self.last_ping>=.8 and self.clock>=self.event_until then event='ping' end
        end
        if event then self.last_ping=self.clock;self.event_until=self.clock+.4 end
        -- Muting updates identity history; unmuting never replays a backlog.
        return {loop=not muted and loop or nil,event=not muted and event or nil}
    end
    return a
end
return M
