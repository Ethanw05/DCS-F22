-- GPL-3.0-or-later. Nine-slot Hornet analogue and manually referenced UTC timing.
local M = { slots = 9, maximum_required_gs_mps = 600 }
local function finite(value)
    return type(value) == 'number' and value == value and math.abs(value) < 1e9
end
function M.seconds(value)
    if not finite(value) or value % 1 ~= 0 or value < 0 or value > 235959 then return end
    local hours=math.floor(value/10000)
    local minutes=math.floor(value/100)%100
    local seconds=value%100
    if minutes>=60 or seconds>=60 then return end
    return hours*3600+minutes*60+seconds
end
function M.clock_text(seconds)
    if not finite(seconds) then return '--:--:--' end
    local value=math.floor(seconds)%86400
    return string.format('%02d:%02d:%02d',math.floor(value/3600),math.floor(value/60)%60,value%60)
end
function M.new()
    local state={marks={},next_slot=1,selected=1,sequence=0,day=0,destination=0}
    for index=1,M.slots do state.marks[index]={valid=false,sequence=0,n=0,e=0,alt=0,source=''}end
    function state:capture(point,source,now)
        if type(point)~='table' or not finite(now) or not finite(point.n) or not finite(point.e)
            or not finite(point.alt) or math.abs(point.n)>1e7 or math.abs(point.e)>1e7
            or point.alt < -1000 or point.alt > 32000 or self.sequence>=16777215 then return false end
        local slot=self.next_slot
        local mark=self.marks[slot]
        self.sequence=self.sequence+1
        mark.n,mark.e,mark.alt=point.n,point.e,point.alt
        mark.source,mark.time,mark.sequence,mark.valid=source,now,self.sequence,true
        self.next_slot=slot%M.slots+1
        return true,slot
    end
    function state:select(slot)
        if not finite(slot) or slot%1~=0 or slot<1 or slot>M.slots then return false end
        self.selected=slot
        return true
    end
    function state:utc(now)
        if not finite(now) or not self.clock_epoch or now<self.clock_epoch then
            self.clock_epoch=nil;self.arrival=nil;self.arrival_input=nil;return
        end
        return self.utc_epoch+now-self.clock_epoch
    end
    function state:set_clock(value,now)
        local seconds=M.seconds(value)
        if seconds==nil or not finite(now) then return false end
        self.utc_epoch,self.clock_epoch,self.clock_input=seconds,now,value
        self.arrival=nil;self.arrival_input=nil -- A changed reference cannot preserve an old absolute deadline.
        return true
    end
    function state:set_arrival(value,now)
        local seconds=M.seconds(value)
        local utc=self:utc(now)
        if seconds==nil or not utc then return false end
        self.arrival_seconds,self.arrival_input=seconds,value
        self.arrival=(math.floor(utc/86400)+self.day)*86400+seconds
        return true
    end
    function state:set_day(day,now)
        if day~=0 and day~=1 then return false end
        self.day=day
        if self.arrival_input then self:set_arrival(self.arrival_input,now)end
        return true
    end
    function state:required_speed(distance,now)
        local utc=self:utc(now)
        if not utc then return nil,'UTC UNAVAILABLE' end
        if not self.arrival then return nil,'NO ARRIVAL' end
        if not finite(distance) or distance<0 then return nil,'NO DISTANCE' end
        local remaining=self.arrival-utc
        if remaining<=0 then return nil,'ARRIVAL PAST' end
        local speed=distance/remaining
        if speed>M.maximum_required_gs_mps then return nil,'RGS LIMIT' end
        return speed,'RGS'
    end
    return state
end
return M
