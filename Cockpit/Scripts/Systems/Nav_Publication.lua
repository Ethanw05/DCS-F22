-- GPL-3.0-or-later. Commit a completed navigation frame through two fixed slots.
local M = {}
function M.new(get, put)
    local keys = {}
    for slot=0,1 do
        local prefix='F22_NAV_SNAPSHOT_'..slot..'_'
        keys[slot]={prefix..'VALID',prefix..'TRACK',prefix..'TIME',prefix..'TERMINAL'}
        for _,key in ipairs(keys[slot])do put(key,0)end
    end
    put('F22_NAV_SNAPSHOT_SEQUENCE',0)
    put('F22_NAV_SNAPSHOT_SCHEMA',1)
    local sequence=0
    local publication={}
    function publication.publish()
        if sequence>=16777215 then return false end
        sequence=sequence+1
        local slot=keys[sequence%2]
        put(slot[1],get('F22_NAV_STEER_VALID'))
        put(slot[2],get('F22_NAV_STEER_TRACK'))
        put(slot[3],get('F22_NAV_STEER_STAMP'))
        local terminal=get('F22_NAV_SOURCE')==0 and get('F22_NAV_ARRIVED')>.5 and get('F22_NAV_OBS')<.5
        put(slot[4],terminal and 1 or 0)
        put('F22_NAV_SNAPSHOT_SEQUENCE',sequence) -- Publish only after all fields.
        return true
    end
    return publication
end
return M
