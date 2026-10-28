-- GPL-3.0-or-later. Consume completed RF work, independent of callback phase.
local M = {}
local function finite(value)
    return type(value)=='number' and value==value and math.abs(value)<1e9
end
local function integer(value)
    return finite(value) and value>=0 and value%1==0
end
local function publication(get,now)
    local sequence=get('F22_AESA_SEQUENCE')
    local generation=get('F22_AESA_GENERATION')
    local stamp=get('F22_AESA_TIME')
    local jobs=get('F22_AESA_SURFACE_DISCOVERY_SEQUENCE')
    local work=get('F22_AESA_SURFACE_DISCOVERY_WORK')
    if get('F22_AESA_READY')~=1 or not integer(sequence) or sequence<2 or sequence%2~=0 then return end
    if not integer(generation) or generation<1 or not integer(jobs) then return end
    if not finite(stamp) or not finite(now) or now<stamp-.01 or now-stamp>.5 then return end
    if not finite(work) or work<0 or sequence~=get('F22_AESA_SEQUENCE') then return end
    return generation,jobs,work
end
function M.new(get)
    local receiver={}
    function receiver:sample(now)
        local generation,jobs,work=publication(get,now)
        if not generation then self.generation=nil;return 0 end
        local continuous=self.generation==generation and jobs>=(self.jobs or 0) and work>=(self.work or 0)
        local credit=continuous and jobs>(self.jobs or 0) and work-self.work or 0
        self.generation,self.jobs,self.work=generation,jobs,work
        -- A stalled half-second control lease cannot deliver unbounded work.
        if credit>128 then return 0 end
        return credit
    end
    return receiver
end
return M
