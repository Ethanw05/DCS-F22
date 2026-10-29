-- Bounded AP-drop notification transport. It never asserts a damaged FCS.
local M = {}
local prefix = 'F22_AP_ANN_'
local function finite(value)
    return type(value)=='number' and value==value and math.abs(value)<math.huge
end
function M.integer(value,low,high)
    return finite(value) and value>=low and value<=high and value%1==0
end
function M.next_epoch(previous)
    return M.integer(previous,1,16777214) and previous+1 or 1
end
function M.publish(put,sequence,epoch,generation,now,event)
    sequence = sequence>=16777212 and 2 or sequence+2
    put(prefix..'SEQUENCE',sequence-1)
    put(prefix..'SCHEMA',1);put(prefix..'EPOCH',epoch)
    put(prefix..'GENERATION',generation);put(prefix..'TIME',now or -1)
    put(prefix..'VALID',event and 1 or 0)
    put(prefix..'TICKET',event and event.ticket or 0)
    put(prefix..'ONSET',event and event.onset or -1)
    put(prefix..'UNTIL',event and event.until_time or -1)
    put(prefix..'SEQUENCE',sequence)
    return sequence
end
local function payload(get,now,generation)
    local epoch,ticket = get(prefix..'EPOCH'),get(prefix..'TICKET')
    local stamp,onset,deadline = get(prefix..'TIME'),get(prefix..'ONSET'),get(prefix..'UNTIL')
    if not M.integer(epoch,1,16777215) or not M.integer(ticket,1,16777215) then return end
    if get(prefix..'SCHEMA')~=1 or get(prefix..'VALID')~=1 or get(prefix..'GENERATION')~=generation then return end
    if not finite(stamp) or stamp>now or now-stamp>.25 then return end
    if not finite(onset) or not finite(deadline) or onset>now or deadline<=now then return end
    if deadline-onset>5.001 or deadline<=onset then return end
    return {epoch=epoch,ticket=ticket,onset=onset,until_time=deadline}
end
function M.read(get,now,generation)
    if not finite(now) or not M.integer(generation,1,4294967295) then return end
    local before = get(prefix..'SEQUENCE')
    if not M.integer(before,2,16777214) or before%2~=0 then return end
    local event = payload(get,now,generation)
    if not event or before~=get(prefix..'SEQUENCE') or event.epoch~=get(prefix..'EPOCH') then return end
    return event
end
return M
