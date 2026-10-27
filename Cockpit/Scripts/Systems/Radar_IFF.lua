-- GPL-3.0-or-later. Identification policy, not a recovered F-22 IFF waveform.
-- The host has one interrogator switch. LOS scope gates our acceptance of
-- newly measured replies; it does not claim a physically narrow native beam.
local M={request_seconds=8,los_half_angle=math.rad(3)}
local function finite(v)return type(v)=='number' and v==v and math.abs(v)<1e9 end
function M.new()
    local s={automatic=true,mode=0,started=0,until_time=0,powered=false,clock=0,az=0,el=0}
    function s:update(now,powered)
        if not finite(now) then powered=false;now=self.clock end
        if now<self.clock or not powered or now>self.until_time then self.mode=0 end
        self.clock=now;self.powered=powered
    end
    function s:enabled()return self.powered and (self.automatic or self.mode~=0)end
    function s:toggle_auto()self.automatic=not self.automatic end
    function s:request(name,now,az,el)
        if not finite(now) or not finite(az) or not finite(el) then return end
        self.mode=name=='interrogate_los' and 2 or 1
        self.started=now;self.until_time=now+M.request_seconds;self.az=az;self.el=el
    end
    function s:reply(value,observed,az,el,simulator_identification)
        -- A complete detected-contact record carries the simulator's explicit
        -- friend/foe classification. A bare STT FRIENDLY boolean does not:
        -- false/no response there remains unknown, not automatically hostile.
        if (value~=1 and not(simulator_identification and value==0)) or not self:enabled() then return -1 end
        if self.mode~=0 then
            if not finite(observed) or observed<self.started then return -1 end
            if self.mode==2 then
                if not finite(az) or not finite(el) then return -1 end
                local da=(az-self.az+math.pi)%(2*math.pi)-math.pi
                if math.abs(da)>M.los_half_angle or math.abs(el-self.el)>M.los_half_angle then return -1 end
            end
        end
        return value
    end
    return s
end
return M
