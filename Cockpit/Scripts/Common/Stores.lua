-- SPDX-License-Identifier: GPL-3.0-or-later
local Math=dofile(LockOn_Options.script_path.."Common/Math.lua")
local Stores={}
function Stores.New() return {door={0,0,0,0},first=false,gun=false,pickle=false,armed=false,override=false,phase=0} end
function Stores.Cancel(s) s.first=false;s.gun=false;s.pickle=false end
function Stores.Step(s,dt,input)
    local permitted=input.power and s.armed and not input.wow and input.combat
    if not permitted then Stores.Cancel(s) end
    local maintenance=input.wow and input.power and input.groundOverride
    local ready=true
    for i=1,3 do
        -- The host does not expose a verified mapping from selected native store to bay.
        -- For actual pickle, open all bays conservatively. Manual override can select one.
        local selected=input.bay==4 or input.bay==i
        local open=maintenance or (permitted and (s.pickle or (s.override and selected)))
        s.door[i]=Math.Approach(s.door[i],open and 1 or 0,input.authority/0.4,dt)
        ready=ready and s.door[i]>=.98
    end
    s.door[4]=Math.Approach(s.door[4],permitted and (s.first or s.gun) and 1 or 0,input.authority/0.22,dt)
    local gun=permitted and s.gun and s.door[4]>=.98
    local pickle=permitted and s.pickle and ready
    if permitted and (s.first or gun) then s.phase=(s.phase+dt*2)%1 end
    return gun,pickle,permitted
end
return Stores
