-- GPL-3.0-or-later. Bounded measured radar history for asynchronous RF association.
local M={capacity=128}
local function finite(v)return type(v)=='number' and v==v and math.abs(v)<1e9 end
local axes={'n','u','e','position_sigma_m'}
local function usable(o)
    if not finite(o.time)then return false end
    for _,axis in ipairs(axes)do if not finite(o[axis])then return false end end
    return o.position_sigma_m>=0
end
function M.at(history,stamp)
    if not history then return end
    local previous
    for offset=history.count-1,0,-1 do
        local b=history.samples[(history.head-offset-1)%M.capacity+1]
        if b.time==stamp then return b end
        if previous and stamp>previous.time and stamp<b.time and b.time-previous.time<=.5 then
            local f=(stamp-previous.time)/(b.time-previous.time)
            local p={time=stamp}
            for _,axis in ipairs(axes)do p[axis]=previous[axis]*(1-f)+b[axis]*f end
            -- Bounded CV interpolation error, using the estimator's declared
            -- process intensity. This does not refresh either sensor's epoch.
            p.position_sigma_m=p.position_sigma_m+math.sqrt(100*(b.time-previous.time)^3/3)
            return p
        end
        previous=b
    end
end
function M.new()
    local state={tracks={}}
    function state:update(batch,now)
        local contacts=batch and batch.contacts or {}
        for source in pairs(self.tracks)do if not contacts[source]then self.tracks[source]=nil end end
        local count=0
        for source,o in pairs(contacts)do
            count=count+1
            if count<=64 and usable(o) and now-o.time>=0 and now-o.time<=1 then
                local h=self.tracks[source]
                if not h then h={samples={},count=0,head=0,time=-1};self.tracks[source]=h end
                if o.time>h.time then
                    h.head=h.head%M.capacity+1;h.count=math.min(M.capacity,h.count+1);h.time=o.time
                    local p=h.samples[h.head] or {};h.samples[h.head]=p;p.time=o.time
                    for _,axis in ipairs(axes)do p[axis]=o[axis] end
                end
            end
        end
    end
    return state
end
return M
