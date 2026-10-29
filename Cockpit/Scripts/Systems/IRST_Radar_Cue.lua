-- GPL-3.0-or-later. Explicit, short bearing cue; no target/launch authority.
local Snapshot=dofile(LockOn_Options.script_path..'Systems/IRST_Snapshot.lua')
local M={}
function M.new(get,put)
    local s={reader=Snapshot.new(get,'F22_IRST_'),until_time=-100,id=0,epoch=0}
    function s:request(now,powered,busy)
        local status=not powered and 2 or busy and 3 or 0
        local packet=self.reader:read(now)
        local selected=packet.selected
        self.id=0
        if status==0 and packet.ready then
            for i=1,#packet.contacts do
                local t=packet.contacts[i]
                if t.id==selected and now-t.time<=.5 then
                    self.id,self.epoch,self.until_time=t.id,packet.epoch,now+5
                    status=1;break
                end
            end
        end
        if status~=1 then self.until_time=now+2 end
        put('F22_IRST_RADAR_CUE_STATUS',status)
        return status==1
    end
    function s:apply(now,scan,powered)
        if now>self.until_time or now<self.until_time-5 then
            self.until_time=-100;put('F22_IRST_RADAR_CUE_STATUS',0);return scan
        end
        if self.id==0 then return scan end
        if not scan or not powered then
            self.until_time=-100;put('F22_IRST_RADAR_CUE_STATUS',0);return scan
        end
        local packet=self.reader:read(now)
        if packet.ready and packet.epoch==self.epoch then
            for i=1,#packet.contacts do
                local t=packet.contacts[i]
                local inside=math.abs(t.az)<=math.rad(60) and math.abs(t.el)<=math.rad(60)
                if t.id==self.id and now-t.time<=.5 and inside then
                    scan.az,scan.el=t.az,t.el
                    scan.half_az,scan.half_el=math.rad(10),math.rad(10)
                    put('F22_IRST_RADAR_CUE_STATUS',1);return scan
                end
            end
        end
        self.until_time=-100;put('F22_IRST_RADAR_CUE_STATUS',0);return scan
    end
    return s
end
return M
