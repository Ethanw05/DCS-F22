-- SPDX-License-Identifier: GPL-3.0-or-later
-- Observed native commands, not a measured host avionics state. Cannon is a
-- toggle overlay (command_defs.lua 113), rather than another latched master mode.
local Modes={}
function Modes.New() return {base=105,cannon=false} end
function Modes.Value(s) return s.cannon and 113 or s.base end
function Modes.Apply(s,command,value)
    if value<=0 or command<105 or command>113 then return false end
    local previous=Modes.Value(s)
    if command==113 then s.cannon=not s.cannon
    else s.base=command;s.cannon=false end
    return previous~=Modes.Value(s)
end
return Modes
