-- GPL-3.0-or-later. Optional pod workflow; all observations remain bearing-only.
local M={capacity=16,rad=math.pi/180}
function M.new()
    local s={enabled=true,width=60,az=0,el=15,selected=0,tracking=false,contacts={},epoch=0}
    function s:clear()
        self.selected,self.tracking=0,false
        for i=#self.contacts,1,-1 do self.contacts[i]=nil end
    end
    function s:target()
        for i=1,#self.contacts do if self.contacts[i].id==self.selected then return self.contacts[i]end end
    end
    function s:command(command)
        if command==11300 then self.enabled=not self.enabled;self:clear()
        elseif command==11301 then self.width=self.width==60 and 90 or self.width==90 and 30 or 60
        elseif command==11302 then self.tracking=false;self.el=math.min(45,self.el+5)
        elseif command==11303 then self.tracking=false;self.el=math.max(0,self.el-5)
        elseif command==11304 then self.tracking=false;self.az=math.max(-75,self.az-5)
        elseif command==11305 then self.tracking=false;self.az=math.min(75,self.az+5)
        elseif command==11306 then self.az,self.el,self.tracking=0,15,false
        elseif command==11307 then
            local next_index=1
            for i=1,#self.contacts do
                if self.contacts[i].id==self.selected then next_index=i%#self.contacts+1;break end
            end
            self.selected=self.contacts[next_index] and self.contacts[next_index].id or 0
        elseif command==11308 then self.tracking=not self.tracking and self:target()~=nil
        elseif command==11309 then self.selected,self.tracking=0,false end
    end
    function s:update(packet,powered)
        if not powered or not packet.ready then self:clear();return end
        if self.epoch~=packet.epoch then self:clear();self.epoch=packet.epoch end
        for i=1,M.capacity do self.contacts[i]=packet.contacts[i]end
        if not self:target() then self.selected,self.tracking=0,false end
        local target=self:target()
        if target and packet.time-target.time>1 then self.tracking=false end
    end
    return s
end
return M
