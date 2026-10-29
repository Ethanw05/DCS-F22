-- GPL-3.0-or-later. Original warning policy; not claimed ALR-94 recordings.
-- Hornet-inspired policy with our existing recordings: acquisition/status-change
-- one-shots and a distinct repeating detected-launch alarm. No routine sweep or
-- disappearing-contact tones. The recordings are not claimed ALR-67 recordings.
local Receiver=dofile(LockOn_Options.script_path..'Systems/RWR_Computer.lua')
local M={names={'new_contact','lock','launch'}}
local function observation(known,c)
    local level=Receiver.coasting(c)and 0 or c.signal
    local old=known[c.source]
    local acquired=level>0 and not old
    local locked=level==2 and (not old or old.level<2)
    return level,acquired,locked
end
local function cue(added,locked,alert,muted)
    if muted then return {loop=nil,event=nil} end
    if alert==3 then return {loop='launch',event=nil} end
    local event=locked and 'lock' or added and 'new_contact' or nil
    return {loop=nil,event=event}
end
function M.new()
    local a={known={}}
    function a:update(_dt,contacts,powered,muted,alert)
        if not powered then
            self.known={}
            return {loop=nil,event=nil}
        end
        local present={};local added,locked=false,false
        for i=1,math.min(#contacts,16) do
            local c=contacts[i]
            local level,new_source,new_lock=observation(self.known,c)
            present[c.source]={level=level}
            added=added or new_source;locked=locked or new_lock
        end
        self.known=present
        -- Muting updates identity history; unmuting never replays a backlog.
        return cue(added,locked,alert,muted)
    end
    return a
end
return M
