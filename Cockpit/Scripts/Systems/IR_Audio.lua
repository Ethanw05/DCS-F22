-- Our audio policy, using the reference interface's signal-strength states.
-- See Standalone-F22-IDA-Research.md: FA18C 0x18031CA50.
-- A seeker tone indicates IR acquisition; it is not a computed launch envelope.
local M={}
function M.levels(enabled,kind,strength,az,el,aim9x,inhibit)
    local v={search=0,detect=0,fov=0,track=0,verify=0,quiet=0,low=0,high=0,pitch=1}
    if not enabled or inhibit then return v end
    local s=tonumber(strength) or 0
    if s~=s or s<0 or s>2 then return v end
    if kind==136 or aim9x then
        if s==0 then v.search=1
        elseif s==2 then
            if math.sqrt((az or 0)^2+(el or 0)^2)>math.rad(27) then v.verify=1 else v.track=1 end
        elseif s<=.7 then v.detect=1
        elseif s<=1 then v.fov=1 end
    else
        local a=math.min(s,1)
        v.quiet=1-a
        if s==2 then v.high=1.5
        elseif s<=1 then v.low=a^3;v.high=.3*a^5;v.pitch=a^4 end
    end
    return v
end
function M.new()
    local host,sources
    local names={'search','detect','fov','track','verify','quiet','low','high'}
    local active={}
    local audio={starts=0,stops=0,on=false}
    function audio:update(enabled,kind,strength,az,el,aim9x,inhibit)
        local v=M.levels(enabled,kind,strength,az,el,aim9x,inhibit)
        if not host and create_sound_host then
            host=create_sound_host('COCKPIT_ARMS','HEADPHONES',0,0,0)
            sources={}
            for _,name in ipairs(names) do sources[name]=host:create_sound('Aircrafts/F-22A/IR/'..name) end
        end
        if not sources then return end
        self.on=false
        for _,name in ipairs(names) do
            local source=sources[name]
            if v[name]>0 then
                source:update(name=='low' and math.max(.05,v.pitch) or 1,v[name])
                -- play_continue owns a loop. Reissuing it on a transient
                -- is_playing result can restart its waveform every update.
                if not active[name] then
                    source:play_continue();active[name]=true;self.starts=self.starts+1
                end
                self.on=true
            elseif active[name] then
                source:stop();active[name]=false;self.stops=self.stops+1
            end
        end
    end
    return audio
end
return M
